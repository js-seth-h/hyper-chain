hc = require '../src'
Boxlet = hc.Boxlet
chai = require 'chai'
expect = chai.expect
debug = require('debug')('test')
_ = require 'lodash'
feature = describe
scenario = it

describe 'Boxlet Triggers;', ()->

  it 'consecution', (done)->
      box = new Boxlet()
        .consecution()
      box.handler.feedback (feedback, cur)->
        debug 'feedback.set'
        feedback.set 0, cur * cur

      box.put 9
      debug 'check expect'
      expect(box.internal_buffer).to.have.lengthOf 0
      done()

  it 'asap', (done)->
      box = new Boxlet()
        .asap()
      box.handler.feedback (feedback, cur)->
        feedback.set 0, cur * cur

      box.put 9
      expect(box.internal_buffer).to.have.lengthOf 1
      _dfn = ()->
        expect(box.internal_buffer).to.have.lengthOf 0
        done()
      setTimeout _dfn, 10

  it 'debounce', (done)->
      box = new Boxlet()
        .debounce 20
      box.handler.feedback (feedback, cur)->
        feedback.set 0, cur * cur

      box.put 9
      expect(box.internal_buffer).to.have.lengthOf 1

      setTimeout (()->
        box.put 20
        expect(box.internal_buffer).to.have.lengthOf 2
      ), 10

      _dfn = ()->
        expect(box.internal_buffer).to.have.lengthOf 0
        done()
      setTimeout _dfn, 25

  it 'interval', (done)->
      box = new Boxlet()
        .interval 20
      box.handler.feedback (feedback, cur)->
        feedback.set 0, cur * cur

      box.put 9
      expect(box.internal_buffer).to.have.lengthOf 1

      setTimeout (()->
        expect(box.internal_buffer).to.have.lengthOf 0
        box.put 20
        expect(box.internal_buffer).to.have.lengthOf 1
      ), 25

      _dfn = ()->
        expect(box.internal_buffer).to.have.lengthOf 0
        done()
      setTimeout _dfn, 45



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



describe 'Boxlet setHandler', ()->
  it 'setHandler', (done)->

    _han = hc()
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        feedback.set 0, cur

    box = new Boxlet()
      .puts [0...10]
      .parallel()
      .setHandler _han
      .pullOut (err, Boxlet)->
        expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
        done()

  it 'setDataHandler', (done)->

    _han = hc()
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        feedback.set 0, cur

    box = new Boxlet()
      .puts [0...10]
      .parallel()
      .setDataHandler _han
      .pullOut (err, Boxlet)->
        expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
        done()
