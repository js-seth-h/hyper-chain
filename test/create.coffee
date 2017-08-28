hc = require '../src'
chai = require 'chai'
expect = chai.expect
debug = require('debug')('test')

feature = describe
scenario = it

###
Features와, 테스트 시나리오

  함수일것 = 호출이 가능할것. 
  값제어 .do, .map
  처리 제어.filter 
  처리 합병 .reduce
  비동기 .async, .wait .makePromise
  시간제어 .delay .timeout
  에러 제어 .catch .finally
  반환 제어 .feedback




###
describe 'chain is a function', ()->
  it 'when create hyper-chain, then return a function', ()->
    chain = hc()
    expect(chain).a 'function' 

  it 'when call chain, then get feedback and execute_context', (done)->
    chain = hc()
    chain null, (err, feedback, execute_context)->

      expect(err).to.not.exist
      expect(feedback).to.be.eql {}
      expect(execute_context).a 'object'
      expect(execute_context.exit_status).to.be.equal 'finished'
      done()


describe 'change data in process', ()-> 
  it 'when add .do, then not change current data', (done)->
    chain = hc()
      .do (cur)->
        return 1
      .do (cur)->
        expect(cur).to.be.equal 2 
        done()
    chain 2

  it 'when add .map, then change current data', (done)->
    ###
    Given 
    When - .map이 반환을 한다 
    Then - cur가 변경된다
    ###
    chain = hc()
      .map (cur)->
        return 1
      .do (cur)->
        expect(cur).to.be.equal 1
        done()

    chain 2

describe 'chain can be stop by filter', ()-> 
  it 'when .filter - return true, then not stop', (done)-> 
    chain = hc()
      .filter (cur)-> true
      .map (cur)->
        return "passed"
      # .do (cur)->
      #   throw new Error 'Should be Filtered'

    chain 2, (err, feedback, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.cur).to.be.equal 'passed'
      expect(execute_context.exit_status).to.be.equal 'finished'
      done()


  it 'when .filter - return false, then stop', (done)-> 
    chain = hc()
      .filter (cur)-> false
      .do (cur)->
        throw new Error 'Should be Filtered'

    chain 2, (err, feedback, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.exit_status).to.be.equal 'filtered'
      done()
 
describe 'error handling', ()-> 

  it 'when occur Error, then jump to .catch & error vanished ', (done)-> 
    chain = hc()
      .map (cur)-> 1
      .do (cur)-> throw new Error 'Just'
      .map (cur)-> 2
      .map (cur)-> 3
      .catch (cur, err)->

    chain 0, (err, feedback, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.cur).to.be.equal 1
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()

  it 'when occur Error and occur again in catch, then callback get Error ', (done)-> 
    chain = hc()
      .map (cur)-> 1
      .do (cur)-> throw new Error 'Just'
      .map (cur)-> 2
      .map (cur)-> 3
      .catch (err, cur)->
        throw err

    chain 0, (err, feedback, execute_context)->
      expect(err).to.exist
      expect(execute_context.cur).to.be.equal 1
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()
  it 'when occur Error and occur different error in catch, then callback get diff Error ', (done)-> 
    chain = hc()
      .map (cur)-> 1
      .do (cur)-> throw new Error 'Just'
      .map (cur)-> 2
      .map (cur)-> 3
      .catch (err, cur)->
        throw new Error 'Other Error'

    chain 0, (err, feedback, execute_context)->
      expect(err).to.exist
      expect(err.toString()).to.equal 'Error: Other Error'
      expect(execute_context.cur).to.be.equal 1
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()

  it 'when .finally , then error still flow', (done)-> 
    chain = hc()
      .map (cur)-> 1
      .do (cur)-> throw new Error 'Just'
      .map (cur)-> 2
      .map (cur)-> 3
      .finally (err, cur)-> 4
      .map (cur)-> 5 

    chain 0, (err, feedback, execute_context)->
      expect(err).to.exist
      expect(err.toString()).to.equal 'Error: Just'
      expect(execute_context.cur).to.be.equal 1
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()




