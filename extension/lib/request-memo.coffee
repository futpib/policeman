

{ windows } = require 'windows'
{ tabs } = require 'tabs'
{ OriginInfo, DestInfo, getWindowFromRequestContext } = require 'request-info'


###
Remembers requests attempted by each tab with corresponding decisions
(for later use by ui/popup).
###
exports.memo = memo =
  _tabIdToArray: {} # tabId -> array of 4-arrays [origin, dest, context, decision]

  init: ->
    tabs.onClose.add @removeRequestsMadeByTab.bind @

  removeRequestsMadeByTab: (tab) ->
    tabId = tabs.getTabId tab
    delete @_tabIdToArray[tabId]

  add: (origin, dest, context, decision) ->
    i = context.tabId
    @_tabIdToArray[i] = [] unless i of @_tabIdToArray
    @_tabIdToArray[i].push [origin, dest, context, decision]

  getByTabId: (tabId) ->
    return @_tabIdToArray[tabId] or []

  getByTab: (tab) ->
    return @getByTabId tabs.getTabId tab

  getByWindow: (win) ->
    [].concat (@getByTabId tabs.getTabId tab for tab in win.gBrowser.tabs)...

  getAll: ->
    [].concat (quads for tab, quads of _tabIdToArray)...



do memo.init
