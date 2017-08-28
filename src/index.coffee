debug =  require('debug')('hc')



ASAP = (fn)-> process.nextTick fn



hyper_chain = ()->


  internal_fns = []
  chain = (input, _callback)->

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
      next: (data)->
        exe_ctx.cur = data 
        exe_ctx.resume()
      resume: ()->
        try
          exe_ctx.step_inx++ 

          # 체인의 끝이면, 종료
          if exe_ctx.step_inx >= internal_fns.length
            exe_ctx.exit_status = 'finished'
            debug 'resume -> exit with no error'
            return exe_ctx.exit()


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
        

      exit: ()->
        ASAP ()-> 
          # 만약 외부 콜백에 문제가 있더라도 내부 프로세스를 타면 안됨 
          return unless _callback
          [cb, _callback] = [_callback, null]
          cb exe_ctx.error, exe_ctx.feedback, exe_ctx


    ASAP ()->
      exe_ctx.resume()

    return exe_ctx

  chain.do = (fn)->
    internal_fns.push (exe_ctx)->
      fn exe_ctx.cur 
      exe_ctx.resume()
    return chain

  chain.map = (fn)->
    internal_fns.push (exe_ctx)->
      # debug '.map', exe_ctx
      new_cur = fn exe_ctx.cur 
      exe_ctx.next new_cur
    return chain

  chain.filter = (fn)->
    internal_fns.push (exe_ctx)->
      can_continue = fn exe_ctx.cur 
      if can_continue
        exe_ctx.resume()
      else 
        exe_ctx.exit_status = 'filtered'
        exe_ctx.exit()
    return chain

  chain.catch = (fn)-> 
    _catcher = (exe_ctx)-> 
      fn exe_ctx.err, exe_ctx.cur 
      exe_ctx.error = null
      exe_ctx.resume() 
    _catcher.accept_error = true
    internal_fns.push _catcher
    return chain


  chain.finally = (fn)-> 
    _catcher = (exe_ctx)-> 
      fn exe_ctx.err, exe_ctx.cur 
      # exe_ctx.error = null
      exe_ctx.resume() 
    _catcher.accept_error = true
    internal_fns.push _catcher
    return chain




  return chain




module.exports = exports = hyper_chain


