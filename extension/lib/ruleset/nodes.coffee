
{ OriginInfo, DestInfo } = require 'request-info'

exports.L10nLookup = class L10nLookup
  constructor: (@key) ->

exports.Test = class Test
  constructor: -> throw new Error 'Not to be instantiated directly'

  eq: (other) ->
    return false unless other instanceof @::
    return @_eqSameClass

exports.ConstantTest = class ConstantTest extends Test # for testing mostly
  constructor: (@value) ->
  _eqSameClass: (other) -> @value == other.value
  test: -> @value

  # parser won't handle this, nor is it supposed to construct ConstantTest
  stringify: -> "#<#{ @constructor.name }(#{ @value })>"

exports.ConstantTrueTest = class ConstantTrueTest extends Test
  constructor: () ->
  _eqSameClass: -> true
  test: (testee) -> [testee]

  stringify: -> '*'

exports.InTest = class InTest extends Test
  constructor: (@str) ->
  _eqSameClass: (other) -> @str == other.str
  test: (testee) -> @str of testee

  stringify: -> JSON.stringify @str

###
|Predicate| below is intended to support backreferences
in one of it's halfs (called 'tests' here)
e.g. to enable destination half to refer to some part of origin.
This implementation resembles String.replace backrefs:
https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replace#Specifying_a_string_as_a_parameter

One of tests in a predicate may have test._hasBackref == true,
in that case another test will be tried first and should return
array of values to be substituted into the first test.
###

backrefRe = ///
  (^|[^\$])     # start of string or anything but $
  (\$\$)*       # zero or even number of $
  \$([\$\&]|[1-9][0-9]*) # backreference like those supported by str.replace
///g            # lacks ['`] support, groups can be used instead

exports.BackrefTest = class BackrefTest extends Test
  constructor: (args...) ->
    @_hasBackref = @_checkForBackrefs args...
  _checkForBackrefs: (str) ->
    backrefRe.test str
  test: (testee, backrefsValues) ->
    if @_hasBackref and backrefsValues
      return @testWithBackrefs testee, backrefsValues
    else
      return @testWithoutBackrefs testee

exports.IntTest = class IntTest extends BackrefTest
  constructor: (@int) -> super @int
  _eqSameClass: (other) -> @int == other.int
  # seems like the only backref that makes sense
  _checkForBackrefs: (i) -> i == '$&'
  testWithoutBackrefs: (testee) ->
    return if testee == @int then [@int] else false
  testWithBackrefs: (testee, backrefsValues) ->
    return backrefsValues[0] == testee

  stringify: -> @int.toString()

substituteBackrefs = (str, backrefsValues) ->
  str.replace backrefRe, (_, start, evenBucks, ref) ->
    bucks = evenBucks.slice(evenBucks.length / 2)
    if ref == '$'
      return start + bucks + '$'
    else if ref == '&'
      ref = 0
    else
      ref = parseInt ref
    return start + bucks + backrefsValues[ref]

exports.EqTest = class EqTest extends BackrefTest
  constructor: (@str) -> super @str
  _eqSameClass: (other) -> @str == other.str
  testWithoutBackrefs: (testee) -> if testee == @str then [@str] else false
  testWithBackrefs: (testee, backrefsValues) ->
    str = substituteBackrefs @str, backrefsValues
    return testee == str

  stringify: -> JSON.stringify @str

escapeRegExp = (str) -> str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

exports.RegExpTest = class RegExpTest extends BackrefTest
  constructor: (@re) -> super @re.source
  _eqSameClass: (other) -> @re.source == other.re.source
  testWithoutBackrefs: (testee) -> @re.exec testee
  testWithBackrefs: (testee, backrefsValues) ->
    newReSrc = escapeRegExp(substituteBackrefs(@re.source, backrefsValues))
    return (new RegExp newReSrc).test testee

  stringify: -> @re.toString()

exports.StartsEndsTest = class StartsEndsTest extends BackrefTest
  constructor: (@start = '', @end = '') -> super
  _eqSameClass: (other) -> @start == other.start and @end == other.end
  _checkForBackrefs: (s, e) -> (backrefRe.test s) or (backrefRe.test e)
  testWithBackrefs: (testee, backrefsValues) ->
    start = substituteBackrefs @start, backrefsValues
    end = substituteBackrefs @end, backrefsValues
    return (testee.startsWith start) and (testee.endsWith end)
  testWithoutBackrefs: (testee) ->
    unless startMatches = testee.startsWith @start
      return false
    unless endMatches = testee.endsWith @end
      return false
    return [
      # whole matched string
      testee,
      # part of matched string between @start and @end
      testee.slice(
        if startMatches then @start.length else 0,
        if endMatches then -@end.length
      )
    ]

  stringify: -> "#{if @start then JSON.stringify start else ''}
              *
              #{if @end then JSON.stringify @end else ''}"

exports.ContainsTest = class ContainsTest extends BackrefTest
  constructor: (@substr) -> super
  _eqSameClass: (other) -> @substr == other.substr
  testWithBackrefs: (testee, backrefsValues) ->
    substr = substituteBackrefs @substr, backrefsValues
    return testee.indexOf(substr) != -1
  testWithoutBackrefs: (testee) ->
    i = testee.indexOf @substr
    if i == -1
      return false
    return [
      # whole matched string
      testee,
      # part before @substr
      testee.slice(0, i),
      # part after @substr
      testee.slice(i + @substr.length),
    ]

  stringify: -> "#{if @start then JSON.stringify start else ''}
              *
              #{if @end then JSON.stringify @end else ''}"

exports.NegateTest = class NegateTest extends BackrefTest
  constructor: (@subtest) -> super
  _eqSameClass: (other) -> @subtest.eq other.subtest
  _checkForBackrefs: -> @subtest._hasBackref
  test: -> not @subtest.test arguments...

  stringify: -> "!#{ @subtest.stringify() }"

exports.OrTest = class OrTest extends BackrefTest
  constructor: (@subtests) -> super
  _eqSameClass: (other) ->
    ts = @subtests.slice() # TODO rewrite without copying (slicing)
    ots = other.subtests.slice()
    while t = ts.pop()
      i = ots.indexOf t
      return false if i == -1
      ots.splice i, 1
    return not ots.length
  _checkForBackrefs: -> @subtests.some (t) -> t._hasBackref
  testWithBackrefs: (testee, backrefsValues) ->
    return @subtests.some (t) -> t.test testee, backrefsValues
  testWithoutBackrefs: (testee) ->
    for t in @subtests
      r = t.test testee
      if r
        return r
    return false

  stringify: -> '(' + (@subtests.map (t) -> t.stringify()).join('|') + ')'


exports.OrigDestPredicate = class OrigDestPredicate
  constructor: (@component, @originTest, @destTest) ->

  eq: (other) ->
    return false unless other instanceof OrigDestPredicate
    return  (@component == other.component) and
            (@originTest.eq other.originTest) and
            (@destTest.eq other.destTest)

  test: (origin, dest, ctx) ->
    if @originTest._hasBackref
      destMatches = @destTest.test dest[@component]
      if destMatches
        return @originTest.test origin[@component], destMatches
    originMatches = @originTest.test origin[@component]
    if originMatches
      return @destTest.test dest[@component], originMatches
    return false

  stringify: -> "[#{ @component }]
                  #{ @originTest.stringify() }
                  ->
                  #{ @destTest.stringify() }"


exports.ContextPredicate = class ContextPredicate
  constructor: (@component, @test_) ->

  eq: (other) ->
    return false unless other instanceof SingleTestPredicate
    return  (@component == other.component) and
            (@test_.eq other.originTest)

  test: (origin, dest, ctx) -> @test_.test ctx[@component]

  stringify: -> "[#{ @component }]
                  #{ @test_.stringify() }"

#
# Few helpers to save keystrokes
#

# Converts object to an instance of Test
# (string to EqTest, regexp to RegExpTest, etc.)
exports.coerceToTest = coerceToTest = (o) ->
  if o instanceof Test
    return o
  if o == true
    return new ConstantTrueTest
  if typeof o == 'string'
    return new EqTest o
  if typeof o == 'number' and o % 1 == 0
    return new IntTest o
  if o instanceof RegExp
    return new RegExpTest o
  if o instanceof Array and o.length == 2
    [s, e] = o
    return new StartsEndsTest s, e
  if 'or' of o
    return new OrTest o.or.map coerceToTest
  throw new Error "Can't coerce #{o} to instance of Test"

# Constructs nested map from a specially structured array
exports.parseRulesArr = parseRulesArr = (arrs, mapConstructor=Map) ->
# Expects nested array representing rules
# * First element is treated as component to match on (scheme, host, etc.)
# * Second — origin test (instance of Test or something coerceToTest accepts)
# * Third — destination test
# * Fourth and later — consequents in same format or
#   boolean representing decision (true for accept, false for reject)
  map = new mapConstructor
  for arr in arrs
    [comp, origin, dest, consequents...] = arr
    pred = new Predicate comp, (coerceToTest origin), (coerceToTest dest)
    if consequents.length = 1 and typeof consequents[0] == 'boolean'
      map.set pred, consequents[0]
    else
      map.set pred, parseRulesArr consequents
  return map


