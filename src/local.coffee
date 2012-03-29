Spine ?= require('spine')

Spine.Model.Local =
  extended: ->
    @change @saveLocal
    @fetch @loadLocal
    
  saveLocal: ->
    result = JSON.stringify(
      result   : @
      idCounter: @idCounter
    )
    localStorage[@className] = result

  loadLocal: ->
    load = localStorage[@className]
    {result, idCounter} = JSON.parse(load) or {}
    @refresh(result or [], clear: true)
    @idCounter = idCounter or 0
    
module?.exports = Spine.Model.Local