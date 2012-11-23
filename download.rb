#!/usr/bin/env ruby
require 'fileutils'
require 'cgi'

FileUtils::mkdir('mp4') unless File::exists?('mp4')
FileUtils::mkdir('aac') unless File::exists?('aac')
FileUtils::mkdir('mp3') unless File::exists?('mp3')

output = `curl -v 2> /dev/stdout`
if output[0, 4].downcase != 'curl'
    puts "Error: curl is required to run this script."
    exit
end
output = `rtmpdump 2> /dev/stdout`
if output[0, 8].downcase != 'rtmpdump'
    puts "Error: rtmpdump is required to run this script."
    exit
end
output = `ffmpeg -v 2> /dev/stdout`
if output[0, 6].downcase != 'ffmpeg'
    puts "Error: ffmpeg is required to run this script."
    exit
end
output = `sox -v 2> /dev/stdout`
if output[0, 3].downcase != 'sox'
    puts "Error: sox is required to run this script."
    exit
end
output = `id3tag -v 2> /dev/stdout`
if output[0, 6].downcase != 'id3tag'
    puts "Error: id3tag is required to run this script."
    exit
end

links = DATA.read.split("\n").collect { |x| x.strip }.reject { |x| x.empty? }

def parseTime(time)
    unless /\d{2}:\d{2}:\d{2}/ =~ time
        puts "Error: Unexpected time format: #{time}."
        exit 1
    end
    return time[0, 2].to_i * 3600 + time[3, 2].to_i * 60 + time[6, 2].to_i
end

links.each do |x|
    next if x.strip[0, 1] == '#'
    link = x.dup
    postprocess = ''
    if x.include?('[')
        link = x[0, x.index(' ') - 1].strip
        postprocess = x.match(/\[([^\]]+)\]/).to_a[1]
    end
    link += '/' unless link[-1, 1] == '/'
    html = ''
    IO.popen("curl -s -o /dev/stdout \"#{link}\"", 'r') do |f|
        html = f.read
    end
    title = CGI.unescapeHTML(html.match(/<title>([^<]*)<\/title>/).to_a[1]).strip
    title = '10 vor 11: Sendung vom 02.04.2012 - Dampfer kaputt!' if link == 'http://www.dctp.tv/filme/10vor11-02042012/'
    puts title
    url = html.match(/[0-9a-f]+_iphone\.m4v/).to_a[0]
    next unless url
    unless url.size == 43
        puts "Error: Video not found."
        next
    end
    mp4Path = "mp4/#{title}.mp4"
    unless File::exist?(mp4Path)
        puts "Downloading video..."
        command = "rtmpdump -q -o \"#{mp4Path.gsub('"', '\"')}\" --host \"s2pqqn4u96e4j8.cloudfront.net\" --playpath \"mp4:#{url}\" --protocol 3 --tcUrl \"rtmpe://s2pqqn4u96e4j8.cloudfront.net/cfx/st/\" --app \"/cfx/st/\" --swfUrl \"http://dctp-front.dctp.tv/dctptv_v91.swf\""
        system(command)
    end
    aacPath = "aac/#{title}.aac"
    unless File::exist?(aacPath)
        puts "Extracting audio..."
        command = "ffmpeg -i \"#{mp4Path.gsub('"', '\"')}\" -acodec copy \"#{aacPath.gsub('"', '\"')}\" 2> /dev/null"
        system(command)
    end
    mp3Path = "mp3/#{title}.mp3"
    unless File::exist?(mp3Path)
        puts "Converting to MP3 (and removing cruft)..."
        unless postprocess.empty?
            parts = postprocess.split(',')
            partFiles = []
            useParts = []
            parts.each do |part|
                times = part.strip.split('-').collect { |x| x.strip }
                start = parseTime(times[0])
                duration = parseTime(times[1]) - start
                duration += 10
                path1 = 'temp' + partFiles.size.to_s + '.wav'
                partFiles << path1
                command = "sox -q -t ffmpeg \"#{aacPath.gsub('"', '\"')}\" \"#{path1}\" pad 5 30"
                system(command)
                path2 = 'temp' + partFiles.size.to_s + '.wav'
                partFiles << path2
                command = "sox -q \"#{path1}\" \"#{path2}\" trim #{start} #{duration} fade h 5 0"
                system(command)
                useParts << path2
            end
            partFiles << "combined.wav"
            command = "sox -q #{useParts.collect { |x| '"' + x + '" ' }} \"#{partFiles.last}\""
            system(command)
            command = "sox -q combined.wav temp.wav silence 1 0.1 0 reverse"
            system(command)
            command = "sox -q temp.wav out.wav silence 1 0.1 0 reverse"
            system(command)
            command = "sox -q out.wav \"#{mp3Path.gsub('"', '\"')}\""
            system(command)
            partFiles.each do |path|
                FileUtils::rm(path)
            end
            FileUtils::rm('temp.wav')
            FileUtils::rm('out.wav')
        else
            command = "sox -q -t ffmpeg \"#{aacPath.gsub('"', '\"')}\" \"#{mp3Path.gsub('"', '\"')}\""
            system(command)
        end
        command = "id3tag -a \"Helge Schneider\" -s \"#{title.gsub('"', '\"')}\" -A \"DCTP.tv\" \"#{mp3Path.gsub('"', '\"')}\""
        system(command)
    end
end

__END__
http://www.dctp.tv/filme/helge-schneider-fukushima/ [00:01:16-00:06:42]
http://www.dctp.tv/filme/helge-schneider-tiefseetaucher/ [00:00:19-00:04:20]
http://www.dctp.tv/filme/helge-schneider-als-hollaender/
http://www.dctp.tv/filme/helge-schneider-baerenfreund/ [00:00:55-00:03:14]
http://www.dctp.tv/filme/helge-schneider-lehrer/ [00:00:00-00:06:58]
http://www.dctp.tv/filme/helge-schneider-nobelpreistraeger/ [00:00:46-00:01:17]
http://www.dctp.tv/filme/helge-schneider-strauss-kahn/ [00:00:30-00:05:47]
http://www.dctp.tv/filme/helge-schneider-motorradrennfahrer/ [00:00:52-00:08:11]
http://www.dctp.tv/filme/helge_schneider_hubble_schraube-verloren-werkzeug-vergessen/ [00:01:56-00:09:12]
# http://www.dctp.tv/filme/lichtschlangenmensch-helge-schneider/
http://www.dctp.tv/filme/helge-schneider-eiersoldat/ [00:00:43-00:04:38]
http://www.dctp.tv/filme/der-letzte-der-nibelungen/ [00:00:10-00:11:13]
http://www.dctp.tv/filme/hartbrettbohrer-helge-schneider/ [00:01:45-00:06:29]
http://www.dctp.tv/filme/blind-kann-ich-geld-zaehlen-helge-schneider/
http://www.dctp.tv/filme/ich-war-ein-treuer-husar-helge-schneider/ [00:00:00-00:07:10]
http://www.dctp.tv/filme/plattmachen-ist-meine-leidenschaft/ [00:00:00-00:09:46,00:11:00-00:17:10,00:18:00-00:22:33]
http://www.dctp.tv/filme/ich-bin-eine-leseratte-helge-schneider/ [00:01:35-00:10:30,00:11:00-00:22:47]
http://www.dctp.tv/filme/helge-schneider-vom-henker-zum-aktiven-sterbehelfer/
http://www.dctp.tv/filme/helge_schneider_im-weltall-braucht-man-keine-lesebrille/ [00:01:32-00:06:55,00:07:23-00:08:01]
http://www.dctp.tv/filme/helge-schneider-mozartluege/ [00:01:03-00:13:29]
http://www.dctp.tv/filme/helge-schneider-extremsport-pur-das-felsenrad/ [00:00:45-00:13:30]
http://www.dctp.tv/filme/das-fahrzeug-ist-die-zweite-haut/ [00:00:52-00:14:21]
# (part/duplicate) http://www.dctp.tv/filme/wanderer-am-meeresgrund/ [00:00:28-00:05:18,00:06:16-00:08:32]
http://www.dctp.tv/filme/helge-schneider-der-unterwasserwanderer/ [00:00:37-00:09:50,00:11:11-00:15:41]
http://www.dctp.tv/filme/helge-schneider-schweinegrippe-general/ [00:00:28-00:08:01]
http://www.dctp.tv/filme/helge-schneider-beinahe-waeren-wir-roemer-geworden/ [00:01:25-00:04:55,00:05:35-00:08:30,00:09:28-00:14:23]
http://www.dctp.tv/filme/helge-schneider-zigarren-willi/ [00:00:35-00:06:50,00:07:17-00:11:21]
http://www.dctp.tv/filme/helge-schneider-dr-mabuse-als-spieler/ [00:00:00-00:03:16,00:03:50-00:13:11]
http://www.dctp.tv/filme/10vor11-02042012/ [00:01:10-00:01:52,00:04:00-00:13:55,00:14:38-00:24:02]
http://www.dctp.tv/filme/helge_schneider_gesang-sieg/ [00:00:59-00:15:00]
http://www.dctp.tv/filme/tag-der-geschichte-schreibt/
# (duplicate) http://www.dctp.tv/filme/cousin-von-asterix/ [00:00:25-00:07:59]
http://www.dctp.tv/filme/der-gluecksvermittler/ [00:00:43-00:09:05,00:09:40-00:11:10]
http://www.dctp.tv/filme/hitlers-maske/ [00:00:20-00:05:28]
http://www.dctp.tv/filme/wo-der-fuehrer-ist/
http://www.dctp.tv/filme/hobbyhistoriker-in-berlin/
http://www.dctp.tv/filme/heroischer-kampf-berlin/
http://www.dctp.tv/filme/news-stories-14102012/
http://www.dctp.tv/filme/10vor11-19112012/

