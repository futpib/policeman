

{
  createElement
  loadSheet
  removeSheet
  Handlers
  reverseLookup
} = require 'utils'

{ manager } = require 'ruleset/manager'
{ memo } = require 'request-memo'
{ policy } = require 'content-policy'

{ windows } = require 'windows'
{ tabs } = require 'tabs'

{ CustomizableUI } = Cu.import "resource:///modules/CustomizableUI.jsm"
{ panelview } = require 'ui/panelview'
{ popup } = require 'ui/popup'
{ aboutPages } = require 'ui/about-policeman'

{ prefs } = require 'prefs'

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

  BUTTON_LEFT = 0
  BUTTON_MIDDLE = 1
  BUTTON_RIGHT = 2
  onBuild: (doc) ->
    btn = createElement doc, 'toolbarbutton',
      id:              @id
      class:           'toolbarbutton-1 chromeclass-toolbar-additional'
      label:           'Policeman'
      tooltiptext:     l10n 'toolbarbutton.tip'
      closemenu:       'none'

    btn.addEventListener 'command', (e) =>
      @events.dispatch 'command', e
    btn.addEventListener 'click', (e) =>
      switch e.button
        when BUTTON_LEFT then @events.dispatch 'leftClick', e
        when BUTTON_MIDDLE then @events.dispatch 'middleClick', e
        when BUTTON_RIGHT then @events.dispatch 'rightClick', e
    btn.addEventListener 'mouseover', (e) =>
      @events.dispatch 'mouseover', e

    return btn

  addUI: (win) ->
    loadSheet win, @styleURI

  removeUI: (win) ->
    removeSheet win, @styleURI

  indicator: new class
    constructor: ->
      tabs.onSelect.add @_onTabSelect.bind @
      policy.onRequest.add @_onRequest.bind @

    _states:
      fallback: (btn) ->
        btn.removeAttribute 'policeman-allow-ratio'
        btn.removeAttribute 'policeman-suspended'

      suspended: (btn) ->
        @fallback btn
        btn.setAttribute 'policeman-suspended', 'true'

      ratioIndicator: (btn, ratio) ->
        # make 0 and 100 less probable
        ratio = .12 + .76 * ratio
        # snap to 0, 25, 50, 75, 100
        ratio = Math.floor(100 * Math.round(4 * ratio) / 4)
        ratio = Math.max(0, Math.min(100, ratio))
        @fallback btn
        btn.setAttribute 'policeman-allow-ratio', ratio

    update: (tab=no) ->
      tab = tabs.getCurrent() unless tab
      doc = windows.getCurrent().document
      btn = doc.getElementById toolbarbutton.id
      if manager.suspended()
        @_states.suspended btn
        return
      if  (temporary = manager.get 'user_temporary') \
      and (temporary.isAllowedTab tabs.getCurrent())
        @_states.suspended btn # TODO maybe another indicator?
        return
      { allowHits: allow, rejectHits: reject } = memo.getStatsByTab tab
      total = allow + reject
      ratio = if total is 0 then 1 else allow / total
      @_states.ratioIndicator btn, ratio

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

  events: new class
    actions =
      noop: ->
      openWidget: (e) ->
        toolbarbutton._getAreaTypeSpecificWidget().onOpenEvent e
      openPreferences: (e) ->
        tabs.open aboutPages.PREFERENCES_USER
      toggleSuspended: (e) ->
        manager.toggleSuspended()
        toolbarbutton.indicator.update()
        if toolbarbutton.events.autoreload.enabled()
          tabs.reload tabs.getCurrent()
      toggleTabSuspended: (e) ->
        if (temporary = manager.get 'user_temporary')
          tab = tabs.getCurrent()
          if temporary.isAllowedTab tab
            temporary.revokeTab tab
          else
            temporary.allowTab tab
          toolbarbutton.indicator.update()
          if toolbarbutton.events.autoreload.enabled()
            tabs.reload tab
      removeTemporaryRules: (e) ->
        if (temporary = manager.get 'user_temporary')
          temporary.revokeAll()
        if toolbarbutton.events.autoreload.enabled()
          tabs.reload tabs.getCurrent()
    _actions: actions

    _eventToAction:
      command: actions.openWidget
      leftClick: actions.noop
      middleClick: actions.toggleSuspended
      rightClick: actions.noop
      mouseover: actions.noop

    _eventNameToPref: (eventName) -> "toolbarbutton.events.#{eventName}.action"

    _initActionPref: (eventName, default_='noop') ->
      prefName = @_eventNameToPref eventName
      prefs.define prefName,
        default: default_
        get: (name) => @_actions[name] or @_actions.noop
        set: (act) => (reverseLookup @_actions, act) or 'noop'
        sync: true
      prefs.onChange prefName, update = =>
        @_eventToAction[eventName] = prefs.get prefName
      do update

    constructor: ->
      @_initActionPref 'command', 'openWidget'
      @_initActionPref 'leftClick'
      @_initActionPref 'middleClick', 'toggleSuspended'
      @_initActionPref 'rightClick'
      @_initActionPref 'mouseover'

    dispatch: (eventName, e) ->
      @_eventToAction[eventName] e

    getActionsList: -> (a for a of @_actions)

    getAction: (eventName) ->
      reverseLookup actions, @_eventToAction[eventName] or @actions.noop

    setAction: (eventName, actionName) ->
      prefs.set (@_eventNameToPref eventName), @_actions[actionName] or actions.noop

    autoreload: new class
      prefs.define AUTORELOAD_PREF = 'ui.toolbarbutton.autoReloadPageOnAction',
        default: true
        sync: true

      enabled: -> prefs.get AUTORELOAD_PREF
      enable: -> prefs.set AUTORELOAD_PREF, true
      disable: -> prefs.set AUTORELOAD_PREF, false
