

{
  loadSheet
  removeSheet
  Handlers
} = require 'utils'
{ windows } = require 'windows'

{ CustomizableUI } = Cu.import "resource:///modules/CustomizableUI.jsm"
{ panelview } = require 'ui/panelview'

{ l10n } = require 'l10n'

exports.toolbarbutton = toolbarbutton =
  id: 'policeman-toolbarbutton'

  styleURI: Services.io.newURI 'chrome://policeman/skin/toolbar.css', null, null

  onViewShowing: new Handlers
  onViewHiding: new Handlers

  init: ->
    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

    @wrapper = CustomizableUI.createWidget
        id:              @id
        type:            'view'
        label:           'Policeman'
        tooltiptext:     l10n 'widget.tip'
        defaultArea:     CustomizableUI.AREA_NAVBAR
        viewId:          panelview.id
        onViewShowing:   panelview.onShowing.execute.bind panelview.onShowing
        onViewHiding:    panelview.onHiding.execute.bind panelview.onHiding
    onShutdown.add => CustomizableUI.destroyWidget @id

  addUI: (win) ->
    panelview.addUI win.document

    loadSheet win, @styleURI

  removeUI: (win) ->
    panelview.removeUI win.document

    removeSheet win, @styleURI

do toolbarbutton.init
