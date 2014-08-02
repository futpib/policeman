
{ prefs } = require 'prefs'
{ manager } = require 'ruleset/manager'
{ tabs } = require 'tabs'
{
  createElement
  removeChildren
} = require 'utils'

{ l10n } = require 'l10n'


window.top.location.hash = "#rulesets-manager"


snapshot = manager.snapshot()


RULESET_CONTENT_TYPE = 'application/x-policeman-ruleset'

installedMenu =
  init: ->
    @$ = $ '#installed-ruleset-menu'

    @_enableMenu = @$.getElementsByClassName('menu-enable')[0]
    @_enableMenu.addEventListener 'command', @_enableCommand

    @_viewSourceMenu = @$.getElementsByClassName('menu-view-source')[0]
    @_viewSourceMenu.addEventListener 'command', @_viewSourceCommand

    @_removeMenu = @$.getElementsByClassName('menu-uninstall')[0]
    @_removeMenu.addEventListener 'command', @_removeCommand

  _enableCommand: ->
    id = InstalledRulesetRichListItem::getData installedList.$.selectedItem
    snapshot.enable id
    installedList.update()
    enabledList.update()

  _removeCommand: ->
    id = InstalledRulesetRichListItem::getData installedList.$.selectedItem
    snapshot.uninstall id
    installedList.update()
    enabledList.update()

  _viewSourceCommand: ->
    id = InstalledRulesetRichListItem::getData installedList.$.selectedItem
    { sourceUrl } = snapshot.getMetadata id
    tabs.open "view-source:#{ sourceUrl }"

  open: (x, y) ->
    id = InstalledRulesetRichListItem::getData installedList.$.selectedItem

    { sourceUrl } = snapshot.getMetadata id

    enabled = snapshot.enabled id
    embedded = id in snapshot.embeddedRuleSets

    @_enableMenu.disabled = enabled
    @_viewSourceMenu.disabled = not sourceUrl
    @_removeMenu.disabled = embedded

    @$.openPopupAtScreen x, y, true


enabledMenu =
  init: ->
    @$ = $ '#enabled-ruleset-menu'

    @_disableMenu = @$.getElementsByClassName('menu-disable')[0]
    @_disableMenu.addEventListener 'command', @_disableCommand

    @_viewSourceMenu = @$.getElementsByClassName('menu-view-source')[0]
    @_viewSourceMenu.addEventListener 'command', @_viewSourceCommand

  _disableCommand: ->
    id = InstalledRulesetRichListItem::getData enabledList.$.selectedItem
    snapshot.disable id
    installedList.update()
    enabledList.update()

  _viewSourceCommand: ->
    id = InstalledRulesetRichListItem::getData enabledList.$.selectedItem
    { sourceUrl } = snapshot.getMetadata id
    tabs.open "view-source:#{ sourceUrl }"

  open: (x, y) ->
    id = InstalledRulesetRichListItem::getData enabledList.$.selectedItem

    { sourceUrl } = snapshot.getMetadata id

    enabled = snapshot.enabled id

    @_disableMenu.disabled = not enabled
    @_viewSourceMenu.disabled = not sourceUrl

    @$.openPopupAtScreen x, y, true


class RulesetRichListItem
  create: (doc, widgetDescription) ->
    {
      id
      name
      description
      version
      sourceUrl
      draggable
    } = widgetDescription

    item = createElement doc, 'richlistitem',
      class: 'ruleset'
    @setData item, id

    item.appendChild draggableBox = createElement doc, 'hbox',
      class: 'ruleset-draggable-part'
      tooltiptext: description
      align: 'center'
      flex: 1
      draggable: draggable

    item.addEventListener 'dragenter', (e) ->
      @classList.add 'dragover'

    item.addEventListener 'dragleave', (e) ->
      @classList.remove 'dragover'

    if draggable
      draggableBox.addEventListener 'dragstart', (e) ->
        e.dataTransfer.setData RULESET_CONTENT_TYPE, id

    draggableBox.appendChild createElement doc, 'label',
      class: 'ruleset-name'
      value: name
    draggableBox.appendChild createElement doc, 'label',
      class: 'ruleset-description'
      value: description
      crop: 'end'
      flex: 1
    draggableBox.appendChild createElement doc, 'spacer',
      flex: 1
    draggableBox.appendChild createElement doc, 'label',
      class: 'ruleset-version'
      value: version

    return item

  setData: (item, str) -> item.setAttribute('data', str)
  getData: (item) -> item.getAttribute('data')


class InstalledRulesetRichListItem extends RulesetRichListItem
  create: (doc, widgetDescription) ->
    {
      id
      name
      description
      version
      sourceUrl
    } = widgetDescription

    enabled = snapshot.enabled id

    widgetDescription.draggable = not enabled

    item = super doc, widgetDescription

    item.appendChild enableBtn = createElement document, 'button',
      class: 'ruleset-enable'
      label: l10n 'preferences_enable'
      icon: 'add'
      disabled: enabled
    if not enabled
      enableBtn.addEventListener 'command', ->
        snapshot.enable id
        installedList.update()
        enabledList.update()

    embedded = id in snapshot.embeddedRuleSets

    item.appendChild removeBtn = createElement document, 'button',
      class: 'ruleset-uninstall'
      label: l10n 'preferences_uninstall'
      icon: 'remove'
      disabled: embedded # disabled for embedded
    if embedded
      removeBtn.setAttribute 'tooltiptext', l10n 'preferences_uninstall.embedded.tip'
    else
      removeBtn.addEventListener 'command', ->
        snapshot.uninstall id
        installedList.update()
        enabledList.update()

    item.addEventListener 'contextmenu', (e) ->
      installedMenu.open e.screenX, e.screenY

    return item


class EnabledRulesetRichListItem extends RulesetRichListItem
  create: (doc, widgetDescription) ->
    widgetDescription.draggable = true

    item = super doc, widgetDescription

    {
      id
      name
      description
      version
      sourceUrl
    } = widgetDescription

    item.appendChild disableBtn = createElement document, 'button',
      class: 'ruleset-disable'
      label: l10n 'preferences_disable'
      icon: 'remove'
    disableBtn.addEventListener 'command', disableCommand = ->
      snapshot.disable id
      installedList.update()
      enabledList.update()

    item.addEventListener 'contextmenu', (e) ->
      enabledMenu.open e.screenX, e.screenY

    return item


installedList =
  init: ->
    @$ = $ '#installed-rulesets-list'

    @$.addEventListener 'dragover', (e) -> e.preventDefault()

    @$.addEventListener 'drop', (e) ->
      id = e.dataTransfer.getData RULESET_CONTENT_TYPE
      return if not id

      if snapshot.enabled id
        snapshot.disable id

      installedList.update()
      enabledList.update()

    @update()

  update: ->
    removeChildren @$

    for rs in snapshot.getInstalledMetadata()
      @$.appendChild InstalledRulesetRichListItem::create document, rs


enabledList =
  init: ->
    @$ = $ '#enabled-rulesets-list'

    @$.addEventListener 'dragover', (e) -> e.preventDefault()

    @$.addEventListener 'drop', (e) ->
      id = e.dataTransfer.getData RULESET_CONTENT_TYPE
      return if not id

      newIndex = Infinity

      count = enabledList.$.itemCount
      for i in [0...count]
        item = enabledList.$.getItemAtIndex i
        { top, bottom } = item.getBoundingClientRect()
        if top <= e.clientY <= bottom
          newIndex = i
          break

      snapshot.enable id, newIndex

      installedList.update()
      enabledList.update()

    @update()

  update: ->
    removeChildren @$

    for rs in snapshot.getEnabledMetadata()
      @$.appendChild EnabledRulesetRichListItem::create document, rs


onLoad = ->
  installedMenu.init()
  enabledMenu.init()
  installedList.init()
  enabledList.init()

window.addEventListener 'beforeunload', (e) ->
  if snapshot.somethingChanged()
    e.preventDefault()
