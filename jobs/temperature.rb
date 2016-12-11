require 'mysql2'
require 'date'
require 'yaml'

SCHEDULER.every '30s', :first_in => 0 do |job|
  config = YAML.load_file('config.yaml')
  mysql_host = config['mysql_host']
  mysql_user = config['mysql_user']
  mysql_pass = config['mysql_pass']
  
  # Myql connection
  db = Mysql2::Client.new(:host => mysql_host, :username => mysql_user, :password => mysql_pass, :port => 3306, :database => "haiot-reporting" )

  sql = "SELECT DISTINCT(sensor_name) FROM sensor_history"
  sensor_rows = db.query(sql)
  
  sensor_items = sensor_rows.map do |row|
    sensor_name = row['sensor_name']
    puts "Sensor=" + sensor_name
    sql = "
    SELECT id, temperature, updated_on FROM sensor_history 
    WHERE sensor_name='" + sensor_name + "' AND temperature is not NULL  
    ORDER BY id DESC LIMIT 50
    "
  
    # Execute the query
    temp_rows = db.query(sql)
    #temp_list = []
    points = []
    # Sending to List widget, so map to :label and :value
    temp_items = temp_rows.map do |row2|
      temp = row2['temperature']
      date = row2['updated_on']
      #id = row2['id']
      #dt = DateTime.parse(date) 
      xval = date.to_i      
      # temp_list << temp
      points.unshift({ x: xval, y: temp })
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
    
    # Update the List widget
    if temp_items.count > 0
      #send_event('temperature-' + sensor_name, { current: temp_list[0], last: temp_list[1] })
      send_event('graphtemp-'+ sensor_name, points: points, tag: heatison)
    end
  end
end