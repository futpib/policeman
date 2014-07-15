
{ superdomains } = require 'utils'

{ l10n } = require 'l10n'


# Holds temporary permissions added by UI (panelview popup).
# Used by popup to temporary allow requests from a certaing domain, tab
# or all requests
exports.temporaryRuleSet = new class
  id: 'temp'
  version: '0.1'
  name: l10n 'temp_ruleset_name'
  description: l10n 'temp_ruleset_description'

  constructor: ->
  stringify: -> throw new Error "Can't stringify temporary rule set"


  any:
    _allowed: false
    isEmpty: -> not @_allowed
    allow: -> @_allowed = true
    isAllowed: -> @_allowed
    revoke: -> @_allowed = false
    revokeAll: -> @_allowed = false
    check: (o, d) -> if @_allowed then true else null


  domain:
    _allowed: {}
    isEmpty: -> not Object.keys(@_allowed).length
    allow: (domain) -> @_allowed[domain] = true unless @isAllowed domain
    isAllowed: (domain) -> domain of @_allowed
    revoke: (domain) -> delete @_allowed[domain] if @isAllowed domain
    revokeAll: -> @_allowed = {}
    check: (o, d) ->
      return null unless o.host
      return superdomains(o.host).some @isAllowed.bind @


  document: # TODO
    isEmpty: -> true
    allow: (doc) ->
    isAllowed: (doc) -> false
    revoke: (doc) ->
    revokeAll: ->
    check: (o, d) -> null


  revokeAll: ->
    do @any.revokeAll
    do @domain.revokeAll
    do @document.revokeAll

  isEmpty: -> [@any, @domain, @document].every (x) -> x.isEmpty()

  check: (origin, dest) ->
    unless origin.scheme in ['http', 'https'] \
          and dest.scheme in ['http', 'https', 'ftp']
      return null

    for rs in [@any, @domain, @document]
      rs.check origin, dest

    return null
