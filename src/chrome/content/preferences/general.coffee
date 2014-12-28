

{ manager } = require 'ruleset/manager'
{ panelview } = require 'ui/panelview'
{ toolbarbutton } = require 'ui/toolbarbutton'
{ blockedElements } = require 'blocked-elements'

{ l10n } = require 'l10n'


checkbox = (selector, initialState, oncommand) ->
  cb = $ selector
  cb.checked = initialState
  cb.addEventListener 'command', oncommand


toolbarbuttonEvents = (container, eventName) ->
  container = $ container

  selectedAction = toolbarbutton.events.getAction eventName

  menuitems = {}
  for action in ['noop', 'openWidget', 'openPreferences', 'toggleSuspended',
                 'toggleTabSuspended', 'removeTemporaryRules']
    menuitems["menuitem_#{action}"] =
      label: l10n "preferences_toolbarbutton_actions.#{action}"
      selected: action is selectedAction
      event_command: do (action=action) -> ->
        toolbarbutton.events.setAction eventName, action

  container.appendChild createElement 'hbox',
    align: 'center'
    _children_:
      label:
        value: l10n "preferences_toolbarbutton_events.#{eventName}"
      menulist:
        _children_:
          menupopup:
            _children_: menuitems


blockedElementHandling = (kwargs) ->
  {
    type
    enabledCheckbox
    handlersRadiogroup
  } = kwargs

  enableCheckbox = $ enabledCheckbox
  handlersRadiogroup = $ handlersRadiogroup

  currentHandler = blockedElements.getHandler type
  enableCheckbox.checked = currentHandler != 'passer'
  handlersRadiogroup.disabled = currentHandler == 'passer'

  updateRadios = ->
    currentHandler = blockedElements.getHandler type
    for i in [0...handlersRadiogroup.itemCount]
      handlerRadio = handlersRadiogroup.getItemAtIndex i
      handler = handlerRadio.getAttribute 'policeman-handler'
      if handler == currentHandler
        handlersRadiogroup.selectedIndex = i
  do updateRadios

  enableCheckbox.addEventListener 'CheckboxStateChange', ->
    if @checked
      handlersRadiogroup.disabled = false
      blockedElements.setHandler type, 'placeholder'
      do updateRadios
    else
      handlersRadiogroup.disabled = true
      blockedElements.setHandler type, 'passer'

  for i in [0...handlersRadiogroup.itemCount]
    handlerRadio = handlersRadiogroup.getItemAtIndex i
    handlerRadio.addEventListener 'RadioStateChange', ->
      if @selected
        blockedElements.setHandler type, @getAttribute 'policeman-handler'


onLoad = ->
  checkbox '#suspended', manager.suspended(), ->
    if @checked
      manager.suspend()
    else
      manager.unsuspend()

  checkbox '#autoreload-panelview', panelview.autoreload.enabled(), ->
    if @checked
      panelview.autoreload.enable()
    else
      panelview.autoreload.disable()

  toolbarbuttonEvents '#toolbarbutton-events', 'command'
  toolbarbuttonEvents '#toolbarbutton-events', 'middleClick'
  toolbarbuttonEvents '#toolbarbutton-events', 'mouseover'

  blockedElementHandling {
    type: 'image'
    enabledCheckbox: '#enable-image-handling'
    handlersRadiogroup: '#image-handling-radiogroup'
  }

  blockedElementHandling {
    type: 'frame'
    enabledCheckbox: '#enable-frame-handling'
    handlersRadiogroup: '#frame-handling-radiogroup'
  }

  blockedElementHandling {
    type: 'object'
    enabledCheckbox: '#enable-object-handling'
    handlersRadiogroup: '#object-handling-radiogroup'
  }

