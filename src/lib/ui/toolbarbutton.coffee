

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
    @wrapper = CustomizableUI.createWidget
        id:              @id
        type:            'custom'
        defaultArea:     CustomizableUI.AREA_NAVBAR
        onBuild:         @onBuild.bind @
    CustomizableUI.addListener
        onWidgetAdded:   (id) => if id == @id then @onWidgetAdded arguments...
        onWidgetRemoved: (id) => if id == @id then @onWidgetRemoved arguments...
    onShutdown.add => CustomizableUI.destroyWidget @id

    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

  _getAreaTypeSpecificWidget: (areaType=@wrapper.areaType) ->
    if areaType == CustomizableUI.TYPE_MENU_PANEL
      return panelview
    return popup

  onBuild: (doc) ->
    btn = createElement doc, 'toolbarbutton',
      id:              @id
      class:           'toolbarbutton-1 chromeclass-toolbar-additional'
      label:           'Policeman'
      tooltiptext:     l10n 'toolbarbutton.tip'
      closemenu:       'none'
    btn.addEventListener 'command', (e) =>
      @_getAreaTypeSpecificWidget().onToobarbuttonCommand e
    return btn

  onWidgetAdded: (_, area) ->
    areaWidget = @_getAreaTypeSpecificWidget CustomizableUI.getAreaType area
    areaWidget.addUI w.document for w in windows.list

  onWidgetRemoved: (_, area) ->
    areaWidget = @_getAreaTypeSpecificWidget CustomizableUI.getAreaType area
    areaWidget.removeUI w.document for w in windows.list

  addUI: (win) ->
    @_getAreaTypeSpecificWidget().addUI win.document

    loadSheet win, @styleURI

  removeUI: (win) ->
    @_getAreaTypeSpecificWidget().removeUI win.document

    removeSheet win, @styleURI

do toolbarbutton.init
