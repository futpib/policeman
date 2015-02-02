

temporaryRuleMenu =
  init: ->
    @$ = $ '#temporary-rule-menu'
    $('#temporary-rule-menu > .menu-remove').addEventListener 'command', ->
      selectedRows = temporaryRules.getSelectedRows()
      for i in selectedRows
        [o, d, t] = temporaryRules.getRule i
        manager.get('user_temporary').revoke o, d, t
      temporaryRules.update()
    $('#temporary-rule-menu > .menu-edit').addEventListener 'command', ->
      [ selectedIndex ] = temporaryRules.getSelectedRows()
      addTemporaryRuleWidget.edit temporaryRules.getRule selectedIndex
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
    $('#persistent-rule-menu > .menu-edit').addEventListener 'command', ->
      [ selectedIndex ] = persistentRules.getSelectedRows()
      addPersistentRuleWidget.edit persistentRules.getRule selectedIndex
  open: (x, y) ->
    @$.openPopupAtScreen x, y, true


addTemporaryRuleWidget = new (class extends AddRuleWidget
  _updateRuleset: ->
    super arguments...
    temporaryRules.update()
) '#add-temporary-rule-container', 'user_temporary'

addPersistentRuleWidget = new (class extends AddRuleWidget
  _updateRuleset: ->
    super arguments...
    persistentRules.update()
) '#add-persistent-rule-container', 'user_persistent'


class EditableRulesTree extends RulesTree
  constructor: (options) ->
    {
      containerSelector
      searchSelector
      ruleset
      contextMenu: @_contextMenu
      addRuleWidget: @_addRuleWidget
    } = options
    super containerSelector, searchSelector, ruleset

  init: ->
    super arguments...
    @$.addEventListener 'dblclick', (event) =>
      return unless event.target.nodeName == 'treechildren'
      @_onTreechildrenDblclick event

  _onTreechildrenContextMenu: (e) ->
    super arguments...
    @_contextMenu.open e.screenX, e.screenY

  _onTreechildrenDblclick: (e) ->
    [ selectedIndex ] = @getSelectedRows()
    @_addRuleWidget.edit @getRule selectedIndex


persistentRules = new EditableRulesTree
  containerSelector: '#persistent-rules'
  searchSelector: '#persistent-rules-search-box'
  ruleset: 'user_persistent'
  contextMenu: persistentRuleMenu
  addRuleWidget: addPersistentRuleWidget

temporaryRules = new EditableRulesTree
  containerSelector: '#temporary-rules'
  searchSelector: '#temporary-rules-search-box'
  ruleset: 'user_temporary'
  contextMenu: temporaryRuleMenu
  addRuleWidget: addTemporaryRuleWidget


onLoad = ->
  if manager.enabled 'user_temporary'
    temporaryRules.init()
    temporaryRuleMenu.init()
    addTemporaryRuleWidget.init()
  else
    $('#temporary-rules-container').hidden = yes

  if manager.enabled 'user_persistent'
    persistentRules.init()
    persistentRuleMenu.init()
    addPersistentRuleWidget.init()
  else
    $('#persistent-rules-container').hidden = yes

  if $('#temporary-rules-container').hidden \
  and $('#persistent-rules-container').hidden
    $('#user-rulesets-diabled-container').hidden = no
