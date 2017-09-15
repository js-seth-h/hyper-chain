_ = require 'lodash'
hc = require './chain'
debug = require('debug')('hc.dynamo')
EventEmitter = require('events')
###
제 1 목적은 능동성을 확보하는것.

Dynamo 는 EventEmitter, Promise와 같은 선상에 있는 능동체이다
또한 상태, 저장공간을 가진다.
  (Reducer와 차이가 먼지 고민하기.. 쩝)
함수의 흐름은 Chain으로 해결한다.
But 고정된 데이터 저장소,버퍼등 
DFD의 흐름이 아니라 다양한 크기의 저장소에 집중한다.

Dynamo는 하나의 핸들러를 가진다.
  > 다수의 핸들러를 상황에 맞춰서운용하면 이미 커스텀 모듈급
  
###
class Dynamo extends EventEmitter
  constructor: ()->
    @routine = hc()
  setDataHandler: (@ext_fn)-> 
  doDataHandling: (data, callback)->
    if @ext_fn
      return @ext_fn data, callback
    else
      callback null, null


Dynamo.Fixed =
class FixedDynamo extends Dynamo
  constructor: (@data)->
    super()
    @feedbacks = _.map @data, (d)-> undefined
    @errors = _.map @data, (d)-> undefined
  start: (callback)->
    self = this
    @routine {}, (err)->
      callback err, self

Dynamo.Flex = # reducer와 코드 구조를 정리하는 것을 고민하자.
class FlexDynamo extends Dynamo
  constructor: (@opt)->
    super()
    @queue = [] 
    @afterHandling = @opt.afterHandling
    @getEvictable = @opt.getEvictable 
    
    if @afterHandling
      @afterHandling = (args...)=> @afterHandling args... 
    unless @getEvictable
      throw new Error "getEvictable is required"
    
    if @opt.check.put 
      @on 'put', ()=> @check()
      
  put: (data)->
    @queue.push data
    @emit 'put', this

  check: ()->
    data = @getEvictable this
    if data
      @doDataHandling data, @afterHandling or undefined
    else 
      @emit 'pending', this
  # afterHandling: (err)->    
  # getEvictable: ()->
  #   throw new Error 'Not Implement'  

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
  _.forEach data, (datum, inx)->
    d.routine.async inx, (cur, done)->
      d.doDataHandling datum, (err, feedback)->
        # debug 'done a parallel', err, feedback
        d.feedbacks[inx] = feedback
        d.errors[inx] = err
        done err 
  d.routine.wait() 
  return d


Dynamo.nPar = 
Dynamo.nParallel = (concurrent, data)-> 
  d = new FixedDynamo data 
  s = new Semaphore concurrent 
  _.forEach data, (datum, inx)->
    d.routine.async inx, (cur, done)->
      s.enter ()->
        d.doDataHandling datum, (err, feedback)->
          s.leave()
          # debug 'done a parallel', err, feedback
          d.feedbacks[inx] = feedback
          d.errors[inx] = err
          done err 

  d.routine.wait() 
  return d

Dynamo.ser =
Dynamo.serial = (data)->
  d = new FixedDynamo data 
  _.forEach data, (datum, inx)->
    d.routine.async inx, (cur, done)->
      debug 'dynamo.fire', datum
      d.doDataHandling datum, (err, feedback)->
        debug 'done a serial', err, feedback
        d.feedbacks[inx] = feedback
        d.errors[inx] = err
        done err
    d.routine.wait() 
  return d

module.exports = exports = Dynamo
