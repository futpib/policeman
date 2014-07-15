

{ windows } = require 'windows'
{ tabs } = require 'tabs'
{ OriginInfo, DestInfo, getWindowFromRequestContext } = require 'request-info'


update = (o1, o2) -> # recursively copy all (enumerable) properties from o2 to o1
  for k, v of o2
    if typeof v == 'object'
      unless k in o1
        o1[k] = {}
      update o1[k], v
    else
      o1[k] = v

###
Remembers requests attempted by each tab with corresponding decisions
###
exports.memo = memo =
  tabToOriginToDestToDecision: {}

  init: ->
    tabs.onClose.add @removeRequestsMadeByTab.bind @

  removeRequestsMadeByTab: (tab) ->
    tabId = tabs.getTabId tab
    delete @tabToOriginToDestToDecision[tabId]

  add: (origin, dest, context, decision) -> # gets stringified origin, dest and ctx
    tab = tabs.findTabThatOwnsDomWindow getWindowFromRequestContext context
    return unless tab

    tabId = tabs.getTabId tab
    unless tabId of @tabToOriginToDestToDecision
      @tabToOriginToDestToDecision[tabId] = {}
    unless origin of @tabToOriginToDestToDecision[tabId]
      @tabToOriginToDestToDecision[tabId][origin] = {}
    @tabToOriginToDestToDecision[tabId][origin][dest] = decision

#     log JSON.stringify @tabToOriginToDestToDecision

  getRequestsByTab: (tab) ->
    return @tabToOriginToDestToDecision[tabs.getTabId tab]

  getRequestsByWindow: (win) ->
    result = {}
    for tab in win.gBrowser.tabs
      update result, @getRequestsByTab(tab)
    return result

  getAllRequests: ->
    result = {}
    for map in @tabToOriginToDestToDecision
      update result, map
    return result

do memo.init
