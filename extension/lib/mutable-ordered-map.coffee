
###
Map implementation with interface similar to Map from ECMAScript 6 proposal
but with some array-ish methods and slow O(n) lookups

https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Map
###

exports.MutableOrderedMap = class MutableOrderedMap
  constructor: (iterable=[]) ->
    @ks = []; @vs = []
    for k, v in iterable
      @ks.push k; @vs.push v

  # Map interface

  Object.defineProperty @prototype, 'size', get: -> @ks.length

  clear: ->
    @ks = []; @vs = []

  delete: (k) ->
    i = @ks.indexOf k
    if i == -1
      return false
    @ks.splice i, 1; @vs.splice i, 1
    return true

  forEach: (callback, this_) ->
    for i in [0...@ks.length]
      callback.call this_, @vs[i], @ks[i], this
    return

  get: (k) ->
    i = @ks.indexOf k
    if i != -1 then return @vs[i]

  set: (k, v) ->
    i = @ks.indexOf k
    if i == -1
      @ks.push k; @vs.push v
    else
      @vs[i] = v

  has: (k) -> (@ks.indexOf k) != -1

  # helpers
  iteratorMap = (f, iter) -> next: -> do (next = iter.next()) ->
    if next.done \
        then next \
        else value: f(next.value), done: false

  zip = (arrays...) -> arrays[0].map (_,i) -> arrays.map (a) -> a[i]

  fst = ([a, b]) -> a
  snd = ([a, b]) -> b
  #

  entries: ->
    i = 0
    return next: -> if i < @ks.length \
        then value: [@ks[i], @vs[i]], done: false \
        else done: true

  keys: -> iteratorMap fst, @entries
  values: -> iteratorMap snd, @entries

  # Array-ish interface

  indexOf: (k, fromIx) -> @ks.indexOf arguments...
  lastIndexOf: (k, fromIx) -> @ks.lastIndexOf arguments...

  pop: -> if @size > 0 then [@ks.pop(), @vs.pop()]
  push: (pairs...) ->
    @ks.push (pairs.map fst)...
    @vs.push (pairs.map snd)...

  shift: -> if @size > 0 then [@ks.shift(), @vs.shift()]
  unshift: (pairs...) ->
    @ks.unshift (pairs.map fst)...
    @vs.unshift (pairs.map snd)...

  splice: (i, count, replacements...) ->
    removedKeys = @ks.splice i, count, (replacements.map fst)...
    removedValues = @vs.splice i, count, (replacements.map snd)...
    return zip removedKeys, removedValues



