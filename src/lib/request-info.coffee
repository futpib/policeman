
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
  schemeInternal: {
    '': true
    'resource': true
    'about': true
    'chrome': true
    'moz-icon': true
    'moz-filedata': true
    'view-source': true
    'wyciwyg': true
    'moz-nullprincipal': true
  }
  schemeInline: {
    'data': true
    'blob': true
    'javascript': true
  }
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
    if @schemeInternal[@scheme]
      @schemeType = 'internal'
    else if @schemeInline[@scheme]
      @schemeType = 'inline'

  stringify: -> @spec
  parse: (str) ->
    uri = path.toURI str
    @copyComponents uri


exports.OriginInfo = class OriginInfo extends UriInfo
  schemeWebOrigin: {
    https: true
    http: true
  }
  copyComponents: (uri) ->
    super uri
    if not @schemeType and @schemeWebOrigin[@scheme]
      @schemeType = 'web'


exports.DestinationInfo = class DestinationInfo extends UriInfo
  schemeWebDestination: {
    https: true
    http: true
    ftp: true
  }
  copyComponents: (uri) ->
    super uri
    if not @schemeType and @schemeWebDestination[@scheme]
      @schemeType = 'web'


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
        @classList = makeClassList @className
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



