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

      _ok = (value)->
        exe_ctx.remember name, value
        exe_ctx.resume()
      _fail = (err)->
        exe_ctx.error = err 
        exe_ctx.resume() 
      p.then _ok, _fail
    return chain

 



  return chain




module.exports = exports = hyper_chain


