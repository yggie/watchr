#!/usr/bin/env ruby

require 'pry'
require 'sonos'
require 'awesome_print'
require 'filewatcher'

system = Sonos::System.new
@speaker = system.speakers.first
@help = {
  what: 'show me what is playing',
  shit_it: 'next track (till the API is sorted)',
  next: 'next track',
  pause: 'pause the current track',
  play: 'play the current track',
  watchr_help: 'print the help text for watchr',
  exit: 'stop watchr'
}

def watchr_help
  @help
end

puts "Found #{system.speakers.count} speakers"
system.speakers.each_with_index do |speaker, i|
  puts "  #{i + 1}. #{speaker.name}"
end

puts ''
@help.each_pair do |key, value|
  puts "\t#{key} - #{value}"
end
puts ''

def shit_it
  @speaker.next
end

def next
  @speaker.next
end

def pause
  @speaker.pause
end

def play
  @speaker.play
end

def what(playing = nil)
  playing = @speaker.now_playing
  notify(title: playing[:title],
    subtitle: "#{playing[:artist]} (#{playing[:album]})",
    message: "click here to skip it")
  playing
end

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

threads << Thread.new do
  loop do
    playing = @speaker.now_playing
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
      shitlist = File.read(filename)
      shitlist.split("\n").each do |item|
        if item
          shit_it
        end
      end

      File.open(filename, 'w') { |file| file.truncate(0) }
    rescue => err
      puts "#{err.class}: #{err.message}"
    end
  end
end

pry_thread = Thread.new { pry; threads.each { |t| t.exit } }

threads.each { |t| t.join }
pry_thread.join
