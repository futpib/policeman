
{ superdomains, defaults, remove } = require 'utils'
{ prefs } = require 'prefs'

{ RuleSet } = require 'ruleset/base'


# Rulesets for easy modification by ui.


exports.ClosuresRS = class ClosuresRS extends RuleSet
  constructor: ->
    @_closures = []
  add: (f) -> @_closures.push f
  revoke: (f) -> remove @_closures, f
  check: (o, d, c) ->
    for f in @_closures.slice()
      decision = f.call f, o, d, c
      return decision if typeof decision is 'boolean'
    return null

exports.ModifiableRS = class ModifiableRS extends RuleSet
  constructor: ->
  isEmpty: -> true
  allow: ->
  isAllowed: -> false
  reject: ->
  isRejected: -> false
  has: (as...) -> @isAllowed(as...) or @isRejected(as...)
  revoke: ->
  revokeAll: ->
  check: (as...) ->
    if @isAllowed(as...)
      return true
    if @isRejected(as...)
      return false
    return null
  stringify: -> throw new Error "Can't stringify code-based ruleset '#{ @id }'"

exports.SavableRS = class SavableRS extends ModifiableRS
  constructor: (@_pref=null) ->
    if @_pref
      prefs.define @_pref,
        default: @_marshal()
      do @load
      prefs.onChange @_pref, @load.bind @
  _marshal: -> throw new Error "Subclass should supply '_marshal' method"
  _unmarshal: (o) -> throw new Error "Subclass should supply '_unmarshal' method"
  save: -> prefs.set @_pref, @_marshal() if @_pref
  load: -> @_unmarshal prefs.get @_pref if @_pref

exports.LookupRS = class LookupRS extends SavableRS
  constructor: (pref) ->
    @revokeAll()
    super pref
  _marshal: -> @_lookup
  _unmarshal: (o) -> @_lookup = o
  revokeAll: -> @_lookup = Object.create null
  isEmpty: -> not Object.keys(@_lookup).length
  allow: (x) -> @_lookup[x] = true
  isAllowed: (x) -> !! @_lookup[x]
  reject: (x) -> @_lookup[x] = false
  isRejected: (x) -> (x of @_lookup) and (not @_lookup[x])
  has: (x) -> x of @_lookup
  revoke: (x) -> delete @_lookup[x]

exports.DeepLookupRS = class DeepLookupRS extends LookupRS
  depthLoop_ = (iter, after) -> (keys) ->
    lookup = @_lookup
    i = 0
    while i < keys.length
      k = keys[i]
      result = iter.call @, lookup, k, keys.length-i-1
      break if result is depthLoop_.break
      if result isnt depthLoop_.continue
        return result
      lookup = lookup[k]
      i += 1
    if after
      return after.call @, lookup, k
  depthLoop_.continue = {}
  depthLoop_.break = {}

  has: depthLoop_ \
    ((l, k) -> if k of l then depthLoop_.continue else false), \
    (-> true)

  lookup: depthLoop_ (l, k, eta) ->
    if k of l
      if eta
        depthLoop_.continue
      else
        l[k]
    else null

  revoke_ = (keys, lookup) ->
    return if not keys.length
    k = keys.shift()
    if (typeof lookup is 'object') and (k of lookup)
      v = lookup[k]
      delete lookup[k] if not keys.length
      revoke_ keys, v
      delete lookup[k] if not (typeof v is 'object' and Object.keys(v).length)
  revoke: (keys) -> revoke_ keys.slice(), @_lookup

  loopSet_ = (val) -> depthLoop_ (l, k, eta) ->
    defaults l, k, if eta then Object.create(null) else val
    depthLoop_.continue

  allow: loopSet_ true
  reject: loopSet_ false

  loopLookup_ = (val) -> depthLoop_ \
    ((l, k) -> if k of l then depthLoop_.continue else false), \
    ((l, k) -> l[k] == val)

  isAllowed: loopLookup_ true
  isRejected: loopLookup_ false

  toTableRec = (lookup) ->
    return [lookup] if typeof lookup isnt 'object'
    rows = []
    for k, v of lookup
      subrows = toTableRec v
      for r in subrows
        rows.push [k].concat r
    return rows
  toTable: -> toTableRec @_lookup

exports.DomainDomainTypeRS = class DomainDomainTypeRS extends DeepLookupRS
  WILDCARD_TYPE: '_ANY_'

  constructor: ->
    super @_sortagePref
    if @_restrictToWebPref
      prefs.define @_restrictToWebPref,
        default: false
      @_restrictToWeb = prefs.get @_restrictToWebPref
      prefs.onChange @_restrictToWebPref, =>
        @_restrictToWeb = prefs.get @_restrictToWebPref

  allow:      (o, d, t=@WILDCARD_TYPE) -> super [o, d, t]
  isAllowed:  (o, d, t=@WILDCARD_TYPE) -> super [o, d, t]
  reject:     (o, d, t=@WILDCARD_TYPE) -> super [o, d, t]
  isRejected: (o, d, t=@WILDCARD_TYPE) -> super [o, d, t]
  has:        (o, d, t=@WILDCARD_TYPE) -> super [o, d, t]
  lookup:     (o, d, t=@WILDCARD_TYPE) -> super [o, d, t]
  revoke:     (o, d, t=@WILDCARD_TYPE) -> super [o, d, t]

  wildLookup: (o, d, t=@WILDCARD_TYPE) ->
    decision = @lookup o, d, t
    return decision if typeof decision == 'boolean'
    return @lookup o, d, @WILDCARD_TYPE

  superdomainsCheckOrder: (oh, dh, f) ->
    for d in superdomains dh
      for o in superdomains oh
        res = f.call @, o, d
        return res if typeof res == 'boolean'
    return null

  checkWithSuperdomains: (oh, dh, t=@WILDCARD_TYPE) ->
    return @superdomainsCheckOrder oh, dh, (o, d) =>
      @wildLookup o, d, t

  theContentTypeMap =
    'OBJECT_SUBREQUEST': 'OBJECT'
  _contentTypeMap: (t) -> theContentTypeMap[t] or t

  check: (o, d, c) ->
    originIsWeb = o.schemeType == 'web'
    destinationIsWeb = d.schemeType == 'web'
    return null if @_restrictToWeb and not (originIsWeb and destinationIsWeb)
    contentType = @_contentTypeMap c.contentType
    # for non-web URI schemes check only wildcard host
    originHost = if originIsWeb then o.host else ''
    destinationHost = if destinationIsWeb then d.host else ''
    return @checkWithSuperdomains originHost, destinationHost, contentType

