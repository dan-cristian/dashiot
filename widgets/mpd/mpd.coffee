class Dashing.mpd extends Dashing.ClickableWidget
  

  ready: ->
    

  onData: (data) ->
    @set 'mpd_playstate', data.mpd_playstate
    @set 'mpd_random', data.mpd_random
    @set 'mpd_repeat', data.mpd_repeat
    @select_mpd("mpd:" + data.mpd_zone, null)
    
  select_mpd: (name, target) ->
    cells = $(@node).find(".zone-name")
    for cell in cells
      cell.style.borderColor=''
      if target == null
        if cell.id == name
          target = cell
    #unselect all
    target.style.borderColor='red'
    #update interface
    $.post '/mpd/change_mpd', mpd_name: name
  
  exec_cmd: (cmd_name, target) ->
    $.post '/mpd/exec_cmd', cmd_name: cmd_name

  exec_cmd_cust: (cmd_name, target) ->
    $.post '/mpd/exec_cmd_cust', cmd_name: cmd_name

  onClick: (event) ->
    console.log("event: " + event.target.id)
    command = event.target.id.split ":"
    
    #if /mpd:/.test(event.target.id)
    switch command[0]
      when 'mpd' then @select_mpd(command[1], event.target)
      when 'cmd' then @exec_cmd(command[1], event.target)
      when 'cmd_cust' then @exec_cmd_cust(command[1], event.target)
      when 'output' then console.log("output")
  