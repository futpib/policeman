

Cu.import "resource://gre/modules/NetUtil.jsm"

{
  remove
  isDead
  superdomains
  isSuperdomain
} = require 'utils'
{ tabs } = require 'tabs'

{ l10n } = require 'l10n'


# 1px transparent gif
TRANSPARENT_PLACEHOLDER = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'


exports.findTabThatOwnsImage = findTabThatOwnsImage = (img) ->
  tabs.getWindowOwner img.ownerDocument.defaultView.top


exports.blockedImage = blockedImage =
  srcPlaceholder: TRANSPARENT_PLACEHOLDER
  background: TRANSPARENT_PLACEHOLDER

  _tabIdToBlockedImages: {}

  init: ->
    tabs.onClose.add @removeByTab.bind @

    NetUtil.asyncFetch 'chrome://policeman/skin/blocked-image-icon-32.png', (stream) =>
      btoa = Cc["@mozilla.org/appshell/appShellService;1"]
              .getService(Ci.nsIAppShellService).hiddenDOMWindow.btoa
      b64 = btoa NetUtil.readInputStreamToString stream, stream.available()
      @background = "data:image/png;base64," + b64

  process: (origin, destination, context, decision) ->
    return unless decision == false \
           and origin.schemeType == origin.schemeType == 'web' \
           and context.nodeName == 'img' \
           and context._element \
           and context._tabId
    img = context._element

    img.setAttribute 'policeman-original-src', destination.spec
    img.setAttribute 'policeman-original-host', destination.host
    img.src = @srcPlaceholder

    img.setAttribute 'policeman-original-style', img.getAttribute 'style'
    img.style.boxShadow = 'inset 0px 0px 0px 1px #fcc'
    img.style.backgroundRepeat = 'no-repeat'
    img.style.backgroundPosition = 'center center'
    img.style.backgroundImage = "url('#{ @background }')"

    img.setAttribute 'policeman-original-title', img.title
    img.title = (if img.title then img.title + ' ' else '') \
        + (if img.alt and img.alt != img.title then img.alt + ' ' else '') \
        + l10n('blocked_image', destination.host)

    i = context._tabId
    unless i of @_tabIdToBlockedImages
      @_tabIdToBlockedImages[i] = []
    @_tabIdToBlockedImages[i].push img

  removeByTab: (tab) ->
    tabId = tabs.getTabId tab
    delete @_tabIdToBlockedImages[tabId]

  getByTabId: (tabId) -> @_tabIdToBlockedImages[tabId] or []

  isBlockedNode: (img) ->
    (not isDead img) and img.hasAttribute 'policeman-original-src'
  getOriginalSrc: (img) -> img.getAttribute 'policeman-original-src'
  getOriginalHost: (img) -> img.getAttribute 'policeman-original-host'

  restore: (img) ->
    return unless @isBlockedNode img
    src = img.getAttribute 'policeman-original-src'
    img.removeAttribute 'policeman-original-src'
    img.removeAttribute 'policeman-original-host'

    title = img.getAttribute 'policeman-original-title'
    img.removeAttribute 'policeman-original-title'

    style = img.getAttribute 'policeman-original-style'
    img.removeAttribute 'policeman-original-style'

    tab = tabs.getNodeOwner img
    if tab
      i = tabs.getTabId tab
      remove @_tabIdToBlockedImages[i], img

    img.style = style
    img.title = title
    img.src = src

  restoreAllOnTab: (tab) ->
    return unless tab
    i = tabs.getTabId tab
    return unless i of @_tabIdToBlockedImages

    for image in @_tabIdToBlockedImages[i].slice()
      continue if isDead(image)
      @restore image

  restoreAllDomainPairOnTab: (oHost, dHost, tab) ->
    return unless tab
    i = tabs.getTabId tab
    return unless i of @_tabIdToBlockedImages

    for image in @_tabIdToBlockedImages[i].slice()
      continue if isDead(image) \
               or not isSuperdomain(
                  oHost,
                  image.ownerDocument.defaultView.location.host) \
               or not isSuperdomain(dHost, @getOriginalHost image)
      @restore image





do blockedImage.init
