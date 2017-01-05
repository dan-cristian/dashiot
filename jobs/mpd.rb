require 'ruby-mpd'

$mpd_mutex = Mutex.new

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
$cmpd_list = [Cmpd.new('living', 6600, @IP), Cmpd.new('headset', 6601, @IP), Cmpd.new('beci', 6602, @IP),
  Cmpd.new('dormitor', 6603, @IP), Cmpd.new('baie', 6604, @IP), Cmpd.new('pod', 6605, @IP)]
$mpd_current_index = nil

post '/mpd/change_mpd' do
  $mpd_mutex.synchronize do
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
end

post '/mpd/exec_cmd' do
  $mpd_mutex.synchronize do
    cmd_name = params["cmd_name"]
    puts "Executing command #{cmd_name}"
    mpd = $cmpd_list[$mpd_current_index].mpd
    mpd.connect unless mpd.connected?
    result = mpd.send(cmd_name)
    puts"Exec result #{result}"
    update_mpd()
    return JSON.generate({"status" => "OK"})
  end
end

# http://www.rubydoc.info/github/archSeer/ruby-mpd/master/MPD
post '/mpd/exec_cmd_cust' do
  $mpd_mutex.synchronize do
    cmd_name = params["cmd_name"]
    puts "Executing custom command #{cmd_name}"
    mpd = $cmpd_list[$mpd_current_index].mpd
    mpd.connect unless mpd.connected?
    case cmd_name
    when 'toggle'
      puts "Set pause to #{mpd.playing?}"
      if mpd.playing? or mpd.paused?
        mpd.pause = mpd.playing?
      elsif mpd.stopped?
        mpd.play
      end
    when 'volume_up'
      mpd.volume = mpd.volume + 5
    when 'volume_down'
      mpd.volume = mpd.volume - 5
    when 'repeat'
      mpd.repeat = !mpd.repeat?
    when 'random'
      mpd.random = !mpd.random?
    when /output:/
      out_zone = cmd_name.split(':')[1]
      toggle_output(mpd, out_zone)
    else
      puts "Unknown command #{cmd_name}"
    end
    update_mpd()
    return JSON.generate({"status" => "OK"})
  end
end

post '/mpd/exec_cmd' do
  $mpd_mutex.synchronize do
    cmd_name = params["cmd_name"]
    puts "Executing command #{cmd_name}"
    mpd = $cmpd_list[$mpd_current_index].mpd
    mpd.connect unless mpd.connected?
    result = mpd.send(cmd_name)
    puts"Exec result #{result}"
    update_mpd()
    return JSON.generate({"status" => "OK"})
  end
end

def toggle_output(mpd, output_name)
  for i in 0..mpd.outputs.count - 1
    out = mpd.outputs[i]
    if out[:outputname].include? output_name
      puts "Toggling output #{out[:outputname]}, before is #{out[:outputenabled]}"
      mpd.toggleoutput(out[:outputid])
      return
    end
  end
  puts "Cannot toggle output for zone #{output_name}"
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
  puts "Updating mpd #{$cmpd_list[$mpd_current_index].zone_name}"
  mpd = $cmpd_list[$mpd_current_index].mpd
  #mpd.disconnect if mpd.connected? 
  mpd.connect unless mpd.connected?
  unless mpd.current_song.nil?
    song = mpd.current_song.artist + ' - ' + mpd.current_song.title
  else
    song = '(none)'
  end
  for i in 0..2
    begin
      if mpd.status[:state] == :play
        playstate = 'playing'
      elsif mpd.status[:state] == :pause
        playstate = 'paused'
      elsif mpd.status[:state] == :stop
        playstate = 'stopped'
      else playstate = 'undefined!'
      end
      mpd_zone = $cmpd_list[$mpd_current_index].zone_name
      mpd_random = mpd.random? ? 'on' : 'off'
      mpd_repeat = mpd.repeat? ? 'on' : 'off'
      outputs_enabled = []
      #outputs_disabled = []

      for i in 0..mpd.outputs.count - 1
        out = mpd.outputs[i]
        if out[:outputenabled]
          outputs_enabled << out[:outputname]
        #else
        #  outputs_disabled << out[:outputname]
        end
      end
      break
    rescue => e
      puts "!!!!!!!!!!!!!!!!!!! That crash again, err=#{e}"
    end
  end
  #puts "Updating song=#{song} state=#{playstate} zone=#{mpd_zone}"
  send_event('mpd', mpd_song: song, mpd_volume: mpd.volume, mpd_playstate: playstate,
    mpd_zone: mpd_zone, mpd_random: mpd_random, mpd_repeat: mpd_repeat,
    outputs_enabled: outputs_enabled)
end

SCHEDULER.every '20s', :first_in => 0 do |job|
  run_start = Time.now
  $mpd_mutex.synchronize do
    update_mpd()
  end
  elapsed = (Time.now - run_start).to_i
  puts "MPD duration=#{elapsed} seconds"
end