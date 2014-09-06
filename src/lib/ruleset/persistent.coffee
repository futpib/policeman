
{ DomainDomainTypeRS } = require 'ruleset/code-ruleset'

{ prefs, foreign } = require 'prefs'
{ l10n } = require 'l10n'


# Holds persistent permissions added by UI (panelview popup).
exports.persistentRuleSet = persistentRuleSet = new (class extends DomainDomainTypeRS
  id: 'user_persistent'
  version: '0.1'
  name: l10n 'pers_ruleset_name'
  description: l10n 'pers_ruleset_description'
  permissiveness: 'mixed'
) 'ruleset.persistent.domainDomainType'

onShutdown.add persistentRuleSet.save.bind persistentRuleSet


prefs.define rpImportPref = 'ruleset.persistent.requestpolicy.triedImport',
  default: false

if not prefs.get rpImportPref
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
      persistentRuleSet.allow o, '', persistentRuleSet.WILDCARD_TYPE
    dests = foreign.get(rpDestsPref).split(' ')
    for d in dests
      continue unless d
      persistentRuleSet.allow '', d, persistentRuleSet.WILDCARD_TYPE
    originsDests = foreign.get(rpODPref).split(' ').map((s) -> s.split('|'))
    for [o, d] in originsDests
      continue unless o or d
      persistentRuleSet.allow o, d, persistentRuleSet.WILDCARD_TYPE
  catch e
    log "Error trying to import PequestPolicy rules: #{e}\n #{e.stack}."
  prefs.set rpImportPref, true
