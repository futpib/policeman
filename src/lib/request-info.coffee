
{ path } = require 'file'
{ tabs } = require 'tabs'

class UriInfo
  _componentsWithoutRefMap:
    'scheme'  : 'scheme'
    'username': 'username'
    'password': 'password'
    'userPass': 'userPass'
    'host'    : 'host'
    'port'    : 'port'
    'hostPort': 'hostPort'
    'prePath' : 'prePath'
    'path'    : 'path'
    'spec'    : 'spec'

  _componentsWithRefMap:
    'ref' : 'ref'
    'path': 'pathRef'
    'spec': 'specRef'

  schemeClassification = Object.create null
  schemeClass = (cls, schemes) -> schemeClassification[s] = cls for s in schemes

  schemeClass 'internal', [
    '',
    'resource',
    'about',
    'chrome',
    'moz-icon',
    'moz-filedata',
    'view-source',
    'wyciwyg',
    'moz-nullprincipal',
  ]
  schemeClass 'inline', [
    'data',
    'blob',
    'javascript',
  ]
  schemeClass 'file', [
    'file',
  ]

  classifyScheme: (s) -> schemeClassification[s] or 'unknown'

  constructor: (uri) ->
    if typeof uri == 'string' # assuming it's a stringified uriinfo
      @parse uri
      return

    if uri
      uriWithRef = uri
      uri = uriWithRef.cloneIgnoringRef()

    uri ?= {}
    uriWithRef ?= {}

    @copyComponents uri, uriWithRef

  copyHelper = (from, to, map) =>
    for f, t of map
      to[t] = \
        try
          from[f] or '' # may throw if such component is inapplicable to uri
        catch
          ''
  copyComponents: (uri, uriWithRef) ->
    copyHelper uri, this, @_componentsWithoutRefMap
    copyHelper uriWithRef, this, @_componentsWithRefMap
    @schemeType = @classifyScheme(@scheme) or ''

  stringify: -> @specRef
  parse: (str) ->
    uriWithRef = path.toURI str
    uri = uriWithRef.cloneIgnoringRef()
    @copyComponents uri, uriWithRef


exports.OriginInfo = class OriginInfo extends UriInfo
  schemeWebOrigin =
    https: true
    http: true
    ftp: true
  classifyScheme: (s) -> if s of schemeWebOrigin \
    then 'web' \
    else super arguments...


exports.DestinationInfo = class DestinationInfo extends UriInfo
  schemeWebDestination =
    https: true
    http: true
    ftp: true
    wss: true
    ws: true
  classifyScheme: (s) -> if s of schemeWebDestination \
    then 'web' \
    else super arguments...


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
    'CSP_REPORT', # 17
    'XSLT', # 18
    'BEACON', # 19
  ]

  makeClassList = (className) ->
    l = Object.create null
    for c in className.split(' ')
      l[c] = true
    return l

  constructor: (originUri, destUri, context, contentType, mime, principal) ->
    # TODO is there any useful data we can get from nsIPrincipal?

    @contentType = intToTypeMap[contentType]
    @mime = mime or ''

    @nodeName = ''
    @_tabId = ''
    if context
      if context instanceof Ci.nsIDOMWindow
        @nodeName = '#window'
        @_window = context
      else if context instanceof Ci.nsIDOMNode
        @nodeName = context.nodeName.toLowerCase()
        @_node = context
        if context instanceof Ci.nsIDOMElement
          @_element = context
          @className = context.className
          @classList = makeClassList @className or ''
          @id = context.id
        else if context instanceof Ci.nsIDOMDocument
          @_document = context

      tab = tabs.getWindowOwner getWindowFromRequestContext context
      if tab
        @_tabId = tabs.getTabId tab

  delimiter = '|' # hoping there is no way | can get into components
  stringify: -> [@nodeName, @className, @id, @contentType, @mime].join delimiter
  parse: (str) ->
    [@nodeName, @className, @id, @contentType, @mime] = str.split delimiter
    @classList = makeClassList @className


exports.ChannelOriginInfo = class ChannelOriginInfo extends OriginInfo
  constructor: (channel) ->
    super channel.loadInfo.triggeringPrincipal.URI


exports.ChannelDestinationInfo = class ChannelDestinationInfo extends DestinationInfo
  constructor: (channel) ->
    super channel.URI


exports.ChannelContextInfo = class ChannelContextInfo extends ContextInfo
  constructor: (channel) ->
    loadInfo = channel.loadInfo
    contentType = loadInfo.contentPolicyType
    context = loadInfo.loadingNode or loadInfo.loadingDocument
    super null, null, context, contentType


XUL_NAMESPACE = 'http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul'
exports.getWindowFromRequestContext = getWindowFromRequestContext = (ctx) ->
  # gets dom window from context argument content policy's shouldLoad gets
  # https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsIContentPolicy#shouldLoad%28%29
  # reference says it's either nsIDOMNode or nsIDOMWindow
  if ctx instanceof Ci.nsIDOMWindow
    return ctx
  if ctx instanceof Ci.nsIDOMDocument
    return ctx.defaultView
  if ctx instanceof Ci.nsIDOMNode
    if (ctx.localName == 'browser') and (ctx.namespaceURI == XUL_NAMESPACE)
      return ctx.contentWindow
    # this will be chrome window in some cases
    return ctx.ownerDocument.defaultView



