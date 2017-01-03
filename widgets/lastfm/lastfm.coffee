class Dashing.lastfm extends Dashing.ClickableWidget

  ready: ->
    status = $(@node).find('p.status')
    if status.html() == 'ok'
      status.remove()

  onData: (data) ->
    # Handle incoming data
    # You can access the html node of this widget with `@node`
    # $(@node).fadeOut().fadeIn()
    @set 'is_loved', data.loved
    @set 'nowplaying', data.nowplaying
    

  onClick: (event) ->
    console.log("Click event: " + event)
    console.log("event: " + event.target.id)
    switch event.target.id
      when 'empty-heart' then $.post '/lastfm/love', track: 'not used'
