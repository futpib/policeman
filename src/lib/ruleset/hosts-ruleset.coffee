
{ DomainsBlacklistRS } = require 'lib/ruleset/domains-blacklist-ruleset'
{ registry } = require 'lib/ruleset/format-registry'

{
  md5
} = require 'lib/utils'

{ l10n } = require 'lib/l10n'


exports.HostsRS = class HostsRS extends DomainsBlacklistRS
  DUMMY_IP_FIELD_RE = /^[^\s]+\s+/gm

  _parse: (str, rest...) ->
    noDummyField = str.replace DUMMY_IP_FIELD_RE, ''
    super noDummyField, rest...

  _parseMetadata: (str) ->
    @id = md5 str
    @version = undefined

    @name = l10n 'hosts_ruleset_name', @_hosts.size
    @description = l10n 'hosts_ruleset_description'

    @permissiveness = 'restrictive'

  LOCALHOST_RE = /^127(\.\d{1,3}){3}\s+.+/gm

  guess: (str) ->
    return -1 != str.search LOCALHOST_RE

registry.register HostsRS, registry.PRIORITY_LOW + 50
