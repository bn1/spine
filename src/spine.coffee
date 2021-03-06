Events =
  bind: (ev, callback) ->
    evs   = ev.split(' ')
    calls = @hasOwnProperty('_callbacks') and @_callbacks or= {}

    for name in evs
      calls[name] or= []
      calls[name].push(callback)
    this

  one: (ev, callback) ->
    @bind ev, ->
      @unbind(ev, arguments.callee)
      callback.apply(@, arguments)

  trigger: (args...) ->
    ev = args.shift()

    list = @hasOwnProperty('_callbacks') and @_callbacks?[ev]
    return unless list

    for callback in list
      if callback.apply(@, args) is false
        break
    true

  unbind: (ev, callback) ->
    unless ev
      @_callbacks = {}
      return this

    list = @_callbacks?[ev]
    return this unless list

    unless callback
      delete @_callbacks[ev]
      return this

    for cb, i in list when cb is callback
      list = list.slice()
      list.splice(i, 1)
      @_callbacks[ev] = list
      break
    this

Log =
  trace: true

  logPrefix: '(App)'

  log: (args...) ->
    return unless @trace
    if @logPrefix then args.unshift(@logPrefix)
    console?.log?(args...)
    this

moduleKeywords = ['included', 'extended']

class Module
  @include: (obj) ->
    throw('include(obj) requires obj') unless obj
    for key, value of obj when key not in moduleKeywords
      @::[key] = value
    obj.included?.apply(@)
    this

  @extend: (obj) ->
    throw('extend(obj) requires obj') unless obj
    for key, value of obj when key not in moduleKeywords
      @[key] = value
    obj.extended?.apply(@)
    this

  @proxy: (func) ->
    => func.apply(@, arguments)

  proxy: (func) ->
    => func.apply(@, arguments)

  constructor: ->
    @init?(arguments...)

class Model extends Module
  @extend Events

  @records: {}
  @crecords: {}
  @attributes: []

  @configure: (name, attributes...) ->
    @className  = name
    @records    = {}
    @crecords   = {}
    @attributes = attributes if attributes.length
    @attributes and= makeArray(@attributes)
    @attributes or=  []
    @unbind()
    this

  @toString: -> "#{@className}(#{@attributes.join(", ")})"

  @find: (id) ->
    record = @records[id]
    if !record and ("#{id}").match(new RegExp("^#{@prefix}\\d+"))
      return @findCID(id)
    throw('Unknown record') unless record
    record.clone()

  @findCID: (cid) ->
    record = @crecords[cid]
    throw('Unknown record') unless record
    record.clone()

  @exists: (id) ->
    try
      return @find(id)
    catch e
      return false

  @refresh: (values, options = {}) ->
    if options.clear
      @records  = {}
      @crecords = {}

    records = @fromJSON(values)
    records = [records] unless isArray(records)

    for record in records
      record.id           or= record.cid
      @records[record.id]   = record
      @crecords[record.cid] = record

    @resetIdCounter()

    @trigger('refresh', @cloneArray(records)) unless options.trigger is false
    this

  @select: (callback) ->
    result = (record for record in @recordsValues() when callback(record))
    @cloneArray(result)

  @findByAttribute: (name, value) ->
    for id, record of @records
      if record[name] is value
        return record.clone()
    null

  @findAllByAttribute: (name, value) ->
    @select (item) ->
      item[name] is value

  @each: (callback) ->
    for key, value of @records
      callback(value.clone())

  @all: ->
    @cloneArray(@recordsValues())

  @delete: (options={}) ->
    @destroyAll options
    @deleteAll()
  
  @__filter: (args, revert=false) ->
    (rec) ->
      q = !!revert
      for key, value of args
        return q unless rec[key] is value
      !q

  @filter: (args) ->  @select @__filter args, false
  @exclude: (args) -> @select @__filter args, true

  @order_by: (keys...) ->
    if len(keys) > 1
      ref = @
      for key in keys.reverse()
        ref = ref.order_by(key)
      ref

    else
      @all().sort (x, y) ->
        key = keys[0]
        result = 1
        rev = false

        if key[0] is '-'
          key = key[1..]
          rev = true

        x = if typeof x[key] is 'function' then x[key]() else x[key]
        y = if typeof y[key] is 'function' then y[key]() else y[key]

        result *= -1 if x < y
        result  =  1 if x is null
        result  = -1 if y is null
        result  =  0 if x is y

        result *= -1 if rev

        return result

  @first: ->
    record = @recordsValues()[0]
    record?.clone()

  @last: ->
    values = @recordsValues()
    record = values[values.length - 1]
    record?.clone()

  @count: ->
    @recordsValues().length

  @deleteAll: ->
    for record in @recordsValues()
      delete @records[record.id]

  @destroyAll: (options) ->
    for record in @recordsValues()
      record.destroy(options)

  @update: (id, atts, options) ->
    @find(id).updateAttributes(atts, options)

  @create: (atts, options) ->
    unless @is_queryset then record = new @(atts)
    else   record = new @model(atts)
    record.save(options)

  @destroy: (id, options) ->
    @find(id).destroy(options)

  @change: (callbackOrParams) ->
    if typeof callbackOrParams is 'function'
      @bind('change', callbackOrParams)
    else
      @trigger('change', callbackOrParams)

  @fetch: (callbackOrParams) ->
    if typeof callbackOrParams is 'function'
      @bind('fetch', callbackOrParams)
    else
      @trigger('fetch', callbackOrParams)

  @toJSON: ->
    @recordsValues()

  @fromJSON: (objects) ->
    return unless objects
    if typeof objects is 'string'
      objects = JSON.parse(objects)
    if isArray(objects)
      (new @(value) for value in objects)
    else
      new @(objects)

  @fromForm: ->
    (new this).fromForm(arguments...)

  # Private

  @recordsValues: ->
    result = []
    for key, value of @records
      result.push(value)
    result

  @is_queryset: false
  @cloneArray: (array) ->
    @model = @ unless @is_queryset

    res = (value.clone() for value in array)
    $.extend res, @model
    
    res.recordsValues = () -> @
    res.is_queryset = true

    res

  @idCounter: 0

  @prefix: 'c-'

  @resetIdCounter: ->
    ids        = (model.cid for model in @all()).sort((a, b) -> a > b)
    lastID     = ids[ids.length - 1]
    lastID     = lastID?.replace?(new RegExp("^#{@prefix}"), '') or lastID
    lastID     = parseInt(lastID, 10)
    @idCounter = (lastID + 1) or 0

  @uid: ->
    @prefix + @idCounter++

  # Instance

  constructor: (atts) ->
    super
    @load atts if atts
    @cid or= @id or @constructor.uid()

  isNew: ->
    not @exists()

  isValid: ->
    not @validate()

  validate: ->

  load: (atts) ->
    for key, value of atts
      if typeof @[key] is 'function'
        @[key](value)
      else
        @[key] = value
    this

  attributes: ->
    result = {}
    for key in @constructor.attributes when key of this
      if typeof @[key] is 'function'
        result[key] = @[key]()
      else
        result[key] = @[key]
    result.id = @id if @id
    result

  eql: (rec) ->
    !!(rec and rec.constructor is @constructor and
        (rec.cid is @cid) or (rec.id and rec.id is @id))

  save: (options = {}) ->
    trigger = not (options.trigger is false)
    unless options.validate is false
      error = @validate()
      if error
        @trigger('error', error) if trigger
        return false

    @trigger('beforeSave', options) if trigger
    record = if @isNew() then @create(options) else @update(options)
    @trigger('save', options) if trigger
    record

  updateAttribute: (name, value, options) ->
    @[name] = value
    @save(options)

  updateAttributes: (atts, options) ->
    @load(atts)
    @save(options)

  changeID: (id) ->
    records = @constructor.records
    records[id] = records[@id]
    delete records[@id]
    @id = id
    @save()

  destroy: (options = {}) ->
    trigger = not (options.trigger is false)
    @trigger('beforeDestroy', options) if trigger
    delete @constructor.records[@id]
    delete @constructor.crecords[@cid]
    @destroyed = true
    @trigger('destroy', options) if trigger
    @trigger('change', 'destroy', options) if trigger
    @unbind()
    this

  dup: (newRecord) ->
    result = new @constructor(@attributes())
    if newRecord is false
      result.cid = @cid
    else
      delete result.id
    result

  clone: ->
    createObject(@)

  reload: ->
    return this if @isNew()
    original = @constructor.find(@id)
    @load(original.attributes())
    original

  toJSON: ->
    @attributes()

  toString: ->
    "<#{@constructor.className} (#{JSON.stringify(@)})>"

  fromForm: (form) ->
    result = {}
    for key in $(form).serializeArray()
      result[key.name] = key.value
    @load(result)

  exists: ->
    @id && @id of @constructor.records

  # Private

  update: (options) ->
    trigger = not (options.trigger is false)
    @trigger('beforeUpdate', options) if trigger
    records = @constructor.records
    records[@id].load @attributes()
    clone = records[@id].clone()
    clone.trigger('update', options) if trigger
    clone.trigger('change', 'update', options) if trigger
    clone

  create: (options) ->
    trigger = not (options.trigger is false)
    @trigger('beforeCreate', options) if trigger
    @id          = @cid unless @id

    record       = @dup(false)
    @constructor.records[@id]   = record
    @constructor.crecords[@cid] = record

    clone        = record.clone()
    clone.trigger('create', options) if trigger
    clone.trigger('change', 'create', options) if trigger
    clone

  bind: (events, callback) ->
    @constructor.bind events, binder = (record) =>
      if record && @eql(record)
        callback.apply(@, arguments)
    @constructor.bind 'unbind', unbinder = (record) =>
      if record && @eql(record)
        @constructor.unbind(events, binder)
        @constructor.unbind('unbind', unbinder)
    binder

  one: (events, callback) ->
    binder = @bind events, =>
      @constructor.unbind(events, binder)
      callback.apply(@, arguments)

  trigger: (args...) ->
    args.splice(1, 0, @)
    @constructor.trigger(args...)

  unbind: ->
    @trigger('unbind')

class Controller extends Module
  @include Events
  @include Log

  eventSplitter: /^(\S+)\s*(.*)$/
  tag: 'div'

  constructor: (options) ->
    @options = options

    for key, value of @options
      @[key] = value

    @el = document.createElement(@tag) unless @el
    @el = $(@el)

    @el.addClass(@className) if @className
    @el.attr(@attributes) if @attributes

    @events = @constructor.events unless @events
    @elements = @constructor.elements unless @elements

    @delegateEvents(@events) if @events
    @refreshElements() if @elements

    super

  release: =>
    @trigger 'release'
    @el.remove()
    @unbind()

  $: (selector) -> $(selector, @el)

  delegateEvents: (events) ->
    for key, method of events

      if typeof(method) is 'function'
        # Always return true from event handlers
        method = do (method) => =>
          method.apply(this, arguments)
          true
      else
        method = do (method) => =>
          @[method].apply(this, arguments)
          true

      match      = key.match(@eventSplitter)
      eventName  = match[1]
      selector   = match[2]

      if selector is ''
        @el.bind(eventName, method)
      else
        @el.delegate(selector, eventName, method)

  refreshElements: ->
    for key, value of @elements
      @[value] = @$(key)

  delay: (func, timeout) ->
    setTimeout(@proxy(func), timeout || 0)

  html: (element) ->
    @el.html(element.el or element)
    @refreshElements()
    @el

  append: (elements...) ->
    elements = (e.el or e for e in elements)
    @el.append(elements...)
    @refreshElements()
    @el

  appendTo: (element) ->
    @el.appendTo(element.el or element)
    @refreshElements()
    @el

  prepend: (elements...) ->
    elements = (e.el or e for e in elements)
    @el.prepend(elements...)
    @refreshElements()
    @el

  replace: (element) ->
    [previous, @el] = [@el, $(element.el or element)]
    previous.replaceWith(@el)
    @delegateEvents(@events)
    @refreshElements()
    @el

# Utilities & Shims

$ = window?.jQuery or window?.Zepto or (element) -> element

createObject = Object.create or (o) ->
  Func = ->
  Func.prototype = o
  new Func()

isArray = (value) ->
  Object::toString.call(value) is '[object Array]'

isBlank = (value) ->
  return true unless value
  return false for key of value
  true

makeArray = (args) ->
  Array::slice.call(args, 0)

# Globals

Spine = @Spine   = {}
module?.exports  = Spine

Spine.version    = '1.0.6'
Spine.isArray    = isArray
Spine.isBlank    = isBlank
Spine.$          = $
Spine.Events     = Events
Spine.Log        = Log
Spine.Module     = Module
Spine.Controller = Controller
Spine.Model      = Model

# Global events

Module.extend.call(Spine, Events)

# JavaScript compatability

Module.create = Module.sub =
  Controller.create = Controller.sub =
    Model.sub = (instances, statics) ->
      class result extends this
      result.include(instances) if instances
      result.extend(statics) if statics
      result.unbind?()
      result

Model.setup = (name, attributes = []) ->
  class Instance extends this
  Instance.configure(name, attributes...)
  Instance

Module.init = Controller.init = Model.init = (a1, a2, a3, a4, a5) ->
  new this(a1, a2, a3, a4, a5)

Spine.Class = Module
