
{ DomainDomainTypeRS } = require 'ruleset/code-based'

{ l10n } = require 'l10n'


# Holds temporary permissions added by UI (panelview popup).
# Used by popup to temporary allow requests from a certaing domain, tab
# or all requests
exports.temporaryRuleSet = new (class extends DomainDomainTypeRS
  id: 'user_temporary'
  version: '0.1'
  name: l10n 'temp_ruleset_name'
  description: l10n 'temp_ruleset_description'
)
