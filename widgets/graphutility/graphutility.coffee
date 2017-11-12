class Dashing.Graphutility extends Dashing.Widget

  @accessor 'current', ->
    @get('day_total_units')

  @accessor 'current2', ->
    tmp=@get('units_2_delta') 
    if tmp != ''
      Math.round(tmp, 0)
    else
      ''

  @accessor 'updateon', ->
    points = @get('points')
    if points
      today = Math.round(new Date().getTime() / 1000)
      delta = today - points[points.length - 1].x
      minutes = Math.floor((delta % 3600) / 60)
      seconds = delta % 60
      "#{minutes}m#{seconds}s"

  @accessor 'unit_name_label', ->
    @get('unit_name')
    
  @accessor 'unit_2_name_label', ->
    @get('unit_2_name')

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
    if @graph
      @graph.series[0].data = data.points
      @graph.render()
