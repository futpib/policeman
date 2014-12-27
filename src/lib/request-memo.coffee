

{ windows } = require 'windows'
{ tabs } = require 'tabs'
{ OriginInfo, DestInfo, getWindowFromRequestContext } = require 'request-info'


###
Remembers requests attempted by each tab with corresponding decisions
(for later use by ui/popup).
###
exports.memo = memo = new class
  class Stats
    constructor: ->
      @allowHits = 0
      @rejectHits = 0
    hit: (origin, destination, context, decision) ->
      if decision
        @allowHits += 1
      else
        @rejectHits += 1

  # tabId -> array of 4-arrays [origin, dest, context, decision]
  _tabIdToArray: Object.create null
  # tabId -> Stats
  _tabIdToStats: Object.create null

  constructor: ->
    tabs.onClose.add @removeRequestsMadeByTab.bind @

  removeRequestsMadeByTab: (tab) ->
    tabId = tabs.getTabId tab
    delete @_tabIdToArray[tabId]
    delete @_tabIdToStats[tabId]

  add: (origin, dest, context, decision) ->
    i = context._tabId
    return if not i
    if context.contentType == 'DOCUMENT'
      # Page reload or navigated to another document
      @_tabIdToArray[i] = []
      @_tabIdToStats[i] = new Stats
      # Not to record the document request itself seems reasonable
      return
    unless i of @_tabIdToArray
      @_tabIdToArray[i] = []
      @_tabIdToStats[i] = new Stats
    @_tabIdToArray[i].push [origin, dest, context, decision]
    @_tabIdToStats[i].hit origin, dest, context, decision

  getByTabId: (tabId) ->
    return @_tabIdToArray[tabId] or []
  getStatsByTabId: (tabId) ->
    return @_tabIdToStats[tabId] or new Stats

  getByTab: (tab) ->
    return @getByTabId tabs.getTabId tab
  getStatsByTab: (tab) ->
    return @getStatsByTabId tabs.getTabId tab

  getByWindow: (win) ->
    [].concat (@getByTabId tabs.getTabId tab for tab in win.gBrowser.tabs)...

  getAll: ->
    [].concat (quads for tab, quads of _tabIdToArray)...


