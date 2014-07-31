
{ superdomains, defaults } = require 'utils'
{ prefs } = require 'prefs'


# Rulesets for easy modification by ui.
# Called code-based as opposite to nodes-based.


exports.CodeBasedRS = class CodeBasedRS
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
  getMetadata: -> {
      id: @id
      version: @version
      name: @name
      description: @description
      sourceUrl: undefined
    }

exports.SavableRS = class SavableRS extends CodeBasedRS
  constructor: (@_pref=null) ->
    if @_pref
      prefs.define @_pref, prefs.TYPE_JSON, @_marshal()
      do @load
      prefs.onChange @_pref, @load.bind @
  _marshal: -> throw new Error "Subclass should supply '_marshal' method"
  _unmarshal: (o) -> throw new Error "Subclass should supply '_unmarshal' method"
  save: -> prefs.set @_pref, @_marshal() if @_pref
  load: -> @_unmarshal prefs.get @_pref if @_pref

exports.TernaryRS = class TernaryRS extends SavableRS
  constructor: (pref) ->
    @revokeAll()
    super pref
  _marshal: -> @_value
  _unmarshal: (o) -> @_value = o
  isEmpty: -> not @_value
  allow: -> @_value = true
  isAllowed: -> @_value == true
  reject: -> @_value = false
  isRejected: -> @_value == false
  revoke: -> @_value = null
  revokeAll: -> @_value = null
  check: -> @_value

exports.LookupRS = class LookupRS extends SavableRS
  constructor: (pref) ->
    @revokeAll()
    super pref
  _marshal: -> @_lookup
  _unmarshal: (o) -> @_lookup = o
  revokeAll: -> @_lookup = {}
  isEmpty: -> not Object.keys(@_lookup).length
  allow: (x) -> @_lookup[x] = true
  isAllowed: (x) -> !! @_lookup[x]
  reject: (x) -> @_lookup[x] = false
  isRejected: (x) -> (x of @_lookup) and (not @_lookup[x])
  has: (x) -> x of @_lookup
  revoke: (x) -> delete @_lookup[x]

exports.Lookup2RS = class Lookup2RS extends LookupRS
  has: (a, b) ->
    if a of @_lookup
      if b of @_lookup[a]
        return true
    return false
  allow: (a, b) ->
    defaults @_lookup, a, {}
    defaults @_lookup[a], b, {}
    @_lookup[a][b] = true
  isAllowed: (a, b) ->
    if @has a, b
      return @_lookup[a][b]
    return false
  reject: (a, b) ->
    defaults @_lookup, a, {}
    defaults @_lookup[a], b, {}
    @_lookup[a][b] = false
  isRejected: (a, b) ->
    if @has a, b
      return not @_lookup[a][b]
    return false
  revoke: (a, b) ->
    delete @_lookup[a][b]
    if not Object.keys(@_lookup[a]).length
      delete @_lookup[a]

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
    (if eta then defaults l, k, {} else defaults l, k, val); depthLoop_.continue

  allow: loopSet_ true
  reject: loopSet_ false

  loopLookup_ = (val) -> depthLoop_ \
    ((l, k) -> if k of l then depthLoop_.continue else false), \
    ((l, k) -> l[k] == val)

  isAllowed: loopLookup_ true
  isRejected: loopLookup_ false

exports.DomainPairRS = class DomainPairRS extends Lookup2RS
  checkOrder: (oh, dh, f) ->
    # order has to be defined separately and publicly for ui to be able to
    # depict it truthfully
    for o in superdomains oh
      for d in superdomains dh
        res = f.call @, o, d
        if typeof res == 'boolean'
          return res
    return null

  checkWithoutSuperdomains: (o, d) ->
    if o of @_lookup
      if d of @_lookup[o]
        return @_lookup[o][d]
    return null

  checkWithSuperdomains: (oh, dh) ->
    return @checkOrder oh, dh, @checkWithoutSuperdomains

  check: (o, d, c) ->
    return null unless (o.schemeType == d.schemeType == 'web')
    return @checkWithSuperdomains o.host, d.host, c

exports.DomainDomainTypeRS = class DomainDomainTypeRS extends DeepLookupRS
  WILDCARD_TYPE: '_ANY_'

  allow:      (o, d, t) -> super [o, d, t]
  isAllowed:  (o, d, t) -> super [o, d, t]
  reject:     (o, d, t) -> super [o, d, t]
  isRejected: (o, d, t) -> super [o, d, t]
  has:        (o, d, t) -> super [o, d, t]
  revoke:     (o, d, t) -> super [o, d, t]

  checkOrder: (oh, dh, type, f) ->
    for o in superdomains oh
      for d in superdomains dh
        res = f.call @, o, d, type
        return res if typeof res == 'boolean'
    return null

  checkWithoutSuperdomains: (o, d, t) ->
    if o of @_lookup
      if d of @_lookup[o]
        if t of @_lookup[o][d]
          return @_lookup[o][d][t]
    return null

  checkWithSuperdomains: (oh, dh, t) ->
    return @checkOrder oh, dh, t, @checkWithoutSuperdomains

  check: (o, d, c) ->
    return null unless (o.schemeType == d.schemeType == 'web')
    decision = @checkWithSuperdomains o.host, d.host, c.contentType
    return decision if decision isnt null
    return @checkWithSuperdomains o.host, d.host, @WILDCARD_TYPE

