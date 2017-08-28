debug =  require('debug')('hc')



ASAP = (fn)-> process.nextTick fn



hyper_chain = ()->


  internal_fns = []
  chain = (input, _callback)->

    _KV_ = {}
    exe_ctx =
      input: input
      error: null
      feedback: {} # callback으로 돌아가는 값
      cur: input # 처리중인 현재 값
      step_inx: -1
      exit_status: undefined
        # undefined: 아직 안끝남
        # error - 에러가 발생
        # filtered - filter 되어 끝남
        # reduced - reduce 되어 끝남
        # finished - 모든 연산 끝남
 
      promises: {}
      next: (data)->
        exe_ctx.cur = data 
        exe_ctx.resume()

      # interrupt: ()-> 
      #   # 처리를 계속하는 측면에서 resume과 같으나, 
      #   # 기존의 처리하던 루틴을 무시해야한다.
      #   # 일단 모두 동기라서 단순 에러 넣기로도 충분한데,
      #   # wait만 특별처리 할까?
      resume: ()->
        ###
          internal_fns를 꺼내서 수행하는 유일한 주체다.
          따라서, 다수의 resume이 생길때 여기서 거부하면 된다.
        ###
        try
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
        return _KV_
        # return _KV_[name]
      remember: (name, value)->
        _KV_[name] = value
      createAsyncPoint :(name)->
        _resolve = _reject = null
        p = new Promise (resolve, reject)->
          [_resolve, _reject] = [resolve, reject]
          # @_setResolve = (v)-> resolve v
          # @_setResolve = (v)-> reject v 
          # debug 'inPromise', @_setReject, @_setResolve

        debug 'createAsyncPoint', _resolve, _reject
        exe_ctx.promises[name] = p
        _done = (err, args...)->
          debug '_done', err, args...
          return _reject err if err 
          _resolve args
        return _done


      # clearTimeout: ()->
      #   clearTimeout exe_ctx.tid_of_timeout
      #   exe_ctx.tid_of_timeout = undefined
      # setTimeout: (ms)->
      #   _dfn = ()->
      #     exe_ctx.error = new Error 'Timeout'
      #     ###
      #       여기서 바로 resume하여 Error를 진행하는게맞겠다.
      #       다만 기존의 처리 루틴은 어떻게 중지 시킬까?
      #       2 줄기로 실행되면 안되니, 기존것을 중지시켜야한다.
      #       1. 기존것을 대기후 진행. 
      #       2. 기존것의 반환을 어떻게든 무시?

      #       !! 기본적으로 흐름은 동기다
      #       async도 동기처리후 반환이고 별개의처리가 되어서 done-wait가 짝이되어 수신한다.
      #       따지자면, wait말고는 비동기, 작업에 대한 interrupt를 생각하지 않아도 될듯하다.
      #       하지만 interrupt가 명확해야할 필요성도 있어보인다. 
      #     ###
      #     exe_ctx.interrupt()
      #   exe_ctx.tid_of_timeout = setTimeout _dfn, ms

    ASAP ()->
      exe_ctx.resume()

    return exe_ctx

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
 
  chain.async = (name_group, fn)-> 
    internal_fns.push (exe_ctx)->
      a_done = exe_ctx.createAsyncPoint name_group
      fn.call exe_ctx, exe_ctx.cur, a_done
      exe_ctx.resume() 
    return chain

  chain.wait = (name)->
    internal_fns.push (exe_ctx)->
      p = exe_ctx.promises[name]
      p.then (value)->
        exe_ctx.remember name, value
        exe_ctx.resume()
      p.catch (err)->
        exe_ctx.remember name, [err]
        exe_ctx.resume()

    return chain


  
  # chain.clearTimeout = ()->
  #   internal_fns.push (exe_ctx)->
  #     exe_ctx.clearTimeout()
  #     exe_ctx.resume()

  # chain.timeout = (limited_duration)-> 
  #   internal_fns.push (exe_ctx)->
  #     exe_ctx.setTimeout limited_duration
  #     exe_ctx.resume()
  #   return chain





  return chain




module.exports = exports = hyper_chain


