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
  setCallback: (@ext_fn)-> 
  fireHook: (data, callback)->
    @ext_fn data, callback if @ext_fn 

Dynamo.Fixed =
class FixedDynamo extends Dynamo
  constructor: (@data)->
    @feedbacks = _.map @data, (d)-> undefined
    @errors = _.map @data, (d)-> undefined


class Semaphore
  constructor: (max)->
    @available = max 
    @queue = []
  enter: (fn)->
    @queue.push fn
    @runAvailable() 
  leave: ()->
    @available++
    @runAvailable() 
  runAvailable: ()->
    return if @queue.length is 0 
    return if @available is 0 
    @available-- 
    fn = @queue.shift()
    fn() 
  destroy: ()->
    @available = 0
    @queue = [] 
    

Dynamo.par = 
Dynamo.parallel = (data)-> 
  d = new FixedDynamo data 

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

      
Dynamo.nPar = 
Dynamo.nParallel = (concurrent, data)-> 
  d = new FixedDynamo data 
    
  d.start = (callback)->
    s = new Semaphore concurrent
    chain = hc()
    _.forEach data, (datum, inx)->
      chain.async inx, (cur, done)->
        s.enter ()->
          d.fireHook datum, (err, feedback)->
            s.leave()
            # debug 'done a parallel', err, feedback
            d.feedbacks[inx] = feedback
            d.errors[inx] = err
            done err 

    chain.wait()
    chain {}, (err, f, exe)-> 
      s.destroy()
      # debug 'callback', err, f, exe
      # debug 'return', err, d
      callback err, d
  return d

Dynamo.ser =
Dynamo.serial = (data)->
  d = new FixedDynamo data 

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