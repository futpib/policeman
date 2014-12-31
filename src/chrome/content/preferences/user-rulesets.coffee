

temporaryRuleMenu =
  init: ->
    @$ = $ '#temporary-rule-menu'
    $('#temporary-rule-menu > .menu-remove').addEventListener 'command', ->
      selectedRows = temporaryRules.getSelectedRows()
      for i in selectedRows
        [o, d, t] = temporaryRules.getRule i
        manager.get('user_temporary').revoke o, d, t
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


addTemporaryRuleWidget = new (class extends AddRuleWidget
  _addButtonClick: ->
    super arguments...
    temporaryRules.update()
) '#add-temporary-rule-container', 'user_temporary'

addPersistentRuleWidget = new (class extends AddRuleWidget
  _addButtonClick: ->
    super arguments...
    persistentRules.update()
) '#add-persistent-rule-container', 'user_persistent'


persistentRules = new (class extends RulesTree
  _onTreechildrenContextMenu: (e) ->
    persistentRuleMenu.open e.screenX, e.screenY
) '#persistent-rules', '#persistent-rules-search-box', 'user_persistent'

temporaryRules = new (class extends RulesTree
  _onTreechildrenContextMenu: (e) ->
    temporaryRuleMenu.open e.screenX, e.screenY
) '#temporary-rules', '#temporary-rules-search-box', 'user_temporary'


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
