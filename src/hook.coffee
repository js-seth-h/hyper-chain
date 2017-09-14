_ = require 'lodash'


###

모듈이 외부 모듈과 소통하는 방법에는...
# 데이터 공개형 - 알아서 읽어가라 1:N
# 이벤트 전파 - 알려는 주는데 후처리는 관심없다, 1:N
# 외부 호출 - Callback : 후처리가 어떤 수행을 할것을 기대 1:1
              상속 : 상속자가 지켜야하는게 있음 1:1  

?의문! -  1:N 이면서, 에러를 수신받는(=어떤 Task를 기대?) 하는 경우는...?
  forking이 되면서 다중에러..? 너무 특수하지 않나..?

제 1 목적은 인터페이스의 차이를 극복하는것.
  chain에게는 단일 인터페이스를 주고,
  외부 세계를 다양화한다

Chain은 FeedBack을 처리 함으로 1:1, 외부호출을 기본으로 한다.
차이가 나는 것은 Hook으로 매꾼다.

hook = 
  on: (a_chain)->
  off: (a_chain)->  

문제!!
  훅은 누구의 소유인가?
  체인의 소유? 
    생존 사이클 동기화 가능.
    1:1 이 명확
  Dynamo의 소유 or 기생
    체인없는 훅이 생긴다. 
    개념적으로 1 Hook : N Chain이 안될 이유가 없어진다.
    다이나모가 Hook을 제공하는...???? - Hook자체가 Gap의 극복이 목적인데..?

  체인 소유가 맞겠다.

###
class Hook  
  constructor: (@opt) -> 
  on: (a_chain)->
    @chain = a_chain
    @opt.afterOn a_chain if @opt.afterOn
  off: ()->
    @opt.beforeOff @chain if @opt.beforeOff
    @chain = undefined
  tow: (data, callback)=> # important!! bind self, 
    @chain data, callback 

Hook.of = (src, opt)->
  unless opt
    opt = 
      setter : 'setDataHandler'
      unsetter : 'setDataHandler'
  return h = new Hook
    afterOn: ()->
      src[opt.setter] h.tow
    beforeOff: ()->
      src[opt.unsetter] null

 
Hook.event = (src, e_name)->
  return new Hook
    afterOn: (a_chain)->
      src.on e_name, a_chain
    beforeOff: (a_chain)->
      src.removeListener e_name, a_chain

Hook.promise = (promise)->
  return new Hook
    afterOn: (a_chain)->
      _ok = (value)-> a_chain value 
      _fail = (err)-> 
        a_chain.throwIn err
      promise.then _ok, _fail

Hook.pull = (src, prop_path, ms = 500)-> 
  return h = new Hook
    prev : undefined
    afterOn: ()->  
      now = _.get src, prop_path
      h.opt.prev = now
      _dfn = ()->
        now = _.get src, prop_path
        if h.opt.prev isnt now 
          h.tow now
        h.opt.prev = now

      h.tid = setInterval _dfn, ms
    beforeOff: ()->
      h.tid = clearInterval h.tid

module.exports = exports = Hook