require 'open-uri'
require 'xmlsimple'
require 'cgi'
require 'net/http'
require 'uri'

$api_key = nil
$song = nil


def init_session()
	$api_sig = Digest::MD5.hexdigest("api_key#{$api_key}methodauth.getSessiontoken#{$api_token}#{$api_secret}")
	http = Net::HTTP.new('ws.audioscrobbler.com')
	response = http.request(Net::HTTP::Get.new("/2.0/?method=auth.getSession&token=#{$api_token}&api_key=#{$api_key}&api_sig=#{$api_sig}"))
	xml_response=XmlSimple.xml_in(response.body, { 'ForceArray' => false })
	if xml_response['status'] == 'ok'
		$session_key = xml_response['session']['key']
	else
		puts 'Error, res=' + response.body
	end
end

def get_params()
	config = YAML.load_file('config.yaml')
	$username = config['lastfm_user']
	password = config['lastfm_pass']
	$api_key = config['lastfm_api']
	$api_secret = config['lastfm_secret']
	puts "Get a token: http://www.last.fm/api/auth?api_key=#{$api_key}&cb=/localhost"
	$api_token = config['lastfm_token']
	$session_key = config['lastfm_session']
	if $session_key.nil?
		init_session()
	end
	$api_sig = Digest::MD5.hexdigest("api_key#{$api_key}methodauth.getSessiontoken#{$api_token}#{$api_secret}")
end

def love_song(artist, track)
	puts 'Loving  song ' + artist + ' - ' + track
	artist = artist.encode('utf-8')
	track = track.encode('utf-8')
	if $api_key.nil?
		get_params()
	end
	uri = URI.parse('http://ws.audioscrobbler.com/2.0/')
	http = Net::HTTP.new(uri.host, uri.port)
	#http = Net::HTTP.new('ws.audioscrobbler.com')
	request = Net::HTTP::Post.new(uri.request_uri)
	love_api_sig = Digest::MD5.hexdigest("api_key#{$api_key}artist#{artist}methodtrack.lovesk#{$session_key}track#{track}#{$api_secret}")
	request.set_form_data({'method' => 'track.love', 'api_key' => $api_key, 'track' => track, 'artist' => artist, 'api_sig' => love_api_sig, 'sk' => $session_key})
	response = http.request(request)
	response_status = XmlSimple.xml_in(response.body, { 'ForceArray' => false })
	puts 'Love status is ' + response_status['status'] + response.body
end


post '/lastfm/love' do
	artist = $song['artist']['content']
	track = $song['name']
	love_song(artist, track)
	update_lastfm()
end

#init_session()
#love_song('FARIUS', 'Brave One')

def update_lastfm()
	if $api_key.nil?
		get_params()
	end
	http = Net::HTTP.new('ws.audioscrobbler.com')
	response = http.request(Net::HTTP::Get.new("/2.0/?method=user.getrecenttracks&user=#{$username}&api_key=#{$api_key}"))
	response_status = XmlSimple.xml_in(response.body, { 'ForceArray' => false })

	if response_status['status'] == "failed"
		failed = response_status['error']['content']
		send_event('lastfm', { :status => failed })
	else
		user_id = XmlSimple.xml_in(response.body, { 'ForceArray' => false })['recenttracks']
		$song = XmlSimple.xml_in(response.body, { 'ForceArray' => false })['recenttracks']['track'][0]
		nowplaying = $song['nowplaying']
		$song['image'][1]['content'].nil? ? image = "assets/no-album-art.jpg" : image = $song['image'][1]['content']
		artist = CGI.escape($song['artist']['content'])
		track = CGI.escape($song['name'])
		response = http.request(Net::HTTP::Get.new("/2.0/?method=track.getInfo&user=#{$username}&api_key=#{$api_key}&artist=#{artist}&track=#{track}"))
		info = XmlSimple.xml_in(response.body, { 'ForceArray' => false })
		if info['status'] != 'failed'
			loved = info['track']['userloved']
		else
			loved = -1
		end
		puts "Lastfm song #{$song['artist']['content']} - #{$song['name']}"
		send_event('lastfm', { :status => 'ok', :cover => image, :artist => $song['artist']['content'], 
			:track => $song['name'], :nowplaying => nowplaying, :loved => loved})
	end
end

SCHEDULER.every '20s', :first_in => 0 do |job|
	run_start = Time.now
	update_lastfm()
	elapsed = (Time.now - run_start).to_i
	puts "Lastfm duration=#{elapsed} seconds"
end