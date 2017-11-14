_ = require 'lodash'
hc = require './chain'
debug = require('debug')('hc.Boxlet')
EventEmitter = require('events')
###
제 1 목적은 능동성을 확보하는것.

Boxlet 는 EventEmitter, Promise와 같은 선상에 있는 능동체이다
또한 상태, 저장공간을 가진다.
  (Reducer와 차이가 먼지 고민하기.. 쩝)
함수의 흐름은 Chain으로 해결한다. <--> 그러면 Boxlet는 무엇인가?
  > program = user defined data + user defined operation
  > 단순히 데이터인가? 그렇지 않다. Boxlet는 ADT라고 봐야한다.
  > 즉 데이터 + 연산의 모임.
  > 그런데 기본제공되는, 널리 쓰이는 사례일 뿐이다. 그럼 뭘 구현해야하지?
  > 스트림은 OS에 규정된 실체를 다룬다. 파일, 네트워크, 파이프등...
  > 체인은 ADT-ADT 내지, 입력데이터 소스 -> 중간/외부 데이터소스로 간다.
  > 없는 데이터를 만들수는 없지. 그러니, 정보량을 보존(변환)하거나, 축소할뿐.(Reduce..?)
  >> 이거자체가 체인... ah...
  > 맥락에 의한 확장도 가능은한데..?(과거 데이터를 이용하는것뿐이지만..) 
  >> 체인에서 외부 요소를 접근하기로 했지...
  >> 그러고보니 par,ser Boxlet자체도 체인으로 정의를 해버렸네.. 흠..

But 고정된 데이터 저장소,버퍼등 
DFD의 흐름이 아니라 다양한 크기의 저장소에 집중한다.

Boxlet는 하나의 핸들러를 가진다.
  > 다수의 핸들러를 상황에 맞춰서운용하면 이미 커스텀 모듈급
  
###
class Boxlet extends EventEmitter
  constructor: ()->
    @routine = hc() 
    @handler = hc()
  setHandler: (@handler)-> 
  setDataHandler: (@handler)-> 
  doHandling: (data, callback)->
    return @handler data, callback


Boxlet.Fixed =
class FixedBoxlet extends Boxlet
  constructor: (@data)->
    super()
    @feedbacks = _.map @data, (d)-> undefined
    @errors = _.map @data, (d)-> undefined
  start: (callback)->
    self = this
    @routine (err)->
      callback err, self
# 
# Boxlet.Flex = # reducer와 코드 구조를 정리하는 것을 고민하자.
# class FlexBoxlet extends Boxlet
#   constructor: (@opt)->
#     super()
#     @queue = [] 
#     @afterHandling = @opt.afterHandling
#     @getEvictable = @opt.getEvictable 
# 
#     if @afterHandling
#       @afterHandling = (args...)=> @afterHandling args... 
#     unless @getEvictable
#       throw new Error "getEvictable is required"
# 
#     if @opt.check.put 
#       @on 'put', ()=> @check()
# 
#   put: (data)->
#     @queue.push data
#     @emit 'put', this
# 
#   check: ()->
#     data = @getEvictable this
#     if data
#       @doHandling data, @afterHandling or undefined
#     else 
#       @emit 'pending', this
#   # afterHandling: (err)->    
#   # getEvictable: ()->
#   #   throw new Error 'Not Implement'  

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


Boxlet.par = 
Boxlet.parallel = (data)-> 
  d = new FixedBoxlet data 
  _.forEach data, (datum, inx)->
    d.routine.async inx, (done)->
      d.doHandling datum, (err, feedback)->
        # debug 'done a parallel', err, feedback
        d.feedbacks[inx] = feedback
        d.errors[inx] = err
        done err 
  d.routine.wait() 
  return d


Boxlet.nPar = 
Boxlet.nParallel = (concurrent, data)-> 
  d = new FixedBoxlet data 
  s = new Semaphore concurrent 
  _.forEach data, (datum, inx)->
    d.routine.async inx, (done)->
      s.enter ()->
        d.doHandling datum, (err, feedback)->
          s.leave()
          # debug 'done a parallel', err, feedback
          d.feedbacks[inx] = feedback
          d.errors[inx] = err
          done err 

  d.routine.wait() 
  return d

Boxlet.ser =
Boxlet.serial = (data)->
  d = new FixedBoxlet data 
  _.forEach data, (datum, inx)->
    d.routine.async inx, (done)->
      debug 'Boxlet.fire', datum
      d.doHandling datum, (err, feedback)->
        debug 'done a serial', err, feedback
        d.feedbacks[inx] = feedback
        d.errors[inx] = err
        done err
    d.routine.wait() 
  return d

module.exports = exports = Boxlet
