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

  toggle_visibility: (element) ->
    if element.offsetParent == null 
      element.style.display = 'block'
    else
      element.style.display = 'none'

  exec_cmd_cust: (cmd_name) ->
    switch cmd_name
      when 'advanced-settings'
        @toggle_visibility(this.parentView.node.getElementById('simple-settings'))
        @toggle_visibility(this.parentView.node.getElementById('advanced-settings'))
      else
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

  update_current: (data) ->
    elements = $(@node).find('.progress-bar')
    for element in elements
      if element.id == 'mpd:volume'
        element.value = data.mpd_volume
      if element.id == 'mpd:duration'
        element.value = data.mpd_songposition
        element.max = data.mpd_songduration

  update_zones_playing: (zonesplaying) ->
    cells = $(@node).find(".zone-status")
    for cell in cells
      cell.className = 'zone-status'
      for zone in zonesplaying
        if cell.id == 'status:' + zone
          cell.className='zone-status zone-status-playing'

  select_playlist: (name) ->
    $.post '/mpd/select_playlist', playlist_name: name

  onClick: (event) ->
    console.log("event: " + event.target.id)
    command = event.target.id.split ":"
    #if /mpd:/.test(event.target.id)
    switch command[0]
      when 'mpd' then @select_mpd(command[1], event.target, true)
      when 'cmd' then @exec_cmd(command[1])
      when 'cmd_cust' then @exec_cmd_cust(command[1])
      when 'output' then @exec_cmd_cust(event.target.id)
      when 'playlist' then @select_playlist(command[1])
    console.log('onclick completed')

  onData: (data) ->
    if typeof(data.mpd_playstate) != 'undefined'
      @set 'mpd_playstate', data.mpd_playstate
    if typeof(data.mpd_random) != 'undefined'
      @set 'mpd_random', data.mpd_random
    if typeof(data.mpd_repeat) != 'undefined'
      @set 'mpd_repeat', data.mpd_repeat
    if typeof(data.mpd_zone) != 'undefined'
      @select_mpd("mpd:" + data.mpd_zone, null, false)
    if typeof(data.outputs_enabled) != 'undefined'
      @refresh_output(data.outputs_enabled)
    if typeof(data.mpd_volume) != 'undefined'
      @update_current(data)
    if typeof(data.mpd_zonesplaying) != 'undefined'
      @update_zones_playing(data.mpd_zonesplaying)
    
