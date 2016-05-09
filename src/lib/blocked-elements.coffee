

Cu.import "resource://gre/modules/NetUtil.jsm"
{ setTimeout, clearTimeout } = Cu.import "resource://gre/modules/Timer.jsm"

{
  WeakSet
  remove
  isDead
  superdomains
  isSuperdomain
  mutateAttribute
} = require 'lib/utils'
{ tabs } = require 'lib/tabs'

{ prefs } = require 'lib/prefs'

{ l10n } = require 'lib/l10n'


# 1px transparent gif
TRANSPARENT_PLACEHOLDER = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'

BACKGROUND_IMAGE = TRANSPARENT_PLACEHOLDER
NetUtil.asyncFetch 'chrome://policeman/skin/blocked-image-icon-32.png', (stream) =>
  window = Cc["@mozilla.org/appshell/appShellService;1"]
          .getService(Ci.nsIAppShellService).hiddenDOMWindow
  b64 = window.btoa NetUtil.readInputStreamToString stream, stream.available()
  BACKGROUND_IMAGE = "data:image/png;base64," + b64


exports.findTabThatOwnsImage = findTabThatOwnsImage = (img) ->
  tabs.getWindowOwner img.ownerDocument.defaultView.top


class Filter
  shouldProcess: (elem, [origin, destination, context], decision) ->
    return decision == false \
           and origin.schemeType == origin.schemeType == 'web' \
           and context._element \
           and context._tabId

imageFilter = new class ImageFilter extends Filter
  TOOLTIP_TEXT_KEY: 'blocked_image.tip'
  isImage = (elem) -> elem.nodeName == 'IMG'
  shouldProcess: (elem, request, decision) ->
    return super(arguments...) \
           and isImage(elem) \
           # filter off 1px counter images
           and not (elem.clientWidth == elem.clientHeight == 1)

frameFilter = new class FrameFilter extends Filter
  TOOLTIP_TEXT_KEY: 'blocked_frame.tip'
  isFrame = (elem) -> elem.nodeName in ['IFRAME', 'FRAME']
  shouldProcess: (elem, request, decision) ->
    return super(arguments...) \
           and isFrame(elem)

objectFilter = new class ObjectFilter extends Filter
  TOOLTIP_TEXT_KEY: 'blocked_object.tip'
  isObject = (elem) -> elem.nodeName in ['OBJECT', 'EMBED']
  shouldProcess: (elem, request, decision) ->
    return super(arguments...) \
           and isObject(elem) \
           # do not process OBJECT_SUBREQUESTs
           and request.context.contentType == 'OBJECT'


class BlockedElementHandler
  _ATTRIBUTE_PREFIX: '__attribute_'
  _backupAttribute: (elem, attr) ->
    @setData elem, @_ATTRIBUTE_PREFIX + attr, (elem.getAttribute attr) or ''
  _restoreAttribute: (elem, attr) ->
    elem.setAttribute attr, @getData elem, @_ATTRIBUTE_PREFIX + attr
    @removeData elem, @_ATTRIBUTE_PREFIX + attr

  _PROCESSED_PREFIX: '__processed_'
  _processedTagName: undefined # to be defined by inferior classes
  isBlocked: (elem) ->
    return @getData elem, @_PROCESSED_PREFIX + @_processedTagName
  tagAsProcessed: (elem) ->
    @setData elem, @_PROCESSED_PREFIX + @_processedTagName, true
  removeProcessedTag: (elem) ->
    @removeData elem, @_PROCESSED_PREFIX + @_processedTagName

  setData: (elem, name, value) ->
    if @_elementToData.has elem
      data = @_elementToData.get elem
    else
      data = Object.create null
      @_elementToData.set elem, data
    data[name] = value
  getData: (elem, name) ->
    return if data = (@_elementToData.get elem) \
              then data[name] \
              else undefined
  removeData: (elem, name) ->
    delete (@_elementToData.get elem)[name]

  _addElemByTabId: (tabId, elem) ->
    @_tabIdToBlockedElements[tabId] ?= []
    @_tabIdToBlockedElements[tabId].push elem
  _removeElemByTabId: (tabId, elem) ->
    remove @_tabIdToBlockedElements[tabId], elem
  _removeAllByTabId: (tabId) -> delete @_tabIdToBlockedElements[tabId]
  _getAllByTabId: (tabId) -> (@_tabIdToBlockedElements[tabId] or []).slice()

  constructor: (@filter) ->
    @_elementToData = new WeakMap
    @_tabIdToBlockedElements = Object.create null # TODO go weak
    tabs.onClose.add (t) => @_removeAllByTabId tabs.getTabId t

  process: (elem, request, decision) ->
    return unless @filter.shouldProcess elem, request, decision
    @_filteredProcess arguments...
    @_addElemByTabId request.context._tabId, elem

  restore: (elem) ->
    return unless @isBlocked elem
    @_filteredRestore arguments...
    @_removeElemByTabId (tabs.getTabId tabs.getNodeOwner elem), elem

  _filteredProcess: (elem, request, decision) ->
    @tagAsProcessed elem
    @setData elem, 'src', request.destination.spec
    @_backupAttribute elem, 'src'

  _filteredRestore: (elem) ->
    @removeProcessedTag elem
    @removeData elem, 'src'
    setTimeout (=>
      @_restoreAttribute elem, 'src'
    ), 1

  restoreAllOnTab: (tab) ->
    return unless tab
    i = tabs.getTabId tab
    return unless i of @_tabIdToBlockedElements

    restored = new WeakSet
    for elem in @_getAllByTabId i
      if isDead elem
        @_removeElemByTabId i, elem
      else
        @restore elem
        restored.add elem, true

    return restored

  restoreAllDomainPairOnTab: (oHost, dHost, tab) ->
    return unless tab
    i = tabs.getTabId tab
    return unless i of @_tabIdToBlockedElements

    restored = new WeakSet
    for elem in @_getAllByTabId i
      if isDead elem
        @_removeElemByTabId i, elem
        continue
      if  isSuperdomain(oHost, elem.ownerDocument.defaultView.location.host) \
      and isSuperdomain(dHost, @getData elem, 'host')
        @restore elem
        restored.add elem

    return restored


class Passer
  process: ->
  restore: ->

class Placeholder extends BlockedElementHandler
  _processedTagName: 'placeholder'

  _filteredProcess: (elem, request) ->
    super arguments...

    @setData elem, 'host', request.destination.host
    @setData elem, 'contentType', request.context.contentType

    @_backupAttribute elem, 'title'
    mutateAttribute elem, 'title', (title) =>
      tip = l10n @filter.TOOLTIP_TEXT_KEY, request.destination.host
      if title \
        then title + '\n' + tip \
        else tip

    @_backupAttribute elem, 'style'

    computedStyle = elem.ownerDocument.defaultView.getComputedStyle elem

    elem.style.boxShadow = 'inset 0px 0px 0px 1px #fcc'
    elem.style.backgroundRepeat = 'no-repeat'
    elem.style.backgroundPosition = 'center center'
    elem.style.backgroundImage = "url('#{ BACKGROUND_IMAGE }')"
    if computedStyle # FF bug 548397 (getComputedStyle == null for hidden iframes)
      if 'inline' == computedStyle.getPropertyValue 'display'
        elem.style.display = 'inline-block'
    elem.style.minWidth = elem.style.minHeight = '32px'

  _filteredRestore: (elem) ->
    super arguments...

    @removeData elem, 'host'
    @removeData elem, 'contentType'

    @_restoreAttribute elem, 'title'
    @_restoreAttribute elem, 'style'

class Remover extends BlockedElementHandler
  _processedTagName: 'removed'

  _filteredProcess: (elem, request) ->
    super arguments...
    @_backupAttribute elem, 'style'
    elem.style.display = 'none'

  _filteredRestore: (elem) ->
    super arguments...
    @_restoreAttribute elem, 'style'


exports.blockedElements = blockedElements = new class
  # define [preference string] <-> [handler class] mapping
  prefToHandlerClass = new Map
  handlerClassToPref = new Map
  defHandlerClassPref = (pref, procClass) ->
    prefToHandlerClass.set pref, procClass
    handlerClassToPref.set procClass, pref

  defHandlerClassPref 'placeholder', Placeholder
  defHandlerClassPref 'remover', Remover
  defHandlerClassPref 'passer', Passer

  # define preferences themselves
  fullHandlerPreferenceName = (name) -> "blockedElements.#{name}.handler"

  defHandlerPref = (name) ->
    prefs.define fullname = fullHandlerPreferenceName(name),
      default: 'placeholder'
      get: (str) ->
        cls = prefToHandlerClass.get(str)
        return cls
      set: (cls) ->
        str = handlerClassToPref.get(cls)
        return str
      sync: true

  _initHandlerPref: (name, filter) ->
    defHandlerPref name
    prefs.onChange fullname = fullHandlerPreferenceName(name), update = =>
      cls = prefs.get fullname
      this[name] = new cls filter
    do update

  constructor: ->
    @_initHandlerPref 'image', imageFilter
    @_initHandlerPref 'frame', frameFilter
    @_initHandlerPref 'object', objectFilter

  setHandler: (filterName, handlerName) ->
    prefs.set fullHandlerPreferenceName(filterName), \
              prefToHandlerClass.get(handlerName)
  getHandler: (filterName) ->
    handlerClassToPref.get prefs.get fullHandlerPreferenceName filterName

  process: (request, decision) ->
    for handler in [@image, @frame, @object]
      handler.process request.context._element, request, decision

  restore: (elem) ->
    for handler in [@image, @frame, @object]
      handler.restore elem

