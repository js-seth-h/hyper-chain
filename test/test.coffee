 
hc = require '../src'   
chai = require 'chai'
expect = chai.expect 
debug = require('debug')('test')
 
describe '?', ()->
  it '?', (done)-> 
    ###
      데이터 변조, Context확보, Filtering, send..


      timing : Load -> 변환 -> Store 
        > 마치 어셈블리의 구조처럼..
 
      chain.reactTo = (Sth)->
        Sth.subscribe (data)-> chain.send data 
      chain.filter = (decider)->
        decider(data)

      체인에 대한 호출은 call_context 를 만든다
      call_context =  # created by send(input, callback)
        input: initial input 
        callback: (args...)-> _callback args... if _callback
        output: null
        asyncTasks: 
          task_id: [error, args...]
          task_id: [error, args...]
        exit_status: as a Promise 
                ok - 정상적인 끝남
                error - 에러가 발생 
                filtered - filter 되어 중지됨
                reduced - reduce 되어 중지됨

      OtherChain과 의존..? 
        > 다른 체인이 취급한 데이터에 반응하는 것...? 음 모듈 구조를 생각해야겠다.

        module은 외부와 소통해야하는데. 결국 함수 호출과 변수. 이벤트(=역함수 호출 + 수신자 불명), Callback(=역함수 호출 + 수신자 명확) 
        현대적으로는 함수 호출이 정공, 변수 설정은 문제가 제어권 문제가 있고 변수읽기는 무난
        reactive 관점에서 변수는 puller 없이는 구성이 어렵고 좋은 선택지가 아니다. 
        결국 Event, observer, promise등을 통해서, 역함수 호출이 필요.
        그냥 함수 호출하는 것은 무난. chain을 함수화 할수 있음으로..(꼭 AsFunction해야할지 고민하자)

        기존 체인의 결과를 복사 받아, 독립적으로 구성하는 것은 아무 문제가 없다. 
        구성된 기능을 임의로 늘리는 것은...?, 정확하게는 기존 chain의 call_context를 이어서 계속 처리하는것은..? 
          -> 기능의 확장 이라는 측면에서 강함. 그러나 안전성을 훼손한다. 
          -> 심각한건 어디까지 될지 알수가 없고, 이는 프로그래밍할수 없는 상태(계획 불가)를 만든다 
        그런데 체인은 원래 늘어날수 있는 것이 정상 상태다. .frezee() / .seal()등의 처리가 별개로 있어야.
        고정시키지 않으면, 어떻게든 할수 있네...   .do + .await 등으로... 
          otherChain.do (x)->
            sync = @async 'connect'
            thisChain x, sync
        내가 다른 체인을 불러 내는 것이나. 다른 체인이 나를 불러 내는 것이나. 가능. 그러나 call_context는 공유안됨. 
        공유하려면 체인과 체인의 관계가 아니라, 하나의 체인을 변경해야한다. 
          1. 바로 수정하던지, 2. 복사하여 수정하던지, 3. Merge하여..(= 연속된 복사자나...쯥.)
        에러를 전파받던 말던, call_context가 다르다.

        But, Error 전파의 파급이 꽤 크지않나...? 아닌가..? 고민할 필요가 없을듯하다.
        Error에 대해서는 직접 처리할수 있으면하고, Default로 전파해야한다. 흐름의 시작점은 어쩃든 모든 Error를 커버해야한다. 
        고로 문제 없음. Default행위가 문제있으면 안되지.

        end 시점에 대한문제...
        reactTo OtherChain을 할경우, OtherChain의 End는 언제인가? ㅁ
          > 만약 callback을 건다면, ThisChain까지 끝나야한다.
          > 그렇지 않다면, fireAndForgot이다. 

          결국 동작이 성격에 따라 달라야겠다. 문제는 확장하는 놈의 사양을 당하는 놈이 알수는 없음으로, 추가될때 결정해야한다.

        .reactTo는 callback을 연결안함. 별개의 사건 처리다.
        .connectTo는 callback을 연결함. 동일한 사건처리로써, 연속적 반응으로 간다. 
    ###

    # chain = hc.create()
    chain = hc() 
      .uncaughtException (err)-> # Error를 수신받을 callback이 없을때 처리함. ex> observer나 다른 체인으로부터 받을떄  
      .reactTo hc.observer.of messages... # Input Queue에 넣고 시작함. messages를 하나씩 처리하도록 함
      .reactTo hc.observer.event src, 'event_name'
      .reactTo hc.observer.interval 1000 # 1000 ms 마다 발생
      .reactTo hc.observer.puller src, 'path', chk_interval
      .reactTo Stream # Stream은 Chain과는 달리, 자체적인 버퍼를 가진다. 제때 못읽는다고 데이터가 사라지지는 않는다.
      .reactTo otherChain #  otherChain.do (x)-> thisChain.send this
      .connectTo otherChain # 
      # .mapTo {} # 고정적인 값으로 변경 _.isFunction 코스트를 물기 그렇다?? 아니, Chain을 구성할때 1번 지불하면..? 그래도 내부적으로는 다 있다는 소리네..
      .load (x)-> # 데이터를 읽는다...? do랑 뭐가 다르냐..?  
        x.var = getDataFromCache()
        x.cfg = readConfig()
      .load 'var.path', hc.getter.obj src, 'bla.bla.path'
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
        sync = @async 'name_of_job' # this === call context { input: x, callback: }. this created by send(input, callback)
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

      .timeout 1000 * 10  # 10초후에는 Error Timeout.  call_context.clearTimeout()으로 해제 됨 or 작업이 끝나면 됨.
      .await 'name_of_job'
      .wait (go)->
        @wait('load').then go

      .do (x)->
        return @callback null, 'ok' if x > 10

      # .return (x, callback)-> 
        # return : return value will pass to callback of send(data, callback)
        # and 
        # callback null, 1,2,3

 
      .filter (x)->
        # return value decide continue or quit
        # if quit,  callback of context is called with zero args. 
        x.one > 10 

      .filter _.isObject
      .filter (x)-> _.include [11,12,13], x
      .filter hc.filter.throttleTime 100
      .filter hc.filter.debounceTime 100
      .filter hc.filter.throttleCount 10
      .filter hc.filter.debounceCount 10

      # reduce : decide continue with Something or not
      .reduce hc.reducer.object (reducer, x, next)->
        reducer.cur = if reducer.cur? then reducer.cur * x else x 
        next reducer.cur if reducer.cur > 1000
      .reduce hc.reducer.array (reducer, x, next)->
        reducer.push x 
        if reducer.length > 3 
          chunk = reducer.get()
          reducer.reset()
          next chunk


      .sendTo otherChain  
      .sendToIf otherChain, (x)-> x > 10 
      .store 'path.for.variable', dest, 'dest.variable.path' # dest.variable.path거 함수인지, 변수인지? 셋팅 동작도 불명..
      # .store을 스트림 or 배열에 Push하는 것도 고민 해야한다. 
      # 이것도 .do랑 뭐가 다르냐..

      .catch (error, x)->
        # throw 를 하지 않으면 Error는 소멸함
      .finally (err, x)->


      # .uncatchedError (error)->


      # .toArray (array)->
      # .do (x)-> array = _.toArray x

      
      # .do (x)-> # .done()
      #   if @call_context.callback
      #     @call_context.callback err



    fn = chain.asFunction()
    # fn = (data, callback)-> chain.send data, callback

    data = 1
    chain.send data, callback #  fn data, callback = (error, call_context)->
    # 기본적으로 Error를 send Data, callback 에 돌려주도록 함
    # ErrorBack이자 done의 의미로 사용

    chain.close()
    chain.open()
    ###
    if closed
      chain.send data, callback. will imediatly call callback with error
      if callback is not provied, throw Error
    ### 
    
    ###

      스팩 취소 chain.pause(), chain.resume()     
      버퍼링이 될만한 구조가 아니다.  체인은 스트림이 아니다. 
      시작값을 거는 것부터가 불가능해서 
        -> .start()구현이 부적절, 동작은 계속 추가되는데(.do .map .reduce) 데이터를 쥐고 있기도 어렵고, 
          Stream처럼 서로 다른 Stream공간으로 넘어간다면 모르겠으나. 일회적이라 무리..
      이 스펙은 취소

    ###  