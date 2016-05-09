
{ WebDestHostRS } = require 'lib/ruleset/in-memory-ruleset'
{ registry } = require 'lib/ruleset/format-registry'

{
  md5
} = require 'lib/utils'

{ l10n } = require 'lib/l10n'


exports.DomainsBlacklistRS = class DomainsBlacklistRS extends WebDestHostRS
  constructor: (str, @sourceUrl) ->
    super
    @_parse arguments...
    @_parseMetadata arguments...

  COMMENT_RE = /#.*\r?\n/g
  SEPARATOR_RE = /\s+/g
  DOMAIN_RE = /^([^\.]+\.)+[^\.]+$/

  _parse: (str) ->
    noComments = str.replace COMMENT_RE, ''
    fields = noComments.split SEPARATOR_RE

    stats = { errors: 0, successes: 0 }
    for field in fields
      if 0 != field.search DOMAIN_RE
        stats.errors += 1
      else
        @reject field
        stats.successes += 1

    # somewhat arbitrary, but better then eating any input at all
    if stats.errors > (stats.successes / 10)
      throw new Error 'Does not look like a list of domains'

  _parseMetadata: (str) ->
    @id = md5 str
    @version = undefined

    @name = l10n 'domains_blacklist_ruleset_name', @_hosts.size
    @description = l10n 'domains_blacklist_ruleset_description'

    @permissiveness = 'restrictive'

  LINE_STARTING_WITH_DOMAIN_RE = /^([^\.]+\.)+[^\.]+/gm

  guess: (str) ->
    return -1 != str.search LINE_STARTING_WITH_DOMAIN_RE

registry.register DomainsBlacklistRS, registry.PRIORITY_LOW + 25
