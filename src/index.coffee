debug =  require('debug')('hc')

_ = require 'lodash'

ASAP = (fn)-> process.nextTick fn


createExecuteContext = (internal_fns, _callback)-> 
  _KV_ = {}
  return exe_ctx =
    error: null
    feedback: {} # callback으로 돌아가는 값
    step_inx: -1
    exit_status: undefined
      # undefined: 아직 안끝남
      # error - 에러가 발생
      # filtered - filter 되어 끝남
      # reduced - reduce 되어 끝남
      # finished - 모든 연산 끝남

    promises: 
      all: []
      # user defined name: []
      # user defined group: []

    next: (data)->
      exe_ctx.cur = data 
      exe_ctx.resume()
 
    resume: ()-> 
      # internal_fns를 꺼내서 수행하는 유일한 주체다. 
      # 절대 병렬 호출이 되서는 안됨 
      try
        #다음 스탭으로
        exe_ctx.step_inx++  

        # 체인의 끝이면, 종료
        if exe_ctx.step_inx >= internal_fns.length
          debug 'resume -> exit with no error'
          return exe_ctx.exit 'finished'


        _fn = internal_fns[exe_ctx.step_inx]
        # 에러가 있으면, 에러 수용체가 아니면 패스
        if exe_ctx.error? 
          if _fn.accept_error isnt true 
            debug 'resume -> skip ', exe_ctx.step_inx, 'because not ErrorHandler'
            return exe_ctx.resume()

        debug 'resume -> call', exe_ctx.step_inx
        _fn(exe_ctx)
      catch err          
        exe_ctx.error = err
        debug 'resume -> catch error', exe_ctx.step_inx, err.toString()
        exe_ctx.resume()
      

    exit: (exit_status)->
      exe_ctx.exit_status = exit_status
      exe_ctx.exit_status = 'error' if exe_ctx.error
      ASAP ()-> 
        # 만약 외부 콜백에 문제가 있더라도 내부 프로세스를 타면 안됨 
        return unless _callback
        [cb, _callback] = [_callback, null]
        cb exe_ctx.error, exe_ctx.feedback, exe_ctx
      
    recall: (name)->
      return _KV_ unless name
      return _KV_[name]
    remember: (name, value)->
      _KV_[name] = value
    createAsyncPoint :(name_at_group)-> 
      _resolve = _reject = null
      p = new Promise (resolve, reject)->
        [_resolve, _reject] = [resolve, reject]   
      exe_ctx.trackingPromise name_at_group, p

      _done = (err, args...)->
        debug '_done', err, args...
        return _reject err if err  
        _resolve args
      return _done 
    getMergedPromise : (labels...)->
      Promise.all _.uniq _.flatten _.map labels, (lb)->
        return exe_ctx.promises[lb]

    trackingPromise: (name_at_group, promise)->
      [name, group] =_.split name_at_group, '@'
      if _.isEmpty name
        throw new Error 'name of .async() is required'  
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



applyChainExtender = (chain, internal_fns)-> 
  chain.do = (fn)->
    internal_fns.push (exe_ctx)->
      fn.call exe_ctx, exe_ctx.cur 
      exe_ctx.resume()
    return chain

  chain.map = (fn)->
    internal_fns.push (exe_ctx)->
      # debug '.map', exe_ctx
      new_cur = fn.call exe_ctx, exe_ctx.cur 
      exe_ctx.next new_cur
    return chain

  chain.filter = (fn)->
    internal_fns.push (exe_ctx)->
      can_continue = fn.call exe_ctx, exe_ctx.cur 
      if can_continue
        exe_ctx.resume()
      else  
        exe_ctx.exit 'filtered'
    return chain

  chain.catch = (fn)-> 
    _catcher = (exe_ctx)-> 
      fn.call exe_ctx, exe_ctx.err, exe_ctx.cur 
      exe_ctx.error = null
      exe_ctx.resume() 
    _catcher.accept_error = true
    internal_fns.push _catcher
    return chain 

  chain.finally = (fn)-> 
    _catcher = (exe_ctx)-> 
      fn.call exe_ctx, exe_ctx.err, exe_ctx.cur 
      # exe_ctx.error = null
      exe_ctx.resume() 
    _catcher.accept_error = true
    internal_fns.push _catcher
    return chain
 
  chain.async = (name_at_group, fn)->  
    internal_fns.push (exe_ctx)->
      a_done = exe_ctx.createAsyncPoint name_at_group
      fn.call exe_ctx, exe_ctx.cur, a_done
      exe_ctx.resume() 
    return chain
    
  chain.makePromise = (name_at_group, fn)->  
    internal_fns.push (exe_ctx)-> 
      promise = fn.call exe_ctx, exe_ctx.cur
      exe_ctx.trackingPromise name_at_group, promise
      exe_ctx.resume() 
    return chain

  chain.wait = (args...)->
    timeout = null
    if _.isNumber args[0]
      timeout = args.shift()  
    internal_fns.push (exe_ctx)->    
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
    internal_fns.push (exe_ctx)->
      fn.call exe_ctx, exe_ctx.cur, exe_ctx.feedback, exe_ctx
      exe_ctx.resume()
    return chain
      
  chain.delay = (ms)->
    internal_fns.push (exe_ctx)->
      _dfn = ()-> exe_ctx.resume()
      setTimeout _dfn, ms
    return chain

  chain.delayIf = (ms, if_fn)->
    internal_fns.push (exe_ctx)->
      yn = if_fn.call exe_ctx, exe_ctx.cur
      if yn 
        _dfn = ()-> exe_ctx.resume()
        setTimeout _dfn, ms
      else 
        exe_ctx.resume() 
    return chain

  chain.reduce = (fn)-> 
    internal_fns.push (exe_ctx)->
      fn.call exe_ctx, exe_ctx.cur, exe_ctx 
    return chain


hyper_chain = ()-> 
  internal_fns = []
  chain = (input, _callback)->
    exe_ctx = createExecuteContext internal_fns, _callback
    ASAP ()->
      # exe_ctx.resume()
      exe_ctx.input = input
      exe_ctx.next input
    return exe_ctx

  applyChainExtender chain, internal_fns 
  return chain


hyper_chain.reducer = (opt)->
  reducer_self = (cur, execute_context)-> 
    reducer_self.reducedPending() 

    reducer_self.pending_context = execute_context
    reducer_self.acc.push cur
    if opt.needFlush reducer_self.acc
      reducer_self.continuePending()
    else unless reducer_self.tid
      reducer_self.tid = setTimeout reducer_self.continuePending, opt.time_slice

  reducer_self.reducedPending = ()->
    return unless reducer_self.pending_context
    reducer_self.pending_context.exit 'reduced' 
    reducer_self.pending_context = null

  reducer_self.continuePending = ()->
    throw new Error 'pending context not exist' unless reducer_self.pending_context

    reducer_self.tid = clearTimeout reducer_self.tid
    reduced_data = opt.reduce reducer_self.acc
    reducer_self.acc = []

    reducer_self.pending_context.next reduced_data
    reducer_self.pending_context = null


  reducer_self.acc = []
  return reducer_self


module.exports = exports = hyper_chain


