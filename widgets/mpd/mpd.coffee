class Dashing.mpd extends Dashing.ClickableWidget
  

  ready: ->
    

  onData: (data) ->
    
  select_mpd: (name, target) ->
    #unselect all
    target.style.borderColor='red'
    #update interface
    $.post '/mpd/change_mpd', mpd_name: name

  onClick: (event) ->
    console.log("event: " + event.target.id)
    command = event.target.id.split ":"
    
    #if /mpd:/.test(event.target.id)
    switch command[0]
      when 'mpd' then @select_mpd(command[1], event.target)
      when 'output' then console.log("output")
  