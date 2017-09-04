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
    chain = hc()
      .reactTo hook.of d
      .map (cur)-> cur * cur 
      .feedback (cur, feedback, exe_ctx)->
        exe_ctx.feedback = cur

    d.start (err, dynamo)->
      expect(dynamo.feedbacks).be.eql [0...10].map (x)-> x * x
      done()




