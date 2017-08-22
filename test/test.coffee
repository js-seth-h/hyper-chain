 
hc = require '../src'   
chai = require 'chai'
expect = chai.expect 
debug = require('debug')('test')
 
describe '?', ()->
  it '?', (done)-> 
    ###
      데이터 변조, Context확보, Filtering, send..


      timing : ( Load Context | 변환 | Store Context | Filter )+


      체인에 대한 호출은 call_context 를 만든다
      call_context =  # created by hc()(input, callback)
        input: initial input 
        callback: (args...)-> _callback args... if _callback
        output: null
        asyncTasks: 
          task_id: [error, args...]
          task_id: [error, args...]
        exit_status: as a Promise 
                error - 에러가 발생 
                filtered - filter 되어 끝남
                reduced - reduce 되어 끝남
                finished - 모든 연산 끝남

      OtherChain과 의존..? 
        > 다른 체인이 취급한 데이터에 반응하는 것...? 음 모듈 구조를 생각해야겠다.

        module은 외부와 소통해야하는데. 결국 함수 호출과 변수. 이벤트(=역함수 호출 + 수신자 불명), Callback(=역함수 호출 + 수신자 명확) 
        현대적으로는 함수 호출이 정공, 변수 설정은 문제가 제어권 문제가 있고 변수읽기는 무난
        reactive 관점에서 변수는 puller 없이는 구성이 어렵고 좋은 선택지가 아니다. 
        결국 Event, observer, promise등을 통해서, 역함수 호출이 필요.
        그냥 함수 호출하는 것은 무난. chain을 함수화 할수 있음으로..

        기존 체인의 결과를 복사 받아, 독립적으로 구성하는 것은 아무 문제가 없다. 
        구성된 기능을 임의로 늘리는 것은...?, 정확하게는 기존 chain의 call_context를 이어서 계속 처리하는것은..? 
          -> 기능의 확장 이라는 측면에서 강함. 그러나 안전성을 훼손한다. 
          -> 심각한건 어디까지 될지 알수가 없고, 이는 프로그래밍할수 없는 상태(계획 불가)를 만든다 
        그런데 체인은 원래 늘어날수 있는 것이 정상 상태다. .frezee() / .seal()등의 처리가 별개로 있어야.
        고정시키지 않으면, 어떻게든 할수 있네...   .do + .await 등으로... 
          otherChain.do (cur)->
            sync = @async 'connect'
            thisChain cur, sync
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

        .reactTo는 callback을 연결안함. 별개의 사건 처리다. (other입장에서 fireAndForgot)
        .connectTo는 callback을 연결함. 동일한 사건처리로써, 연속적 반응으로 간다. (other입장에서 비동기)


        .do = .load = .store 그냥 의미상 구분.  
          .load .store에서 cur.var = getter() 또는 그 역을 수행하려고 보니, 어설프게 하는게 더 복잡함. 너무 다양함.
      
      Reducer에 대해서... 이것은 시간에 대해서 reduce를 해야한다.
        Reducer는 cur를 drop할찌 Next할지 동기로 결정할수 없다. 
        thisChain, thisReducer에 대한 acc공간이 필요함. acc공간은 배열말고는 없음.(특정 시간에 들어온 것들을 저장해야하니까) 
        때가 되면 배열에 대한 Reduce를 하여 넘기면 된다. 
        Reducer (timingSelector, ReductionFn, ResetFn)

        .reduce thisReducer = (thisReducer, cur, call_context)->
          의문 1. Drop/Next를 하나의 함수로 처리가능한가? 넘길값이 뭔지 몰라서 불가.
          만약 call_context를 받으면..? call_context.reduced()로 깔끔히 처리가능.. call_context.next() 도 괜찮은 선택일듯.

        쉽게 만들 방법이 있을까? 없을듯. 
          시간 관련인데 불확실한 미래를 고려하는가? 아닌가?는 복잡.  timeout + condition이면 되지 않나..?
          reduceFn은 정형화 가능. Reset은 어떨지 모르겠음. setEmpty를 전제로한다면...
  
      input.user_list 식으로 배열을 받을테고, 이에 대한 처리는? 
        chain은 시작점은 1개 끝점은 여러개로 본다. callback 있을수도 없을수도.. exit_status가 프로미스라서...output은 필수네.
        SIMD(단일명령 다중 데이터)는 고려해야겠는데..?
          이거는 또 순차적 Ser과 병렬적 Par이 있고.. 

  
      

      SISD 
      SIMD - ser?par? 이거면 적절하겠네.. 
      MISD - 용처가??
      MIMD - async + await 로 해결보는게....

      SIMD면 충분하고, 타이밍 제어는 observer가 수행할수 있다.
      다만. 정적인 Observer가 끝났는지를 어떻게 알 것인가? 
        > 먼가 RxJS비슷..? 그런것 같지는 않네...

      t가 메시지를 뿌리는 시점이 중요하다. 
      hc()가 함수 체인이 완성되는 시점을 알수없다. 

      t = hc.trigger.of messages... 
      hc().reactTo(t).do (cur)-> ....
      t.start() # 이건 스트림인가?? 
        .finished.then ()-> 


    ###

    # chain = hc.create()
    chain = hc() # return function 
      .uncaughtException (err)-> # Error를 수신받을 callback이 없을때 처리함. ex> observer나 다른 체인으로부터 받을떄  
      .reactTo hc.trigger.of messages... # Input Queue에 넣고 시작함. messages를 하나씩 처리하도록 함 Serial? Parallel? 기본은 직렬, 하나씩 끝내자
      .reactTo hc.trigger.par messages... # 메시지를 동시에 뿌려버린다.
      .reactTo hc.trigger.event src, 'event_name'
      # src.on 'event_name', (cur)-> thisChain cur
      ###
      (src, event_name)->
        src.on event_name, (evt)->
          
      ###
      .reactTo hc.trigger.interval 1000 # 1000 ms 마다 발생
      # setIntervale ()->{thisChain()}, 1000 
      .reactTo hc.trigger.puller src, 'path', chk_interval
      # setIntervale ()->{thisChain() if (_.get(src, 'path') is chagned) }, chk_interval 
      ###
        reactTo = (trigger)->
          trigger.attachChain thisChain 


      ###
      .reactTo Stream # Stream은 Chain과는 달리, 자체적인 버퍼를 가진다. 제때 못읽는다고 데이터가 사라지지는 않는다.
      .reactTo otherChain #  otherChain.do (cur)-> thisChain cur
      .connectTo otherChain # otherChain.do (cur)-> thisChain cur, @async()
      # .mapTo {} # 고정적인 값으로 변경 _.isFunction 코스트를 물기 그렇다?? 아니, Chain을 구성할때 1번 지불하면..? 그래도 내부적으로는 다 있다는 소리네..
      .load (cur)-> # 데이터를 읽는다...? do랑 뭐가 다르냐..?  
        cur.var = getDataFromCache()
        cur.cfg = readConfig()
      .load 'var.path', hc.getter.obj src, 'bla.bla.path'
      .map (cur)-> cur * cur # map : return value become value In Stream
      .map (cur)-> obj = 
        one: cur
        two : cur * cur 
      .do (cur)->  # do : return value ignored
        cur.triple = cur.one * cur.one * cur.one
      .do (cur)-> console.log cur # == each
      # .doAsync (cur, done)->
      #   done null
      # .mapAsync (cur, done)->
      #   done null
      .do (cur)->
        sync = @async 'name_of_job' # this === call context { input: cur, callback: }. this created by hc()(input, callback)
        callAsync sync.err (err)->
          sync null
          # @get ? @result 'name_of_job'으로 처리.? 

      .delay 10
      # .wait (go)-> setTimeout go, 10
      .delayWhen 10, (cur)-> cur.one > 10
      # .wait (go)-> 
      #   return go() if cur.one > 0
      #   setTimeout go, 10
      .delayWhen 10, _.isObject

      .timeout 1000 * 10  # 10초후에는 Error Timeout.  call_context.clearTimeout()으로 해제 됨 or 작업이 끝나면 됨.
      .await 'name_of_job'
      .wait (go)->
        @wait('load').then go

      .do (cur)->
        return @callback null, 'ok' if cur > 10

      # .return (cur, callback)-> 
        # return : return value will pass to callback of hc()(data, callback)
        # and 
        # callback null, 1,2,3

 
      .filter (cur)->
        # return value decide continue or quit
        # if quit,  callback of context is called with zero args. 
        cur.one > 10 

      .filter _.isObject
      .filter (cur)-> _.include [11,12,13], cur
      .filter hc.filter.throttleTime 100
      .filter hc.filter.debounceTime 100
      .filter hc.filter.throttleCount 10
      .filter hc.filter.debounceCount 10

      # reduce : decide continue with Something or not
      .reduce hc.reducer.object (reducer, cur, next)->
        reducer.cur = if reducer.cur? then reducer.cur * cur else cur 
        next reducer.cur if reducer.cur > 1000
      .reduce hc.reducer.array (reducer, cur, next)->
        reducer.push cur 
        if reducer.length > 3 
          chunk = reducer.get()
          reducer.reset()
          next chunk

      # .call  otherChain  
      .do (cur)-> otherChain cur, @async() 
      # .fork otherChain  
      .do (cur)-> otherChain cur 
      # .sendToIf otherChain, (cur)-> cur > 10 
      .gotoIf 'label', (cur)-> cur > 10
      # .store 'path.for.variable', dest, 'dest.variable.path' # dest.variable.path거 함수인지, 변수인지? 셋팅 동작도 불명..
      # .store을 스트림 or 배열에 Push하는 것도 고민 해야한다. 
      # 이것도 .do랑 뭐가 다르냐.. 
      .label 'label'
      .loop 3 # === for 3
      .loopback()
      .loop (cur)-> cur < 10 #  < 10 이면 반복. === while
      .loopback()
      .catch (error, cur)->
        # throw 를 하지 않으면 Error는 소멸함
      .finally (err, cur)->   
        # err는 절대 소멸안함
      .output (cur, output)->
        output.cur = cur 


    data = 1
    chain data, callback #  fn data, callback = (error, call_context)->
    # 기본적으로 Error를 callback 에 돌려주도록 함
    # ErrorBack이자 done의 의미로 사용

    chain.close()
    chain.open()
    ###
    if closed
      chain(data, callback). will imediatly call callback with error
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