class Dashing.Graphtemp extends Dashing.Widget

  @accessor 'current', ->
    return @get('displayedValue') if @get('displayedValue')
    val = @get('current_temp')
    if val
      return val
    else
      return "-"

  @accessor 'updateon', ->
    points = @get('points_temp')
    if points
      today = Math.round(new Date().getTime() / 1000)
      delta = today - points[points.length - 1].x
      minutes = Math.floor((delta % 3600) / 60)
      seconds = delta % 60
      "#{minutes}:#{seconds}"
  
  @accessor 'humidity_value', ->
    val = @get('current_humid')
    if val
        return "#{val}%"
    return ""
  
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
    points = @get('points_temp')
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
        data: [{x:0, y:0}],
        name: 'temp'
        },
        {
        color: "#faa",
        data: [{x:0, y:0}],
        name: 'humid'
        }
      ]
      padding: {top: 0.02, left: 0.1, right: 0.1, bottom: 0.02}
    )

    @graph.series[0].data = @get('points_temp') if @get('points_temp')
    @graph.series[1].data = @get('points_humid') if @get('points_humid')

    x_axis = new Rickshaw.Graph.Axis.Time(graph: @graph,
      tickTransform: (svg) ->
        svg.call(xAxis).selectAll("text").style("text-anchor", "start").attr("transform", "rotate(-45)")
    )
    y_axis = new Rickshaw.Graph.Axis.Y(graph: @graph, 
      tickFormat: Rickshaw.Fixtures.Number.formatKMBT
      )
    @graph.render()
    
    #hoverDetail = new Rickshaw.Graph.HoverDetail( {
	  #  graph: @graph,
    #} );

  onData: (data) ->
    if @graph
      @graph.series[0].data = data.points_temp
      @graph.series[1].data = data.points_humid
      @graph.render()
    extra = @get('tag')
    if extra == 1
      @set 'is-heat-on', 'true'
    else
      if extra == 0
        @set 'is-heat-on', 'false'
