
{ path } = require 'file'
{ tabs } = require 'tabs'

exports.UriInfo = class UriInfo
  components: [
    'scheme',
    'username',
    'password',
    'userPass',
    'host',
    'port',
    'hostPort',
    'prePath',
    'path',
    'spec',
  ]
  constructor: (uri) ->
    if typeof uri == 'string' # assuming it's a stringified uriinfo
      @parse uri
      return

    if uri
      uri = uri.cloneIgnoringRef()
    else
      uri = {}

    @copyComponents uri

  copyComponents: (uri) ->
    (
      @[k] = \
        try
          uri[k] # throws if such component is inapplicable to uri
        catch
          ''
    ) for k in @components

  stringify: -> @spec
  parse: (str) ->
    uri = path.toURI str
    @copyComponents uri


exports.ContextInfo = class ContextInfo
  components: ['nodeName', 'contentType', 'mime']

  # maps integer values of contentType argument to strings according to
  # https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsIContentPolicy#Constants
  intToTypeMap = [
    undefined,
    'OTHER', # 1
    'SCRIPT', # 2
    'IMAGE', # 3
    'STYLESHEET', # 4
    'OBJECT', # 5
    'DOCUMENT', # 6
    'SUBDOCUMENT', # 7
    'REFRESH', # 8
    'XBL', # 9
    'PING', # 10
    'XMLHTTPREQUEST', # 11
    'OBJECT_SUBREQUEST', # 12
    'DTD', # 13
    'FONT', # 14
    'MEDIA', # 15
    'WEBSOCKET', # 16
  ]

  makeClassList = (className) ->
    l = {}
    for c in className.split(' ')
      l[c] = true
    return l

  constructor: (context, contentType, @mime) ->
    @contentType = intToTypeMap[contentType]
    @nodeName = ''
    if context instanceof Ci.nsIDOMWindow
      @nodeName = '#window'
    else if context instanceof Ci.nsIDOMNode
      @nodeName = context.nodeName.toLowerCase()
    @tabId = '' # intended for internal use. Is not persistent between restarts
    tab = tabs.findTabThatOwnsDomWindow getWindowFromRequestContext context
    if tab
      @tabId = tabs.getTabId tab

  delimiter = '|' # hoping there is no way | can get into components
  stringify: -> [@nodeName, @contentType, @mime].join delimiter
  parse: (str) ->
    [@nodeName, @contentType, @mime] = str.split delimiter

exports.getWindowFromRequestContext = getWindowFromRequestContext = (ctx) ->
  # gets dom window from context argument content policy's shouldLoad gets
  # https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsIContentPolicy#shouldLoad%28%29
  # reference says it's either nsIDOMNode or nsIDOMWindow
  if ctx instanceof Ci.nsIDOMNode
    ctx = ctx.defaultView
  return ctx



