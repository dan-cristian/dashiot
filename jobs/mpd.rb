require 'ruby-mpd'
require 'net/http'

class Cmpd
  def initialize(zone_name, port, ip)
    @zone_name = zone_name
    @port = port
    @ip = ip
    @mpd = nil
  end
  @lastfm_song = ''
  @lastfm_loved = ''
  attr_reader :zone_name, :port, :ip, :mpd, :lastfm_song, :lastfm_loved
  attr_writer :mpd, :lastfm_song, :lastfm_loved
end

$mpd_mutex = Mutex.new
$last_mpd_update = Time.at(0)
@IP='192.168.0.9'
$cmpd_list = [Cmpd.new('living', 6600, @IP), Cmpd.new('headset', 6601, @IP), Cmpd.new('beci', 6602, @IP),
  Cmpd.new('dormitor', 6603, @IP), Cmpd.new('baie', 6604, @IP), Cmpd.new('pod', 6605, @IP)]
$mpd_current_index = nil
$DELETE_MPD_COMMAND = "/home/scripts/audio/mpc-play.sh <mpd_zone_name> delete"
$lastfm_api_key = nil
$mpd_database = nil
$mpd_usbstick_model = nil

######### LASTFM #################
def init_lastfm_session()
	$lastfm_api_sig = Digest::MD5.hexdigest("api_key#{$lastfm_api_key}methodauth.getSessiontoken#{$lastfm_api_token}#{$lastfm_api_secret}")
	http = Net::HTTP.new('ws.audioscrobbler.com')
	response = http.request(Net::HTTP::Get.new("/2.0/?method=auth.getSession&token=#{$lastfm_api_token}&api_key=#{$lastfm_api_key}&api_sig=#{$lastfm_api_sig}"))
	xml_response=XmlSimple.xml_in(response.body, { 'ForceArray' => false })
	if xml_response['status'] == 'ok'
		$lastfm_session_key = xml_response['session']['key']
    puts "New session key is #{$lastfm_session_key}, save it to config!"
	else
		puts 'Error, res=' + response.body
	end
end

def get_lastfm_params()
	config = YAML.load_file('config.yaml')
	$lastfm_username = config['lastfm_user']
	password = config['lastfm_pass']
	$lastfm_api_key = config['lastfm_api']
	$lastfm_api_secret = config['lastfm_secret']
	puts "Get a new token with: http://www.last.fm/api/auth?api_key=#{$api_key}"
	$lastfm_api_token = config['lastfm_token']
	$lastfm_session_key = config['lastfm_session']
	if $lastfm_session_key.nil?
		init_lastfm_session()
	end
end

def get_loved_tracks()
  http = Net::HTTP.new('ws.audioscrobbler.com')
  mpd = $cmpd_list[$mpd_current_index].mpd
  mpd.connect unless mpd.connected?
  restarted = false
	page_count = 1
  page = 1
  loop do
    puts "Getting all loved lastfm tracks for page #{page}"
    response = http.request(Net::HTTP::Get.new("/2.0/?method=user.getlovedtracks&user=#{$lastfm_username}&api_key=#{$lastfm_api_key}&page=#{page}"))
    response_body = XmlSimple.xml_in(response.body, { 'ForceArray' => false })
    if response_body['status'] == "failed"
      failed = response_body['error']['content']
      send_event('mpd', { :lastfm_status => failed })
      puts "Error, get all loved failed with #{failed}"
      return
    end
    page_count = response_body['lovedtracks']['totalPages'].to_i
    tracks = response_body['lovedtracks']['track']
    # puts tracks
    mpd.clear if tracks.count > 0 && page == 1
    for track in tracks
      artist = track['artist']['name']
      title = track['name']
      image_url_small = track['image'][0]['content']
      # puts "#{artist} - #{title} #{image_url_small}"
      #todo add song in mpd queue
      found = mpd.where({artist: artist, title: title}, {strict: true, add: true})
      #puts "Added above song OK" if found
    end
    if restarted == false
        mpd.play
        restarted = true if mpd.playing?
      end
    page = page + 1
    break if page > page_count
	end
  puts "Added all loved lastfm tracks"
  mpd.pause = false
  update_mpd()
end

def get_lastfm_info(artist, track)
  http = Net::HTTP.new('ws.audioscrobbler.com')
  artist = CGI.escape(artist)
	track = CGI.escape(track)
  response = http.request(Net::HTTP::Get.new("/2.0/?method=track.getInfo&user=#{$lastfm_username}&api_key=#{$lastfm_api_key}&artist=#{artist}&track=#{track}"))
  response_body = XmlSimple.xml_in(response.body, {'ForceArray' => false})
  if response_body['status'] == "failed"
    failed = response_body['error']['content']
    send_event('mpd', { :lastfm_status => failed })
    puts "Error, is loved failed with #{failed}"
    return nil
  end
  #puts "lastfm info=#{response_body['track']}"
  return response_body['track']
end

#loved = '1' or '0'
def set_love(loved)
  cmpd = $cmpd_list[$mpd_current_index]
  mpd = cmpd.mpd
  mpd.connect unless mpd.connected?
  unless mpd.current_song.nil? or mpd.current_song.artist.nil?
    if loved == '1' 
      method = 'track.love'
    elsif loved == '0'
      method = 'track.unlove'
    else
      puts "Warning unknown love value #{loved}, ignoring"
      return
    end
    artist = mpd.current_song.artist
    track = mpd.current_song.title
    puts 'Love=#{loved} song ' + artist + ' - ' + track
    artist = artist.encode('utf-8')
    track = track.encode('utf-8')
    uri = URI.parse('http://ws.audioscrobbler.com/2.0/')
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    love_api_sig = Digest::MD5.hexdigest("api_key#{$lastfm_api_key}artist#{artist}method#{method}sk#{$lastfm_session_key}track#{track}#{$lastfm_api_secret}")
    request.set_form_data({'method' => method, 'api_key' => $lastfm_api_key, 'track' => track, 'artist' => artist, 'api_sig' => love_api_sig, 'sk' => $lastfm_session_key})
    response = http.request(request)
    response_status = XmlSimple.xml_in(response.body, { 'ForceArray' => false })
    puts 'Love status is ' + response_status['status'] + response.body
    cmpd.lastfm_song = nil
  end
end
######### MPD ####################

def change_mpd(mpd_name)
  for i in 0..$cmpd_list.count - 1
    if $cmpd_list[i].zone_name == mpd_name
      puts "Selected zone index #{i}"
      $mpd_current_index = i
      $cmpd_list[i].lastfm_song = nil
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
    puts "Volume is #{mpd.volume}"
    mpd.volume = [mpd.volume + 5, 100].min
    puts "Volume is #{mpd.volume}"
  when 'volume_down'
    puts "Volume is #{mpd.volume}"
    mpd.volume = [mpd.volume - 5, 0].max
    puts "Volume is #{mpd.volume}"
  when 'repeat'
    mpd.repeat = !mpd.repeat?
  when 'random'
    mpd.random = !mpd.random?
  when 'trash'
    sys_cmd = $DELETE_MPD_COMMAND.sub('<mpd_zone_name>', $cmpd_list[$mpd_current_index].zone_name)
    puts "Executing trash command #{sys_cmd}"
    res_cmd = `#{sys_cmd}`
    puts "Command result is #{res_cmd}"
  when 'lastfm_loved'
    get_loved_tracks()
  when 'love'
    set_love('1')
  when 'unlove'
    set_love('0')
  when 'play_all'
    mpd.clear
    mpd.where({title: ''}, {add: true})
  when 'save_to_usb'
    save_songs_usb()
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

def save_songs_usb()
  target_root = "/var/run/usbmount/#{$mpd_usbstick_model}"
  if File.exists?(target_root)
    mpd = $cmpd_list[$mpd_current_index].mpd
    mpd.connect unless mpd.connected?
    t = Time.now
    playlist = "#{$cmpd_list[$mpd_current_index].zone_name}_#{t.month}-#{t.day}"
    count = mpd.queue.count
    i = 1
    for song in mpd.queue
      source_file = "#{$mpd_database}/#{song.file}"
      dest_file = "#{target_root}/#{playlist}/#{song.file}"
      if File.exists?(dest_file) && File.size(dest_file) == File.size(source_file)
        puts "Skip copy #{i}/#{count} as already exists, song #{song.file}"
      else
        begin
          FileUtils.mkdir_p(File.dirname(dest_file))
          puts "Copy #{i}/#{count} song #{song.file}"
          FileUtils.cp(source_file, dest_file)
        rescue => e
          puts "Cannot copy song to usb, e=#{e}"
        end
      end
      i = i + 1
    end
  end
  puts "Save to usb completed"
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
  config = YAML.load_file('config.yaml')
  $mpd_database = config['mpd_database']
  $mpd_usbstick_model = config['mpd_usbstick_model']
  #debug
  #$mpd_current_index = 0
  #exec_cmd_cust('play_all')
  #save_songs_usb()
end

#todo: optimise by updating only changed parts 
def update_mpd()
  puts "Updating mpd #{$cmpd_list[$mpd_current_index].zone_name}"
  mpd = $cmpd_list[$mpd_current_index].mpd
  cmpd = $cmpd_list[$mpd_current_index]
  mpd.connect unless mpd.connected?
  artist = ''
  title = ''
  unless mpd.current_song.nil? or mpd.current_song.artist.nil?
    artist = mpd.current_song.artist
    title = mpd.current_song.title
    song = artist + ' - ' + title
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
      out_count = mpd.outputs.count
      for i in 0..out_count - 1
        out = mpd.outputs[i]
        if out[:outputenabled]
          outputs_enabled << out[:outputname]
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
      puts "!!!!!!!!!!!!!!!!!!! That crash again, err=#{e} index=#{$mpd_current_index}"
      puts e.backtrace
      mpd.disconnect if mpd.connected?
      mpd.connect unless mpd.connected?
    end
  end
  if cmpd.lastfm_song != song
    lastfm_track_info = get_lastfm_info(artist, title)
    #puts "Updating song=#{song} state=#{playstate} zone=#{mpd_zone}"
    if !lastfm_track_info.nil?
      loved = lastfm_track_info['userloved']
      playcount = lastfm_track_info['userplaycount']
      if !lastfm_track_info['album'].nil? and !lastfm_track_info['album']['image'].nil? 
        image = lastfm_track_info['album']['image'][0]['content']
        puts "Track image is #{image}"
      end
      # puts "Track #{lastfm_track_info}"
      send_event('mpd', lastfm_loved: loved, lastfm_playcount: playcount)
      cmpd.lastfm_song = song
      cmpd.lastfm_loved = loved
      sleep 1 #seems to be needed otherwise above message is not sent
    else
      puts "Warning, no lastfm info! #{lastfm_track_info}"
    end
  else
    puts "Skipping lastfm update, same song"
  end
  send_event('mpd', mpd_song: song, mpd_volume: mpd.volume, mpd_playstate: playstate,
    mpd_zone: mpd_zone, mpd_random: mpd_random, mpd_repeat: mpd_repeat,
    outputs_enabled: outputs_enabled, mpd_songposition: mpd_songposition,
    mpd_songduration: mpd_songduration, mpd_zonesplaying: zones_playing)
  $last_mpd_update = Time.now
end

###########################

get_lastfm_params()
init()

SCHEDULER.every '30s', allow_overlapping: false, :first_in => 0 do |job|
  run_start = Time.now
  $mpd_mutex.synchronize do
    elapsed = (Time.now - $last_mpd_update).to_i
    #only update if no updates in the last x seconds
    update_mpd() if elapsed >=10 or $mpd_current_index.nil?
  end
  elapsed = (Time.now - run_start).to_i
  puts "MPD duration=#{elapsed} seconds"
end