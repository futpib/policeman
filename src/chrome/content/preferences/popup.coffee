

{ manager } = require 'ruleset/manager'
{ popup } = require 'ui/popup'

{ ContextInfo } = require 'request-info'

{ l10n } = require 'l10n'


USER_AVAILABLE_CONTENT_TYPES = ContextInfo::USER_AVAILABLE_CONTENT_TYPES

checkbox = (selector, initialState, oncommand) ->
  cb = $ selector
  cb.checked = initialState
  cb.addEventListener 'command', oncommand

onLoad = ->
  checkbox '#autoreload', popup.autoreload.enabled(), ->
    if @checked
      popup.autoreload.enable()
    else
      popup.autoreload.disable()

  checkbox '#show-zero-content-type-filters', popup.filters.enabledEmpty(), ->
    if @checked
      popup.filters.enableEmpty()
    else
      popup.filters.disableEmpty()

  groupbox = $ '#content-type-groupbox'
  for type in USER_AVAILABLE_CONTENT_TYPES
    id = "content-type-checkbox-#{type}"
    groupbox.appendChild cb = createElement 'checkbox',
      id: id
      label: l10n "content_type.title.plural.#{type}"
    if type == ContextInfo::WILDCARD_TYPE
      cb.disabled = true

    checkbox "##{id}", popup.contentTypes.enabled(type), do (type) -> ->
      if @checked
        popup.contentTypes.enable type
      else
        popup.contentTypes.disable type
