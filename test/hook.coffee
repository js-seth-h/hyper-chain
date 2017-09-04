hook = require '../src/hook'
hc = require '../src/chain'

chai = require 'chai'
expect = chai.expect
debug = require('debug')('test')

feature = describe
scenario = it

describe 'hook.of', ()->
  it 'when hook.of, then should call setCallback', ()->
    chain = hc()
    ObjHasCallback =
      setCallback : (fn)->
        ObjHasCallback.callback = fn
    h = hook.of ObjHasCallback
    h.on chain
    expect(ObjHasCallback.callback).to.be.exist


  it 'when hook.of & .off(), then should call setCallback with Nil', ()->
    chain = hc()
    ObjHasCallback =
      setCallback : (fn)->
        ObjHasCallback.callback = fn
    h = hook.of ObjHasCallback
    h.on chain
    expect(ObjHasCallback.callback).to.be.exist
    h.off()
    expect(ObjHasCallback.callback).not.to.be.exist


  it 'when hook.of & trigger callback. then chain get args of callback', ()->
    chain = hc()
    ObjHasCallback =
      setCallback : (fn)->
        ObjHasCallback.callback = fn
    h = hook.of ObjHasCallback
    h.on chain
    expect(ObjHasCallback.callback).to.be.exist

    chain.do (cur)->
      expect(cur).to.eql 5
    ObjHasCallback.callback 5

describe 'hook.event', ()->
  EventEmitter  = require 'events'
  it 'when hook.event. then Emitter has listner', ()->
    chain = hc()
    emiter = new EventEmitter
    h = hook.event emiter, 'fire'
    h.on chain
    expect(emiter.listenerCount 'fire').to.be.eql 1



  it 'when hook.event & .off. then Emitter has no listner', ()->
    chain = hc()
    emiter = new EventEmitter
    h = hook.event emiter, 'fire'
    h.on chain
    expect(emiter.listenerCount 'fire').to.be.eql 1
    h.off()
    expect(emiter.listenerCount 'fire').to.be.eql 0


  it 'when hook.event & trigger. then chain get args of event', ()->
    chain = hc()
    emiter = new EventEmitter
    h = hook.event emiter, 'fire'
    h.on chain
    expect(emiter.listenerCount 'fire').to.be.eql 1
    chain.do (cur)->
      expect(cur).to.eql 5
    emiter.emit 'fire', 10




describe 'hook.promise', ()->

  it 'when hook.promise & resolve. then chain get args of event', (done)->

    _resolve = null
    p = new Promise (resolve, reject)->
      _resolve = resolve
    chain = hc()
    h = hook.promise p
    h.on chain
    chain.do (cur)->
      expect(cur).to.eql 5
      done()
    _resolve 5


  it 'when hook.promise & reject. then chain not called', (done)->

    _reject = null
    p = new Promise (resolve, reject)->
      _reject = reject
    chain = hc()
    chain.catch (err, cur)->
      # debug 'err, cur', err, cur
      expect(err).to.be.exist
      done()

    h = hook.promise p
    h.on chain
    _reject new Error 'JUST'



describe 'hook.pull', ()->
  it 'when hook.pull & change. then chain get args', (done)->

    obj = value: 5
    h = hook.pull obj, 'value', 10
    expect(h.tid).to.be.not.exist
    chain = hc()
    h.on chain
    expect(h.tid).to.be.exist
    chain.do (cur)->
      expect(cur).to.eql 9
      done()
    obj.value = 9

  it 'when hook.pull & .off. then remove timer ', (done)->
    obj = value: 5
    h = hook.pull obj, 'value', 10
    chain = hc()
    h.on chain
    h.off()
    expect(h.tid).to.be.not.exist
    done()
