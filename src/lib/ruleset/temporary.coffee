
{
  DomainDomainTypeRS
  ClosuresRS
  LookupRS
} = require 'ruleset/code-ruleset'

{ tabs } = require 'tabs'

{ l10n } = require 'l10n'


# Holds temporary permissions added by UI (panelview popup).
# Used by popup to temporary allow requests from a certaing domain, tab
# or all requests
exports.temporaryRuleSet = new (class extends DomainDomainTypeRS
  id: 'user_temporary'
  version: '0.1'
  name: l10n 'temp_ruleset_name'
  description: l10n 'temp_ruleset_description'
  permissiveness: 'mixed'
  homepage: 'https://github.com/futpib/policeman/wiki/Preinstalled-rulesets-description#temporary-rules-added-by-ui'

  _sortagePref: null
  _restrictToWebPref: 'ruleset.temporary.restrictToWeb'

  constructor: ->
    @_closures = new ClosuresRS
    @_tabs = new LookupRS
    tabs.onClose.add (tab) =>
      @_tabs.revoke tabs.getTabId tab
    super arguments...

  addClosure: (f) -> @_closures.add f
  revokeClosure: (f) -> @_closures.revoke f

  allowTab: (t) -> @_tabs.allow tabs.getTabId t
  revokeTab: (t) -> @_tabs.revoke tabs.getTabId t
  isAllowedTab: (t) -> @_tabs.isAllowed tabs.getTabId t

  check: (origin, destination, context) ->
    if context._tabId
      decision = @_tabs.check context._tabId
      return decision if typeof decision is 'boolean'
    decision = @_closures.check arguments...
    return decision if typeof decision is 'boolean'
    return super arguments...
)
