require 'ruby-mpd'

class Cmpd
  def initialize(zone_name, port, ip)
    @zone_name = zone_name
    @port = port
    @ip = ip
    @mpd = nil
  end
  attr_reader :zone_name, :port, :ip, :mpd
  attr_writer :mpd
end

@IP='192.168.0.9'
$mpd_server_name_list = ['living', 'headset', 'beci', 'dormitor', 'baie', 'pod']
$mpd_server_port_list = [6600, 6601, 6602, 6603, 6604, 6605]
$mpd_server_ip_list   = [@IP, @IP, @IP, @IP, @IP, @IP]
$mpd_list             = Array.new(6)

$cmpd_list = [Cmpd.new('living', 6600, @IP), Cmpd.new('headset', 6601, @IP), Cmpd.new('beci', 6602, @IP),
  Cmpd.new('dormitor', 6603, @IP), Cmpd.new('baie', 6604, @IP), Cmpd.new('pod', 6605, @IP)]
$mpd_current_index = nil

post '/mpd/change_mpd' do
  mpd_name = params["mpd_name"]
  for i in 0..$cmpd_list.count - 1
    if $cmpd_list[i].zone_name == mpd_name
      puts "Selected zone index #{i}"
      $mpd_current_index = i
      update_mpd()
      return
    end
  end
  puts "Warning, no mpd instance found for name #{mpd_name}"
end

post '/mpd/exec_cmd' do
  cmd_name = params["cmd_name"]
  puts "Executing command #{cmd_name}"
  mpd = $cmpd_list[$mpd_current_index].mpd
  mpd.connect unless mpd.connected?
  result = mpd.send(cmd_name)
  puts"Exec result #{result}"
  update_mpd()
  return JSON.generate({"status" => "OK"})
end

post '/mpd/exec_cmd_cust' do
  cmd_name = params["cmd_name"]
  puts "Executing custom command #{cmd_name}"
  mpd = $cmpd_list[$mpd_current_index].mpd
  mpd.connect unless mpd.connected?
  case cmd_name
  when 'toggle'
    puts "Set pause to #{mpd.playing?}"
    mpd.pause = mpd.playing?
  when 'volume_up'
    mpd.volume = mpd.volume + 5
  when 'volume_down'
    mpd.volume = mpd.volume - 5
  when 'repeat'
    mpd.repeat = !mpd.repeat?
  when 'random'
    mpd.random = !mpd.random?
  else
    puts "Unknown command #{cmd_name}"
  end
  update_mpd()
  return JSON.generate({"status" => "OK"})
end


def init()
  for i in 0..$cmpd_list.count - 1
	  mpd = MPD.new $cmpd_list[i].ip, $cmpd_list[i].port
	  mpd.connect
    puts "Connected" if mpd.connected?
    $cmpd_list[i].mpd = mpd
  end
  $mpd_current_index = 0
end

def update_mpd()
  init() if $cmpd_list[0].mpd.nil?
  puts "Updating mpd #{$mpd_server_name_list[$mpd_current_index]}"
  mpd = $cmpd_list[$mpd_current_index].mpd
  mpd.connect unless mpd.connected?
  unless mpd.current_song.nil?
    song = mpd.current_song.artist + ' - ' + mpd.current_song.title
  else
    song = '(none)'
  end
  if mpd.playing?
    playstate = 'playing'
  elsif mpd.paused?
    playstate = 'paused'
  elsif mpd.stopped?
    playstate = 'stopped'
  else playstate = 'undefined!'
  end
  mpd_zone = $cmpd_list[$mpd_current_index].zone_name
  mpd_random = mpd.random? ? 'on' : 'off'
  mpd_repeat = mpd.repeat? ? 'on' : 'off'
  puts "Updating song=#{song} state=#{playstate}"
  send_event('mpd', mpd_song: song, mpd_volume: mpd.volume, mpd_playstate: playstate, 
    mpd_zone: mpd_zone, mpd_random: mpd_random, mpd_repeat: mpd_repeat)
end

SCHEDULER.every '20s', :first_in => 0 do |job|
  run_start = Time.now
  update_mpd()
  elapsed = (Time.now - run_start).to_i
  puts "MPD duration=#{elapsed} seconds"
end