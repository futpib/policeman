
{ file } = require 'file'
{ locale } = require 'l10n'
{ parser } = require 'ruleset/parser'
{ L10nLookup } = require 'ruleset/nodes'
{ MutableOrderedMap } = require 'mutable-ordered-map'

L10n = (raw) ->
  lcl = if locale of raw then locale else 'en-US'
  lookup = (k) ->
    if lcl of raw and k of raw[lcl]
      return raw[lcl][k]
    else
      return "<l10n error: locale: '#{lcl}' key: '#{k}' >"
  return localize = (str, defaultKey=null) ->
    if str instanceof L10nLookup
      return lookup str.key
    if typeof str == 'string'
      return str
    if defaultKey
      return lookup defaultKey
    throw new Error \
        "RuleSet l10n error: Can't localize '#{str}' (type: #{typeof str})"

exports.RuleSet = class RuleSet
  constructor: (uri) ->
    @parse file.read uri
    log @stringify()

  _mapConstructor: Map
  parse: (str) ->
    parser.config.set Map: @_mapConstructor
    parsed = parser.parse str
    {
      id: @id
      version: @version
      name: @name
      description: @description
      rules: @rules
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
      name: @names
      description: @description
      rules: @rules
    }
      s += "#{ k }: #{ stringifyHelper v }\n"
    return s

  checkHelper = (origin, dest, ctx, map) ->
    iterator = map.entries()
    while not (next = iterator.next()).done
      [predicate, consequent] = next.value
      if predicate.test origin, dest, ctx
        return consequent if typeof consequent is 'boolean'
        throw 'RETURN' if consequent is null
        decision = checkHelper origin, dest, ctx, consequent
        if decision != null
          return decision
    return null

  # returns true for accept, false for reject and null for undecided
  check: (origin, dest, context) ->
    try
      return checkHelper origin, dest, context, @rules
    catch e
      return null if e == 'RETURN'
      throw e



exports.MutableRuleSet = class MutableRuleSet extends RuleSet
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



exports.MutableOrderedRuleSet = class MutableOrderedRuleSet extends MutableRuleSet
  _mapConstructor: MutableOrderedMap
  # TODO















