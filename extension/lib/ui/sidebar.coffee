
{ windows } = require 'windows'
{ createElement, removeNode } = require 'utils'
{ overlayQueue } = require 'ui/overlay-queue'

{ l10n } = require 'l10n'

exports.sidebar = sidebar =
  init: ->
    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

  addUI: (win) ->
    doc = win.document
    overlayQueue.add doc, 'chrome://policeman/content/sidebar-overlay.xul'

  removeUI: (win) ->
    doc = win.document
    removeNode doc.getElementById id for id in [
      # ids of nodes added by sidebar-overlay.xul
      'menu_policemanSidebar',
      'key_openPolicemanSidebar',
      'viewPolicemanSidebar',
    ]

do sidebar.init
