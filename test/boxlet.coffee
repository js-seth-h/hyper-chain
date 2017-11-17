hc = require '../src/chain'
Boxlet = require '../src/Boxlet2'
hook = require '../src/hook'
chai = require 'chai'
expect = chai.expect
debug = require('debug')('test')

feature = describe
scenario = it

describe 'Boxlet.parallel', ()->
  it 'when start and callbacked, then feedbacks fullfill', (done)->

    d = Boxlet.parallel()
    d.puts [0...10]
    chain = hc()
      .reactTo hook.of d
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        feedback.set 0, cur

    d.start (err, Boxlet)->
      expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
      done()



describe 'Boxlet.serial', ()->
  it 'when start and callbacked, then feedbacks fullfill', (done)->

    d = Boxlet.serial()
    d.puts [0...10]
    last = -1
    chain = hc()
      .reactTo hook.of d
      .do (cur)->
        expect(last + 1).be.eql cur
        last = cur
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        feedback.set 0, cur

    d.start (err, Boxlet)->
      expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
      done()



describe 'Boxlet.nParallel', ()->
 it 'when start and callbacked, then feedbacks fullfill ', (done)->
  d = Boxlet.nParallel 5
  d.puts [0...10]
  chain = hc()
    .reactTo hook.of d
    .map (cur)-> cur * cur
    .feedback (feedback, cur)->
      feedback.set 0, cur
  d.start (err, Boxlet)->
    expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
    done()

 it 'when start and callbacked, then feedbacks fullfill & concurrent limited ', (done)->
  d = Boxlet.nParallel 2
  d.puts [0...10]
  chain = hc()
    .reactTo hook.of d
    .map (cur)-> cur * cur
    .async 'test', (cur, a_done)->
      _dfn = ()->
        a_done null
      setTimeout _dfn, 5
    .feedback (feedback, cur)->
      feedback.set 0, cur

  t_start = (new Date).getTime()
  time_accuracy = 5
  d.start (err, Boxlet)->
    t_end = (new Date).getTime()
    t_gap = t_end - t_start
    expect(t_gap).be.least 5 * 10 / 2 - time_accuracy
    expect(Boxlet.feedbacks).be.eql [0...10].map (x)-> x * x
    done()
