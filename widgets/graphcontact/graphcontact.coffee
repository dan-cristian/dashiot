class Dashing.Graphcontact extends Dashing.Widget

  @accessor 'current', ->
    type = @get('event_type')
    if @get('is_connected') == 1
      connected = "LOCKED" 
    else
      connected = "UNLOCKED!"
    "#{type} #{connected}"

  # 0 for not connected (alarm, contact open), 1 for connected (contact is safe, door is closed)
  @accessor 'connected', ->
    @get('is_connected')

  @accessor 'updateon', ->
    points = @get('points')
    if points
      today = Math.round(new Date().getTime() / 1000)
      delta = today - points[points.length - 1].x
      minutes = Math.floor((delta % 3600) / 60)
      seconds = delta % 60
      "#{minutes}m#{seconds}s"
  

  contact_status: (contact_type) ->
    status = ""
    recent_move = false
    if @get('sensors')
      for sensor in @get('sensors')
          is_connected = sensor['is_connected']
          event_type = sensor['event_type']
          updated_on = sensor['updated_on']
          sensor_name = sensor['sensor_name']
          age = sensor['age']
          if event_type == contact_type
            # http://stackoverflow.com/questions/658044/tick-symbol-in-html-xhtml
            if age > 60
              symbol = '&#10004;' # check ok
            else
              symbol = '&#10008;' # open, not ok
              recent_move = true
            status = status + symbol + age + " "
            safe = safe & is_connected
            if recent_move
              # https://github.com/aelse/dashing-health/blob/master/widgets/health/health.html
              @set 'status-' + contact_type + '-state', 'recent'
              @set 'status-' + contact_type + '-recent',  sensor_name
    if !recent_move
      @set 'status-' + contact_type + '-state', 'closed'
    status


  @accessor 'status-cam', ->
    @contact_status('cam')

  @accessor 'status-pir', ->
    @contact_status('pir')
    
    

  @accessor 'status-contact', ->
    status = ""
    safe = 1
    if @get('sensors')
      for sensor in @get('sensors')
          is_connected = sensor['is_connected']
          event_type = sensor['event_type']
          updated_on = sensor['updated_on']
          sensor_name = sensor['sensor_name']
          age = sensor['age']
          if event_type == 'contact'
            # http://stackoverflow.com/questions/658044/tick-symbol-in-html-xhtml
            if is_connected == 1
              symbol = '&#10004;' # check ok
            else
              symbol = '&#10008;' # open, not ok
            status = status + symbol + " "
            safe = safe & is_connected
            # fix: only last sensor is shown
            if safe == 0
              # https://github.com/aelse/dashing-health/blob/master/widgets/health/health.html
              @set 'status-contact-state', 'open'
              @set 'status-contact-open',  sensor_name + ' ' + age + 'm '
    if safe == 1
      @set 'status-contact-state', 'closed'
    status

  ready: ->
    container = $(@node).parent()
    # Gross hacks. Let's fix this.
    width = (Dashing.widget_base_dimensions[0] * container.data("sizex")) + Dashing.widget_margins[0] * 2 * (container.data("sizex") - 1)
    height = (Dashing.widget_base_dimensions[1] * container.data("sizey"))
    @graph = new Rickshaw.Graph(
      element: @node
      width: width
      height: height
      renderer: "bar"
      #renderer: @get("graphtype")
      series: [
        {
        color: "#fff",
        data: [{x:0, y:0}]
        }
      ]
      padding: {top: 0.02, left: 0.02, right: 0.02, bottom: 0.02}
    )
    @graph.series[0].data = @get('points') if @get('points')
    x_axis = new Rickshaw.Graph.Axis.Time(graph: @graph)
    y_axis = new Rickshaw.Graph.Axis.Y(graph: @graph, tickFormat: Rickshaw.Fixtures.Number.formatKMBT)
    @graph.render()

  onData: (data) ->
    console.log("OnData started " + @get('zone_name'))
    if @graph && data.points
      @graph.series[0].data = data.points
      @graph.render()
    
