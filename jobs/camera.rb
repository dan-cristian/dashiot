require 'net/http'
require 'yaml'
require 'fileutils'
 
@cameraDelay = 1 # Needed for image sync
@fetchNewImageEvery = '10s'

@camera1Host = "192.168.0.28"
@camera1Port = "80"
@camera1URL = "/Streaming/channels/1/picture"
@newFile1 = "assets/images/cameras/snapshot1_new.jpeg"
@oldFile1 = "assets/images/cameras/snapshot1_old.jpeg"

@camera2Host = "192.168.0.23"
@camera2Port = "80"
@camera2URL = "/Streaming/channels/1/picture"
@newFile2 = "assets/images/cameras/snapshot2_new.jpeg"
@oldFile2 = "assets/images/cameras/snapshot2_old.jpeg"

@camera3Host = "192.168.0.22"
@camera3Port = "80"
@camera3URL = "/Streaming/channels/1/picture"
@newFile3 = "assets/images/cameras/snapshot3_new.jpeg"
@oldFile3 = "assets/images/cameras/snapshot3_old.jpeg"


@camera4Host = "192.168.0.21"
@camera4Port = "80"
@camera4URL = "/cgi-bin/CGIProxy.fcgi?cmd=snapPicture2&usr=<user>&pwd=<password>"
@newFile4 = "assets/images/cameras/snapshot4_new.jpeg"
@oldFile4 = "assets/images/cameras/snapshot4_old.jpeg"

@camera5Host = "192.168.0.9"
@camera5Port = "10005"
@camera5URL = "/"
@newFile5 = "assets/images/cameras/snapshot5_new.jpeg"
@oldFile5 = "assets/images/cameras/snapshot5_old.jpeg"
 
def fetch_image(host, old_file, new_file, cam_port, cam_user, cam_pass, cam_url)
	begin
		if File.exist?(old_file)
			FileUtils.rm(old_file)
			#`rm #{old_file}`
		end
		if File.exist?(new_file)
			# puts "Moving  #{new_file} to #{old_file}"
			FileUtils.mv(new_file, old_file)
			#`mv #{new_file} #{old_file}`
		end
		Net::HTTP.start(host, cam_port) do |http|
			cam_url = cam_url.sub '<user>', cam_user
			cam_url = cam_url.sub '<password>', cam_pass
			req = Net::HTTP::Get.new(cam_url)
			if cam_user != "None" ## if username for any particular camera is set to 'None' then assume auth not required.
				req.basic_auth cam_user, cam_pass
			end
			response = http.request(req)
			open(new_file, "wb") do |file|
				file.write(response.body)
			end
		end
		new_file
	rescue
		puts "Exception for #{host} #{cam_url}"
		""
	end
end
 
def make_web_friendly(file)
  "/" + File.basename(File.dirname(file)) + "/" + File.basename(file)
end
 
SCHEDULER.every @fetchNewImageEvery, allow_overlapping: false, first_in: 0 do
  run_start = Time.now
  config = YAML.load_file('config.yaml')
  camuser1 = config['camuser1']
  campass1 = config['campass1']
  camuser2 = config['camuser2']
  campass2 = config['campass2']
  camuser3 = config['camuser3']
  campass3 = config['campass3']
  camuser4 = config['camuser4']
  campass4 = config['campass4']
  camuser5 = 'None'
  campass5 = ''
  
	new_file1 = fetch_image(@camera1Host,@oldFile1,@newFile1,@camera1Port,camuser1,campass1,@camera1URL)
	new_file2 = fetch_image(@camera2Host,@oldFile2,@newFile2,@camera2Port,camuser2,campass2,@camera2URL)
	new_file3 = fetch_image(@camera3Host,@oldFile3,@newFile3,@camera3Port,camuser3,campass3,@camera3URL)
	new_file4 = fetch_image(@camera4Host,@oldFile4,@newFile4,@camera4Port,camuser4,campass4,@camera4URL)
	#new_file5 = fetch_image(@camera5Host,@oldFile5,@newFile5,@camera5Port,camuser5,campass5,@camera5URL)

	if not File.exists?(@newFile1 && @newFile2 && @newFile3 && @newFile4) #&& @newFile5)
		warn "Failed to Get Camera Image"
	end
 
	send_event('camera1', image: make_web_friendly(@oldFile1))
	send_event('camera2', image: make_web_friendly(@oldFile2))
	send_event('camera3', image: make_web_friendly(@oldFile3))
	send_event('camera4', image: make_web_friendly(@oldFile4))
	#send_event('camera5', image: make_web_friendly(@oldFile5))
	sleep(@cameraDelay)
	send_event('camera1', image: make_web_friendly(new_file1))
	send_event('camera2', image: make_web_friendly(new_file2))
	send_event('camera3', image: make_web_friendly(new_file3))
	send_event('camera4', image: make_web_friendly(new_file4))
	#send_event('camera5', image: make_web_friendly(new_file5))
	elapsed = (Time.now - run_start).to_i
	puts "Camera duration=#{elapsed} seconds"
end
