
{ superdomains, defaults } = require 'utils'
{ prefs } = require 'prefs'


# Rulesets for easy modification by ui.
# Called code-based as opposite to nodes-based.


exports.SubRS = class SubRS
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


exports.TernaryRS = class TernaryRS extends SubRS
  constructor: (@_pref=null) ->
    @revokeAll()
    if @_pref
      prefs.define @_pref, prefs.TYPE_JSON, @_value
      do @load
      prefs.onChange @_pref, @load.bind @
  isEmpty: -> not @_value
  allow: -> @_value = true
  isAllowed: -> @_value == true
  reject: -> @_value = false
  isRejected: -> @_value == false
  revoke: -> @_value = null
  revokeAll: -> @_value = null
  check: -> @_value
  save: -> prefs.set @_pref, @_value if @_pref
  load: -> @_value = prefs.get @_pref if @_pref

exports.LookupRS = class LookupRS extends SubRS
  constructor: (@_pref=null) ->
    @revokeAll()
    if @_pref
      prefs.define @_pref, prefs.TYPE_JSON, @_lookup
      do @load
      prefs.onChange @_pref, @load.bind @
  revokeAll: -> @_lookup = {}
  isEmpty: -> not Object.keys(@_lookup).length
  allow: (x) -> @_lookup[x] = true
  isAllowed: (x) -> !! @_lookup[x]
  reject: (x) -> @_lookup[x] = false
  isRejected: (x) -> (x of @_lookup) and (not @_lookup[x])
  has: (x) -> x of @_lookup
  revoke: (x) -> delete @_lookup[x]
  save: -> prefs.set @_pref, @_lookup if @_pref
  load: -> @_lookup = prefs.get @_pref if @_pref

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
    return null if c.kind != 'web'
    return @checkWithSuperdomains o.host, d.host, c
