require 'mysql2'
require 'date'
require 'yaml'

SCHEDULER.every '2m', allow_overlapping: false, :first_in => 0 do |job|
  run_start = Time.now
  config = YAML.load_file('config.yaml')
  mysql_host = config['mysql_host']
  mysql_user = config['mysql_user']
  mysql_pass = config['mysql_pass']
  
  # Myql connection
  db = Mysql2::Client.new(:host => mysql_host, :username => mysql_user, :password => mysql_pass, :port => 3306, :database => "haiot-reporting" )

  sql = '
  SELECT DISTINCT(sensor_name) 
  FROM sensor_history 
  WHERE updated_on >= CURDATE()
  '
  sensor_rows = db.query(sql)

  sensor_items = sensor_rows.map do |row|
    sensor_name = row['sensor_name']
    #puts "Sensor=" + sensor_name
    #sql = "
    #SELECT id, temperature, humidity, updated_on FROM sensor_history 
    #WHERE sensor_name='" + sensor_name + "' AND temperature is not NULL  
    #ORDER BY id DESC LIMIT 50
    #"
  
    sql = "
    SELECT max(temperature) as temperature, max(humidity) as humidity, max(updated_on) as updated_on
     FROM sensor_history
     WHERE sensor_name='" + sensor_name + "' AND temperature is not NULL AND updated_on >= (CURDATE() - 1)
     group by
     year(updated_on) , month(updated_on) , day(updated_on) , hour(updated_on)
     order by max(updated_on) desc
    "

    # Execute the query
    temp_rows = db.query(sql)
    #temp_list = []
    points_temp = []
    points_humid = []
    #humid = -1
    # Sending to List widget, so map to :label and :value
    temp_items = temp_rows.map do |row2|
      temp = row2['temperature']
      date = row2['updated_on']
      humid = row2['humidity']
      #if humid == -1
      #  humid = row2['humidity']
      #end
      #id = row2['id']
      #dt = DateTime.parse(date)
      xval = date.to_i
      # temp_list << temp
      points_temp.unshift({ x: xval, y: temp })
      points_humid.unshift({ x: xval, y: humid })
    end
    
    sql = "
    SELECT heat_is_on, updated_on FROM zoneheatrelay_history
     WHERE heat_pin_name='" + sensor_name + "' ORDER BY id DESC LIMIT 1
    "
    heat_rows = db.query(sql)
    if heat_rows.count > 0
      heatison = heat_rows.first['heat_is_on']
      # puts "heat is on = #{heatison}"
    end
    
    sql = "
    SELECT temperature, humidity FROM sensor_history
     WHERE sensor_name='" + sensor_name + "' AND updated_on >= CURDATE() order by id desc LIMIT 1
    "
    current_rows = db.query(sql)
    if current_rows.count > 0
      current_temp = current_rows.first['temperature']
      current_humid = current_rows.first['humidity']
    else
      current_temp = '-'
      current_humid = '-'
    end
    # Update the List widget
    if temp_items.count > 0
      #send_event('temperature-' + sensor_name, { current: temp_list[0], last: temp_list[1] })
      send_event('graphtemp-' + sensor_name, points_temp: points_temp, points_humid: points_humid, tag: heatison, 
        current_temp: current_temp, current_humid: current_humid)
    end
  end
  elapsed = (Time.now - run_start).to_i
  puts "Temperature duration=#{elapsed} seconds"
end