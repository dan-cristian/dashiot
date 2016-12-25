require 'mysql2'
require 'date'

SCHEDULER.every '1m', :first_in => 0 do |job|
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
    
    puts "Contact zone=#{main_name}"
    sql = "
    SELECT count(*) AS count, MAX(updated_on) as updated_on 
    FROM presence_history 
    WHERE zone_name='" + main_name + 
    "' AND updated_on >= CURDATE() AND is_connected=0
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
    
    sql = "
    SELECT * FROM presence_history 
    where zone_name='" + main_name + "'
    order by id desc limit 1
    "
    detail_rows = db.query(sql)
    if detail_rows.count > 0
      is_connected = detail_rows.first['is_connected']
      if detail_rows.first['event_io_date']
        event_type='IO'
      else
        if detail_rows.first['event_camera_date']
          event_type='CAM'
        else
          event_type='N/A'
        end
      end
    else
      puts "Warning no presence rows for zone " + main_name
    end
    
    # Update the widget
    if second_rows.count > 0
      puts "Contact #{main_name} type #{event_type} connected=#{is_connected}"
      send_event('graphcontact-'+ main_name, points: points, event_type: event_type, is_connected: is_connected)
    else
      puts "Warning no presence rows today for zone " + main_name
    end
  end
end