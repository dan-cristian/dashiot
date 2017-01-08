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

$mpd_mutex = Mutex.new
$last_mpd_update = Time.now
@IP='192.168.0.9'
$cmpd_list = [Cmpd.new('living', 6600, @IP), Cmpd.new('headset', 6601, @IP), Cmpd.new('beci', 6602, @IP),
  Cmpd.new('dormitor', 6603, @IP), Cmpd.new('baie', 6604, @IP), Cmpd.new('pod', 6605, @IP)]
$mpd_current_index = nil
$DELETE_MPD_COMMAND = "/home/scripts/audio/mpc-play.sh <mpd_zone_name> delete"

def change_mpd(mpd_name)
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

post '/mpd/change_mpd' do
  $mpd_mutex.synchronize do
    mpd_name = params["mpd_name"]
    change_mpd(mpd_name)
  end
end

def exec_cmd(cmd_name)
  puts "Executing command #{cmd_name}"
  mpd = $cmpd_list[$mpd_current_index].mpd
  mpd.connect unless mpd.connected?
  result = mpd.send(cmd_name)
  puts"Exec result #{result}"
  update_mpd()
end

post '/mpd/exec_cmd' do
  $mpd_mutex.synchronize do
    cmd_name = params["cmd_name"]
    exec_cmd(cmd_name)
    return JSON.generate({"status" => "OK"})
  end
end

def exec_cmd_cust(cmd_name)
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
  when 'trash'
    sys_cmd = $DELETE_MPD_COMMAND.sub('<mpd_zone_name>', $cmpd_list[$mpd_current_index].zone_name)
    puts "Executing trash command #{sys_cmd}"
    res_cmd = `#{sys_cmd}`
    puts "Command result is #{res_cmd}"
  when /output:/
    out_zone = cmd_name.split(':')[1]
    toggle_output(mpd, out_zone)
  else
    puts "Unknown command #{cmd_name}"
  end
  update_mpd()
end

# http://www.rubydoc.info/github/archSeer/ruby-mpd/master/MPD
post '/mpd/exec_cmd_cust' do
  $mpd_mutex.synchronize do
    cmd_name = params["cmd_name"]
    exec_cmd_cust(cmd_name)
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

post '/mpd/select_playlist' do
  $mpd_mutex.synchronize do
    playlist_name = params["playlist_name"]
    puts "Selecting playlist #{[playlist_name]}"
    mpd = $cmpd_list[$mpd_current_index].mpd
    mpd.connect unless mpd.connected?
    playlist = mpd.playlists.find {|p| p.name == playlist_name}
    if !playlist.nil?
      mpd.stop
      mpd.clear
      started = false
      for song in playlist.songs
        puts "Adding song #{song.title} - #{song.artist}"
        begin
          mpd.add(song)
        rescue => e
          puts "Warning, cannot add song #{song.file}, error #{e}"
        end
        if !started
          mpd.play
          started = true
        end  
      end
    else
      puts "Warning, no playlist found with name #{playlist_name}"
    end
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
    $mpd_current_index = i if mpd.status[:state] == :play and $mpd_current_index.nil?
  end
  $mpd_current_index = 0 if $mpd_current_index.nil?
  #debug
  #exec_cmd_cust('trash')
end

def update_mpd()
  init() if $cmpd_list[0].mpd.nil?
  puts "Updating mpd #{$cmpd_list[$mpd_current_index].zone_name}"
  mpd = $cmpd_list[$mpd_current_index].mpd
  #mpd.disconnect if mpd.connected?
  mpd.connect unless mpd.connected?
  unless mpd.current_song.nil? or mpd.current_song.artist.nil?
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
      if mpd.status[:time].nil?
        mpd_songposition = 0
        mpd_songduration = 0
      else
        mpd_songposition = mpd.status[:time][0]
        mpd_songduration = mpd.status[:time][1]
      end

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
      zones_playing = []
      for i in 0..$cmpd_list.count - 1
        tmpmpd = $cmpd_list[i].mpd
        tmpmpd.connect unless tmpmpd.connected?
        zones_playing << $cmpd_list[i].zone_name if tmpmpd.status[:state] == :play
      end
      break
    rescue => e
      puts "!!!!!!!!!!!!!!!!!!! That crash again, err=#{e}"
      puts e.backtrace
      mpd.disconnect if mpd.connected?
      mpd.connect unless mpd.connected?
    end
  end
  #puts "Updating song=#{song} state=#{playstate} zone=#{mpd_zone}"
  send_event('mpd', mpd_song: song, mpd_volume: mpd.volume, mpd_playstate: playstate,
    mpd_zone: mpd_zone, mpd_random: mpd_random, mpd_repeat: mpd_repeat,
    outputs_enabled: outputs_enabled, mpd_songposition: mpd_songposition,
    mpd_songduration: mpd_songduration, mpd_zonesplaying: zones_playing)
  $last_mpd_update = Time.now
end

SCHEDULER.every '30s', allow_overlapping: false, :first_in => 0 do |job|
  run_start = Time.now
  $mpd_mutex.synchronize do
    elapsed = (Time.now - $last_mpd_update).to_i
    #only update if no updates in the last 30 seconds
    update_mpd() if elapsed >=30 or $mpd_current_index.nil?
  end
  elapsed = (Time.now - run_start).to_i
  puts "MPD duration=#{elapsed} seconds"
end