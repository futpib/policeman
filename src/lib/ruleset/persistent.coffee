
{ DomainDomainTypeRS } = require 'lib/ruleset/in-memory-ruleset'

{ prefs } = require 'lib/prefs'
{ updating } = require 'lib/updating'
{ l10n } = require 'lib/l10n'


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


updating.from '0.12', ->
  ###
  0.12 and below used 'ruleset.persistent.domainDomainType' which was defined
  as 'object' by ruleset/in-memory-ruleset#SavableRS.
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
