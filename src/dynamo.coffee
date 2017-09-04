_ = require 'lodash'
hc = require './chain'
debug =  require('debug')('hc.dynamo')
###
제 1 목적은 능동성을 확보하는것.

Dynamo 는 EventEmitter, Promise와 같은 선상에 있는 능동체이다

  addChain
  removeChain
###
class Dynamo
  constructor: (opt) -> 

  setCallback: (@ext_fn)-> 
  fireHook: (data, callback)->
    @ext_fn data, callback if @ext_fn 


Dynamo.par = 
Dynamo.parallel = (data)->

  d = new Dynamo()
  d.data = data
  d.feedbacks = _.map data, (d)-> undefined
  d.errors = _.map data, (d)-> undefined

  d.start = (callback)->
    chain = hc()
    _.forEach data, (datum, inx)->
      chain.async inx, (cur, done)->
        d.fireHook datum, (err, feedback)->
          # debug 'done a parallel', err, feedback
          d.feedbacks[inx] = feedback
          d.errors[inx] = err
          done err 

    chain.wait()
    chain {}, (err, f, exe)-> 
      # debug 'callback', err, f, exe
      # debug 'return', err, d
      callback err, d
  return d

Dynamo.ser =
Dynamo.serial = (data)->
  d = new Dynamo()
  d.data = data
  d.feedbacks = _.map data, (d)-> undefined
  d.errors = _.map data, (d)-> undefined

  d.start = (callback)->
    chain = hc()
    _.forEach data, (datum, inx)->
      chain.async inx, (cur, done)->
        debug 'dynamo.fire', datum
        d.fireHook datum, (err, feedback)->
          debug 'done a serial', err, feedback
          d.feedbacks[inx] = feedback
          d.errors[inx] = err
          done err
      chain.wait() 
    # chain.do ()->
    #   debug 'serial end'
    chain {}, (err, f, exe)-> 
      debug 'callback', err, f, exe
      debug 'return', err, d
      callback err, d
  return d

module.exports = exports = Dynamo