require 'mysql2'
require 'date'

SCHEDULER.every '5m', :first_in => 0 do |job|
  run_start = Time.now
  config = YAML.load_file('config.yaml')
  mysql_host = config['mysql_host']
  mysql_user = config['mysql_user']
  mysql_pass = config['mysql_pass']
  
  # Myql connection
  db = Mysql2::Client.new(:host => mysql_host, :username => mysql_user, :password => mysql_pass, :port => 3306, :database => "haiot-reporting" )

  sql = "
  SELECT zone_name, MAX(updated_on) as updated_on
  FROM presence_history
  WHERE updated_on >= CURDATE()
  GROUP BY zone_name
  "
  
  main_rows = db.query(sql)
  main_items = main_rows.map do |row|
    main_name = row['zone_name']
    main_date = row['updated_on']
    
    # puts "Contact graph zone=#{main_name}"
    sql = "
    SELECT count(*) AS count, MAX(updated_on) as updated_on 
    FROM presence_history 
    WHERE zone_name='" + main_name + 
    "' AND updated_on >= CURDATE()
    GROUP BY hour(updated_on)
    ORDER BY hour(updated_on)
    "
    
    second_rows = db.query(sql)
    points = []
    second_items = second_rows.map do |row2|
      x_value = row2['updated_on'].to_i
      y_value = row2['count']
      points << { x: x_value, y: y_value }
    end
    
    
    # Update the widget
    if second_rows.count > 0
      send_event('graphcontact-'+ main_name, points: points, zone_name: main_name)
    else
      puts "Warning no presence rows today for zone " + main_name
    end
  end
  elapsed = (Time.now - run_start).to_i
  puts "Contact-graph duration=#{elapsed} seconds"
end