class Dashing.Graphutilityex extends Dashing.Widget

  @accessor 'current', ->
    return @get('displayedValue') if @get('displayedValue')
    points = @get('points_value')
    if points
      points[points.length - 1].y

  @accessor 'updateon', ->
    points = @get('points_value')
    if points
      today = Math.round(new Date().getTime() / 1000)
      delta = today - points[points.length - 1].x
      minutes = Math.floor((delta % 3600) / 60)
      seconds = delta % 60
      "#{minutes}:#{seconds}"
  
  
  @accessor 'arrow', ->
    points = @get('points_value')
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
        name: 'depth'
        }
      ]
      padding: {top: 0.02, left: 0.1, right: 0.1, bottom: 0.02}
    )

    @graph.series[0].data = @get('points_value') if @get('points_value')

    x_axis = new Rickshaw.Graph.Axis.Time(graph: @graph,
      tickTransform: (svg) ->
        svg.call(xAxis).selectAll("text").style("text-anchor", "start").attr("transform", "rotate(-45)")
    )
    y_axis = new Rickshaw.Graph.Axis.Y(graph: @graph, 
      tickFormat: Rickshaw.Fixtures.Number.formatKMBT
      )
    @graph.render()
  
  onData: (data) ->
    if @graph
      @graph.series[0].data = data.points_value
      @graph.render()
