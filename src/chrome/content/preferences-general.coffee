

{ manager } = require 'ruleset/manager'
{ panelview } = require 'ui/panelview'
{ blockedElements } = require 'blocked-elements'


window.top.location.hash = "#general"


checkbox = (selector, initialState, oncommand) ->
  cb = $ selector
  cb.checked = initialState
  cb.addEventListener 'command', oncommand


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

