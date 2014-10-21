

Cu.import "resource://gre/modules/NetUtil.jsm"

{
  defaults
  remove
  isDead
  superdomains
  isSuperdomain
} = require 'utils'
{ tabs } = require 'tabs'

{ l10n } = require 'l10n'


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


class BlockedElements
  constructor: ->
    @_tabIdToBlockedElements = Object.create null
    tabs.onClose.add (t) => @_removeAllByTabId tabs.getTabId t

  _addElemByTabId: (tabId, elem) ->
    defaults @_tabIdToBlockedElements, tabId, []
    @_tabIdToBlockedElements[tabId].push elem
  _removeElemByTabId: (tabId, elem) ->
    remove @_tabIdToBlockedElements[tabId], elem
  _removeAllByTabId: (tabId) -> delete @_tabIdToBlockedElements[tabId]
  _getAllByTabId: (tabId) -> (@_tabIdToBlockedElements[tabId] or []).slice()

  _backupAttribute: (elem, attr) ->
    elem.setAttribute 'policeman-original-' + attr, (elem.getAttribute attr) or ''
  _restoreAttribute: (elem, attr) ->
    elem.setAttribute attr, elem.getAttribute 'policeman-original-' + attr
    elem.removeAttribute 'policeman-original-' + attr

  setData: (elem, name, value) ->
    elem.setAttribute 'policeman-data-' + name, value
  getData: (elem, name) ->
    elem.getAttribute 'policeman-data-' + name
  removeData: (elem, name) ->
    elem.removeAttribute 'policeman-data-' + name

  _filter: (origin, destination, context, decision) ->
    return decision == false \
           and origin.schemeType == origin.schemeType == 'web' \
           and context._element \
           and context._tabId

  process: (origin, destination, context, decision) ->
    return unless @_filter arguments...
    @_filteredProcess context._element, origin, destination, context

  _filteredProcess: (elem, origin, destination, context) ->
    elem.setAttribute 'policeman-blocked', 'true'

    @setData elem, 'src', destination.spec
    @setData elem, 'host', destination.host
    @setData elem, 'contentType', context.contentType

    @_backupAttribute elem, 'src'
    @_backupAttribute elem, 'title'

    @_backupAttribute elem, 'style'
    elem.style.boxShadow = 'inset 0px 0px 0px 1px #fcc'
    elem.style.backgroundRepeat = 'no-repeat'
    elem.style.backgroundPosition = 'center center'
    elem.style.backgroundImage = "url('#{ BACKGROUND_IMAGE }')"
    elem.style.minWidth = elem.style.minHeight = '32px'

    @_addElemByTabId context._tabId, elem

  isBlocked: (elem) ->
    (not isDead elem) and 'true' == elem.getAttribute 'policeman-blocked'

  restore: (elem) ->
    return unless @isBlocked elem

    elem.removeAttribute 'policeman-blocked'
    @removeData elem, 'src'
    @removeData elem, 'host'

    elem.ownerDocument.defaultView.setTimeout (=>
      @_restoreAttribute elem, 'src'
    ), 1

    @_restoreAttribute elem, 'style'
    @_restoreAttribute elem, 'title'

    @_removeElemByTabId tabs.getTabId tabs.getNodeOwner elem

  restoreAllOnTab: (tab) ->
    return unless tab
    i = tabs.getTabId tab
    return unless i of @_tabIdToBlockedElements

    restored = new Map
    for elem in @_getAllByTabId i
      if isDead elem
        @_removeElemByTabId i, elem
      else
        @restore elem
        restored.set elem, true

    return restored

  restoreAllDomainPairOnTab: (oHost, dHost, tab) ->
    return unless tab
    i = tabs.getTabId tab
    return unless i of @_tabIdToBlockedElements

    restored = new Map
    for elem in @_getAllByTabId i
      if isDead elem
        @_removeElemByTabId i, elem
        continue
      if  isSuperdomain(oHost, elem.ownerDocument.defaultView.location.host) \
      and isSuperdomain(dHost, @getData elem, 'host')
        @restore elem
        restored.set elem

    return restored


class BlockedImages extends BlockedElements
  isBlocked: (elem) ->
    (super elem) and 'true' == elem.getAttribute 'policeman-blocked-image'
  _filter: (o, d, c) ->
    return super(arguments...) \
           and c.nodeName == 'img' \
           # filter off 1px counter images
           and not (c._element.clientWidth == c._element.clientHeight == 1)
  _filteredProcess: (img, o, d, c) ->
    super img, o, d, c
    img.setAttribute 'policeman-blocked-image', 'true'
    img.src = TRANSPARENT_PLACEHOLDER
    img.title = (if img.title then img.title + ' ' else '') \
        + (if img.alt and img.alt != img.title then img.alt + ' ' else '') \
        + l10n('blocked_image.tip', d.host)


class BlockedFrames extends BlockedElements
  isBlocked: (elem) ->
    (super elem) and 'true' == elem.getAttribute 'policeman-blocked-frame'
  _filter: (o, d, c) -> c.nodeName in ['iframe', 'frame'] and super arguments...
  _filteredProcess: (elem, o, d, c) ->
    super elem, o, d, c
    elem.setAttribute 'policeman-blocked-frame', 'true'
    elem.title = (if elem.title then elem.title + ' ' else '') \
        + l10n('blocked_frame.tip', d.host)


class BlockedObjects extends BlockedElements
  isBlocked: (elem) ->
    (super elem) and 'true' == elem.getAttribute 'policeman-blocked-object'
  _filter: (o, d, c) ->
    return c.nodeName in ['object', 'embed'] \
           and c.contentType == 'OBJECT' \ # do not process OBJECT_SUBREQUESTs
           and super arguments...
  _filteredProcess: (elem, o, d, c) ->
    super elem, o, d, c
    elem.setAttribute 'policeman-blocked-object', 'true'
    elem.title = (if elem.title then elem.title + ' ' else '') \
        + l10n('blocked_object.tip', d.host)


exports.blockedElements = blockedElements =
  image: new BlockedImages
  frame: new BlockedFrames
  object: new BlockedObjects

  process: (origin, destination, context, decision) ->
    @image.process arguments...
    @frame.process arguments...
    @object.process arguments...

