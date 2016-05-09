

{ windows } = require 'lib/windows'
{ Handlers } = require 'lib/utils'

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
    @list.push t for t in win.gBrowser.tabs for win in windows.list
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
    return tab if typeof tab is 'string'
    # returns DOM id of linked panel
    # inspired by addon-sdk/lib/tabs/utils.js#getTabId
    return tab.linkedPanel

  getTabById: (id) ->
    for tab in @list
      return tab if id == @getTabId tab
    return null

  getCurrent: -> windows.getCurrent().gBrowser.tabContainer.tabbox.selectedTab

  getWindowOwner: (win) ->
    return null unless win
    for tab in @list
      if tab.linkedBrowser.contentWindow == win.top
        return tab
    return null

  getNodeOwner: (node) -> @getWindowOwner node.ownerDocument.defaultView.top

  reload: (tab) -> tab.linkedBrowser.reload()

  open: (url, reuse=on) ->
    if reuse
      for t in @list
        if t.linkedBrowser.contentDocument.location.href == url
          windows.getCurrent().gBrowser.selectedTab = t
          return
    bro = windows.getCurrent().gBrowser
    bro.selectedTab = bro.addTab url

do tabs.init
