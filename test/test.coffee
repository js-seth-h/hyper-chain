 
hc = require '../src'   
chai = require 'chai'
expect = chai.expect 
debug = require('debug')('test')
 
describe '?', ()->
  it '?', (done)-> 
    ###
      데이터 변조, Context확보, Filtering, send..


      timing : ( Load Context | 변환 | Store Context | Filter )+


      체인에 대한 호출은 execute_context 를 만든다
      execute_context =  # created by hc()(input, callback)
        input: initial input 
        cur: # 처리중인 현재 값
        callback: (err, feedback, execute_context)-> 
          if _callback
            _callback err, feedback, execute_context 
        output: null
        exit_status:  
          undefined: 아직 안끝남  
          error - 에러가 발생 
          filtered - filter 되어 끝남
          reduced - reduce 되어 끝남
          finished - 모든 연산 끝남
        storage: {}  # promise와 callbacked async 는 여기 저장됨.
        getItem
        setItem
        removeItem
        items

        promises: 
          all: []
          user_defined_group_name: []
        asyncTasks: 
          task_id: [error, args...]
          task_id: [error, args...]



            

      OtherChain과 의존..? 
        > 다른 체인이 취급한 데이터에 반응하는 것...? 음 모듈 구조를 생각해야겠다.

        module은 외부와 소통해야하는데. 결국 함수 호출과 변수. 이벤트(=역함수 호출 + 수신자 불명), Callback(=역함수 호출 + 수신자 명확) 
        현대적으로는 함수 호출이 정공, 변수 설정은 문제가 제어권 문제가 있고 변수읽기는 무난
        reactive 관점에서 변수는 puller 없이는 구성이 어렵고 좋은 선택지가 아니다. 
        결국 Event, observer, promise등을 통해서, 역함수 호출이 필요.
        그냥 함수 호출하는 것은 무난. chain을 함수화 할수 있음으로..

        기존 체인의 결과를 복사 받아, 독립적으로 구성하는 것은 아무 문제가 없다. 
        구성된 기능을 임의로 늘리는 것은...?, 정확하게는 기존 chain의 execute_context를 이어서 계속 처리하는것은..? 
          -> 기능의 확장 이라는 측면에서 강함. 그러나 안전성을 훼손한다. 
          -> 심각한건 어디까지 될지 알수가 없고, 이는 프로그래밍할수 없는 상태(계획 불가)를 만든다 
        그런데 체인은 원래 늘어날수 있는 것이 정상 상태다. .frezee() / .seal()등의 처리가 별개로 있어야.
        고정시키지 않으면, 어떻게든 할수 있네...   .do + .await 등으로... 
          otherChain.do (cur)->
            sync = @async 'connect'
            thisChain cur, sync
        내가 다른 체인을 불러 내는 것이나. 다른 체인이 나를 불러 내는 것이나. 가능. 그러나 execute_context는 공유안됨. 
        공유하려면 체인과 체인의 관계가 아니라, 하나의 체인을 변경해야한다. 
          1. 바로 수정하던지, 2. 복사하여 수정하던지, 3. Merge하여..(= 연속된 복사자나...쯥.)
        에러를 전파받던 말던, execute_context가 다르다.

        But, Error 전파의 파급이 꽤 크지않나...? 아닌가..? 고민할 필요가 없을듯하다.
        Error에 대해서는 직접 처리할수 있으면하고, Default로 전파해야한다. 흐름의 시작점은 어쩃든 모든 Error를 커버해야한다. 
        고로 문제 없음. Default행위가 문제있으면 안되지.

        end 시점에 대한문제...
        reactTo OtherChain을 할경우, OtherChain의 End는 언제인가? ㅁ
          > 만약 callback을 건다면, ThisChain까지 끝나야한다.
          > 그렇지 않다면, fireAndForgot이다. 

          결국 동작이 성격에 따라 달라야겠다. 문제는 확장하는 놈의 사양을 당하는 놈이 알수는 없음으로, 추가될때 결정해야한다.

        .forkFrom는 callback을 연결안함. 별개의 사건 처리다. (other입장에서 fireAndForgot)
        .concatTO는 callback을 연결함. 동일한 사건처리로써, 연속적 반응으로 간다. (other입장에서 비동기)


        .do = .load = .store 그냥 의미상 구분.  
          .load .store에서 cur.var = getter() 또는 그 역을 수행하려고 보니, 어설프게 하는게 더 복잡함. 너무 다양함.
      
      Reducer에 대해서... 이것은 시간에 대해서 reduce를 해야한다.
        Reducer는 cur를 drop할찌 Next할지 동기로 결정할수 없다. 
        thisChain, thisReducer에 대한 acc공간이 필요함. acc공간은 배열말고는 없음.(특정 시간에 들어온 것들을 저장해야하니까) 
        때가 되면 배열에 대한 Reduce를 하여 넘기면 된다. 
        Reducer (timingSelector, ReductionFn, ResetFn)

        .reduce thisReducer = (thisReducer, cur, execute_context)->
          의문 1. Drop/Next를 하나의 함수로 처리가능한가? 넘길값이 뭔지 몰라서 불가.
          만약 execute_context를 받으면..? execute_context.reduced()로 깔끔히 처리가능.. execute_context.next() 도 괜찮은 선택일듯.

        쉽게 만들 방법이 있을까? 없을듯. 
          시간 관련인데 불확실한 미래를 고려하는가? 아닌가?는 복잡.  timeout + condition이면 되지 않나..?
          reduceFn은 정형화 가능. Reset은 어떨지 모르겠음. setEmpty를 전제로한다면...
  
      input.user_list 식으로 배열을 받을테고, 이에 대한 처리는? 

      SIMD(단일명령 다중 데이터)는 고려해야겠는데..?
        이거는 또 순차적 Ser과 병렬적 Par이 있고.. 
  

        

      SISD 
      SIMD - ser?par? 이거면 적절하겠네.. 
      MISD - 용처가??
      MIMD - async + await 로 해결보는게....

      SIMD면 충분하고, 타이밍 제어는 Enforcer 수행할수 있다.
      다만. Enforcer가 끝났는지를 어떻게 알 것인가?  이건 Enforcer가 알아서...

  
      Enforcer, 데이터를 밀어 넣는 장치
        When & What이 핵심인데 다양하니까 정형화는 무리
        다양성을 허용하면 많은 문제 해결가능

      when ...
        1. 생길때마다. 
        2. 변경될때마다. 
        3. 주기적으로..? interval? callback chain? 
        4. 동시 병렬?, 
        4.1. 병렬의 갯수 제한 = 쓰래드 수 제한
      What ...

      How - 이건 Chain이 하는것이다.

      따지자면 끝도 없고, 니맘대로다.
      고려할것 enforcer와 외부와의 관계.
      외부는 What Source, When Source?? 
        데이터의 소스는 분명한데 When이 소스가 있나..? 있네. 뭐가됫든 직접만들기도, 위임하기도 가능.

      의문1. enforcer는 callback을 수신 한다?안한다? 
        Flow 컨트롤을 하려면 수신을 해야맞다. 다만 Error까지 온다.
        Error는 Enforcer가 처리해야하는가? 
        항상 UncaughtException이 문제지.. 캐치되면 요청 맥락에서 처리가 되니까..

        hook.event, interval, cron의 경우, Callback이 의미가 없다. event는 wait안하니까.
        > 처리중엔 처리하지 않는다? 이건 Reducer나 Filter로 되지 않나? 이건 연산특징인가?발생 특징인가?
          처리 상태에 대하여 처리 여부를 결정하니, 연산특징. 2번 할 필요가 없는 연산
      
        Enforcer = chain with self trigger가 되어 버려서 의미없는 논의 
        chain이 다른 체인(=Enforcer)에 편입될지 말지는 concatTo, forkFrom 구분하여 3rd의 판단에 맞김
        > 이거 틀렸음. Enforcer는 모듈이고, Timing 제어권이 있어서 Enforcer가 Callbak수신여부를 판단해야함.

      
      event 'end', Enfocer가 끝을 인식 했을떄, 무한 스트림은 안생긴다. ex> EventStream
      Enforcer는 능동체라서 'drain'은 없을듯하다. 

      체인은  WritableStream과 유사.
        > 그러나 체인은 데이터를 보관하지 않는다. 흘려 보낸다.
      Enforcer는 ReaderbleStream과 유사하다.
        > 데이터보관을 해도 되고, 정지도 될텐데..?, 파이프와 다르바 없는 체인.


      DataBox를 놓아야하는가? 
        > 이벤트 - 크기를 알수없는 언제 발생할지 모르는 박스 
        > 스트림 - 크기를 알수도 모를수도 있는 언제 발생할지 모르는
        > iterater - 크기를 알수도 모를수도? 
        > 

      
      t가 메시지를 뿌리는 시점이 중요하다. 
      hc()가 함수 체인이 완성되는 시점을 알수없다. 

      forcer = hc.hook.ser messages... 
      hc().reactTo(forcer).do (cur)-> ....

      hc().reactTo hc.hook.sensor (forcer가 끝인지?) 현상태 + 상태의 변화 == 기대값
        .do (cur)->
          message에 대한 모든 처리가 끝났으니 후처리

      일단 저렇게 해도 굴러는 가겠는데.. 더 간단하게..
      결국 감시 대상이, 목표 상태가 되면 호출하는 것이다.       
        check Timing, 
        Expect Value == 감시 대상 getter()  => CheckChain
        Prev Value != 감시 대상 getter()  => CheckChain

        Enforcer = Enforcer + filter도 가능하겠네.. 

        hc.enforcer()
          .asap()
          .event src, 'event_name'
          .filter 

        hc()
          .reactTo hc.timing.asap()
          .reactTo hc.timing.event src, 'event_name'

        체인이 스스로 능동체가 되면 enforcer 로 변한다.
        피동 반응 vs 능동반응? 능동반은 == Pull? PullWhen? -> 피동 반응? 

      hc.hook.ser는 어떻게 되냐?
        hc()
          .reactTo hc.timing.ser message...
          .connectTo hc.timing.ser message...
        응????
        ser처리를 하려면 필히 callback을 받아야한다. 

        꼬였다.. reactTo를 아래처럼 코딩하면 안됨.
          reactTo = (enforcer)->
            hook.do (cur)-> thisChain cur
    
        아래 처럼 되어서, Callback여부가 enforcer 책임하에 가야함.
          reactTo = (enforcer)->
            hook.attach thisChain

          
          enforcer = (opt)->
            self = 
              attach: (chain)->
              activate: (cur)->
                self.chains. cur
                또는
                self.chains. cur, calback?
            return self
        
          타이밍 제어를 위해서는 Enforcer가 알아함.

      Enforcer is a EventEmitter 'end'
      Enforcer is not Function - 실행불가. 실행시 해야할 작업 불명
      Enforcer is a Object

      Enforcer has call Reactors, 이를 위한 판단 로직, Function call의 진입점(~트리거)을 가짐.
              is 다수의 H-Chain이 모인 구조물 => 모듈 
              모듈 내부 데이터도 포함가능하고...
              특별한 규격을 가진 모듈

      Chain은 애초에 Module/data/Model ---------> Moudle/Data/Model을 하려고 만든거다. 
      Chain의 시작점인 Enforce는 어찌보면 Module인게 당연...
  
      Enforcer는 
        최소한 Timing(함수 실행)을 가져야한다. 
          즉 hook.event 처럼 최소한것 것만 가져도 enforcer다.
        연결된 모든 Chain = Function을 호출해줘야한다. 
          callback을 수신하든 안하든 자유다.

        데이터 가공 루틴을 가질수도 있다. 
        입력 데이터를 가지고 시작해도 되고, 어디서 퍼와도 된다.
        버퍼를 하던 drop을 하던 자유다.

      Enforcer = 외부로 드러는것..?
        addChain : #  AddFunction.
        Chain_list
        Name? 
        event, 'end'
  
      Enforcer는 너무 직접적인가..? 
      React에 초점을 두는게 아니라 Drive에 초점이 가니까..
      React to Something??? Something!!!
      
    ###
    # chain = hc.create()

    chain = hc() # return function 
      .uncaughtException (err)-> # Error를 수신받을 callback이 없을때 처리함. ex> observer나 다른 체인으로부터 받을떄  
      .reactTo hc.hook.of hc.generator.ser messages... # Input Queue에 넣고 시작함. messages를 하나씩 처리하도록 함 Serial? Parallel? 기본은 직렬, 하나씩 끝내자
      .reactTo hc.hook.of hc.generator.par messages... # 메시지를 동시에 뿌려버린다.
      .reactTo hc.hook.event src, 'event_name' 
      .reactTo hc.hook.promise new Promise 
      .reactTo hc.hook.callback (cb)-> fs.open '', cb
      ###
      reactTo = (hook)->
        hook.on thisChain
      stopReactTo = (hook)->
        hook.off thisChain
      hook.of = (opt, target)->
        unless target 
          target = opt
          opt = 
            unsetter : 'removeChain'
            setter : 'addChain'
        return hook = 
          off: (a_chain)->
            generator[opt.unsetter] a_chain

          on : (a_chain)->
            generator[opt.setter] a_chain
      hook.event = (src, e_name)->
        _trigger = (evt)-> a_chain evt
        return hook =
          on: (a_chain)->
            src.on e_name, _trigger
          off: ()->
            src.off e_name, _trigger
      hook.promise = (promise)->
        return hook =
          on: (a_chain)->
            promise.then (value)-> a_chain value
          off: ()-> throw new Error 
      hook.callback = (fn)->
        return hook =
          on: (a_chain)->
            fn (err, args...)-> 
              unless err
                a_chain args...
              else 
                a_chain.throwIn err


      ###
      # .event src, 'event_name' 도 가능하다. 짧고 직접적. 3단어 짧다 reactTo hc.enforcer  
      # 늘 그렇듯이 간접층이 없으면, 여러 문제를 해결하기가 어렵지..
      # 게다가 참 다양한 enforcer형태가 있을텐데, 다 구현해넣기도 무리. 짧게 쓸방법은..?
      # .reactTo hook.event src, 'event_name'
      # hook.event(src, 'event_name').drive chain
      .reactTo hc.actor.interval 1000 # 1000 ms 마다 발생 
      .reactTo hc.actor.puller src, 'path', chk_interval 

      .reactTo hc.adapter.stream Stream # Stream은 Chain과는 달리, 자체적인 버퍼를 가진다. 제때 못읽는다고 데이터가 사라지지는 않는다.

      .forkFrom otherChain # otherChain.do (cur)-> thisChain cur
      .concatTo otherChain # otherChain.do (cur)-> thisChain cur, @async()
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

      .delay 10
      # .wait (go)-> setTimeout go, 10
      .delayIf 10, (cur)-> cur.one > 10
      # .wait (go)-> 
      #   return go() if cur.one > 0
      #   setTimeout go, 10
      .delayIf 10, _.isObject

      .timeout 1000 * 10  # 10초후에는 Error Timeout.  execute_context.clearTimeout()으로 해제 됨 or 작업이 끝나면 됨.

      .async 'async_job_name', (cur, done)->
        # hc.tagging 'name_str', done
        # hc.tagging {name: '', group: ['a','b']}, done 
        # sync = @async 'name_of_job' # this === call context { input: cur, callback: }. this created by hc()(input, callback)
        callAsync done.catch (err)->
          done null
          # @get ? @result 'name_of_job'으로 처리.? 

      ### 
        .await (cur, result_dictionary)->  # all 
        .await 'async_job_name', (cur, result)->  # a job
        .awaitGroup 'gorup_name', (cur, result_dictionary)-> 

        .await 가 함수화 되면.. 이건 .do .map .reduce .filter .if등등 뭐가 되어야하지..?  
        결국 조합의 숫자가 폭주해서 제어하기 힘들게된다. 
        대기 이후에는 값을 간단히 꺼낼 방법을 쓰자. 
        어차피 "이름" 없이 엑세스도 안되는거..      

        생각 2. .await와 .waitPromise의 차이는..?
        async 호출을 한다고 2번 Callback을 해도 되는것도 아니고,
        대기 루틴 처리도 promise가 제공하는게 신뢰도 있기도 하다. 
        통합 결정. 

      ###
      .promise "promise_name" ()->
        return new Promise()

      .wait() # all 
      .wait 'async_job_name',
      .waitGroup 'gorup_name'
      .do (cur)->
        {async_job_name, promise_name} = @items()

      # .waitPromiseAll (cur, values_dictionary)-> # all    
      # .waitPromise 'name', (cur, value)->  # not all
      # .waitPromiseGroup'group_name', (cur, values_dictionary)-> # not all

    chain = hc() 
      ###
        .if .else .unless 
        .for .while .until 
        .goto 
        .break
        .continue.

        일단 보통의 프로그램에서 Statement는 Sub Statement를 가지고 scope는 공유한다

        currentExecute와  .if의 Execute의 관계는...? 
          1. 별개의 함수. - 구현이 용이하나 맥락이 불편.
          2. 연속된 문. - 구현어려움..

        맥락의 문제... if를 수행하여 현재 cur 가 바뀌어야하는가? 
        만약 그렇다면 map안에서 if처리하면 되지 않는가? 
          -> 비동기가 아니면 이상없음.
        
        비동기 처리를 한다면 문제???

        chain이 유지하는 데이터는 1개라는 관점과 비동기 작업의 관리 원칙에서 보자.
        비동기 작업 이후에 if든 뭐든 한다면?? 큰 문제가 없다. .aync > .wait > .do/.map 순
        그렇다면 반대로 if로 인해 비동기 작업이 발생한다면? 
        즉 비동기 작업을 건너 뛸것이라면..? 
        .... 흐름을 매끄럽게 하기 위해서 일단 .async하고 바로 callback해야 일관성이.. 
        후방에서 앞선 비동기 작업의 진행 YN을 판단하는 것은 무리수다.
        결국 무조건 있다고 가정. 앞에서 맞춰야하고, 
          !! 그렇다면 조건부 비동기 실행은 없다. !!

        for/while도 동기 실행은 문제 없고
        비동기 실행은..? 
          음 맥락 데이터가 문제시 되기는 하겠는데...
          원래 closure로 처리를 했지...
          함수 자체가 체인화 되어서 클로져가 원활하지가 않아. 함수적이게 되긴하나.. 
          cur와 storage가 분리되어서 좀 피곤.

        cur와 feedback의 관계
          feedback은 함수의 콜백으로 호출자에게 되돌아간다. 
          함수의 리턴은 비동기인 순간 의미가 없다. 
          last cur == feedback인가? -> 체인 연결을 하면 안된다. 연결되면 feedback이 달라짐. 
          
          게다가 다중 끝점 구조를 하려는 것이니까,
          Feedback은 특별한(named endPoint)로써 처리가 필요할수있고 -> 명확해야함          

        모든 비동기는 일단 결과를 저장한 뒤에,
        불러다가 동기처리한다. 
        
        그러면 문제는 결과 저장소에 엑세스가 되는가?
        그리고 다수를 시작시킬수 있는가?

        SIMD 만 고려.. 
        MIxx은 이미 명령문이 지저분하게 여러개라 루틴상 의미없다.

        다수의 비동기 즉 SIMD를 1 error시 끝내버리는게 적절한가? 
        적절하다. error는 무조건 최단시간에 전파 할것. 오히려 그렇게 해야한다. 

        이를 어떻게 처리할까?
        Chain은 SISD고 
        SIMD는 generator를 이용할껀데....

        .async 'name', (cur, done)->
          newGen 
          hc()
            .react newGen

          newGen.start (err)-> 
          
            done err
        .do (cur)->
          {name} = items() 



      ###
      .if ((cur)-> cur > 10), 
        hc()
        .map (cur)->
            cur + 1
        .do (cur)-> 
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

      .reduce hc.reducer (thisReducer, cur, execute_context)->
        thisReducer.acc.push cur 
        if thisReducer.acc.length > 3
          chunk = thisReducer.acc
          thisReducer.acc = [] # thisReducer.reset
          execute_context.next chunk
        else 
          thisReducer.prev_execute_context.reduced()
          thisReducer.prev_execute_context = execute_context
        ###
          여기에 더해서 타임아웃되면 방출?
        ###


      .reducer hc.reducer
        time_slice: 1000 # 최대 1000ms마다 방출
        reduce: (acc)-> return reduced_data
        needFlush: (acc)-> return true or false 
      ###
      hc.reducer = (opt)->
        return thisReducer = (cur, execute_context)->
          thisReducer.acc.push cur
          if thisReducer.pending_context 
            thisReducer.pending_context.reduced()
          
          thisReducer.pending_context = execute_context

          _tout = ()->
            thisReducer.tid = null
            data = opt.reduce thisReducer.acc
            thisReducer.acc = []
            thisReducer.pending_context.next data 

          if opt.needFlush()
            _tout()
          else
            unless thisReducer.tid
              thisReducer.tid = setTimeout _tout, opt.time_slice
              ###
      ###
        timeout + condition로 방출 시점을 결정
        시점이 되면 ReduceFn으로 누적된 데이터를 줄임

        시간 관련인데 불확실한 미래를 고려하는가? 아닌가?는 복잡.  timeout + condition이면 되지 않나..?
        reduceFn은 정형화 가능. Reset은 어떨지 모르겠음. setEmpty를 전제로한다면...
      ###


      # .reduce hc.reducer.object (reducer, cur, next)->
      #   reducer.cur = if reducer.cur? then reducer.cur * cur else cur 
      #   next reducer.cur if reducer.cur > 1000
      # .reduce hc.reducer.array (reducer, cur, next)->
      #   reducer.push cur 
      #   if reducer.length > 3 
      #     chunk = reducer.get()
      #     reducer.reset()
      #     next chunk

      # .call  otherChain  
      .do (cur)-> otherChain cur, @async() 
      # .fork otherChain  
      .do (cur)-> otherChain cur 
      # .sendToIf otherChain, (cur)-> cur > 10 
      # .gotoIf 'label', (cur)-> cur > 10
      # .store 'path.for.variable', dest, 'dest.variable.path' # dest.variable.path거 함수인지, 변수인지? 셋팅 동작도 불명..
      # .store을 스트림 or 배열에 Push하는 것도 고민 해야한다. 
      # 이것도 .do랑 뭐가 다르냐.. 
      # .label 'label'
      # .loop 3 # === for 3
      # .loopback()
      # .loop (cur)-> cur < 10 #  < 10 이면 반복. === while
      # .loopback()
      .catch (cur, error)->
        # throw 를 하지 않으면 Error는 소멸함
      .finally (cur, err)->   
        # err는 절대 소멸안함
      .feedback (cur, feedback_data)->
        feedback_data.cur = cur 

    data = 1
    chain data, callback #  fn data, callback = (error, execute_context)->
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