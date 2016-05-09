
{ MutableOrderedMap } = require 'lib/mutable-ordered-map'

{ prefered_locales } = require 'lib/l10n'

{ RuleSet } = require 'lib/ruleset/base'
{ parser } = require 'lib/ruleset/tree-parser'
{ L10nLookup } = require 'lib/ruleset/tree-nodes'
{ registry } = require 'lib/ruleset/format-registry'


L10n = (raw) ->
  # create aliases for short language codes if they are missing
  # e.g. 'en' for 'en-US'
  for locale of raw
    [language, region] = locale.split '-'
    if region and language not of raw
      raw[language] = raw[locale]
  lookup = (k) ->
    for locale in prefered_locales
      if locale of raw and k of raw[locale]
        return raw[locale][k]
    return "<l10n error: locale: '#{locale}' key: '#{k}' >"
  return localize = (str, defaultKey=null) ->
    if str instanceof L10nLookup
      return lookup str.key
    if typeof str == 'string'
      return str
    if defaultKey
      return lookup defaultKey
    throw new Error \
        "RuleSet l10n error: Can't localize '#{str}' (type: #{typeof str})"

exports.TreeRS = class TreeRS extends RuleSet
  constructor: (str, @sourceUrl) ->
    @parse str

  _mapConstructor: Map
  parse: (str) ->
    parser.config.set Map: @_mapConstructor
    parsed = parser.parse str
    {
      id: @id
      version: @version
      name: @name
      description: @description
      homepage: @homepage
      rules: @rules
      permissiveness: @permissiveness
    } = parsed
    localize = L10n parsed.l10n or {}

    @name = localize @name, 'name'
    @description = localize @description, 'description'

  indent = (s) -> s.split('\n').map((l) -> '  ' + l).join('\n')

  stringifyHelper = (o) ->
    s = ''
    if typeof o in ['string', 'number']
      s += JSON.stringify(o)
    else if typeof o == 'boolean'
      s += if o then 'ACCEPT' else 'REJECT'
    else if o instanceof Map or o instanceof MutableOrderedMap
      iterator = o.entries()
      while not (next = iterator.next()).done
        [k, v] = next.value
        s += '\n'
        s += indent "#{ k.stringify() }: #{ stringifyHelper v }"
    else
      for k, v of o
        s += '\n'
        s += indent "#{ k }: #{ stringifyHelper v }"
    return s

  stringify: ->
    s = ''
    for k, v of {
      version: @version
      id: @id
      name: @name
      description: @description
      rules: @rules
    }
      s += "#{ k }: #{ stringifyHelper v }\n"
    return s

  RETURN = {}
  checkHelper = (origin, dest, ctx, map) ->
    iterator = map.entries()
    while not (next = iterator.next()).done
      [predicate, consequent] = next.value
      if fallthrough or predicate.test origin, dest, ctx
        return consequent if typeof consequent is 'boolean'
        throw RETURN if consequent is null
        fallthrough = consequent.size is 0
        decision = checkHelper origin, dest, ctx, consequent
        if decision != null
          return decision
    return null

  # returns true for accept, false for reject and null for undecided
  check: (origin, dest, context) ->
    try
      return checkHelper origin, dest, context, @rules
    catch e
      return null if e is RETURN
      throw e

  MAGIC_RE = /^magic:\s*['"]?policeman_ruleset['"]?$/gm

  guess: (str) ->
    return -1 != str.search MAGIC_RE

registry.register TreeRS, registry.PRIORITY_HIGH



exports.MutableTreeRS = class MutableTreeRS extends RuleSet
  add: (predicate, consequent, locationPath=[]) ->
    ###
    Adds predicate-consequent pair to rules at given |locationPath|.
    Expects array of keys (predicates) as |locationPath| argument.
    Returns location of inserted consequent.
    Location must point to a subtree (map) not a leaf (decision (bool or null)).
    XXX Since Map uses === (shallow equality rather then deep) |locationPath|
    should consists of the same objects that map already has as keys.
    ###
    map = @rules
    for key in locationPath
      map = map.get key
    map.set predicate, consequent
    newLocation = locationPath.slice()
    newLocation.push predicate
    return newLocation

  delete: (location) ->
    # Removes predicate-consequent pair from rules map at given |location|
    if arguments.length == 2
      # if given two argument treat them as predicate and location
      newArgs = arguments[1].concat arguments[0]
      return @remove newArgs

    map = @rules
    while key = location.shift()
      if not location.length
        return map.delete key
      map = map.get key

  find: (path) ->
    ###
    Finds a path equal (deep equality by eq method on nodes) to |path|.
    Returns first found path. Returned value can be passed as location argument
    to shallow equality-based methods (add, delete).
    Returns false if path can't be found.
    ###
    loc = []
    map = @rules

    targetFound = false
    for target in path
      iterator = map.entries()
      while not (next = iterator.next()).done
        [predicate, consequent] = next.value
        if target.eq predicate
          targetFound = true
          loc.push predicate
          map = consequent
          break
      return false if not targetFound
      targetFound = false
    return loc



exports.MutableOrderedTreeRS = class MutableOrderedTreeRS extends MutableTreeRS
  _mapConstructor: MutableOrderedMap
  # TODO?















