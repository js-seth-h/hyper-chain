 
hc = require '../src'   
chai = require 'chai'
expect = chai.expect 
debug = require('debug')('test')
 
describe '?', ()->
  it '?', (done)-> 
    ###
      데이터 변조, Context확보, Filtering, send..


      timing : getter -> 변환 -> setter 
 
      chain.reactTo = (Sth)->
        Sth.subscribe (data)-> chain.send data 
      chain.filter = (decider)->
        decider(data)
    ###

    # chain = hc.create()
    chain = hc() 
      .uncaughtException (err)-> # Error를 수신받을 callback이 없을때 처리함. ex> observer나 다른 체인으로부터 받을떄  
      .reactTo hc.observer.of messages... # Input Queue에 넣고 시작함. messages를 하나씩 처리하도록 함
      .reactTo hc.observer.event src, 'event_name'
      .reactTo hc.observer.interval 1000 # 1000 ms 마다 발생
      .reactTo hc.observer.puller src, 'path', chk_interval
      .reactTo otherChain #  otherChain.do (x)-> thisChain.send this
      # .filter hc.getter src, 'path'
      .reactTo otherChain # <=> otherChain.sendTo thisChain
      # .mapTo {} # 고정적인 값으로 변경 _.isFunction 코스트를 물기 그렇다?? 아니, Chain을 구성할때 1번 지불하면..? 그래도 내부적으로는 다 있다는 소리네..
      .map (x)-> x * x # map : return value become value In Stream
      .map (x)-> obj = 
        one: x
        two : x * x 
      .do (x)->  # do : return value ignored
        x.triple = x.one * x.one * x.one
      .do (x)-> console.log x # == each
      # .doAsync (x, done)->
      #   done null
      # .mapAsync (x, done)->
      #   done null
      .do (x)->
        sync = @async 'name_of_job' # this === call conext { input: x, callback: }. this created by send(input, callback)
        callAsync sync.err (err)->
          sync null
          # @get ? @result 'name_of_job'으로 처리.? 

      .delay 10
      # .wait (go)-> setTimeout go, 10
      .delayWhen 10, (x)-> x.one > 10
      # .wait (go)-> 
      #   return go() if x.one > 0
      #   setTimeout go, 10
      .delayWhen 10, _.isObject

      .await 'name_of_job'
      .wait (go)->
        @wait('load').then go
 
      .filter (x)-> x.one > 10 # return value decide continue or quit
      .filter _.isObject
      .filter (x)-> _.include [11,12,13], x
      .filter hc.filter.throttleTime 100
      .filter hc.filter.debounceTime 100
      .filter hc.filter.throttleCount 10
      .filter hc.filter.debounceCount 10

      # reduce : decide continue with Something or not
      .reduce hc.reducer.object (reducer, x, send)->
        reducer.cur = if reducer.cur? then reducer.cur * x else x 
        send reducer.cur if reducer.cur > 1000
      .reduce hc.reducer.array (reducer, x, send)->
        reducer.push x 
        if reducer.length > 3 
          chunk = reducer.get()
          reducer.reset()
          send chunk


      .sendTo otherChain  
      .sendToIf otherChain, (x)-> x > 10 
      .set 'path.for.variable', dest, 'dest.variable.path'

      .catch (error, x)->
        # throw 를 하지 않으면 Error는 소멸함

      # .uncatchedError (error)->


      # .toArray (array)->
      # .do (x)-> array = _.toArray x

      
      # .do (x)-> # .done()
      #   if @call_context.callback
      #     @call_context.callback err



    fn = chain.asFunction()
    # fn = (data, callback)-> chain.send data, callback

    data = 1
    chain.send data, callback #  fn data, callback
    # 기본적으로 Error를 send Data, callback 에 돌려주도록 함
    # ErrorBack이자 done의 의미로 사용

    chain.close()
    ###
    if closed
      chain.send data, callback. will imediatly call callback with error
      if callback is not provied, throw Error
    ### 
    
    chain.pause()
    ###
    not processing, buffering sended data
    ###

    chain.resume()
    ###
    became processable, and buffed request will be processing
    ###