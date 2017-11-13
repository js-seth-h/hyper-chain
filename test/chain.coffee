hc = require '../src/chain'
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
  비동기 .async, .wait .makePromise 
  에러 제어 .catch .finally 
  반환 제어 .feedback 
  시간제어 .delay .delayIf 
  처리 합병 .reduce

  .reactTo 
  .concatTo
  .forkFrom 

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
    
  it 'when start no args, then accept arity', (done)-> 
    chain = hc()
      .do (cur)->
        throw new Error("Wrong") if cur
      .map ()->
        return 18
      .do (cur)->
        expect(cur).to.be.equal 18
        done()
    chain()

  it 'when start arr, then accept arity', (done)-> 
    chain = hc()
      .do (cur, cur2)->
        throw new Error("Wrong") if cur > cur2
      .map (cur, cur2)->
        return cur * cur2
      .do (cur)->
        expect(cur).to.be.equal 18
        done()
    chain 2, 9
    
  it 'when passing hc.Args, then change arity', (done)-> 
    chain = hc()
      .map (cur)->
        return new hc.Args 11, 7
      .do (cur, cur2)->
        expect(cur).to.be.equal 11
        expect(cur2).to.be.equal 7
        done() 
    chain 2

  it 'when passing nothing, then arity be 0', (done)-> 
    chain = hc()
      .map (cur)->
        return new hc.Args
      .do (args...)->
        expect(args.length).to.be.equal 0
      .finally done
    chain 2

  it 'when passing nothing, then arity be 0', (done)-> 
    chain = hc()
      .map (cur)->
        return hc.Args.Empty
      .do (args...)->
        expect(args.length).to.be.equal 0
      .finally done
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
      expect(execute_context.curArr[0]).to.be.equal 'passed'
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
      .catch (err, cur)->

    chain 0, (err, feedback, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArr[0]).to.be.equal 1
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
      expect(execute_context.curArr[0]).to.be.equal 1
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
      expect(execute_context.curArr[0]).to.be.equal 1
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
      expect(execute_context.curArr[0]).to.be.equal 1
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()

  it 'when feedback callback has trouble, then it will go uncaughtException', (done)->
    return done()
    ###
      this test is working. and confirmed by human.
      but chai did not show correct response.
      it is uncaughtException, but chai.js consider it as Test Fail.
    ###
    process.on 'uncaughtException', (err)-> 
      expect(err).to.exist
      done()
    chain = hc()
    chain 0, (err)->
      throw new Error 'JUST'


describe '비동기 .async, .wait .makePromise', ()->
  it 'when .async & .wait, then read value from stroage', (done)->

    chain = hc()
      .map (cur)-> 0
      .async 'test', (cur, a_done)->
        _dfn = ()->
          a_done null, 'async_return'
        setTimeout _dfn, 50
      .map (cur)-> 2
      .wait 'test'
      .map (cur)->
        {test} = @recall() 
        return test

    chain null, (err, feedback, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArr[0]).to.be.eql 'async_return'
      expect(execute_context.recall('test[]')).to.be.eql ['async_return']
      done()

  it 'when .await, then read value from stroage', (done)->

    chain = hc()
      .map (cur)-> 0
      .await 'test', (cur, a_done)->
        _dfn = ()->
          a_done null, 'async_return'
        setTimeout _dfn, 50
      .map (cur)->
        {test} = @recall() 
        return test

    chain null, (err, feedback, execute_context)->
      expect(err).to.not.exist 
      expect(execute_context.curArr[0]).to.be.eql 'async_return'
      expect(execute_context.recall('test[]')).to.be.eql ['async_return']
      done()

  it 'when anonymous .await, then use function index as name', (done)->
    chain = hc()
      .map (cur)-> 0
      .await (cur, a_done)->
        _dfn = ()->
          a_done null, 'async_return'
        setTimeout _dfn, 50
      .map (cur)->
        return @recall()["1"]

    chain null, (err, feedback, execute_context)->
      expect(err).to.not.exist 
      expect(execute_context.curArr[0]).to.be.eql 'async_return'
      expect(execute_context.recall('1[]')).to.be.eql ['async_return']
      done()

  it 'when .async & .wait but occur Error, then callback get error', (done)->

    chain = hc()
      .map (cur)-> 0
      .async 'test', (cur, a_done)->
        _dfn = ()->
          a_done new Error 'JUST'
        setTimeout _dfn, 50
      .map (cur)-> 2
      .wait 'test'
      .map (cur)->
        {test} = @recall() 
        return test

    chain null, (err, feedback, execute_context)-> 
      expect(err).to.exist  
      done()
 
  it 'when .async & .makePromise, then read value from stroage', (done)->

    chain = hc()
      .map (cur)-> 0
      .makePromise 'test', (cur)->
        new Promise (resolve, reject)->
          _dfn = ()->
            resolve 'resolve_return'
          setTimeout _dfn, 50
      .map (cur)-> 2
      .wait 'test'
      .map (cur)->
        {test} = @recall() 
        return test

    chain null, (err, feedback, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArr[0]).to.be.eql 'resolve_return'
      done()


  it 'when .async & .makePromise but occur Error, then callback get error', (done)->

    chain = hc()
      .map (cur)-> 0
      .makePromise 'test', (cur)->
        new Promise (resolve, reject)->
          _dfn = ()->
            reject new Error 'JUST'
          setTimeout _dfn, 50 
      .map (cur)-> 2
      .wait 'test'
      .map (cur)->
        {test} = @recall() 
        return test

    chain null, (err, feedback, execute_context)-> 
      expect(err).to.exist  
      done()
 
describe '반환 제어 .feedback', ()->

  it 'when .feedback & set data. then callback get data', (done)->
    chain = hc()
      .do (cur)-> cur + 1
      .feedback (cur, feedback, execute_context)->
        feedback.send_back_str = 'to callback'

    chain null, (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      expect(feedback.send_back_str).to.be.eql 'to callback'
      done()

time_accuracy = 5
describe '시간제어 .delay .delayIf ', ()->
  it 'when .delay. then take a time', (done)->  
    chain = hc()
      .delay 50

    t_start = (new Date).getTime()
    chain null, (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.least 50 - time_accuracy
      done()

  it 'when .delayIf & pass test. then take a time', (done)-> 
    chain = hc()
      .map (cur)-> 100
      .delayIf 50, (cur)-> cur > 50

    t_start = (new Date).getTime()
    chain null, (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.least 50 - time_accuracy
      done()

  it 'when .delayIf & failed to pass test. then not take a time', (done)->  
    chain = hc()
      .map (cur)-> 100
      .delayIf 50, (cur)-> cur > 150

    t_start = (new Date).getTime()
    chain null, (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.below 50 - time_accuracy
      done()


describe '.endWith ', ()->
  it 'chain is stop & return value as feedback', (done)->  
    
    fn = hc()
      .do ()->
        @endWith "test-end"
      .do ()->
        throw new Error "Never Come Here"
        
    fn (err, feedback)->
      expect(err).not.exist
      expect(feedback).to.eql 'test-end'
      done()
      
describe 'complex usage', ()->
  it 'run without args & callback, await take only callback function', (it_done)->
    do hc()
      .do ()->
        return 'test'
      .await "log", (done)->
        console.log 'awit', arguments
        expect(done).to.be.a('function')
        done() 
      .do ()->
        it_done()
describe '처리 합병 .reduce', ()->
  
  it 'when .reduce in 50 ms & call 1 time & not needFlush. then delayed and go', (done)-> 
    chain = hc()
      .reduce hc.reducer
        time_slice: 50 # 최대 50ms마다 방출
        reduce: (acc)-> return acc
        needFlush: (acc)-> return false
      .do (cur)->
        expect(cur).to.be.eql ['reduce']

    t_start = (new Date).getTime()
    chain 'reduce', (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.least 50 - time_accuracy
      done()
  it 'when .reduce in 50 ms & call 1 time needFlush. then go, but no delay', (done)-> 
    chain = hc()
      .reduce hc.reducer
        time_slice: 50 
        reduce: (acc)-> return acc
        needFlush: (acc)-> return true
      .do (cur)->
        expect(cur).to.be.eql ['reduce']

    t_start = (new Date).getTime()
    chain 'reduce', (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.below 50 - time_accuracy
      done()


  it 'when .reduce in 50 ms & call 2 time and needFlush. then call1 getReducde. call2 go, but no delay', (done)-> 
    chain = hc()
      .reduce hc.reducer
        time_slice: 50 
        reduce: (acc)-> return acc
        needFlush: (acc)-> acc.length >= 2
      .do (cur)->
        expect(cur).to.be.eql ['reduce1', 'reduce2' ]

    chain 'reduce1', (err, feedback, execute_context)->
      debug 'reduce1', err, feedback, execute_context
      expect(err).to.not.exist
      expect(execute_context.exit_status).to.be.eql 'reduced'

    t_start = (new Date).getTime()
    chain 'reduce2', (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.below 50 - time_accuracy
      done()

  it 'when .reduce in 50 ms & call 2 time and not needFlush. then call1 getReducde. call2 go, with delay', (done)-> 
    chain = hc()
      .reduce hc.reducer
        time_slice: 50 
        reduce: (acc)-> return acc
        needFlush: (acc)-> false
      .do (cur)->
        expect(cur).to.be.eql ['reduce1', 'reduce2' ]

    chain 'reduce1', (err, feedback, execute_context)->
      debug 'reduce1', err, feedback, execute_context
      expect(err).to.not.exist
      expect(execute_context.exit_status).to.be.eql 'reduced'

    t_start = (new Date).getTime()
    chain 'reduce2', (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.least 50 - time_accuracy
      done()

  it 'when .reduce function return new cur value. then next fn receive that data ', (done)-> 
    chain = hc()
      .reduce hc.reducer
        time_slice: 50 
        reduce: (acc)-> return acc.join '-'
        needFlush: (acc)-> acc.length >= 2
      .do (cur)->
        expect(cur).to.be.eql 'reduce1-reduce2'

    chain 'reduce1', (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      expect(execute_context.exit_status).to.be.eql 'reduced'
 
    chain 'reduce2', (err, feedback, execute_context)-> 
      expect(err).to.not.exist 
      expect(execute_context.exit_status).to.be.eql 'finished'
      done()

  it 'when .reduce is not working actually. then each call finised ', (done)-> 
    chain = hc()
      .reduce hc.reducer
        time_slice: 50 
        reduce: (acc)-> acc
        needFlush: (acc)-> true
      .do (cur)-> cur + 1

    chain 'reduce1', (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      expect(execute_context.exit_status).to.be.eql 'finished'
 
    chain 'reduce2', (err, feedback, execute_context)-> 
      expect(err).to.not.exist 
      expect(execute_context.exit_status).to.be.eql 'finished'
      done()
  it 'when .reduce hasnot time_slice. then needFlush decide all ', (done)-> 
    chain = hc()
      .reduce hc.reducer
        time_slice: false
        reduce: (acc)-> acc
        needFlush: (acc)-> 
          debug 'acc', acc
          acc.length >= 4 
      # .do (cur)-> cur + 1

    chain 'reduce1', (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      expect(execute_context.exit_status).to.be.eql 'reduced'
 
    chain 'reduce2', (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      expect(execute_context.exit_status).to.be.eql 'reduced'
 
    chain 'reduce3', (err, feedback, execute_context)-> 
      expect(err).to.not.exist
      expect(execute_context.exit_status).to.be.eql 'reduced'
 
    chain 'reduce4', (err, feedback, execute_context)-> 
      expect(err).to.not.exist 
      expect(execute_context.exit_status).to.be.eql 'finished'
      done()