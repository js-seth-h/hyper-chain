hc = require '../src/chain'
dynamo = require '../src/dynamo'
hook = require '../src/hook'
chai = require 'chai'
expect = chai.expect
debug = require('debug')('test')

feature = describe
scenario = it
 
describe 'dynamo.parallel', ()->
  it 'when start and callbacked, then feedbacks fullfill', (done)->

    d = dynamo.parallel [0...10]
    chain = hc()
      .reactTo hook.of d
      .map (cur)-> cur * cur 
      .feedback (cur, feedback, exe_ctx)->
        exe_ctx.feedback = cur

    d.start (err, dynamo)->
      expect(dynamo.feedbacks).be.eql [0...10].map (x)-> x * x
      done()


  
describe 'dynamo.serial', ()->
  it 'when start and callbacked, then feedbacks fullfill', (done)->

    d = dynamo.serial [0...10]
    last = -1
    chain = hc()
      .reactTo hook.of d
      .do (cur)->
        expect(last + 1).be.eql cur
        last = cur
      .map (cur)-> cur * cur 
      .feedback (cur, feedback, exe_ctx)->
        exe_ctx.feedback = cur

    d.start (err, dynamo)->
      expect(dynamo.feedbacks).be.eql [0...10].map (x)-> x * x
      done()



describe 'dynamo.nParallel', ()->
 it 'when start and callbacked, then feedbacks fullfill ', (done)->
  d = dynamo.nParallel 5, [0...10]
  chain = hc()
    .reactTo hook.of d
    .map (cur)-> cur * cur 
    .feedback (cur, feedback, exe_ctx)->
      exe_ctx.feedback = cur 
  d.start (err, dynamo)->
    expect(dynamo.feedbacks).be.eql [0...10].map (x)-> x * x
    done()

 it 'when start and callbacked, then feedbacks fullfill & concurrent limited ', (done)->
  d = dynamo.nParallel 2, [0...10] 
  chain = hc()
    .reactTo hook.of d
    .map (cur)-> cur * cur 
    .async 'test', (cur, a_done)->
      _dfn = ()->
        a_done null
      setTimeout _dfn, 5
    .feedback (cur, feedback, exe_ctx)->
      exe_ctx.feedback = cur 
      
  t_start = (new Date).getTime()
  time_accuracy = 5
  d.start (err, dynamo)->
    t_end = (new Date).getTime()
    t_gap = t_end - t_start
    expect(t_gap).be.least 5 * 10 / 2 - time_accuracy
    expect(dynamo.feedbacks).be.eql [0...10].map (x)-> x * x
    done()


 

