require 'mysql2'
require 'date'

SCHEDULER.every '5m', :first_in => 0 do |job|
  config = YAML.load_file('config.yaml')
  mysql_host = config['mysql_host']
  mysql_user = config['mysql_user']
  mysql_pass = config['mysql_pass']
  
  # Myql connection
  db = Mysql2::Client.new(:host => mysql_host, :username => mysql_user, :password => mysql_pass, :port => 3306, :database => "haiot-reporting" )

  sql = "
  SELECT DISTINCT(sensor_name), unit_name, sum(units_delta) as day_total_units
  FROM utility_history 
  WHERE unit_name IS NOT null AND updated_on >= CURDATE()
  GROUP BY sensor_name, unit_name
  "
  
  utility_rows = db.query(sql)
  
  utility_items = utility_rows.map do |row|
    sensor_name = row['sensor_name']
    unit_name = row['unit_name']
    day_total_units = row['day_total_units'].round(1)
    
    puts "Sensor=#{sensor_name} #{unit_name} #{day_total_units}"
    sql = "
    SELECT HOUR(updated_on) as hour, SUM(units_delta) as units, MAX(updated_on) as updated_on 
    FROM utility_history
    WHERE sensor_name='" + sensor_name + "' AND updated_on >= CURDATE()
    GROUP BY hour(updated_on)
    ORDER BY hour(updated_on)
    "
  
    day_rows = db.query(sql)
    points = []
    day_items = day_rows.map do |row2|
      hour = row2['updated_on'].to_i
      units = row2['units']
      # puts "Hour #{hour} units=#{units}"
      points << { x: hour, y: units}
    end
    
    # Update the List widget
    if day_rows.count > 0
      #send_event('temperature-' + sensor_name, { current: temp_list[0], last: temp_list[1] })
      send_event('graphutility-'+ sensor_name, points: points, day_total_units: day_total_units, unit_name: unit_name)
    end
  end
end