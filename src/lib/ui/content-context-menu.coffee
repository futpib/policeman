

{
  createElement
  removeNode
  removeChildren
  superdomains
} = require 'utils'
{ windows } = require 'windows'
{ tabs } = require 'tabs'

{ manager } = require 'ruleset/manager'
{ blockedElements } = require 'blocked-elements'

{ l10n } = require 'l10n'


exports.contentContextMenu = contentContextMenu =
  init: ->
    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

  addUI: (win) ->
    doc = win.document
    popup = doc.getElementById 'contentAreaContextMenu'
    popup.addEventListener 'popupshowing', @_popupshowing =  (e) =>
      @populateMenu doc if e.target == popup
    popup.addEventListener 'popuphiding', @_popuphiding = (e) =>
      @cleanupMenu doc if e.target == popup

  removeUI: (win) ->
    doc = win.document
    popup = doc.getElementById 'contentAreaContextMenu'
    popup.removeEventListener 'popupshowing', @_popupshowing
    popup.removeEventListener 'popuphiding', @_popuphiding
    if menu = doc.getElementById 'context-policeman-blocked-element'
      removeNode menu

  populateMenu: (doc) ->
    popup = doc.getElementById 'contentAreaContextMenu'
    elem = popup.triggerNode or doc.popupNode or doc.defaultView.gContextMenu.target

    temp = manager.get 'user_temporary'
    pers = manager.get 'user_persistent'

    currentTabId = tabs.getTabId tabs.getCurrent() # == getNodeOwner img

    contextMenu = doc.getElementById 'contentAreaContextMenu'

    for subj in ['image', 'frame', 'object']
      blocked = blockedElements[subj]
      continue unless blocked.isBlocked(elem) \
               and (temp or pers)

      ohost = elem.ownerDocument.defaultView.location.host
      dhost = blocked.getData elem, 'host'

      contentType = blocked.getData elem, 'contentType'

      menu = createElement doc, 'menu',
        id: 'context-policeman-blocked-element'
        class: 'menu-iconic menuitem-with-favicon'
        image: 'chrome://policeman/skin/toolbar-icon-16.png'
        label: l10n "context_blocked_#{subj}"

      menu.appendChild popup = createElement doc, 'menupopup',
        id: 'context-policeman-blocked-element-popup'

      if temp
        popup.appendChild createElement doc, 'menuitem',
          id: "context-policeman-blocked-#{subj}-load"
          label: l10n "context_blocked_#{subj}_load"
          event_command: do (blocked=blocked) ->  ->
            src = blocked.getData elem, 'src'
            once = false
            temp.addClosure (o, d, c) ->
              temp.revokeClosure @ if once
              if c._element is elem
                once = true
                return true
              return null
            blocked.restore elem

        popup.appendChild createElement doc, 'menuitem',
          id: "context-policeman-blocked-#{subj}-load-all-on-tab"
          label: l10n "context_blocked_#{subj}_load_all_on_tab", ds
          event_command: do (blocked=blocked, ds=ds) -> ->
            temp.addClosure (o, d, c) ->
              return true if c._tabId == currentTabId \
                          and restored.get c._element
              temp.revokeClosure @ # FIXME may be revoked too soon
            restored = blocked.restoreAllOnTab currentTabId

      tempFragment = doc.createDocumentFragment()
      persFragment = doc.createDocumentFragment()

      buttonsCount = 0
      for ds in superdomains dhost, 2
        if temp
          buttonsCount += 1
          tempFragment.appendChild createElement doc, 'menuitem',
            label: l10n \
              "context_blocked_#{subj}_temp_allow_domain_pair_and_load", ds
            event_command: do (blocked=blocked, ds=ds) -> ->
              temp.allow ohost, ds, contentType
              blocked.restoreAllDomainPairOnTab ohost, ds, currentTabId

        if pers
          buttonsCount += 1
          persFragment.appendChild createElement doc, 'menuitem',
            label: l10n "context_blocked_#{subj}_pers_allow_domain_pair_and_load", ds
            event_command: do (blocked=blocked, ds=ds) -> ->
              pers.allow ohost, ds, contentType
              blocked.restoreAllDomainPairOnTab ohost, ds, currentTabId

      if buttonsCount > 0
        popup.appendChild createElement doc, 'menuseparator'
      popup.appendChild tempFragment

      if buttonsCount > 2 and temp and pers
        popup.appendChild createElement doc, 'menuseparator'
      popup.appendChild persFragment

      contextMenu.appendChild menu

      break


  cleanupMenu: (doc) ->
    if menu = doc.getElementById 'context-policeman-blocked-element'
      removeNode menu


do contentContextMenu.init
