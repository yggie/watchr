#!/usr/bin/env ruby

require 'pry'
require 'sonos'
require 'awesome_print'
require 'filewatcher'

@help = {
  what: 'show me what is playing',
  shit_it: 'next track (till the API is sorted)',
  skip_it: 'next track',
  stop_it: 'pause the current track',
  stomp_it: 'remove the current track from the queue',
  play_it: 'play the current track',
  help_me: 'print the help text for watchr',
  exit: 'stop watchr'
}

def help_me
  @help
end

def system
  @system
end

def speaker
  @speaker ||= system.speakers.last
end

def now_playing
  speaker.now_playing
end

def shit_it(item=nil)
  item ||= now_playing[:title]
  @speaker.next
end

def skip_it
  speaker.next
end

def stop_it
  speaker.pause
end

def stomp_it
  speaker.remove_from_queue(now_playing[:queue_id])
end

def play
  speaker.play
end

def what(playing = nil)
  playing = speaker.now_playing
  notify(title: playing[:title],
    subtitle: "#{playing[:artist]} (#{playing[:album]})",
    message: "click here to skip it")
  playing
end

def notify(options={})
  s = ''
  if options[:title]
    options[:execute] = %Q{echo '#{options[:title]}' >> '#{@watch}'}
  end
  @default_options.merge(options).each_pair do |key, value|
    s << %Q{ -#{key} "#{value}"}
  end

  `terminal-notifier#{s}`
end

# -----------------------------------------------------------------------------

system = Sonos::System.new
@speaker = system.speakers.first
puts "Found #{system.speakers.count} speakers"
system.speakers.each_with_index do |speaker, i|
  puts "  #{i + 1}. #{speaker.name}"
end

puts ''
@help.each_pair do |key, value|
  puts "\t#{key} - #{value}"
end
puts ''

threads = []
last_playing = ''
@dir = `pwd`
Dir.mkdir('tmp/') unless Dir.exists?('tmp/')
tmp_file = Tempfile.new('skip_list', 'tmp')
@watch = [@dir.gsub("\n", ''), tmp_file.path].join('/')
@default_options = {
  sender: 'com.sonos.macController',
  contentImage: 'http://ecx.images-amazon.com/images/I/51H9mCZPB-L._SL500_SS100_.jpg'
}

threads << Thread.new do
  loop do
    playing = speaker.now_playing
    if playing && playing[:uri] != last_playing
      last_playing = playing[:uri]
      notify title: playing[:title],
        subtitle: "#{playing[:artist]} (#{playing[:album]})",
        message: "click here to skip it"
    end
    sleep 5
  end
end

threads << Thread.new do
  FileWatcher.new(tmp_file).watch do |filename|
    begin
      File.open(filename, 'r+') do |file|
        while (item = file.gets)
          shit_it(item)
        end
        file.truncate(0)
      end

    rescue => err
      puts "#{err.class}: #{err.message}"
    end
  end
end

pry_thread = Thread.new do
  pry
  threads.each { |t| t.exit }
  tmp_file.close
  tmp_file.unlink
end

threads.each { |t| t.join }
pry_thread.join
