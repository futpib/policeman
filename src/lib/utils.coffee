
{
    Cc,
    Ci,
    components
} = require 'chrome'

{ Services } = require 'resource://gre/modules/Services.jsm'


exports.Handlers = class Handlers
  constructor: (@errorHandler=@defaultErrorHandler) ->
    @handlers = []
    @execute = Object.getPrototypeOf(@).execute.bind @
  defaultErrorHandler: (e) ->
    log "Handlers.execute:
            error: #{ e } \n
            file: '#{ e.fileName }' \n
            line: #{ e.lineNumber } \n
            stack: #{ e.stack }"
  add: (handler) ->
    unless handler in @handlers
      @handlers.push handler
  remove: (handler) ->
    @handlers = @handlers.filter (h) -> h isnt handler
  purge: ->
    @handlers = []
  execute: ->
    for h in @handlers
      try
        h(arguments...)
      catch e
        @errorHandler e

# executes handlers in reverse add order
exports.ReverseHandlers = class ReverseHandlers extends Handlers
  add: (handler) ->
    unless handler in @handlers
      @handlers.unshift handler


observerService = Cc["@mozilla.org/observer-service;1"]
        .getService(Ci.nsIObserverService)

exports.Observer = class Observer
  constructor: (@topic, @observe) ->
    @register()
  register: ->
    observerService.addObserver @, @topic, false
  unregister: ->
    observerService.removeObserver @, @topic


exports.cache = cache = ({hash, version, function: f}) ->
  if not hash
    hash = -> JSON.stringify arguments
  if not version
    version = -> '' # just a constant
  versions = Object.create null
  cache_ = new ValueWeakMap
  return (args...) ->
    k = hash args...
    v = version args...
    if cache_.has(k) and versions[k] == v
      return cache_.get(k)
    else
      value = f args...
      versions[k] = v
      cache_.set k, value
      return value


exports.defineLazyProperty = defineLazyProperty = (cls, name, getter) ->
  ###
  Defines a property `name` on `cls::`. Once that property is accesed
  `getter` is called to determine it's value. This value is set on this
  and returned as a result.
  ###
  proto = cls::
  Object.defineProperty proto, name,
    enumerable: yes
    get: ->
      try
        value = getter.call this
      catch e
        console.error 'Getter for property', name, 'of', this, 'threw', e
        value = Object.getPrototypeOf(proto)?[name]
      Object.defineProperty this, name,
        enumerable: yes
        value: value
      return value

exports.forceLazyProperties = forceLazyProperties = (obj) ->
  ###
  Accesses all enumerable properties of `obj`.
  Useful for debugging the `defineLazyProperty` util.
  ###
  continue for n, p of obj


CHILDREN_RESERVED_ATTRIBUTE = '_children_'
EVENT_PREFIX = 'event_'
exports.createElement = createElement = (doc, tag, attrs={}) ->
  el = doc.createElement tag
  for n, v of attrs
    continue if n == CHILDREN_RESERVED_ATTRIBUTE
    if n.startsWith EVENT_PREFIX
      el.addEventListener n.slice(EVENT_PREFIX.length), v
    else
      el.setAttribute n, v
  if CHILDREN_RESERVED_ATTRIBUTE of attrs
    for n, v of attrs[CHILDREN_RESERVED_ATTRIBUTE]
      el.appendChild createElement doc, n.split('_')[0], v
  return el

exports.removeChildren = removeChildren = (node, selector='*') ->
  for descendant in node.querySelectorAll selector
    if descendant.parentNode == node
      node.removeChild descendant

exports.removeNode = removeNode = (node) ->
  node.parentNode.removeChild node

exports.mutateAttribute = mutateAttribute = (node, attr, f) ->
  node.setAttribute attr, f(node.getAttribute attr)

exports.isDead = isDead = (node) ->
  try
    node.nodeName
  catch e
    if e instanceof TypeError
      return true
  return false

exports.loadSheet = (win, styleURI, type=Ci.nsIDOMWindowUtils.AUTHOR_SHEET) ->
  styleURI = newURI styleURI if 'string' == typeof styleURI
  win.QueryInterface(Ci.nsIInterfaceRequestor)
      .getInterface(Ci.nsIDOMWindowUtils)
      .loadSheet(styleURI, type)

exports.removeSheet = (win, styleURI, type=Ci.nsIDOMWindowUtils.AUTHOR_SHEET) ->
  styleURI = newURI styleURI if 'string' == typeof styleURI
  win.QueryInterface(Ci.nsIInterfaceRequestor)
      .getInterface(Ci.nsIDOMWindowUtils)
      .removeSheet(styleURI, type)


exports.newURI = newURI = (spec, originCharset=null, baseURI=null) ->
  return Services.io.newURI spec, originCharset, baseURI


exports.XMLHttpRequest = XMLHttpRequest = require 'sdk/net/xhr'


exports.zip = zip = (arrs...) ->
  shortest = arrs.reduce((a,b) -> if a.length < b.length then a else b)
  return shortest.map((_,i) -> arrs.map((array) -> array[i]))

exports.remove = remove = (array, value, limit=1) ->
  while ((limit is off) or (limit > 0)) and ((i = array.indexOf value) != -1)
    array.splice i, 1
    limit -= 1 unless limit is off
  return undefined

exports.move = move = (array, value, newIx=Infinity) ->
  currentIx = array.indexOf value
  return if (currentIx < 0) or (newIx == currentIx)
  array.splice currentIx, 1
  if newIx < currentIx
    array.splice newIx, 0, value
  else if newIx > currentIx
    array.splice newIx - 1, 0, value
  return undefined

exports.tails = tails = (arr, minLength=1) ->
  minLength = Math.min arr.length, Math.max 0, minLength
  arr = arr.slice()
  ts = []
  loop
    ts.push arr.slice()
    break if arr.length <= minLength
    arr.shift()
  return ts

split = (str, delim) -> if str.length then str.split delim else []
exports.superdomains = superdomains = (domain, minLevel=0) ->
  tails(split(domain, '.'), minLevel).map((x) -> x.join '.')

exports.isSuperdomain = isSuperdomain = (super_, sub) ->
  (not super_) or (sub == super_) or sub.endsWith('.' + super_)


exports.reverseLookup = reverseLookup = (o, v) ->
  for k, v_ of o
    return k if v_ is v
  return undefined


exports.runAsync = runAsync = (f) ->
  Services.tm.currentThread.dispatch f, Ci.nsIEventTarget.DISPATCH_NORMAL


exports.time = time = do ->
  stack = []
  peek = -> stack[stack.length-1]
  push = (e) -> stack.push e
  pop = -> stack.pop()

  time_ = (note, f) -> ->
    start = (new Date).getTime()
    push {
      note
      start
      last: start
    }
    result = f.apply this, arguments
    end = (new Date).getTime()
    runAsync -> log 'time', note, \
                    'call to', f, \
                    'on this = ', this, 'and arguments = ', arguments, \
                    'took', end - start, 'ms of real time'
    return result

  time_.checkpoint = (note) ->
    frame = peek()
    { start, last } = frame
    reached = (new Date).getTime()
    runAsync -> log 'time', 'checkpoint', note, \
                    'reached in', reached - start, \
                    'time from last checkpoint:', reached - last
    frame.last = reached

  return time_


exports.WeakSet = WeakSet
if not WeakSet # Firefox < 34
  exports.WeakSet = WeakSet = class WeakSet
    constructor: (iterable) ->
      @_map = new WeakMap # Firefox >= 20
      @add x for x in iterable if iterable
    length: 1
    add: (value) -> @_map.set value, true
    clear: -> @_map.clear()
    delete: (value) -> @_map.delete value
    has: (value) -> @_map.has value

exports.ValueWeakMap = class ValueWeakMap
  ###
  A map where values are transparently wrapped using Cu.getWeakReference.
  Use with object-values only.
  ###
  constructor: (array) ->
    @_map = new Map
    @set k, v for [k, v] in array if array
  length: 1
  set: (k, v) -> @_map.set k, Cu.getWeakReference v
  get: (k) ->
    v = @_map.get(k)?.get()
    @delete k if not v # save some memory
    return v
  has: (k) -> !! @get k
  delete: (k) -> @_map.delete k


criptoHash = Cc["@mozilla.org/security/hash;1"]
        .createInstance Ci.nsICryptoHash

unicodeConverter = Cc["@mozilla.org/intl/scriptableunicodeconverter"]
        .createInstance Ci.nsIScriptableUnicodeConverter
unicodeConverter.charset = "UTF-8"

byteToHexStr = (byte) -> ('0' + byte.toString 16).slice -2

exports.md5 = md5 = (str, options={}) ->
  ###
  Compute md5 hash of `str`
  options:
    format     'b64', 'hex' or 'bytes' — format of returned value, default: hex
  ###
  {
    format
  } = options
  format ?= 'hex'

  data = unicodeConverter.convertToByteArray str, {}
  criptoHash.init criptoHash.MD5
  criptoHash.update data, data.length

  switch format
    when 'b64'
      return criptoHash.finish true
    when 'bytes'
      return criptoHash.finish false
    when 'hex'
      hash = criptoHash.finish false
      return ((byteToHexStr hash.charCodeAt i) for _, i in hash).join ''


exports.versionComparator = versionComparator =
  cmp: Services.vc.compare.bind Services.vc
  eq:  -> 0 == @cmp arguments...
  gt:  -> 0 <  @cmp arguments...
  lt:  -> 0 >  @cmp arguments...
  gte: -> 0 <= @cmp arguments...
  lte: -> 0 >= @cmp arguments...
