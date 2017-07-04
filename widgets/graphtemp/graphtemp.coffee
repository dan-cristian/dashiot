class Dashing.Graphtemp extends Dashing.Widget

  @accessor 'current', ->
    return @get('displayedValue') if @get('displayedValue')
    points = @get('points')
    if points
      points[points.length - 1].y

  @accessor 'updateon', ->
    points = @get('points')
    if points
      today = Math.round(new Date().getTime() / 1000)
      delta = today - points[points.length - 1].x
      minutes = Math.floor((delta % 3600) / 60)
      seconds = delta % 60
      "#{minutes}:#{seconds}"
  
  @accessor 'humidity', ->
    humidity = @get('humidity')
    if humidity
      return "#{humidity}%"
    else
      return "-"
  
  @accessor 'extra', ->
    extra = @get('tag')
    if extra == 1
      "ON"
    else
      if extra == 0
        "OFF"
      else
        extra

  @accessor 'arrow', ->
    points = @get('points')
    if points && points.length >= 3 
      last = points[points.length - 1].y
      prev1 = points[points.length - 2].y
      prev2 = points[points.length - 3].y
      if last >= prev1 && prev1 >= prev2 then 'fa fa-arrow-up' else 'fa fa-arrow-down'

  ready: ->
    container = $(@node).parent()
    # Gross hacks. Let's fix this.
    width = (Dashing.widget_base_dimensions[0] * container.data("sizex")) + Dashing.widget_margins[0] * 2 * (container.data("sizex") - 1)
    height = (Dashing.widget_base_dimensions[1] * container.data("sizey"))
    @graph = new Rickshaw.Graph(
      element: @node
      width: width
      height: height
      renderer: "line"
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
    if @graph
      @graph.series[0].data = data.points
      @graph.render()
    extra = @get('tag')
    if extra == 1
      @set 'is-heat-on', 'true'
    else
      if extra == 0
        @set 'is-heat-on', 'false'