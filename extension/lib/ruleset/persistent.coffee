
{ DomainDomainTypeRS } = require 'ruleset/code-based'

{ l10n } = require 'l10n'


# Holds persistent permissions added by UI (panelview popup).
exports.persistentRuleSet = persistentRuleSet = new (class extends DomainDomainTypeRS
  id: 'user_persistent'
  version: '0.1'
  name: l10n 'pers_ruleset_name'
  description: l10n 'pers_ruleset_description'
) 'ruleset.persistent.domainDomainType'

onShutdown.add persistentRuleSet.save.bind persistentRuleSet
