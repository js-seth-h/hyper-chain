_ = require 'lodash'
hc = require './chain'
debug = require('debug')('hc.Boxlet2')

###

Puller 계열
  * Reduce 리듀싱 처리
  * PullAll

outer 계열

Trigger 계열
* Manual: 쭉기다리다가 명령이 오면 나감.
* ASAP 들어오는 즉시 나감
* Debounce: 지연된 시간내의 것을 모아서.
* Interval: 지정된 간격으로 나감
* Emittable : 특정 조건을 만족하여 나갈수 있을때

###


_proto = (klass, dict)->
  for own key, v of dict
    klass.prototype[key] = v

class Boxlet
  constructor:()->
    @data = []
    @reset()
  reset: ()->
    reduce = null
    @afterPut = hc() # event handler

    @puller = hc() # 데이터 추출 루틴
    @outer = hc() # 방출 제어 루틴.
    @handler = hc() # 개별 방출 핸들러

    return this
  put: (item)->
    @data.push item
    @afterPut()
    return this
  putAll: (items...)->
    @data.push items...
    @afterPut()
    return this
  puts: (array)->
    @data.push array...
    @afterPut()
    return this

  pullOut: (callback)->
    box = this
    _fn = hc()
      .await "data", (done)->
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
        box.outer data, done
    _fn (err)-> callback err, box

    return this

  setHandler: (@handler)->
    return this
  setDataHandler: (@handler)->
    return this
  doHandling: (data, callback)->
    @handler data, callback
    return this


_proto Boxlet,
  ###
  ASAP라면..
  ###
  ASAP : ()->
    @afterPut
      .do ()->
        box.pullOut()
    return box

  Interval : (msec)->
    box = this
    _tick = ()->
      box.pullOut()
    setInterval _tick, msec
    return box

  Debounce : (msec)->
    box = this
    box.afterPut
      .do ()->
        return if box.tid
        _dfn = ()->
          box.tid = null
          box.pullOut()
        box.tid = setTimeout _dfn, msec
    return box

  pullAll: ()->
    box = this
    box.puller.do (box)->
      list = box.data
      box.data = []
      @feedback.reset list
    return box
  pullReduce: (reduce_fn)->
    box = this
    box.puller.do (box)->
      list = box.data
      box.data = []
      val = reduce_fn list
      @feedback.reset [val]
    return box

  par : ()-> @parallel()
  parallel : ()->
    box = this
    box.outer.await (data, done)->
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
    box.outer.await (data, done)->
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
    box.outer.await (data, done)->
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
