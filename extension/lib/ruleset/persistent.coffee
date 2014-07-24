
{ superdomains } = require 'utils'
{ prefs } = require 'prefs'

{ l10n } = require 'l10n'


prefs.define 'permissions.domains',
  prefs.TYPE_JSON,
  {}

# Holds persistent permissions added by UI (panelview popup).
exports.persistentRuleSet = new class
  id: 'user_persistent'
  version: '0.1'
  name: l10n 'pers_ruleset_name'
  description: l10n 'pers_ruleset_description'

  constructor: ->
    prefs.onChange 'permissions.domains', @load.bind @
    do @load

  domain:
    _lookup: {}
    load: -> @_lookup = prefs.get 'permissions.domains'
    save: -> prefs.set 'permissions.domains', @_lookup
    isAllowed: (d) -> !! @_lookup[d]
    allow: (d) -> @_lookup[d] = true
    revoke: (d) -> delete @_lookup[d]
    check: (o, d) ->
      return null unless o.host
      for d in superdomains o.host
        if d of @_lookup
          return @_lookup[d]
      return null

  load: ->
    do @domain.load

  save: ->
    do @domain.save

  check: (o, d) -> @domain.check o, d


