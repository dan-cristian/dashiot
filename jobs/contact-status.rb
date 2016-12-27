require 'mysql2'
require 'date'
require 'yaml'

def my_job()
  config = YAML.load_file('config.yaml')
  mysql_host = config['mysql_host']
  mysql_user = config['mysql_user']
  mysql_pass = config['mysql_pass']

  # Myql connection
  db = Mysql2::Client.new(:host => mysql_host, :username => mysql_user, :password => mysql_pass, :port => 3306, :database => "haiot-reporting" )

  # get all zones with move in last 5 days 
  sql = "
  SELECT DISTINCT(zone_name), sensor_name
  FROM presence_history
  WHERE updated_on >= CURDATE() - 5
  ORDER BY zone_name
  "
  zone_prev = ""
  zone_name = ""
  sensors = []
  main_rows = db.query(sql)
  main_items = main_rows.map do |row|
    zone_name = row['zone_name']
    sensor_name = row['sensor_name']

    if zone_name != zone_prev
      if zone_prev != ""
        send_event('graphcontact-' + zone_prev, zone_name: zone_prev, sensors: sensors)
      end
      sensors = []
      zone_prev = zone_name
    end  
    # get all sensors in this zone
    sql = "
    SELECT event_type, updated_on, is_connected
    FROM presence_history
    WHERE zone_name='" + zone_name + "' AND sensor_name='" + sensor_name + "'
    ORDER BY id DESC LIMIT 1
    "
    detail_rows = db.query(sql)
    if detail_rows.count > 0
      is_connected = detail_rows.first['is_connected']
      event_type = detail_rows.first['event_type']
      updated_on = detail_rows.first['updated_on']
      sensors << { sensor_name: sensor_name, event_type: event_type, is_connected: is_connected, updated_on: updated_on}
      puts "Zone #{zone_name} sensor #{sensor_name} conn=#{is_connected} type #{event_type} update #{updated_on}"
    else
      puts "Warning no presence rows for zone #{zone_name} sensor #{sensor_name}"
    end
  end # main_items
  # send last
  send_event('graphcontact-' + zone_name, zone_name: zone_name, sensors: sensors)
end


if ARGV.empty?
  #my_job
  #exit
end


SCHEDULER.every '30s', :first_in => 0 do |job|
  my_job
end
