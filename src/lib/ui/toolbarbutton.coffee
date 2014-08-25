

{
  createElement
  loadSheet
  removeSheet
  Handlers
} = require 'utils'
{ windows } = require 'windows'

{ CustomizableUI } = Cu.import "resource:///modules/CustomizableUI.jsm"
{ panelview } = require 'ui/panelview'
{ popup } = require 'ui/popup'

{ l10n } = require 'l10n'

exports.toolbarbutton = toolbarbutton =
  id: 'policeman-toolbarbutton'

  styleURI: Services.io.newURI 'chrome://policeman/skin/toolbar.css', null, null

  init: ->
    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

    @wrapper = CustomizableUI.createWidget
        id:              @id
        type:            'custom'
        defaultArea:     CustomizableUI.AREA_NAVBAR
        onBuild:         @onBuild.bind @
    onShutdown.add => CustomizableUI.destroyWidget @id

  onBuild: (doc) ->
    btn = createElement doc, 'toolbarbutton',
      id:              @id
      class:           'toolbarbutton-1 chromeclass-toolbar-additional'
      label:           'Policeman'
      tooltiptext:     l10n 'toolbarbutton.tip'
      closemenu:       'none'
    btn.addEventListener 'command', (e) =>
      inMenu = @wrapper.areaType == CustomizableUI.TYPE_MENU_PANEL
      (if inMenu then panelview else popup).onToobarbuttonCommand e
    return btn

  addUI: (win) ->
    panelview.addUI win.document
    popup.addUI win.document

    loadSheet win, @styleURI

  removeUI: (win) ->
    panelview.removeUI win.document
    popup.removeUI win.document

    removeSheet win, @styleURI

do toolbarbutton.init
