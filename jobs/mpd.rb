require 'ruby-mpd'

$mpd_server_name_list = ['living', 'headset']
$mpd_server_port_list = [6600, 6601]
$mpd_server_ip_list = ['192.168.0.9', '192.168.0.9']
$mpd_list = Array.new(2)

$mpd_current_index = nil

post '/mpd/change_mpd' do
  mpd_name = params["mpd_name"]
  $mpd_current_index = $mpd_server_name_list.index(mpd_name)
  if $mpd_current_index.nil?
	  puts "Warning, no mpd instance found for name #{mpd_name}"
	else
	  update()
  end
end

def init()
  for i in 0..$mpd_server_name_list.count - 1
	mpd = MPD.new $mpd_server_ip_list[i], $mpd_server_port_list[i]
	mpd.connect
	song = mpd.current_song.artist + ' - ' + mpd.current_song.title
	hostname = mpd.hostname
	puts "Connected to #{hostname} song is #{song}"
	mpd.disconnect
	$mpd_list.insert(i, mpd)
  end
end

def update()
  if $mpd_list[0].nil?
	  init()
	  $mpd_current_index = 0
  end
  puts "Updating mpd #{$mpd_server_name_list[$mpd_current_index]}"
  mpd = $mpd_list[$mpd_current_index]
  mpd.connect
  song = mpd.current_song.artist + ' - ' + mpd.current_song.title
  volume = mpd.volume
  puts "Sending song #{song} volume #{volume}"
  send_event('mpd', mpd_song: song, mpd_volume: volume)
  mpd.disconnect
end


SCHEDULER.every '20s', :first_in => 0 do |job|
  run_start = Time.now
  update()
  elapsed = (Time.now - run_start).to_i
  puts "MPD duration=#{elapsed} seconds"
end