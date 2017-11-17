_ = require 'lodash'
hc = require './chain'
debug = require('debug')('hc.Boxlet2')
EventEmitter = require('events')

###
* Manual: 쭉기다리다가 명령이 오면 나감.
* ASAP 들어오는 즉시 나감
* Interval: 지정된 간격으로 나감
* Emittable : 특정 조건을 만족하여 나갈수 있을때
* Debounce: 지연된 시간내의 것을 모아서.

###
class Boxlet extends EventEmitter
  constructor:()->
    @data = []
    @puller = hc() # 방출 제어 루틴.
    @handler = hc()
  put: (item)->
    @data.push item
  putAll: (items...)->
    @data.push items...
  puts: (array)->
    @data.push array...

  pullOut: (callback)->
    self = this
    @puller (err)-> callback err, self

  setHandler: (@handler)->
  setDataHandler: (@handler)->
  doHandling: (data, callback)->
    return @handler data, callback

###
ASAP라면..
###
Boxlet.ASAP = ()->
  box = new Boxlet()
  box._put = box._put
  box.put = (item)->
    box._put item
    process.nextTick ()->
      box.pullOut()
  box.puller = hc()
    .map ()->
      return box.data.pop()
    .async (data, done)->
      box.doDataHandling data, done
  return box
# class AsapBoxlet extends Boxlet
#   constructor:()->
#     @data = []
#     @puller = hc() # 방출 제어 루틴.
#     @handler = hc()
#   put: (item)->
#     @data.push item
#     process.nextTick ()->
#       @pullOut()
#   pullOut: (callback)->
#     self = this
#     @puller (err)->
#       callback err, self if callback


Boxlet.par =
Boxlet.parallel = ()->
  box = new Boxlet
  box.start = (callback)->
    data = box.data
    box.feedbacks = _.map data, (d)-> undefined
    box.errors = _.map data, (d)-> undefined
    box.puller = hc()
    _.forEach data, (datum, inx)->
      box.puller.async inx, (done)->
        box.doHandling datum, (err, feedback)->
          # debug 'done a parallel', err, feedback
          box.feedbacks[inx] = feedback
          box.errors[inx] = err
          done err
    box.puller.wait()
    box.pullOut callback

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

Boxlet.nPar =
Boxlet.nParallel = (concurrent)->
  box = new Boxlet
  s = new Semaphore concurrent
  box.start = (callback)->
    data = box.data
    box.feedbacks = _.map data, (d)-> undefined
    box.errors = _.map data, (d)-> undefined
    box.puller = hc()

    _.forEach data, (datum, inx)->
      box.puller.async inx, (done)->
        s.enter ()->
          box.doHandling datum, (err, feedback)->
            s.leave()
            # debug 'done a parallel', err, feedback
            box.feedbacks[inx] = feedback
            box.errors[inx] = err
            done err

    box.puller.wait()
    box.pullOut callback
  return box

Boxlet.ser =
Boxlet.serial = ()->
  box = new Boxlet
  box.start = (callback)->
    data = box.data
    box.feedbacks = _.map data, (d)-> undefined
    box.errors = _.map data, (d)-> undefined
    box.puller = hc()

    _.forEach data, (datum, inx)->
      box.puller.async inx, (done)->
        debug 'Boxlet.fire', datum
        box.doHandling datum, (err, feedback)->
          debug 'done a serial', err, feedback
          box.feedbacks[inx] = feedback
          box.errors[inx] = err
          done err
      box.puller.wait()
    box.pullOut callback
  return box

module.exports = exports = Boxlet
