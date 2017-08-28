debug =  require('debug')('ficent')




hyper_chain = ()->


  internal_fns = []
  chain = (inputs..., _callback)->

    execute_context =
      input: inputs
      feedback: {} # callback으로 돌아가는 값
      cur: inputs # 처리중인 현재 값
      step_inx: 0 
      next: (data)->
        execute_context.cur = data 
        execute_context.step_inx++ 
        _fn = internal_fns[execute_context.step_inx]
        _fn(execute_context)

      callback: (err)->
        if _callback
          [cb, _callback] = [_callback, null]
          exe_cxt = execute_context 
          cb err, exe_cxt.feedback, exe_cxt


    return execute_context

  chain.do = (fn)->
    internal_fns.push (execute_context)->
      fn execute_context.cur 
      execute_context.next execute_context.cur
    return chain

  chain.map = (fn)->
    internal_fns.push (execute_context)->
      new_cur = fn execute_context.cur 
      execute_context.next new_cur
    return chain



  return chain




module.exports = exports = hyper_chain


