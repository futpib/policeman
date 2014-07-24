
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


exports.createElement = createElement = (doc, tag, attrs={}) ->
  el = doc.createElement tag
  el.setAttribute n, v for n, v of attrs
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

exports.tails = tails = (arr) ->
  ts = []
  while arr.length
    ts.push arr.slice()
    arr.shift()
  return ts

exports.superdomains = superdomains = (domain) ->
  # 'a.b.c' -> ['a.b.c', 'b.c', 'c']
  tails(domain.split('.')).map (x) -> x.join '.'


exports.defaults = defaults = (o, k, v) ->
  unless k of o
    o[k] = v
