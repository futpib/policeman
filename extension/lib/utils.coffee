
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


CHILDREN_RESERVED_ATTRIBUTE = '_'
exports.createElement = createElement = (doc, tag, attrs={}) ->
  el = doc.createElement tag
  for n, v of attrs
    continue if n == CHILDREN_RESERVED_ATTRIBUTE
    el.setAttribute n, v
  if CHILDREN_RESERVED_ATTRIBUTE of attrs
    for n, v of attrs[CHILDREN_RESERVED_ATTRIBUTE]
      el.appendChild createElement doc, n.split('_')[0], v
  return el

exports.removeChildren = removeChildren = (node) ->
  while node.firstChild
    node.removeChild node.firstChild

exports.removeNode = removeNode = (node) ->
  node.parentNode.removeChild node

exports.loadSheet = (win, styleURI, type=Ci.nsIDOMWindowUtils.AUTHOR_SHEET) ->
  win.QueryInterface(Ci.nsIInterfaceRequestor)
      .getInterface(Ci.nsIDOMWindowUtils)
      .loadSheet(styleURI, type)

exports.removeSheet = (win, styleURI, type=Ci.nsIDOMWindowUtils.AUTHOR_SHEET) ->
  win.QueryInterface(Ci.nsIInterfaceRequestor)
      .getInterface(Ci.nsIDOMWindowUtils)
      .removeSheet(styleURI, type)


exports.zip = zip = (arrs...) ->
  shortest = arrs.reduce((a,b) -> if a.length < b.length then a else b)
  return shortest.map((_,i) -> arrs.map((array) -> array[i]))

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


exports.defaults = defaults = (o, k, v) ->
  unless k of o
    o[k] = v
