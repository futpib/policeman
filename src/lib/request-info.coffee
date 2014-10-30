
{ path } = require 'file'
{ tabs } = require 'tabs'

class UriInfo
  components: [
    'scheme',
    'schemeType',
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

  classifyScheme: (s) -> schemeClassification[s]

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
          uri[k] or '' # may throw if such component is inapplicable to uri
        catch
          ''
    ) for k in @components
    @schemeType = @classifyScheme(@scheme) or ''

  stringify: -> @spec
  parse: (str) ->
    uri = path.toURI str
    @copyComponents uri


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

  constructor: (originUri, destUri, context, contentType, @mime, principal) ->
    # TODO is there any useful data we can get from nsIPrincipal?

    @contentType = intToTypeMap[contentType]

    @nodeName = ''
    if context
      if context instanceof Ci.nsIDOMWindow
        @nodeName = '#window'
      else if context instanceof Ci.nsIDOMNode
        @nodeName = context.nodeName.toLowerCase()
      try
        element = context.QueryInterface Ci.nsIDOMElement
        @_element = element
        @className = element.className
        @classList = makeClassList @className or ''
        @id = element.id
      catch e
        unless e instanceof Ci.nsIException \
        and    e.result == Cr.NS_ERROR_NO_INTERFACE
          throw e

    @_tabId = '' # intended for internal use. Is not persistent between restarts
    tab = tabs.getWindowOwner getWindowFromRequestContext context
    if tab
      @_tabId = tabs.getTabId tab

  delimiter = '|' # hoping there is no way | can get into components
  stringify: -> [@nodeName, @className, @id, @contentType, @mime].join delimiter
  parse: (str) ->
    [@nodeName, @className, @id, @contentType, @mime] = str.split delimiter
    @classList = makeClassList @className

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



