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

  @accessor 'status-cam', ->
    if @get('event_type') == 'cam'
      if @get('is_connected') == 1
        status = "CAM-OK" 
      else
        status = "CAM-MOVE"
      "#{status}"
    else
      "-"

  @accessor 'status-pir', ->
    if @get('event_type') == 'pir'
      if @get('is_connected') == 1
        status = "PIR-OK" 
      else
        status = "PIR-MOVE"
      "#{status}"
    else
      "-"

  @accessor 'status-contact', ->
    console.log("Request status contact " + @get('zone_name'))
    status = "+"
    index = 0
    if @get('sensors')
      parent = $(@node).find("contact-1")
      for sensor in @get('sensors')
          is_connected = sensor['is_connected']
          event_type = sensor['event_type']
          updated_on = sensor['updated_on']
          sensor_name = sensor['sensor_name']
          if event_type == 'contact'
            status = status + sensor_name + is_connected + " "
    status

  @accessor 'status-contact2', ->
    if @get('event_type') == 'contact'
      if @get('is_connected') == 1
        status = "IO-CLOSED" 
      else
        status = "IO-OPEN"
      "#{status}"
    else
      "-"


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
    
