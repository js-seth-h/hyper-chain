debug =  require('debug')('hc')

_ = require 'lodash'


_ASAP = (fn)-> setTimeout fn, 0
if process?.nextTick?
  _ASAP = (fn)-> process.nextTick fn

class Args # TODO  1: 'test', 2: var 식의 처리 고안하자
  constructor : (@args...)->
  reset: (@args...)->
  set: (inx, val)->
    @args[inx] = val
  get:(inx)->
    @args[inx]
  length: ()->
    @args.length

Args.Empty = new Args()
createExecuteContext = (internal_fns, _callback)->
  _KV_ = {}

  outCallback = (error, exit_status)->
    exe_ctx.exit_status = exit_status
    exe_ctx.error = error
    _ASAP ()-> # 만약 외부 콜백에 문제가 있더라도 내부 프로세스를 타면 안됨
      return unless _callback
      [cb, _callback] = [_callback, null]
      debug 'outcallback', exe_ctx.error, exe_ctx.feedback, exe_ctx
      cb exe_ctx.error, exe_ctx.feedback.args...

  return exe_ctx =
    error: null
    curArgs: new Args
    feedback: new Args
    step_inx: -1
    exit_status: undefined
      # undefined: 실행중
      # exiting - 끝내는 작업 진행
      # error - 에러가 발생
      # filtered - filter 되어 끝남
      # reduced - reduce 되어 끝남
      # finished - 모든 연산 끝남

    promises:
      all: []
      # user defined name: []
      # user defined group: []

    next: (args_obj)->
      exe_ctx.curArgs = args_obj
      exe_ctx.resume()

    resume: ()->
      # internal_fns를 꺼내서 수행하는 유일한 주체다.
      # 절대 병렬 호출이 되서는 안됨
      try
        return if exe_ctx.exit_status
        #다음 스탭으로
        exe_ctx.step_inx++

        # 체인의 끝이면, 종료
        if exe_ctx.step_inx >= internal_fns.length
          debug 'resume -> exit with no error'
          return exe_ctx._exit 'finished'


        _fn = internal_fns[exe_ctx.step_inx]
        # 에러가 있으면, 에러 수용체가 아니면 패스
        if exe_ctx.error?
          if _fn.accept_error isnt true
            debug 'resume -> skip ', exe_ctx.step_inx, 'because not ErrorHandler'
            return exe_ctx.resume()

        debug 'resume -> call', exe_ctx.step_inx #, 'with', exe_ctx
        _fn(exe_ctx)
      catch err
        exe_ctx.error = err
        debug 'resume -> catch error', exe_ctx.step_inx, err.toString()
        exe_ctx.resume()

    # evacuation 함수 실행을 중지하고 반환처리
    evac: (args...)->
      # 배열반환은 필요없다. HC()는 함수 취급임으로 항상 단일 값 반환
      # args 길이를 확인하기 위해서 처리.

      if args.length > 0
        if args[0] instanceof Args
          exe_ctx.feedback = args[0]
        else
          exe_ctx.feedback.reset args...
      # exe_ctx.feedback = args[0] if args.length > 0
      exe_ctx._exit 'finished'

    _exit: (exit_status)->
      exe_ctx.exit_status = "exiting"
      p = new Promise (resolve, reject)->
        return reject exe_ctx.error if exe_ctx.error
        task_promise = exe_ctx.getMergedPromise()
        task_promise.then resolve, reject
      _ok = ()->
        outCallback null, exit_status
      _fail = (error)->
        outCallback error, 'error'
      p.then _ok, _fail

    recall: (name)->
      return _KV_ unless name
      return _KV_[name]
    remember: (name, value)->
      _KV_[name] = value
    createSynchronizePoint :(name_at_group)->
      _resolve = _reject = null
      p = new Promise (resolve, reject)->
        [_resolve, _reject] = [resolve, reject]
      exe_ctx.trackingPromise name_at_group, p

      [name, group] =_.split name_at_group, '@'
      _done = (err, args...)->
        debug '_done', err, args...
        return _reject err if err
        value = args[0]
        _resolve value
        exe_ctx.remember name, value
        exe_ctx.remember name + '[]', args
      _done.catch = (fn)->
        return (err, args...)->
          return _done err if err
          fn err, args...
      return _done
    getMergedPromise : (labels...)->
      if labels.length is 0
        return Promise.all exe_ctx.promises.all
      Promise.all _.uniq _.flatten _.map labels, (lb)->
        return exe_ctx.promises[lb]

    trackingPromise: (name_at_group, promise)->
      [name, group] =_.split name_at_group, '@'
      if _.isEmpty name
        throw new Error 'name of asyncTask is required'
      if exe_ctx.promises[name]
        throw new Error 'name must be uniq'

      exe_ctx.promises['all'].push promise
      exe_ctx.promises[name] = []
      exe_ctx.promises[name].push promise
      unless _.isEmpty group
        exe_ctx.promises[group] = [] unless exe_ctx.promises[group]
        exe_ctx.promises[group].push promise

      promise.then (value)->
        exe_ctx.remember name, value
      , ()-> # prevent node worning. error handled after .wait()



applyChainBuilder = (chain)->

  chain.clear = ()->
    chain._internal_fns = []
    return chain
  chain.load = (var_name)->
    chain._internal_fns.push (exe_ctx)->
      val = exe_ctx.recall var_name
      exe_ctx.next new Args val
    return chain
  chain.store = (var_name)->
    chain._internal_fns.push (exe_ctx)->
      exe_ctx.remember var_name, exe_ctx.curArgs.get 0
      exe_ctx.remember var_name + "[]", exe_ctx.curArgs.args
      exe_ctx.next new Args()
    return chain

  chain.do = (fn)->
    chain._internal_fns.push (exe_ctx)->
      fn.call exe_ctx, exe_ctx.curArgs.args...
      exe_ctx.resume()
    return chain

  chain.map = (fn)->
    chain._internal_fns.push (exe_ctx)->
      # debug '.map', exe_ctx
      new_cur = fn.call exe_ctx, exe_ctx.curArgs.args...
      unless new_cur instanceof Args
        new_cur = new Args new_cur
      exe_ctx.next new_cur
    return chain

  chain.dropArgs = ()->
    chain._internal_fns.push (exe_ctx)->
      exe_ctx.next new Args

  chain.filter = (fn)->
    chain._internal_fns.push (exe_ctx)->
      can_continue = fn.call exe_ctx, exe_ctx.curArgs.args...
      if can_continue
        exe_ctx.resume()
      else
        exe_ctx._exit 'filtered'
    return chain

  chain.catch = (fn)->
    _catcher = (exe_ctx)->

      unless exe_ctx.error
        return exe_ctx.resume()
      fn.call exe_ctx, exe_ctx.error, exe_ctx.curArgs.args...
      exe_ctx.error = null
      exe_ctx.resume()
    _catcher.accept_error = true
    chain._internal_fns.push _catcher
    return chain

  chain.finally = (fn)->
    _catcher = (exe_ctx)->
      fn.call exe_ctx, exe_ctx.error, exe_ctx.curArgs.args...
      # exe_ctx.error = null
      exe_ctx.resume()
    _catcher.accept_error = true
    chain._internal_fns.push _catcher
    return chain

  chain.async = (name_at_group, fn)->
    unless fn
      fn = name_at_group
      name_at_group = chain._internal_fns.length.toString()
    chain._internal_fns.push (exe_ctx)->
      a_done = exe_ctx.createSynchronizePoint name_at_group

      fn.call exe_ctx, exe_ctx.curArgs.args..., a_done
      exe_ctx.resume()
    return chain

  chain.await = (name_at_group, fn)->
    unless fn
      fn = name_at_group
      name_at_group = chain._internal_fns.length.toString()
      # console.log 'anonymous_awiat', name_at_group, fn
    chain._internal_fns.push (exe_ctx)->
      a_done = exe_ctx.createSynchronizePoint name_at_group
      fn.call exe_ctx, exe_ctx.curArgs.args..., a_done
      _ok = ()->
        exe_ctx.resume()
      _fail = (err)->
        exe_ctx.error = err
        exe_ctx.resume()

      [name, group] =_.split name_at_group, '@'
      task_promise = exe_ctx.getMergedPromise name
      task_promise.then _ok, _fail
    return chain

  # chain.makePromise =
  chain.promise = (name_at_group, fn)->
    chain._internal_fns.push (exe_ctx)->
      promise = fn.call exe_ctx, exe_ctx.curArgs.args...
      exe_ctx.trackingPromise name_at_group, promise
      exe_ctx.resume()
    return chain

  chain.wait = (args...)->
    timeout = null
    if _.isNumber args[0]
      timeout = args.shift()
    chain._internal_fns.push (exe_ctx)->
      p = new Promise (resolve, reject)->
        task_promise = exe_ctx.getMergedPromise args...
        task_promise.then resolve, reject
        if timeout
          _dfn = ()-> reject new Error "timeout"
          setTimeout _dfn, timeout
      _ok = (value)->
        exe_ctx.resume()
      _fail = (err)->
        exe_ctx.error = err
        exe_ctx.resume()
      p.then _ok, _fail
    return chain

  chain.feedback = (fn)->
    chain._internal_fns.push (exe_ctx)->
      fn.call exe_ctx, exe_ctx.feedback, exe_ctx.curArgs.args...
      exe_ctx.resume()
    return chain

  chain.feedbackExeContext = ()->
    chain._internal_fns.push (exe_ctx)->
      exe_ctx.feedback.reset exe_ctx
      exe_ctx.resume()
    return chain


  chain.delay = (ms)->
    chain._internal_fns.push (exe_ctx)->
      _dfn = ()-> exe_ctx.resume()
      setTimeout _dfn, ms
    return chain

  chain.delayIf = (ms, if_fn)->
    chain._internal_fns.push (exe_ctx)->
      yn = if_fn.call exe_ctx, exe_ctx.curArgs.args...
      if yn
        _dfn = ()-> exe_ctx.resume()
        setTimeout _dfn, ms
      else
        exe_ctx.resume()
    return chain

  # chain.reduce = (fn)->
  #   chain._internal_fns.push (exe_ctx)->
  #     fn.call exe_ctx, exe_ctx.curArgs.args..., exe_ctx
  #   return chain

applyInvokeFn = (chain)->
  chain.invoke = (inputs...)->
    _callback = undefined
    if _.isFunction _.last inputs
      _callback = inputs.pop()
      # inputs.push _callback
      # _callback = undefined

    exe_ctx = createExecuteContext chain._internal_fns, _callback
    # _ASAP ()->
    #   # exe_ctx.resume()
    exe_ctx.inputs = inputs
    exe_ctx.next new Args inputs...
    return exe_ctx

  chain.throwIn = (err)->
    exe_ctx = createExecuteContext chain._internal_fns

    exe_ctx.error = err
    # debug 'throwIn', exe_ctx
    # _ASAP ()->
    exe_ctx.resume()
    return exe_ctx

  chain.invokeByEvent = (src_obj, event_name)->
    src_obj.on event_name, (args...)->
      chain.invoke args...
    return chain
  chain.invokeByPromise = (promise)->
    _ok = (value)-> chain.invoke value
    _fail = (err)->
      chain.throwIn err
    promise.then _ok, _fail
    return chain

hyper_chain = ()->
  chain = (inputs...)->
    chain.invoke inputs...

  applyInvokeFn chain
  applyChainBuilder chain
  chain.clear()
  return chain

#
# hyper_chain.reducer = (opt)->
#   reducer_self = (cur, execute_context)->
#     reducer_self.reducedPending()
#
#     reducer_self.pending_context = execute_context
#     reducer_self.acc.push cur
#     if opt.needFlush reducer_self.acc
#       reducer_self.continuePending()
#     else if opt.time_slice and not reducer_self.tid
#       reducer_self.tid = setTimeout reducer_self.continuePending, opt.time_slice
#
#   reducer_self.reducedPending = ()->
#     return unless reducer_self.pending_context
#     reducer_self.pending_context._exit 'reduced'
#     reducer_self.pending_context = null
#
#   reducer_self.continuePending = ()->
#     throw new Error 'pending context not exist' unless reducer_self.pending_context
#
#     reducer_self.tid = clearTimeout reducer_self.tid if reducer_self.tid
#     reduced_data = opt.reduce reducer_self.acc
#     reducer_self.acc = []
#
#
#     unless reduced_data instanceof Args
#       reduced_data = new Args reduced_data
#
#     reducer_self.pending_context.next reduced_data
#     reducer_self.pending_context = null
#
#
#   reducer_self.acc = []
#   return reducer_self

hyper_chain.Args = Args
module.exports = exports = hyper_chain
