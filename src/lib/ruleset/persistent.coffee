
{ DomainDomainTypeRS } = require 'ruleset/code-ruleset'

{ prefs, foreign } = require 'prefs'
{ updating } = require 'updating'
{ l10n } = require 'l10n'


# Holds persistent permissions added by UI (panelview popup).
exports.persistentRuleSet = persistentRuleSet = new (class extends DomainDomainTypeRS
  id: 'user_persistent'
  version: '0.1'
  name: l10n 'pers_ruleset_name'
  description: l10n 'pers_ruleset_description'
  permissiveness: 'mixed'
  homepage: 'https://github.com/futpib/policeman/wiki/Preinstalled-rulesets-description#persistent-rules-added-by-ui'

  _sortagePref: 'ruleset.persistent.domainDomainTypeUnicode'
  _restrictToWebPref: 'ruleset.persistent.restrictToWeb'
)

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
  prefs.set rpImportPref, true


updating.from '0.12', ->
  ###
  0.12 and below used 'ruleset.persistent.domainDomainType' which was defined
  as 'object' by ruleset/code-ruleset#SavableRS.
  Now we have 'ruleset.persistent.domainDomainTypeUnicode' define as 'uobject'
  for proper internationalized domain names support.
  ###
  prefs.define ddtPref = 'ruleset.persistent.domainDomainType',
    type: 'object'
    default: {}
  ddt = prefs.get ddtPref
  for o of ddt
    for d of ddt[o]
      for t of ddt[o][d]
        if ddt[o][d][t]
          persistentRuleSet.allow o, d, t
        else
          persistentRuleSet.reject o, d, t
  persistentRuleSet.save()
  prefs.delete ddtPref
