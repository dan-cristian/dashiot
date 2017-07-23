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
  SELECT DISTINCT(utility_name) 
  FROM utility_history 
  WHERE updated_on >= CURDATE()
  '
  main_rows = db.query(sql)

  main_items = main_rows.map do |row|
    main_name = row['utility_name']
    
    sql = "
    SELECT max(units_total) as units, max(updated_on) as updated_on
     FROM utility_history
     WHERE utility_name='" + main_name + "' AND units_total is not NULL AND updated_on >= (CURDATE() - 1)
     group by
     year(updated_on) , month(updated_on) , day(updated_on) , hour(updated_on)
     order by max(updated_on) desc
    "

    # Execute the query
    value_rows = db.query(sql)
    #temp_list = []
    points_value = []
    # Sending to List widget, so map to :label and :value
    value_items = value_rows.map do |row2|
      value = row2['units'].round(2)
      date = row2['updated_on']
      xval = date.to_i
      # temp_list << temp
      points_value.unshift({ x: xval, y: value })
    end
    
    
    # Update the List widget
    if value_items.count > 0
      #send_event('temperature-' + sensor_name, { current: temp_list[0], last: temp_list[1] })
      send_event('graphutilityex-' + main_name, points_value: points_value)
    end
  end
  elapsed = (Time.now - run_start).to_i
  puts "Utilityex duration=#{elapsed} seconds"
end