require 'mysql2'
require 'date'

SCHEDULER.every '2m', :first_in => 0 do |job|
  run_start = Time.now
  config = YAML.load_file('config.yaml')
  mysql_host = config['mysql_host']
  mysql_user = config['mysql_user']
  mysql_pass = config['mysql_pass']
  
  # Myql connection
  db = Mysql2::Client.new(:host => mysql_host, :username => mysql_user, :password => mysql_pass, :port => 3306, :database => "haiot-reporting" )

  sql = "
  SELECT DISTINCT(utility_name), unit_name, sum(units_delta) as day_total_units
  FROM utility_history 
  WHERE unit_name IS NOT null AND updated_on >= CURDATE()
  GROUP BY utility_name, unit_name
  "
  
  utility_rows = db.query(sql)
  
  utility_items = utility_rows.map do |row|
    #sensor_name = row['sensor_name']
    utility_name = row['utility_name']
    unit_name = row['unit_name']
    unless row['day_total_units'].nil?
      day_total_units = row['day_total_units'].round(1)
    end
    
    #puts "Sensor=#{sensor_name} #{unit_name} #{day_total_units}"
    sql = "
    SELECT HOUR(updated_on) as hour, SUM(units_delta) as units, MAX(updated_on) as updated_on 
    FROM utility_history
    WHERE utility_name='" + utility_name + "' AND updated_on >= CURDATE()
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
    
    sql = "
    SELECT units_2_delta, unit_2_name FROM utility_history
     WHERE utility_name='" + utility_name + "' AND updated_on >= CURDATE() order by id desc LIMIT 1
    "
    current_rows = db.query(sql)
    if current_rows.count > 0
      units_2_delta = current_rows.first['units_2_delta']
      unit_2_name = current_rows.first['unit_2_name']
    else
      units_2_delta = ''
      unit_2_name = 'n/a!'
    end

    # Update the List widget
    if day_rows.count > 0
      #send_event('temperature-' + sensor_name, { current: temp_list[0], last: temp_list[1] })
      send_event('graphutility-'+ utility_name, points: points, day_total_units: day_total_units, unit_name: unit_name, units_2_delta: units_2_delta, unit_2_name: unit_2_name)
    end
  end
  elapsed = (Time.now - run_start).to_i
  puts "Utility duration=#{elapsed} seconds"
end