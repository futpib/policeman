
{ prefs } = require 'prefs'
{ manager } = require 'ruleset/manager'
{ DomainDomainTypeRS } = require 'ruleset/code-based'
{ tabs } = require 'tabs'
{
  createElement
  removeChildren
} = require 'utils'

{ l10n } = require 'l10n'


WILDCARD_TYPE = DomainDomainTypeRS::WILDCARD_TYPE

localizeTypeLookup =
  IMAGE: l10n 'preferences_type_image'
  STYLESHEET: l10n 'preferences_type_stylesheet'
  SCRIPT: l10n 'preferences_type_script'
  SUBDOCUMENT: l10n 'preferences_type_subdocument'
  OBJECT: l10n 'preferences_type_object'
localizeTypeLookup[WILDCARD_TYPE] = l10n 'preferences_type_wildcard'
localizeType = (t) -> localizeTypeLookup[t]

localizeDecision = (d) -> l10n if d then 'allow' else 'reject'

L10N_ANY_DOMAIN = l10n 'preferences_any_domain'


window.top.location.hash = "#user-rulesets"


temporaryRuleMenu =
  init: ->
    @$ = $ '#temporary-rule-menu'
    $('#temporary-rule-menu > .menu-remove').addEventListener 'command', ->
      item = temporaryRules.$.selectedItem
      o = Rule::getOrigin item
      d = Rule::getDestination item
      t = Rule::getType item
      manager.get('user_temporary').revoke(o, d, t)
      temporaryRules.update()
    $('#temporary-rule-menu > .menu-promote').addEventListener 'command', ->
      item = temporaryRules.$.selectedItem
      o = Rule::getOrigin item
      d = Rule::getDestination item
      t = Rule::getType item
      decision = Rule::getDecision item
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
      item = persistentRules.$.selectedItem
      o = Rule::getOrigin item
      d = Rule::getDestination item
      t = Rule::getType item
      manager.get('user_persistent').revoke(o, d, t)
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

    validateDomain = (textbox) ->
      str = textbox.value
      return str if /^(([a-z]+\.)+[a-z]+)?$/.test str
      textbox.select()
      textbox.focus()
      return null

    @_addButton = $ "##{ @_idPrefix }-button"
    @_addButton.addEventListener 'command', =>
      allowReject = @_decisionList.selectedItem.value
      type = @_typeList.selectedItem.value
      origin = validateDomain @_originTextbox
      destination = validateDomain @_destinationTextbox
      return if origin is null or destination is null
      manager.get(@_rulesetId)[allowReject](origin, destination, type)
      @_onAdd()


addTemporaryRuleWidget = new AddRuleWidget 'add-temporary-rule', 'user_temporary', ->
  temporaryRules.update()
addPersistentRuleWidget = new AddRuleWidget 'add-persistent-rule', 'user_persistent', ->
  persistentRules.update()


class Rule
  create: (description) ->
    {
      origin
      destination
      type
      decision
    } = description
    row = createElement document, 'listitem',
      'data-policeman-origin': origin
      'data-policeman-destination': destination
      'data-policeman-type': type
      'data-policeman-decision': decision
    row.appendChild createElement document, 'listcell',
      label: localizeDecision decision
    row.appendChild createElement document, 'listcell',
      label: localizeType type
    row.appendChild createElement document, 'listcell',
      label: origin or L10N_ANY_DOMAIN
    row.appendChild createElement document, 'listcell',
      label: destination or L10N_ANY_DOMAIN
    return row

  getOrigin: (el) -> el.getAttribute 'data-policeman-origin'
  getDestination: (el) -> el.getAttribute 'data-policeman-destination'
  getType: (el) -> el.getAttribute 'data-policeman-type'
  getDecision: (el) -> 'true' == el.getAttribute 'data-policeman-decision'


class TemporaryRule extends Rule
  create: (description) ->
    row = super arguments...
    row.addEventListener 'contextmenu', (e) ->
      temporaryRuleMenu.open e.screenX, e.screenY
    return row


class PersistentRule extends Rule
  create: (description) ->
    row = super arguments...
    row.addEventListener 'contextmenu', (e) ->
      persistentRuleMenu.open e.screenX, e.screenY
    return row


class RulesList
  constructor: (@_selector, @_searchSelector, @_rulesetId) ->

  init: ->
    @$ = $ @_selector
    @_searchBox = $ @_searchSelector
    @_searchBox.addEventListener 'command', do (that=@) -> ->
      that._filter = @value
      that.update()
    @update()

  _ruleClass: Rule

  update: ->
    removeChildren @$, 'listitem'
    for [o, d, t, decision] in manager.get(@_rulesetId).toTable()
      if @_filter
        continue unless (o or L10N_ANY_DOMAIN).contains(@_filter.toLowerCase()) \
          or (d or L10N_ANY_DOMAIN).contains(@_filter.toLowerCase()) \
          or localizeType(t).toLowerCase().contains(@_filter.toLowerCase()) \
          or localizeDecision(t).toLowerCase().contains(@_filter.toLowerCase())
      @$.appendChild @_ruleClass::create {
        origin: o
        destination: d
        type: t
        decision: decision
      }


class TemporaryRulesList extends RulesList
  _ruleClass: TemporaryRule


class PersistentRulesList extends RulesList
  _ruleClass: PersistentRule


temporaryRules = new TemporaryRulesList '#temporary-rules', '#temporary-rules-search-box', 'user_temporary'
persistentRules = new PersistentRulesList '#persistent-rules', '#persistent-rules-search-box', 'user_persistent'

onLoad = ->
  temporaryRules.init()
  persistentRules.init()
  temporaryRuleMenu.init()
  persistentRuleMenu.init()
  addTemporaryRuleWidget.init()
  addPersistentRuleWidget.init()
