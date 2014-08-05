

{
  createElement
  removeNode
  removeChildren
  superdomains
} = require 'utils'
{ overlayQueue } = require 'ui/overlay-queue'
{ windows } = require 'windows'
{ tabs } = require 'tabs'

{ manager } = require 'ruleset/manager'
{ blockedImage } = require 'blocked-image'

{ l10n } = require 'l10n'


exports.contentContextMenu = contentContextMenu =
  init: ->
    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

  addUI: (win) ->
    doc = win.document
    overlayQueue.add doc, 'chrome://policeman/content/content-context-menu-overlay.xul', =>
      popup = doc.getElementById 'contentAreaContextMenu'
      popup.addEventListener 'popupshowing', (e) =>
        @updateMenu doc if e.target == popup
      popup.addEventListener 'popuphiding', (e) =>
        @cleanupMenu doc if e.target == popup

  removeUI: (win) ->
    doc = win.document
    removeNode doc.getElementById 'context-policeman-blocked-image'

  updateMenu: (doc) ->
    return unless blockedImage.isBlockedNode img = doc.popupNode

    temp = manager.get 'user_temporary'
    pers = manager.get 'user_persistent'

    doc.getElementById('context-policeman-blocked-image')
            .hidden = not (temp or pers)

    popup = doc.getElementById 'context-policeman-blocked-image-menupopup'

    ohost = img.ownerDocument.defaultView.location.host
    dhost = blockedImage.getOriginalHost img

    tab = tabs.getCurrent() # == getNodeOwner img
    if tab
      tabId = tabs.getTabId tab

    if temp
      popup.appendChild loadImage = createElement doc, 'menuitem',
        id: 'context-policeman-blocked-image-load'
        label: l10n 'context_blocked_image_load'
      loadImage.addEventListener 'command', ->
        src = blockedImage.getOriginalSrc img
        once = false
        temp.addClosure (o, d, c) ->
          temp.revokeClosure @ if once
          return once = true if o.schemeType == d.schemeType == 'web' \
                      and c.nodeName == 'img' \
                      and c._tabId == tabId \
                      and d.spec == src
          return null
        blockedImage.restore img

      popup.appendChild loadTab = createElement doc, 'menuitem',
        id: 'context-policeman-blocked-image-load-all-on-tab'
        label: l10n 'context_blocked_image_load_all_on_tab', ds
      loadTab.addEventListener 'command', do (ds=ds) -> ->
        temp.addClosure (o, d, c) ->
          return true if c._tabId == tabId \
                      and c.contentType == 'IMAGE'
          # May be revoked too early for images to be loaded,
          # can't come up with anything better.
          temp.revokeClosure @
        blockedImage.restoreAllOnTab tabId

    tempFragment = doc.createDocumentFragment()
    persFragment = doc.createDocumentFragment()

    buttonsCount = 0
    for ds in superdomains dhost, 2
      if temp
        buttonsCount += 1
        tempFragment.appendChild loadDomain = createElement doc, 'menuitem',
          label: l10n 'context_blocked_image_temp_allow_domain_pair_and_load', ds
        loadDomain.addEventListener 'command', do (ds=ds) -> ->
          temp.allow ohost, ds, 'IMAGE'
          blockedImage.restoreAllDomainPairOnTab ohost, ds, tabId

      if pers
        buttonsCount += 1
        persFragment.appendChild loadDomainAllways = createElement doc, 'menuitem',
          label: l10n 'context_blocked_image_pers_allow_domain_pair_and_load', ds
        loadDomainAllways.addEventListener 'command', do (ds=ds) -> ->
          pers.allow ohost, ds, 'IMAGE'
          blockedImage.restoreAllDomainPairOnTab ohost, ds, tabId

    if buttonsCount > 0
      popup.appendChild createElement doc, 'menuseparator'
    popup.appendChild tempFragment

    if buttonsCount > 2 and temp and pers
      popup.appendChild createElement doc, 'menuseparator'
    popup.appendChild persFragment

  cleanupMenu: (doc) ->
    doc.getElementById('context-policeman-blocked-image').hidden = true
    removeChildren doc.getElementById 'context-policeman-blocked-image-menupopup'


do contentContextMenu.init
