

{
  createElement
  loadSheet
  removeSheet
  Handlers
} = require 'utils'

{ manager } = require 'ruleset/manager'
{ memo } = require 'request-memo'

{ windows } = require 'windows'
{ tabs } = require 'tabs'

{ CustomizableUI } = Cu.import "resource:///modules/CustomizableUI.jsm"
{ panelview } = require 'ui/panelview'
{ popup } = require 'ui/popup'

{ l10n } = require 'l10n'

exports.toolbarbutton = toolbarbutton = new class
  id: 'policeman-toolbarbutton'

  styleURI: Services.io.newURI 'chrome://policeman/skin/toolbar.css', null, null

  constructor: ->
    @wrapper = CustomizableUI.createWidget
        id:              @id
        type:            'custom'
        defaultArea:     CustomizableUI.AREA_NAVBAR
        onBuild:         @onBuild.bind @
    onShutdown.add => CustomizableUI.destroyWidget @id

    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

  _getAreaTypeSpecificWidget: (areaType=@wrapper.areaType) ->
    if areaType == CustomizableUI.TYPE_MENU_PANEL
      return panelview
    return popup

  onBuild: (doc) ->
    btn = createElement doc, 'toolbarbutton',
      id:              @id
      class:           'toolbarbutton-1 chromeclass-toolbar-additional'
      label:           'Policeman'
      tooltiptext:     l10n 'toolbarbutton.tip'
      closemenu:       'none'
    btn.addEventListener 'command', (e) =>
      @_getAreaTypeSpecificWidget().onToobarbuttonCommand e
    return btn

  addUI: (win) ->
    loadSheet win, @styleURI

  removeUI: (win) ->
    removeSheet win, @styleURI

  indicator: new class
    constructor: ->
      tabs.onSelect.add @_onTabSelect.bind @
      memo.onRequest.add @_onRequest.bind @

    _clear: (btn) ->
      btn.removeAttribute 'policeman-allow-ratio'
      btn.removeAttribute 'policeman-suspended'

    _setSuspended: (btn, suspended) ->
      @_clear btn
      btn.setAttribute 'policeman-suspended', 'true'

    _setRatio: (btn, ratio) ->
      # make 0 and 100 less probable
      ratio = .12 + .76 * ratio
      # snap to 0, 25, 50, 75, 100
      ratio = Math.floor(100 * Math.round(4 * ratio) / 4)
      ratio = Math.max(0, Math.min(100, ratio))
      @_clear btn
      btn.setAttribute 'policeman-allow-ratio', ratio

    update: (tab=no) ->
      tab = tabs.getCurrent() unless tab
      doc = windows.getCurrent().document
      btn = doc.getElementById toolbarbutton.id
      if manager.suspended()
        @_setSuspended btn, true
        return
      { allowHits: allow, rejectHits: reject } = memo.getStatsByTab tab
      total = allow + reject
      ratio = if total is 0 then 1 else allow / total
      @_setRatio btn, ratio

    updateTimeoutId = null

    ON_TAB_SELECT_UPDATE_TIMEOUT = 100
    _onTabSelect: (tab) ->
      return if updateTimeoutId
      browser = tab.ownerDocument.defaultView
      updateTimeoutId = browser.setTimeout (=>
        updateTimeoutId = null
        @update tabs.getCurrent()
      ), ON_TAB_SELECT_UPDATE_TIMEOUT

    ON_REQUEST_UPDATE_TIMEOUT = 1500
    _onRequest: (origin, destination, context, decision) ->
      return if updateTimeoutId
      return unless ctxTabId = context._tabId
      currentTab = tabs.getCurrent()
      return unless ctxTabId == tabs.getTabId currentTab
      browser = currentTab.ownerDocument.defaultView
      updateTimeoutId = browser.setTimeout (=>
        updateTimeoutId = null
        @update tabs.getCurrent()
      ), ON_REQUEST_UPDATE_TIMEOUT

