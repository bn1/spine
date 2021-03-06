Spine   = do -> @Spine ? require 'spine'
isArray = Spine.isArray
require = @require or ((value) -> eval(value))


class M2MCollection extends Spine.Module
  constructor: (options={}) ->
    for key, value of options
      @[key] = value

  add: (item) ->
    if isArray(item)
      @add i for i in item

    else
      item = @model.find item unless item instanceof @model
      tmp = new @hub()
      if @left_to_right
        tmp["#{@rev_name}_id"] = @record.id
        tmp["#{@name}_id"] = item.id

      else
        tmp["#{@rev_name}_id"] = item.id
        tmp["#{@name}_id"] = @record.id
      tmp.save()

  remove: (item) ->
    i.destroy() for i in @hub.select (item) =>
      @associated(item)

  _link: (items) ->
    items.map (item) =>
      if @left_to_right then return @model.find item["#{@name}_id"]
      else return @model.find item["#{@rev_name}_id"]

  all: ->
    @_link @hub.select (item) =>
      @associated(item)

  first: ->
    @all()[0]

  last: ->
    values = @all()
    values[values.length -1]
  
  find: (id) ->
    records = @hub.select (rec) =>
      @associated(rec, id)

    throw 'Unknown record' unless records[0]
    @_link(records)[0]

  create: (record) ->
    @add @model.create(record)

  associated: (record, id) ->
    if @left_to_right
      return false unless record["#{@rev_name}_id"] is @record.id
      return record["#{@rev_name}_id"] is id if id
      
    else
      return false unless record["#{@name}_id"] is @record.id
      return record["#{@name}_id"] is id if id

    true
    
class Instance extends Spine.Module
  constructor: (options = {}) ->
    for key, value of options
      @[key] = value

  exists: ->
    @record[@fkey] and @model.exists(@record[@fkey])

  update: (value) ->
    unless value instanceof @model
      value = new @model(value)
    value.save() if value.isNew()
    @record[@fkey] = value and value.id

class Singleton extends Spine.Module
  constructor: (options = {}) ->
    for key, value of options
      @[key] = value

  find: ->
    @record.id and @model.findByAttribute(@fkey, @record.id)

  update: (value) ->
    unless value instanceof @model
      value = @model.fromJSON(value)

    value[@fkey] = @record.id
    value.save()

singularize = (str) ->
  str.replace(/s$/, '')

underscore = (str) ->
  str.replace(/::/g, '/')
     .replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
     .replace(/([a-z\d])([A-Z])/g, '$1_$2')
     .replace(/-/g, '_')
     .toLowerCase()

Spine.Model.extend
  hasMany: (name, model, fkey) ->
    fkey ?= "#{underscore(this.className)}_id"

    association = (record) ->
      model = require(model) if typeof model is 'string'

      q = {}; q[fkey] = record.id
      model.filter(q)

    @::[name] = (value) ->
      association(@).refresh(value) if value?
      association(@)

  belongsTo: (name, model, fkey) ->
    fkey ?= "#{singularize(name)}_id"

    association = (record) ->
      model = require(model) if typeof model is 'string'

      new Instance(
        name: name, model: model,
        record: record, fkey: fkey
      )

    @::[name] = (value) ->
      association(@).update(value) if value?
      association(@).exists()

    @attributes.push(fkey)

  hasOne: (name, model, fkey) ->
    fkey ?= "#{underscore(@className)}_id"

    association = (record) ->
      model = require(model) if typeof model is 'string'

      new Singleton(
        name: name, model: model,
        record: record, fkey: fkey
      )

    @::[name] = (value) ->
      association(@).update(value) if value?
      association(@).find()




  foreignKey: (model, name, rev_name) ->
    unless rev_name?
      rev_name = @className.toLowerCase()
      rev_name = singularize underscore rev_name
      rev_name = "#{rev_name}s"

    model = require(model) if typeof model is 'string'
    unless name?
      name = model.className.toLowerCase()
      name = singularize underscore name

    @belongsTo name, model
    model.hasMany rev_name, @


  manyToMany: (model, name, rev_name) ->
    unless rev_name?
      rev_name = @className.toLowerCase()
      rev_name = singularize underscore rev_name
      rev_name = "#{rev_name}s"
    rev_model = @

    model = require(model) if typeof model is 'string'
    unless name?
      name = model.className.toLowerCase()
      name = singularize underscore name

    local = typeof model.loadLocal is 'function' and typeof rev_model.loadLocal is 'function'

    class tmpModel extends Spine.Model
      @configure "_#{rev_name}_to_#{name}", "#{@rev_name}_id", "#{@name}_id"
      @extend Spine.Model.Local if local

    tmpModel.fetch() if local

    tmpModel.foreignKey rev_model, "#{rev_name}"
    tmpModel.foreignKey model,     "#{name}"


    association = (record, model, left_to_right) ->
      new M2MCollection {name, rev_name, record, model, hub: tmpModel, left_to_right}


    rev_model::["#{name}s"] = (value) ->
      association(@, model, true)

    model::["#{rev_name}s"] = (value) ->
      association(@, rev_model, false)
