
{ prefs } = require 'prefs'
{ manager } = require 'ruleset/manager'
{ tabs } = require 'tabs'
{
  createElement
  removeChildren
  removeNode
} = require 'utils'
{ path } = require 'file'

{ l10n } = require 'l10n'


prompt = Cc["@mozilla.org/embedcomp/prompt-service;1"]
          .getService(Ci.nsIPromptService)

filepicker = Cc["@mozilla.org/filepicker;1"]
          .createInstance(Ci.nsIFilePicker)
filepicker.init(window, l10n('install_file_dialog'), Ci.nsIFilePicker.modeOpen)


window.top.location.hash = "#rulesets-manager"


RULESET_CONTENT_TYPE = 'application/x-policeman-ruleset'


class ContextMenu
  init: (@list, @menupopupSelector) ->
    @$ = $ @menupopupSelector

    @_visitHomepageMenu = @$.getElementsByClassName('menu-visit-homepage')[0]
    @_visitHomepageMenu.addEventListener 'command', @_visitHomepageCommand.bind @

    @_viewSourceMenu = @$.getElementsByClassName('menu-view-source')[0]
    @_viewSourceMenu.addEventListener 'command', @_viewSourceCommand.bind @

  _visitHomepageCommand: ->
    id = InstalledRulesetRichListItem::getData @list.$.selectedItem
    { homepage } = snapshot.getMetadata id
    tabs.open homepage

  _viewSourceCommand: ->
    id = InstalledRulesetRichListItem::getData @list.$.selectedItem
    { sourceUrl } = snapshot.getMetadata id
    tabs.open "view-source:#{ sourceUrl }"

  open: (x, y) ->
    id = InstalledRulesetRichListItem::getData @list.$.selectedItem

    rulesetMetadata = snapshot.getMetadata id
    @_beforeOpen rulesetMetadata

    @$.openPopupAtScreen x, y, true

  _beforeOpen: ({sourceUrl, homepage}) ->
    @_viewSourceMenu.disabled = not sourceUrl
    @_visitHomepageMenu.disabled = not homepage


installedMenu = new class extends ContextMenu
  init: ->
    super installedList, '#installed-ruleset-menu'

    @_enableMenu = @$.getElementsByClassName('menu-enable')[0]
    @_enableMenu.addEventListener 'command', @_enableCommand.bind @

    @_removeMenu = @$.getElementsByClassName('menu-uninstall')[0]
    @_removeMenu.addEventListener 'command', @_removeCommand.bind @

  _enableCommand: ->
    id = InstalledRulesetRichListItem::getData @list.$.selectedItem
    snapshot.enable id
    updateUi()

  _removeCommand: ->
    id = InstalledRulesetRichListItem::getData @list.$.selectedItem
    snapshot.uninstall id
    updateUi()

  _beforeOpen: (rulesetMetadata) ->
    super rulesetMetadata
    { id } = rulesetMetadata

    enabled = snapshot.enabled id
    embedded = id in snapshot.embeddedRuleSets
    @_enableMenu.disabled = enabled
    @_removeMenu.disabled = embedded


enabledMenu = new class extends ContextMenu
  init: ->
    super enabledList, '#enabled-ruleset-menu'

    @_disableMenu = @$.getElementsByClassName('menu-disable')[0]
    @_disableMenu.addEventListener 'command', @_disableCommand.bind @

  _disableCommand: ->
    id = InstalledRulesetRichListItem::getData @list.$.selectedItem
    snapshot.disable id
    updateUi()

  _beforeOpen: (rulesetMetadata) ->
    super rulesetMetadata
    { id } = rulesetMetadata

    enabled = snapshot.enabled id
    @_disableMenu.disabled = not enabled


class RulesetRichListItem
  create: (doc, widgetDescription) ->
    {
      id
      name
      description
      version
      sourceUrl
      permissiveness

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

    draggableBox.appendChild createElement doc, 'image',
      class: 'ruleset-icon'
      src: "chrome://policeman/skin/ruleset-#{permissiveness}-icon-16.png"
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
        updateUi()

    canUninstall = snapshot.canUninstall id

    item.appendChild removeBtn = createElement document, 'button',
      class: 'ruleset-uninstall'
      label: l10n 'preferences_uninstall'
      icon: 'remove'
      disabled: not canUninstall
    if not canUninstall
      removeBtn.setAttribute 'tooltiptext', l10n 'preferences_uninstall.embedded.tip'
    else
      removeBtn.addEventListener 'command', ->
        snapshot.uninstall id
        updateUi()

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
      disabled: not snapshot.canDisable id
    disableBtn.addEventListener 'command', disableCommand = ->
      snapshot.disable id
      updateUi()

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

      updateUi()

    @update()

  update: ->
    removeChildren @$

    for rs in snapshot.getInstalledMetadata()
      @$.appendChild InstalledRulesetRichListItem::create document, rs


class DownloadsRichListItem
  create: (doc, widgetDescription) ->
    {
      link
      abort
    } = widgetDescription

    item = createElement doc, 'richlistitem',
      class: 'download'

    item.appendChild vbox = createElement doc, 'vbox',
      flex: 1

    vbox.appendChild createElement doc, 'hbox',
      flex: 1
      _children_:
        label:
          class: 'text-link download-link'
          value: link
          crop: 'start'
          flex: 1
        spacer:
          flex: 1

    vbox.appendChild hbox = createElement doc, 'hbox',
      align: 'center'
      flex: 1

    hbox.appendChild createElement doc, 'label',
      class: 'download-progress'
      value: l10n 'preferences_download_install_starting'

    hbox.appendChild createElement doc, 'progressmeter',
      class: 'download-progressmeter'
      mode: 'undetermined'
      flex: 1

    hbox.appendChild createElement doc, 'spacer',
      flex: 1

    hbox.appendChild createElement doc, 'button',
      class: 'download-abort-button'
      label: l10n 'preferences_download_install_abort'
      icon: "cancel"
      event_click: abort

    return item

  setProgress: (item, {phase, progress}) ->
    meter = item.getElementsByClassName('download-progressmeter')[0]
    label = item.getElementsByClassName('download-progress')[0]

    label.value = l10n "preferences_download_install_#{phase}"
    if progress is undefined
      meter.mode = 'undetermined'
    else
      meter.mode = 'determined'
      meter.value = (progress * 100) // 1

  setFailed: (item, error) ->
    meter = item.getElementsByClassName('download-progressmeter')[0]
    label = item.getElementsByClassName('download-progress')[0]

    meter.hidden = true
    label.value = l10n('preferences_download_install_failed') + if error \
      then ': ' + error.message \
      else ''


downloadsList =
  init: ->
    @$ = $ '#downloads-list'
    @$.hidden = yes

  add: (link) ->
    item = null
    snapshot.downloadInstall link,
      start: ({abort}) =>
        @_addItem item = DownloadsRichListItem::create document, {link, abort}
      progress: ({phase, progress}) ->
        DownloadsRichListItem::setProgress item, {phase, progress}
      error: (e) ->
        DownloadsRichListItem::setFailed item, e
      abort: =>
        @_removeItem item
      success: =>
        @_removeItem item
        updateUi()

  _addItem: (item) ->
    @$.appendChild item
    @$.hidden = not @$.childNodes.length
  _removeItem: (item) ->
    removeNode item
    @$.hidden = not @$.childNodes.length



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

      updateUi()

    @update()

  update: ->
    removeChildren @$

    for rs in snapshot.getEnabledMetadata()
      @$.appendChild EnabledRulesetRichListItem::create document, rs


updateUi = ->
  installedList.update()
  enabledList.update()
  buttons.update()


snapshot = null

man =
  restore: ->
    if snapshot
      snapshot.destroy()
    snapshot = manager.snapshot()
  save: ->
    manager.loadSnapshot snapshot

do man.restore


buttons =
  init: ->
    @restoreBtn = $ '#restore'
    @saveBtn = $ '#save'
    @installFileBtn = $ '#install-file'
    @installLinkBtn = $ '#install-link'

    @restoreBtn.addEventListener 'command', ->
      man.restore()
      updateUi()
    @saveBtn.addEventListener 'command', ->
      man.save()
      updateUi()
    @installFileBtn.addEventListener 'command', ->
      res = filepicker.show()
      if res != Ci.nsIFilePicker.returnCancel
        downloadsList.add path.toURI(filepicker.file).spec
    @installLinkBtn.addEventListener 'command', ->
      links = value: ''
      result = prompt.prompt null,
          l10n('install_link_dialog'),
          l10n('install_link_dialog.body'),
          links,
          null,
          {}
      if result and links.value
        for link in links.value.split(' ')
          if link
            downloadsList.add link



  update: ->
    @restoreBtn.disabled = not snapshot.somethingChanged()
    @saveBtn.disabled = not snapshot.somethingChanged()


onLoad = ->
  buttons.init()
  installedMenu.init()
  enabledMenu.init()
  installedList.init()
  enabledList.init()
  downloadsList.init()


window.addEventListener 'beforeunload', (e) ->
  if snapshot.somethingChanged()
    man.save()
  snapshot.destroy()
