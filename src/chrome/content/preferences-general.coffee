

{ manager } = require 'ruleset/manager'
{ popup } = require 'ui/popup'
{ panelview } = require 'ui/panelview'


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

  checkbox '#autoreload-popup', popup.autoreload.enabled(), ->
    if @checked
      popup.autoreload.enable()
    else
      popup.autoreload.disable()

  checkbox '#autoreload-panelview', panelview.autoreload.enabled(), ->
    if @checked
      panelview.autoreload.enable()
    else
      panelview.autoreload.disable()
