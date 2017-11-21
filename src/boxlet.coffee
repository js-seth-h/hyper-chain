_ = require 'lodash'
hc = require './chain'
debug = require('debug')('hc.Boxlet2')


###


Trigger 계열 - pullout에 대한 자동화
  * consecution: 들어오는 즉시 나감. 처리함수의 연속.
  * asap : 가능한 빨리 큐에서 꺼냄. 비동기
  * debounce: 지연된 시간내의 것을 모아서.
  * throttle: 우선 들어온것 처리하고, given time 동안 처리를 안함.
  * interval: 지정된 간격으로 나감
  * backPressure:
    pullOut이 처리되면 연속 호출
    처리할 데이터가 없으면? setTimeout
    최초의 시작은?
    데이터가 없으면 알림?
    
  
Puller 계열
  * passthough 들어온 것을 그대로 내보냄
  * dequeue: 1개만 꺼냄
  * latest 가장 마지막 것만 처리
  * reduce 리듀싱 처리
  * outSource: 외부에서 가져옴

Outer 계열
  * serial 순차 처리
  * parallel 전체 동시 병렬 처리
  * nParallel 갯수 제한 동시 처리

Handler
  * 100% 커스텀.

대량 처리시의 문제.
이때는 puts로 전부 넣기가 무리고, 
스트림처리식도 부족함. 동기화가 안되서, 막 밀어넣고 전부 버퍼링 되게됨.
BackPressure 개념을 적용해야하나..?


###

_ASAP = (fn)-> setTimeout fn, 0
if process?.nextTick?
  _ASAP = process.nextTick
  

_proto = (klass, dict)->
  for own key, v of dict
    klass.prototype[key] = v

class Boxlet
  constructor:()->
    @internal_buffer = []
    @reset()
  reset: ()->
    # @afterPut = hc() # event handler
    # @afterPullOut = hc() #event handler
    @trigger = hc()
    
    @manual()
    @puller = hc() # 데이터 추출 루틴
    @passthough()
    @outer = hc() # 방출 제어 루틴.
    @serial()
    @handler = hc() # 개별 방출 핸들러
    return this

  _push: (items)->
    @internal_buffer.push items...
    debug '_push'
    @trigger("after-put", @internal_buffer)
  put: (item)->
    @_push [ item ]
    return this
  putAll: (items...)->
    @_push items
    return this
  puts: (array)->
    @_push array
    return this

  pullOut: (callback)->
    box = this
    _fn = hc()
      .await "data", (done)->
        debug 'call puller'
        box.puller box, done 
      .load "data"
      .await (data, done)->
        debug 'call outter'
        box.outer data, done
      .do (data)->
        box.trigger 'after-pullout', data
    _fn (err)->
      if callback
        callback err, box

    return this

  setHandler: (@handler)->
    return this
  setDataHandler: (@handler)->
    return this
  doHandling: (data, callback)->
    @handler data, callback
    return this


_proto Boxlet,
  manual : ()->
    box = this
    box.trigger.clear()
    return box
  consecution : ()->
    box = this
    box.trigger.clear()
      .do (timing_name)->
        return if timing_name isnt 'after-put'
        debug 'consecution call pullOut'
        box.pullOut()
    return box

  asap: ()->
    box = this
    box.trigger.clear()
      .do (timing_name)->
        return if timing_name isnt 'after-put'
        _ASAP ()-> box.pullOut()
    return box 
  
  backPressure: (msec)->
    box = this
    box.trigger.clear()
      .do (timing_name, data)->
        return if timing_name isnt 'after-pullout'        
        _pullout = ()-> box.pullOut() 
        if data.length > 0 
          _ASAP _pullout
        else 
          setTimeout _pullout, msec
    
  interval : (msec)->
    box = this
    box.trigger.clear()
    _tick = ()->
      box.pullOut()
    setInterval _tick, msec
    return box

  throttle: (msec)->
    box = this
    box.trigger.clear()
      .do (timing_name)->
        return if timing_name isnt 'after-put' 
        return if box.tid
        _dfn = ()->
          box.tid = null
          box.pullOut()
        box.tid = setTimeout _dfn, msec
        box.pullOut()
    return box
    
  debounce : (msec)->
    box = this
    box.trigger.clear()
      .do (timing_name)->
        return if timing_name isnt 'after-put'  
        return if box.tid
        _dfn = ()->
          box.tid = null
          box.pullOut()
        box.tid = setTimeout _dfn, msec
    return box

  passthough: ()->
    box = this
    box.puller.clear().do (box)->
      list = box.internal_buffer
      box.internal_buffer = []
      @feedback.reset list
    return box
  latest: ()->
    box = this
    box.puller.clear().do (box)->
      list = box.internal_buffer
      box.internal_buffer = []
      @feedback.reset [ _.last list ]  
  reduce: (reduce_fn)->
    box = this
    box.puller.clear().do (box)->
      list = box.internal_buffer
      box.internal_buffer = []
      val = reduce_fn list
      @feedback.reset [val]
    return box

  par : ()-> @parallel()
  parallel : ()->
    box = this
    box.outer.clear().await (data, done)->
      _fn = hc()
      box.feedbacks = _.map data, (d)-> undefined
      box.errors = _.map data, (d)-> undefined
      _.forEach data, (datum, inx)->
        _fn.async inx, (done)->
          box.doHandling datum, (err, feedback)->
            box.feedbacks[inx] = feedback
            box.errors[inx] = err
            done err
      _fn.wait()
      _fn done
    return box

  ser : ()-> @serial()
  serial : ()->
    box = this
    box.outer.clear().await (data, done)->
      _fn = hc()
      box.feedbacks = _.map data, (d)-> undefined
      box.errors = _.map data, (d)-> undefined
      _.forEach data, (datum, inx)->
        _fn.async inx, (done)->
          box.doHandling datum, (err, feedback)->
            debug 'done a serial', err, feedback
            box.feedbacks[inx] = feedback
            box.errors[inx] = err
            done err
        _fn.wait()
      _fn done
    return box

# for N-Parallel
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

_proto Boxlet,
  nPar : (concurrent)-> @nParallel concurrent
  nParallel : (concurrent)->
    box = this
    s = new Semaphore concurrent
    box.outer.clear().await (data, done)->
      _fn = hc()
      box.feedbacks = _.map data, (d)-> undefined
      box.errors = _.map data, (d)-> undefined
      _.forEach data, (datum, inx)->
        _fn.async inx, (done)->
          s.enter ()->
            box.doHandling datum, (err, feedback)->
              s.leave()
              box.feedbacks[inx] = feedback
              box.errors[inx] = err
              done err
      _fn.wait()
      _fn done
    return box

module.exports = exports = Boxlet
