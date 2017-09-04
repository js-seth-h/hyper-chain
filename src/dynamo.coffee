


###
제 1 목적은 능동성을 확보하는것.

Dynamo 는 EventEmitter, Promise와 같은 선상에 있는 능동체이다

  addChain
  removeChain
###
class Dynamo
  constructor: (opt) -> 

  addHook: (@hook)->

  removeHook: ()-> @hook = null
  fireHook: (data, callback)->
    @hook data, callback if @hook
  # start: ()->

 
Dynamo.parallel = (data...)->

  d = new Dynamo() 
  d.data = data 
  d.feedbacks = _.map data, (d)-> undefined
  d.errors = _.map data, (d)-> undefined

  d.start = (callback)->
    chain = hc()
    _.forEach data, (datum, inx)->
      chain.async inx, (cur, done)->
        d.fireHook datum, (err, feedback)->
          d.feedbacks[inx] = feedback
          d.errors[inx] = err
          done()            
    chain.wait()
    chain {}, callback 
  return d
Dynamo.serial = (data...)->
  d = new Dynamo() 
  d.data = data  
  d.feedbacks = _.map data, (d)-> undefined
  d.errors = _.map data, (d)-> undefined

  d.start = (callback)-> 
    chain = hc()
    _.forEach data, (datum, inx)->
      chain.async inx, (cur, done)->
        d.fireHook datum, (err, feedback)->
          d.feedbacks[inx] = feedback
          d.errors[inx] = err
          done()
      chain.wait()
    chain {}, callback




  return d

module.exports = exports = Dynamo