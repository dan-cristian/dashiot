require 'open-uri'
require 'xmlsimple'
require 'cgi'


username = 'dancri77'
api_key = '0589cb68cd7478b22f5854db59d00ae8'

SCHEDULER.every '45s', :first_in => 0 do |job|
	http = Net::HTTP.new('ws.audioscrobbler.com')
	response = http.request(Net::HTTP::Get.new("/2.0/?method=user.getrecenttracks&user=#{username}&api_key=#{api_key}"))
	response_status = XmlSimple.xml_in(response.body, { 'ForceArray' => false })

	if response_status['status'] == "failed"
		failed = response_status['error']['content']
		send_event('lastfm', { :status => failed })
	else
		user_id = XmlSimple.xml_in(response.body, { 'ForceArray' => false })['recenttracks']
		song = XmlSimple.xml_in(response.body, { 'ForceArray' => false })['recenttracks']['track'][0]
		song['nowplaying'] == "true" ? track_status = "last.fm playing" : track_status = "last.fm last played"
		song['image'][1]['content'].nil? ? image = "assets/no-album-art.jpg" : image = song['image'][1]['content']
		artist = CGI.escape(song['artist']['content'])
		track = CGI.escape(song['name'])
		response = http.request(Net::HTTP::Get.new("/2.0/?method=track.getInfo&user=#{username}&api_key=#{api_key}&artist=#{artist}&track=#{track}"))
		info = XmlSimple.xml_in(response.body, { 'ForceArray' => false })
		if info['status'] != 'failed'
			loved = info['track']['userloved']
		else
			loved = -1
		end
		send_event('lastfm', { :status => 'ok', :cover => image, :artist => song['artist']['content'], 
			:track => song['name'], :title => track_status, :loved => loved})
	end
end