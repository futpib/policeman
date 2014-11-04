
{ prefs } = require 'prefs'
{ manager } = require 'ruleset/manager'
{ DomainDomainTypeRS } = require 'ruleset/code-ruleset'
{ tabs } = require 'tabs'
{
  createElement
  removeChildren
  mutateAttribute
} = require 'utils'

{ l10n } = require 'l10n'


CHROME_DOMAIN = DomainDomainTypeRS::CHROME_DOMAIN

localizeType = (t) -> l10n 'content_type.title.plural.' + t

localizeDecision = (d) -> l10n if d then 'allow' else 'reject'

localizeDomain = (d) ->
  if d == CHROME_DOMAIN
    return l10n 'preferences_chrome_domain'
  else if not d
    return l10n 'preferences_any_domain'
  else
    return d

window.top.location.hash = "#user-rulesets"


temporaryRuleMenu =
  init: ->
    @$ = $ '#temporary-rule-menu'
    $('#temporary-rule-menu > .menu-remove').addEventListener 'command', ->
      selectedRows = temporaryRules.getSelectedRows()
      for i in selectedRows
        [o, d, t] = temporaryRules.getRule i
        manager.get('user_persistent').revoke o, d, t
      temporaryRules.update()
    $('#temporary-rule-menu > .menu-promote').addEventListener 'command', ->
      selectedRows = temporaryRules.getSelectedRows()
      for i in selectedRows
        [o, d, t, decision] = temporaryRules.getRule i
        manager.get('user_temporary').revoke(o, d, t)
        manager.get('user_persistent')[if decision then 'allow' else 'reject'](o, d, t)
      temporaryRules.update()
      persistentRules.update()

  open: (x, y) ->
    @$.openPopupAtScreen x, y, true


persistentRuleMenu =
  init: ->
    @$ = $ '#persistent-rule-menu'
    $('#persistent-rule-menu > .menu-remove').addEventListener 'command', ->
      selectedRows = persistentRules.getSelectedRows()
      for i in selectedRows
        [o, d, t] = persistentRules.getRule i
        manager.get('user_persistent').revoke o, d, t
      persistentRules.update()
  open: (x, y) ->
    @$.openPopupAtScreen x, y, true


class AddRuleWidget
  constructor: (@_idPrefix, @_rulesetId, @_onAdd) ->

  init: ->
    @_decisionList = $ "##{ @_idPrefix }-decision"
    @_typeList = $ "##{ @_idPrefix }-type"
    @_originTextbox = $ "##{ @_idPrefix }-origin-domain"
    @_destinationTextbox = $ "##{ @_idPrefix }-destination-domain"

    webHostRe = ///
      ^(
        ([a-z0-9][a-z0-9-]*\.)+[a-z]+ # something like a domain name
        |([0-9]{1,3}\.){3}[0-9]{1,3}  # or ip4 address
      )?$
    ///i
    validateHost = (textbox) ->
      str = textbox.value.toLowerCase()
      return str if webHostRe.test str
      textbox.select()
      textbox.focus()
      return null

    add = =>
      allowReject = @_decisionList.selectedItem.value
      type = @_typeList.selectedItem.value
      origin = validateHost @_originTextbox
      destination = validateHost @_destinationTextbox
      return if origin is null or destination is null
      manager.get(@_rulesetId)[allowReject](origin, destination, type)
      @_onAdd()

    @_addButton = $ "##{ @_idPrefix }-button"
    @_addButton.addEventListener 'command', add

    addOnEnterPress = (event) ->
      if event.keyCode == 13 # Enter
        do add
    @_originTextbox.addEventListener 'keypress', addOnEnterPress
    @_destinationTextbox.addEventListener 'keypress', addOnEnterPress


addTemporaryRuleWidget = new AddRuleWidget 'add-temporary-rule', 'user_temporary', ->
  temporaryRules.update()
addPersistentRuleWidget = new AddRuleWidget 'add-persistent-rule', 'user_persistent', ->
  persistentRules.update()


class RulesTree
  COLUMNS_COUNT = 4

  constructor: (@_selector, @_searchSelector, @_rulesetId) ->

  init: ->
    @$ = $ @_selector
    @_searchBox = $ @_searchSelector

    that = this
    @$.addEventListener 'contextmenu', (event) ->
      return unless event.target.nodeName == 'treechildren' \
                    and that._treeView.selection.count > 0
      that._onTreechildrenContextMenu event

    @$.addEventListener 'keypress', (event) ->
      if event.keyCode == 46 # Delete
        selectedRows = that.getSelectedRows()
        for i in selectedRows
          [o, d, t] = that.getRule i
          manager.get(that._rulesetId).revoke o, d, t
        that.update()

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

  _onTreechildrenContextMenu: ->

  update: ->
    @_rows = []
    for rule in manager.get(@_rulesetId).toTable()
      [o, d, t, dec] = rule
      origin = localizeDomain o
      destination = localizeDomain d
      type = localizeType   t
      decision = localizeDecision dec
      if @_filter
        filter = @_filter.toLowerCase()
        continue unless origin.toLowerCase().contains(filter) \
          or destination.toLowerCase().contains(filter) \
          or type.toLowerCase().contains(filter) \
          or decision.toLowerCase().contains(filter)
      @_rows.push {
        decision,    0: decision
        type,        1: type
        origin,      2: origin
        destination, 3: destination
        length: 4
        source: rule
      }

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

persistentRules = new (class extends RulesTree
  _onTreechildrenContextMenu: (e) ->
    persistentRuleMenu.open e.screenX, e.screenY
) '#persistent-rules', '#persistent-rules-search-box', 'user_persistent'

temporaryRules = new (class extends RulesTree
  _onTreechildrenContextMenu: (e) ->
    temporaryRuleMenu.open e.screenX, e.screenY
) '#temporary-rules', '#temporary-rules-search-box', 'user_temporary'


onLoad = ->
  temporaryRules.init()
  persistentRules.init()
  temporaryRuleMenu.init()
  persistentRuleMenu.init()
  addTemporaryRuleWidget.init()
  addPersistentRuleWidget.init()
