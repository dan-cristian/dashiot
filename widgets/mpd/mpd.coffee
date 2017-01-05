class Dashing.mpd extends Dashing.ClickableWidget
  

  ready: ->
    

  select_mpd: (name, target, do_post) ->
    console.log('select_mpd started for ' + name)
    cells = $(@node).find(".zone-name")
    #unselect all
    for cell in cells
      if cell.className != 'zone-name'
        cell.className = 'zone-name'
      if target == null
        if cell.id == name
          target = cell
    if target == null
      console.log('!!!! Warning target is null for ' + name)
      return
    target.className = 'zone-name inverted'
    if do_post
      #update interface
      $.post '/mpd/change_mpd', mpd_name: name
    console.log('select_mpd completed')
  
  exec_cmd: (cmd_name) ->
    $.post '/mpd/exec_cmd', cmd_name: cmd_name

  exec_cmd_cust: (cmd_name) ->
    $.post '/mpd/exec_cmd_cust', cmd_name: cmd_name

  refresh_output: (enabled_list) ->
    console.log('refresh_output started')
    cells = $(@node).find(".output")
    for cell in cells
      if cell.className != 'output'
        cell.className = 'output'
      if cell.id.search("output:") >= 0
        zone = (cell.id.split ":")[1]
        @set 'output_'+zone, 'off'
        for out in enabled_list
          #fix this
          if out.search(zone) >= 0
            #console.log('Found cell ' + zone + ' for output ' + out)
            cell.className='output inverted'
            @set 'output_'+zone, 'on'
    console.log('refresh_output completed')

  update_volume: (volume) ->
    elements = $(@node).find('.volume')
    for element in elements
      if element.id == 'mpd:volume'
        element.value = volume

  onClick: (event) ->
    console.log("event: " + event.target.id)
    command = event.target.id.split ":"
    #if /mpd:/.test(event.target.id)
    switch command[0]
      when 'mpd' then @select_mpd(command[1], event.target, true)
      when 'cmd' then @exec_cmd(command[1])
      when 'cmd_cust' then @exec_cmd_cust(command[1])
      when 'output' then @exec_cmd_cust(event.target.id)
    console.log('onclick completed')

  onData: (data) ->
    @set 'mpd_playstate', data.mpd_playstate
    @set 'mpd_random', data.mpd_random
    @set 'mpd_repeat', data.mpd_repeat
    if data.mpd_zone != null
      @select_mpd("mpd:" + data.mpd_zone, null, false)
    else
      console.log('Error mpd zone is missing at onData')
    if data.outputs_enabled != null
      @refresh_output(data.outputs_enabled)
    else
      console.log('Error, enabled outputs missing')
    @update_volume(data.mpd_volume)
    
