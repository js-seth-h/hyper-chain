_ = require 'lodash'
hc = require './chain'
debug = require('debug')('hc.Boxlet2')


###

Trigger 계열
  * Manual: 쭉기다리다가 명령이 오면 나감.
  * consecution: 들어오는 즉시 나감. 처리함수의 연속.
  * asap : 가능한 빨리 큐에서 꺼냄. 비동기
  * debounce: 지연된 시간내의 것을 모아서.
  * interval: 지정된 간격으로 나감

Puller 계열
  * passthough 들어온 것을 그대로 내보냄
  * reduce 리듀싱 처리

Outer 계열
  * serial 순차 처리
  * parallel 전체 동시 병렬 처리
  * nParallel 갯수 제한 동시 처리

###

_ASAP = (fn)-> setTimeout fn, 0
if process.nextTick
  _ASAP = (fn)-> process.nextTick fn


_proto = (klass, dict)->
  for own key, v of dict
    klass.prototype[key] = v

class Boxlet
  constructor:()->
    @data = []
    @reset()
  reset: ()->
    @afterPut = hc() # event handler
    @manual()
    @puller = hc() # 데이터 추출 루틴
    @passthough()
    @outer = hc() # 방출 제어 루틴.
    @serial()
    @handler = hc() # 개별 방출 핸들러
    return this

  _push: (items...)->
    @data.push items...
    debug '_push'
    @afterPut()
  put: (item)->
    @_push item
    return this
  putAll: (items...)->
    @_push items...
    return this
  puts: (array)->
    @_push array...
    return this

  pullOut: (callback)->
    box = this
    _fn = hc()
      .await "data", (done)->
        debug 'call puller'
        box.puller box, done
      #   list = box.data
      #   box.data = []
      #   return list
      # .await "data", (data, done)->
      #   unless box.reduce
      #     return done null, data
      #   box.reduce data, done
      .load "data"
      .await (data, done)->
        debug 'call outter'
        box.outer data, done
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
    box.afterPut.clear()
    return box
  consecution : ()->
    box = this
    box.afterPut.clear()
      .do ()->
        debug 'consecution call pullOut'
        box.pullOut()
    return box

  asap: ()->
    box = this
    box.afterPut.clear()
      .do ()->
        _dfn = ()-> box.pullOut()
        _ASAP _dfn
    return box


  interval : (msec)->
    box = this
    box.afterPut.clear()
    _tick = ()->
      box.pullOut()
    setInterval _tick, msec
    return box

  debounce : (msec)->
    box = this
    box.afterPut.clear()
      .do ()->
        return if box.tid
        _dfn = ()->
          box.tid = null
          box.pullOut()
        box.tid = setTimeout _dfn, msec
    return box

  passthough: ()->
    box = this
    box.puller.clear().do (box)->
      list = box.data
      box.data = []
      @feedback.reset list
    return box
  reduce: (reduce_fn)->
    box = this
    box.puller.clear().do (box)->
      list = box.data
      box.data = []
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
