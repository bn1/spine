should = require 'should'
sinon  = require 'sinon'
zombie = require 'zombie'

describe "Queryset", ->
  $ = jQuery = undefined

  before (done) ->
    browser = new zombie.Browser()

    browser.visit("file://localhost#{__dirname}/index.html", ->
      global.document      ?= browser.document
      global.window        ?= browser.window
      global.window.jQuery ?= require('jQuery').create(window)

      global.Spine ?= require '../src/spine'
      require '../../../app/lib/extras'
      $ = jQuery = Spine.$

      done()
    )

  after ->
    delete global[key] for key in ['document', 'window', 'Spine', 'name']

  Product = undefined

  beforeEach ->
    Product = Spine.Model.setup('Product', ["name", "price"])
    Product.refresh([
      {name: 'product1', price: 5}
      {name: 'product2', price: 5}
      {name: 'product3', price: 3}
      {name: 'product4', price: 3}
      {name: 'product5', price: 1}
    ])

  it 'should recognize queryset', ->
    Product.is_queryset.should.equal false
    Product.all().is_queryset.should.equal true
    
  it 'should filter results', ->
    Product.filter(price: 3).length.should.equal 2
    Product.filter(price: 1).length.should.equal 1
    Product.filter(price: 5).length.should.equal 2

  it 'should exclude results', ->
    Product.exclude(price: 5).length.should.equal 3
    Product.exclude(price: 3).length.should.equal 3
    Product.exclude(price: 1).length.should.equal 4

  it 'should chain filters', ->
    Product.filter(price: 5).filter(price: 3).length.should.equal 0
    Product.filter(price: 3).filter(name: 'product4').length.should.equal 1

  it 'can order', ->
    ordered = Product.order_by('name')

    ordered[0].name.should.equal 'product1'
    ordered[1].name.should.equal 'product2'
    ordered[2].name.should.equal 'product3'
    ordered[3].name.should.equal 'product4'
    ordered[4].name.should.equal 'product5'

  it 'can rev order', ->
    ordered = Product.order_by('-name')
    
    ordered[0].name.should.equal 'product5'
    ordered[1].name.should.equal 'product4'
    ordered[2].name.should.equal 'product3'
    ordered[3].name.should.equal 'product2'
    ordered[4].name.should.equal 'product1'

  it 'can chain ordering', ->
    ordered = Product.order_by('price', '-name')

    ordered[0].price.should.equal 1
    ordered[0].name.should.equal 'product5'

    ordered[1].price.should.equal 3
    ordered[1].name.should.equal 'product4'
    ordered[2].price.should.equal 3
    ordered[2].name.should.equal 'product3'

    ordered[3].price.should.equal 5
    ordered[3].name.should.equal 'product2'
    ordered[4].price.should.equal 5
    ordered[4].name.should.equal 'product1'

  it 'can mix ordering', ->
    ordered = Product.order_by('-price', '-name')

    ordered[0].price.should.equal 5
    ordered[0].name.should.equal 'product2'
    ordered[1].price.should.equal 5
    ordered[1].name.should.equal 'product1'

    ordered[2].price.should.equal 3
    ordered[2].name.should.equal 'product4'
    ordered[3].price.should.equal 3
    ordered[3].name.should.equal 'product3'

    ordered[4].price.should.equal 1
    ordered[4].name.should.equal 'product5'

  it 'can do all ordering with functions', ->
    Product::return_price = -> @price

    ordered = Product.order_by('-return_price')

    ordered[0].return_price().should.equal 5
    ordered[1].return_price().should.equal 5

    ordered[2].return_price().should.equal 3
    ordered[3].return_price().should.equal 3

    ordered[4].return_price().should.equal 1

  it 'can also do mix ordering with functions', ->
    Product::return_price = -> @price
    Product::return_name = -> @name

    ordered = Product.order_by('-return_price', '-return_name')

    ordered[0].return_price().should.equal 5
    ordered[0].return_name().should.equal 'product2'
    ordered[1].return_price().should.equal 5
    ordered[1].return_name().should.equal 'product1'

    ordered[2].return_price().should.equal 3
    ordered[2].return_name().should.equal 'product4'
    ordered[3].return_price().should.equal 3
    ordered[3].return_name().should.equal 'product3'

    ordered[4].return_price().should.equal 1
    ordered[4].return_name().should.equal 'product5'

  it 'can also mix functions ordering with classic field\'s ordering', ->
    Product::return_name = -> @name

    ordered = Product.order_by('-price', '-return_name')

    ordered[0].price.should.equal 5
    ordered[0].return_name().should.equal 'product2'
    ordered[1].price.should.equal 5
    ordered[1].return_name().should.equal 'product1'

    ordered[2].price.should.equal 3
    ordered[2].return_name().should.equal 'product4'
    ordered[3].price.should.equal 3
    ordered[3].return_name().should.equal 'product3'

    ordered[4].price.should.equal 1
    ordered[4].return_name().should.equal 'product5'

  it 'can delete items', ->
    Product.all().delete()
    Product.all().length.should.equal 0

  it 'can delete filtered/excluded items', ->
    Product.exclude(price: 5).delete()
    Product.all().length.should.equal 2
