

Cu.import 'resource://gre/modules/osfile.jsm'


{ foreign } = require 'prefs'
{ manager } = require 'ruleset/manager'
{ DomainDomainTypeRS } = require 'ruleset/in-memory-ruleset'

{
  zip
} = require 'utils'


WILDCARD_TYPE = DomainDomainTypeRS::WILDCARD_TYPE


loadedRules = new RulesTree \
  '#loaded-rules', '#loaded-rules-search-box', []

dumpLoader =
  init: ->
    table = []

    foreign.define rpOriginsPref = 'extensions.requestpolicy.allowedOrigins',
      default: ''
    foreign.define rpDestsPref = 'extensions.requestpolicy.allowedDestinations',
      default: ''
    foreign.define rpODPref = 'extensions.requestpolicy.allowedOriginsToDestinations',
      default: ''
    try
      origins = foreign.get(rpOriginsPref).split(' ')
      for o in origins
        continue unless o
        table.push [o, '', WILDCARD_TYPE, yes]
      dests = foreign.get(rpDestsPref).split(' ')
      for d in dests
        continue unless d
        table.push ['', d, WILDCARD_TYPE, yes]
      originsDests = foreign.get(rpODPref).split(' ').map((s) -> s.split('|'))
      for [o, d] in originsDests
        continue unless o or d
        table.push [o, d, WILDCARD_TYPE, yes]
    catch e
      log 'Error reading RequestPolicy config:', e

    loadedRules.setDataSource table


importSelection =
  init: ->
    @allRadio = $ '#import-all-rules'
    @selectedRadio = $ '#import-selected-rules'

  getSelectedRules: ->
    if @allRadio.selected
      return loadedRules.toTable()
    else
      return loadedRules.getSelectedTable()


conflictResolution = new class
  bindShouldImport = (btn, f) ->
    btn.addEventListener 'RadioStateChange', =>
      if btn.selected
        @shouldImport = f

  init: ->
    @_newRadio = $ '#conflict-resolution-prefer-new'
    @_existingRadio = $ '#conflict-resolution-prefer-existing'
    @_permissiveRadio = $ '#conflict-resolution-prefer-permissive'
    @_restrictiveRadio = $ '#conflict-resolution-prefer-restrictive'

    bindShouldImport @_newRadio, -> yes
    bindShouldImport @_existingRadio, -> no
    bindShouldImport @_permissiveRadio, ([_o, _d, _t, decision]) -> decision
    bindShouldImport @_restrictiveRadio, ([_o, _d, _t, decision]) -> not decision

  shouldImport: -> yes


importButton =
  init: ->
    @$ = $ '#import-button'
    @$.addEventListener 'command', @onCommand.bind @

  onCommand: ->
    return unless persistent = manager.get 'user_persistent'

    import_ = (o, d, t, decision) ->
      if decision
        persistent.allow o, d, t
      else
        persistent.reject o, d, t

    table = importSelection.getSelectedRules()

    stats =
      selected: table.length
      imported: 0

    for rule in table
      [o, d, t, decision] = rule
      if null == persistent.lookup o, d, t # no such rule exists
        import_ o, d, t, decision
        stats.imported += 1
      else # conflict found
        if conflictResolution.shouldImport rule
          import_ o, d, t, decision
          stats.imported += 1

    statusIndicator.setStatus \
      text: l10n 'preferences_user_rulesets_imported_rules_count', \
                  stats.imported, stats.selected


statusIndicator =
  init: ->
    @_statusLabel = $ '#import-status-label'
    @_statusLabel.addEventListener 'click', -> @value = ''
  setStatus: (description) ->
    {
      text
    } = description
    @_statusLabel.value = text


onLoad = ->
  if manager.enabled 'user_persistent'
    loadedRules.init()
    dumpLoader.init()
    importSelection.init()
    conflictResolution.init()
    importButton.init()
    statusIndicator.init()
  else
    $('#import-container').hidden = yes
    $('#persistent-ruleset-diabled-container').hidden = no
