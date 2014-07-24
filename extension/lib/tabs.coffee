

{ windows } = require 'windows'
{ Handlers } = require 'utils'

exports.tabs = tabs =
  onOpen: new Handlers
  onClose: new Handlers
  onSelect: new Handlers

  list: []

  init: ->
    listeners =
      TabOpen: (e) => @onOpen.execute e.target
      TabClose: (e) => @onClose.execute e.target
      TabSelect: (e) => @onSelect.execute e.target

    addListeners = (tabContainer) ->
      tabContainer.addEventListener e, h for e, h of listeners

    removeListeners = (tabContainer) ->
      tabContainer.removeEventListener e, h for e, h of listeners

    addListeners(win.gBrowser.tabContainer) for win in windows.list
    onShutdown.add ->
      removeListeners(win.gBrowser.tabContainer) for win in windows.list

    windows.onOpen.add (w) =>
      # pretend that tabs, that were already in new window, just opened
      @onOpen.execute(t) for t in w.gBrowser.tabs
      addListeners w.gBrowser.tabContainer
    windows.onClose.add (w) =>
      # pretend that tabs, that were in closed window, closed
      @onClose.execute(t) for t in w.gBrowser.tabs
      removeListeners w.gBrowser.tabContainer

    @onOpen.add (t) => @list.push t
    @onClose.add (t) => @list = @list.filter (t_) -> t_ isnt t

  getTabId: (tab) ->
    # not a DOM id or smth, just a unique string
    # copypasted from addon-sdk/lib/tabs/utils.js#getTabId
    String.split(tab.linkedPanel, 'panel').pop()

  getCurrent: -> windows.getCurrent().gBrowser.tabContainer.tabbox.selectedTab

do tabs.init
