
{ l10n } = require 'l10n'

{ manager } = require 'ruleset/manager'
{ DomainDomainTypeRS } = require 'ruleset/in-memory-ruleset'

idnService = Cc["@mozilla.org/network/idn-service;1"]
              .getService Ci.nsIIDNService

{
  mutateAttribute
} = require 'utils'


{
  USER_AVAILABLE_CONTENT_TYPES
  WILDCARD_TYPE
} = DomainDomainTypeRS::


class AddRuleWidget
  constructor: (@_containerSelector, @_rulesetId) ->
    @_currentlyEditingRule = null

  init: ->
    container = $ @_containerSelector

    container.appendChild box = createElement 'hbox',
      align: 'center'
      flex: 1

    box.appendChild @_decisionList = createElement 'menulist',
      _children_:
        menupopup: {}

    for decision in ['allow', 'reject']
      @_decisionList.menupopup.appendChild createElement 'menuitem',
        label: l10n "preferences_custom_rule.#{decision}"
        value: decision
    @_decisionList.selectedIndex = 0

    box.appendChild @_typeList = createElement 'menulist',
      _children_:
        menupopup: {}

    for type in USER_AVAILABLE_CONTENT_TYPES
      @_typeList.menupopup.appendChild createElement 'menuitem',
        label: l10n "content_type.title.plural.#{type}"
        value: type
    @_typeList.selectedIndex = 0

    box.appendChild @_originTextbox = createElement 'textbox',
      placeholder: l10n "origin_domain"
      class: "compact"
      flex: 1

    box.appendChild @_destinationTextbox = createElement 'textbox',
      placeholder: l10n "destination_domain"
      class: "compact"
      flex: 1

    box.appendChild @_addButton = createElement 'button',
      label: l10n "preferences_custom_rule.add"
      icon: "add"
      event_command: @_addButtonClick.bind this

    addOnEnterPress = (event) =>
      if event.keyCode == 13 # Enter
        @_addButtonClick()
    @_originTextbox.addEventListener 'keypress', addOnEnterPress
    @_destinationTextbox.addEventListener 'keypress', addOnEnterPress

    box.appendChild @_saveButton = createElement 'button',
      label: l10n "preferences_custom_rule.save"
      icon: "save"
      hidden: yes
      event_command: @_saveButtonClick.bind this

    box.appendChild @_cancelEditingButton = createElement 'button',
      label: l10n "preferences_custom_rule.cancel_editing"
      icon: "cancel"
      hidden: yes
      event_command: @_cancelButtonClick.bind this

  WEB_HOST_RE = ///
    ^(
      ([^\.]+\.)+[^\.]+ # something like an IDN or ip4 address
    )?$
  ///i

  _validateHost: (textbox) ->
    str = textbox.value.toLowerCase()
    if idnService.isACE str
      # Doc on `nsIIDNService` says `convertToDisplayIDN` ensures that
      # the encoding is consistent with `nsIURI.host` which is precisely
      # what we want here
      str = idnService.convertToDisplayIDN str, no
    return str if WEB_HOST_RE.test str
    textbox.select()
    textbox.focus()
    return null

  _saveCurrentRule: ->
    allowReject = @_decisionList.selectedItem.value
    type = @_typeList.selectedItem.value
    origin = @_validateHost @_originTextbox
    destination = @_validateHost @_destinationTextbox
    return if origin is null or destination is null
    manager.get(@_rulesetId)[allowReject](origin, destination, type)

  _selectMenuitemByValue: (menulist, value) ->
    for i in [0...menulist.itemCount]
      if menulist.getItemAtIndex(i).value == value
        menulist.selectedIndex = i
        break

  _loadRuleForEditing: (rule) ->
    [o, d, t, dec] = rule
    @_originTextbox.value = o
    @_destinationTextbox.value = d
    @_selectMenuitemByValue @_typeList, t
    @_selectMenuitemByValue @_decisionList, dec

  _resetInputsState: ->
    @_loadRuleForEditing ['', '', WILDCARD_TYPE, yes]

  _addButtonClick: ->
    @_saveCurrentRule()
    @_updateRuleset()

  _saveButtonClick: ->
    return unless @_currentlyEditingRule
    [origin, destination, type] = @_currentlyEditingRule
    manager.get(@_rulesetId).revoke(origin, destination, type)
    @_saveCurrentRule()
    @cancelEditing()
    @_updateRuleset()

  _cancelButtonClick: ->
    @cancelEditing()

  _updateRuleset: ->

  edit: (rule) ->
    @_loadRuleForEditing rule
    @_currentlyEditingRule = rule
    @_addButton.hidden = yes
    @_saveButton.hidden = @_cancelEditingButton.hidden = no

  cancelEditing: ->
    @_resetInputsState()
    @_currentlyEditingRule = null
    @_addButton.hidden = no
    @_saveButton.hidden = @_cancelEditingButton.hidden = yes


class RulesTree
  constructor: (@_selector, @_searchSelector, @_rulesetOrId) ->

  _rulesTable: ->
    if 'function' == typeof @_rulesetOrId.toTable
      return @_rulesetOrId.toTable()
    if 'string' == typeof @_rulesetOrId
      return manager.get(@_rulesetOrId).toTable()
    if Array.isArray @_rulesetOrId
      return @_rulesetOrId
    return undefined

  _ruleset: ->
    if @_rulesetOrId instanceof DomainDomainTypeRS
      return @_rulesetOrId
    if 'string' == typeof @_rulesetOrId
      return manager.get(@_rulesetOrId)
    return undefined

  setDataSource: (source) ->
    @_rulesetOrId = source
    @update()

  init: ->
    @_searchBox = $ @_searchSelector

    container = $ @_selector
    container.appendChild @$ = createElement 'tree',
      flex: 1
      enableColumnDrag: "true"
      persist: "sortDirection sortResource"
      sortDirection: "ascending"
      sortResource: "description"

    @$.appendChild treecols = createElement 'treecols'
    @$.appendChild createElement 'treechildren'

    appendTreecol = (description) ->
      {
        label
        sortResource
      } = description
      treecols.appendChild createElement 'treecol',
        label: l10n label
        sortResource: sortResource
        persist: 'width ordinal hidden'
        flex: 1

    appendTreecol
      label: 'decision'
      sortResource: 'decision'
    appendTreecol
      label: 'content_type'
      sortResource: 'type'
    appendTreecol
      label: 'origin_domain'
      sortResource: 'origin'
    appendTreecol
      label: 'destination_domain'
      sortResource: 'destination'

    that = this
    @$.addEventListener 'contextmenu', (event) ->
      return unless event.target.nodeName == 'treechildren' \
                    and that._treeView.selection.count > 0
      that._onTreechildrenContextMenu event

    @$.addEventListener 'keypress', (event) ->
      if event.keyCode == 46 # Delete
        that._onDeleteKeyPress event

    for col in @$.getElementsByTagName 'treecol'
      col.addEventListener 'click', ->
        for col in that.$.getElementsByTagName 'treecol'
          if col isnt this
            col.removeAttribute 'sortDirection'
        mutateAttribute this, 'sortDirection', (order) ->
          if order == 'ascending' then 'descending' else 'ascending'
        that.$.setAttribute 'sortResource', this.getAttribute 'sortResource'
        that.$.setAttribute 'sortDirection', this.getAttribute 'sortDirection'
        that.update()

    @_searchBox.addEventListener 'command', ->
      that._filter = this.value
      that.update()
    @update()

  getSelectedRows: ->
    selection = @_treeView.selection
    selectedRows = []

    if selection.single
      selectedRows.push selection.currentIndex
      return selectedRows

    start = {}
    end = {}
    for i in [0...selection.getRangeCount()]
      selection.getRangeAt i, start, end
      for j in [start.value..end.value]
        selectedRows.push j
    return selectedRows

  getRule: (i) -> @_rows[i].source

  toTable: -> @_rows.map (row) -> row.source

  getSelectedTable: -> @_rows[i].source for i in @getSelectedRows()

  _onTreechildrenContextMenu: ->

  _onDeleteKeyPress: ->
    return unless ruleset = @_ruleset()
    selectedRows = @getSelectedRows()
    for i in selectedRows
      [o, d, t] = @getRule i
      ruleset.revoke o, d, t
    @update()

  localizeTypeLookup = {}
  for t in DomainDomainTypeRS::USER_AVAILABLE_CONTENT_TYPES
    localizeTypeLookup[t] = l10n 'content_type.title.plural.' + t

  localizeDomainLookup = {}
  localizeDomainLookup[''] = l10n 'preferences_any_domain'

  localizeDecisionLookup = {
    true: l10n 'allow'
    false: l10n 'reject'
  }

  update: ->
    @_rows = []
    for rule in @_rulesTable()
      [o, d, t, dec] = rule
      origin = if o of localizeDomainLookup \
               then localizeDomainLookup[o] \
               else o
      destination = if d of localizeDomainLookup \
                    then localizeDomainLookup[d] \
                    else d
      type = localizeTypeLookup[t]
      decision = localizeDecisionLookup[dec]
      @_rows.push {
        decision,    0: decision
        type,        1: type
        origin,      2: origin
        destination, 3: destination
        length: 4
        source: rule
      }

    if @_filter
      filter = @_filter.toLowerCase()
      @_rows = @_rows.filter ({origin, destination, type, decision}) ->
        return origin.toLowerCase().contains(filter) \
               or destination.toLowerCase().contains(filter) \
               or type.toLowerCase().contains(filter) \
               or decision.toLowerCase().contains(filter)

    sortResource = @$.getAttribute 'sortResource'
    sortDirection = if 'ascending' == @$.getAttribute 'sortDirection' \
      then 1 \
      else -1
    @_rows.sort (rowA, rowB) ->
      a = rowA[sortResource]
      b = rowB[sortResource]
      if a < b
        return - sortDirection
      if a > b
        return sortDirection
      return 0

    that = this
    @_treeView =
      rowCount: that._rows.length
      getCellText: (row, column) -> that._rows[row][column.index]
      setTree: (@treebox) ->
      cycleHeader: (col, elem) ->
      isContainer: (row) -> no
    @$.view = @_treeView


class DeepLookupRSFileFormat # export/import format definition
  versionToClass = Object.create null
  latestVersion = undefined
  register = (formatClass) ->
    versionToClass[formatClass::version] = formatClass
    latestVersion = formatClass::version
  getFormatByVersion = (version) -> new versionToClass[version]

  class FileFormat
    magic: 'policeman rules dump'
    version: undefined
    parse: (obj) -> # table (as defined by DomainDomainTypeRS::toTable)
    stringify: (table) -> # string

  register class FileFormat1 extends FileFormat
    version: '1'
    parse: (obj) -> obj.table
    stringify: (table) ->
      return JSON.stringify {
        magic: @magic
        version: @version
        table: table
      }

  stringify: (table) -> getFormatByVersion(latestVersion).stringify arguments...
  parse: (string) ->
    obj = JSON.parse string
    format = getFormatByVersion obj.version
    return format.parse obj
