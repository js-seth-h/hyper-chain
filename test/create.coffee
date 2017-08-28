hc = require '../src'
chai = require 'chai'
expect = chai.expect
debug = require('debug')('test')

feature = describe
scenario = it

###
Features와, 테스트 시나리오

  함수일것 = 호출이 가능할것. 
  값제어 .do, .map
  처리 제어.filter .reduce
  비동기 .async, .wait .makePromise
  시간제어 .delay .timeout
  에러 제어 .catch .finally
  반환 제어 .feedback




###
describe 'chain is a function', ()->
  it 'return a function', ()->
    ###
    Given 
    When - 체인을 생성하면
    Then - 함수이다.
    ###
    chain = hc()
    expect(chain).a 'function'



describe 'change data in process', ()-> 
  it '.do not change current data', ()->
    ###
    Given 
    When - .do에서 반환을 한다
    Then - cur를 변경하지 않느다
    ###
    chain = hc()
      .do (cur)->
        return 1
      .do (cur)->
        expect(cur).to.be.equal 2 
    chain(2)







  it '.map change current data', ()->
    ###
    Given 
    When - .map이 반환을 한다 
    Then - cur가 변경된다
    ###
    chain = hc()
      .map (cur)->
        return 1
      .do (cur)->
        expect(cur).to.be.equal 1
         
    chain(2)



















