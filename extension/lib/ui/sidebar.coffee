
{ windows } = require 'windows'
{ createElement, removeNode } = require 'utils'

{ l10n } = require 'l10n'

exports.sidebar = sidebar =
  init: ->
    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

  addUI: (win) ->
    doc = win.document
#     doc.loadOverlay 'chrome://policeman/content/sidebar-overlay.xul', null
    ###
    Loading that overlay seems to break panelview overlay loading,
    presumably due to #330458 or for some other reason (may be our own BUG).
    As a workaround, code below (being a straightforward translation
    of sidebar-overlay.xul) does effectively what the loadOverlay call would
    have done.
    File itself is kept in hope of finding a better workaround or a bug being
    fixed some day.
    If it really is #330458, another possible workaround is to create overlays
    queue.
    ###
    doc.getElementById('viewSidebarMenu').appendChild createElement doc,
      'menuitem',
        id: "menu_policemanSidebar"
        key: "key_openPolicemanSidebar"
        observes: "viewPolicemanSidebar"
        label: l10n "policeman"
    doc.getElementById('mainKeyset').appendChild createElement doc,
      'key',
        id: "key_openPolicemanSidebar"
        command: "viewPolicemanSidebar"
        key: "P"
        modifiers: "shift accel"
    doc.getElementById('mainBroadcasterSet').appendChild createElement doc,
      'broadcaster',
        id: "viewPolicemanSidebar"
        autoCheck: "false"
        type: "checkbox"
        group: "sidebar"
        sidebarurl: "chrome://policeman/content/sidebar-page.xul"
        sidebartitle: l10n "policeman"
        oncommand: "toggleSidebar('viewPolicemanSidebar');"

  removeUI: (win) ->
    doc = win.document
    removeNode doc.getElementById id for id in [
      # ids of nodes added by sidebar-overlay.xul
      'menu_policemanSidebar',
      'key_openPolicemanSidebar',
      'viewPolicemanSidebar',
    ]

do sidebar.init
