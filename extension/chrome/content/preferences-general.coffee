

{ manager } = require 'ruleset/manager'
{ popup } = require 'ui/popup'


window.top.location.hash = "#general"


checkbox = (selector, initialState, oncommand) ->
  cb = $ selector
  cb.checked = initialState
  cb.addEventListener 'command', oncommand


onLoad = ->
  checkbox '#suspended', manager.suspended(), ->
    if @checked
      manager.suspend()
    else
      manager.unsuspend()

  checkbox '#autoreload', popup.autoreload.enabled(), ->
    if @checked
      popup.autoreload.enable()
    else
      popup.autoreload.disable()
