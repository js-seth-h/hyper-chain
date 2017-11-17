hc = require '../src'
Boxlet = hc.Boxlet 
chai = require 'chai'
expect = chai.expect
debug = require('debug')('test')
_ = require 'lodash'
feature = describe
scenario = it

describe 'Boxlet.parallel', ()->
  it 'when start and callbacked, then feedbacks fullfill', (done)->

    box = new Boxlet()
      .puts [0...10]
      .parallel()

    box.handler
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        feedback.set 0, cur

    box.pullOut (err, Boxlet)->
      expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
      done()



describe 'Boxlet.serial', ()->
  it 'when start and callbacked, then feedbacks fullfill', (done)->

    box = new Boxlet()
      .puts [0...10]
      .serial()

    last = -1
    box.handler
      .do (cur)->
        expect(last + 1).be.eql cur
        last = cur
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        feedback.set 0, cur

    box.pullOut (err, Boxlet)->
      expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
      done()



describe 'Boxlet.nParallel', ()->
  it 'when start and callbacked, then feedbacks fullfill ', (done)->

    box = new Boxlet()
      .puts [0...10]
      .parallel()
    box.handler
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        feedback.set 0, cur
    box.pullOut (err, Boxlet)->
      expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
      done()

  it 'when start and callbacked, then feedbacks fullfill & concurrent limited ', (done)->

    box = new Boxlet()
      .puts [0...10]
      .nParallel 2

    box.handler
      .map (cur)-> cur * cur
      .async 'test', (cur, a_done)->
        _dfn = ()->
          a_done null
        setTimeout _dfn, 5
      .feedback (feedback, cur)->
        feedback.set 0, cur

    t_start = (new Date).getTime()
    time_accuracy = 5
    box.pullOut (err, Boxlet)->
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.least 5 * 10 / 2 - time_accuracy
      expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
      done()

describe 'Boxlet.reduce', ()->
  it 'reduce', (done)->
    box = new Boxlet()
      .puts [0...10]
      .reduce (list)->
        return _.sum list
      .parallel()

    box.handler
      .feedback (feedback, cur)->
        feedback.set 0, cur

    box.pullOut (err, Boxlet)->
      expect(Boxlet.feedbacks[0]).be.eql _.sum [0...10]
      done()
