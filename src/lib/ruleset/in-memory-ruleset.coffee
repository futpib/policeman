
{ superdomains, remove } = require 'lib/utils'
{ prefs } = require 'lib/prefs'

{ ContextInfo } = require 'lib/request-info'
{ RuleSet } = require 'lib/ruleset/base'

{ setTimeout, clearTimeout } = Cu.import "resource://gre/modules/Timer.jsm"


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
  stringify: -> throw new Error "Can't stringify ruleset '#{ @id }'"

exports.WebDestHostRS = class WebDestHostRS extends ModifiableRS
  constructor: ->
    @_hosts = new Map
  isEmpty: -> not @_hosts.size
  allow: (d) -> @_hosts.set d, true
  isAllowed: (d) -> true == @_hosts.get d
  reject: (d) -> @_hosts.set d, false
  isRejected: (d) -> false == @_hosts.get d
  has: (d) -> @_hosts.has d
  revoke: (d) -> @_hosts.delete d
  revokeAll: -> @_hosts.clear()
  check: (o, d, c) ->
    if d.schemeType == 'web' and @_hosts.has d.host
      return @_hosts.get d.host
    return null

exports.SavableRS = class SavableRS extends ModifiableRS
  constructor: (@_pref=null) ->
    if @_pref
      prefs.define @_pref,
        type: 'uobject'
        default: @_marshal()
        sync: true
      do @load
      prefs.onChange @_pref, @load.bind @
  _marshal: -> throw new Error "Subclass should supply '_marshal' method"
  _unmarshal: (o) -> throw new Error "Subclass should supply '_unmarshal' method"
  save: -> prefs.set @_pref, @_marshal() if @_pref
  load: -> @_unmarshal prefs.get @_pref if @_pref


exports.AutosavableRS = class AutosavableRS extends SavableRS
  minToMs = (n) -> n * 60 * 1000
  msToMin = (n) -> Math.round n / (60 * 1000)

  MINIMUM_INTERVAL_MINUTES = 2
  prefs.define SAVE_INTERVAL_PREF = 'ruleset.autosave.checkIntervalMinutes',
    default: 7
    get: (minutes) ->
      if minutes < MINIMUM_INTERVAL_MINUTES
        throw new Error 'Autosave interval too low'
      return minutes
    onChange: (minutes) =>
      @::_SAVE_INTERVAL_MINUTES = minutes

  @::_SAVE_INTERVAL_MINUTES = prefs.get SAVE_INTERVAL_PREF

  marksForAutosave: (f) -> ->
    @markForAutosave()
    return f.apply @, arguments

  proto = @::
  superProto = Object.getPrototypeOf proto

  markForAutosave: ->
    @_hasUnsavedChanges = true

  for modOp in [
      'allow',
      'reject',
      'revoke',
      'revokeAll',
    ]
    superOp = superProto[modOp]
    proto[modOp] = proto.marksForAutosave superOp

  constructor: ->
    super arguments...
    if @_pref
      @_hasUnsavedChanges = false
      weakThat = Cu.getWeakReference this
      timeout = setTimeout (callback = ->
        clearTimeout timeout
        if that = weakThat.get()
          that._autosave()
          timeout = setTimeout callback, minToMs that._SAVE_INTERVAL_MINUTES
      ), minToMs @_SAVE_INTERVAL_MINUTES

  _autosave: ->
    if @_hasUnsavedChanges
      @save arguments...
      @_hasUnsavedChanges = false

  load: ->
    super arguments...
    @_hasUnsavedChanges = false

exports.LookupRS = class LookupRS extends AutosavableRS
  constructor: (pref) ->
    @revokeAll()
    super pref
  _marshal: -> @_lookup
  _unmarshal: (o) -> @_lookup = o
  revokeAll: @::marksForAutosave -> @_lookup = Object.create null
  isEmpty: -> not Object.keys(@_lookup).length
  allow: @::marksForAutosave (x) -> @_lookup[x] = true
  isAllowed: (x) -> !! @_lookup[x]
  reject: @::marksForAutosave (x) -> @_lookup[x] = false
  isRejected: (x) -> (x of @_lookup) and (not @_lookup[x])
  has: (x) -> x of @_lookup
  revoke: @::marksForAutosave (x) -> delete @_lookup[x]

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
  revoke: @::marksForAutosave (keys) -> revoke_ keys.slice(), @_lookup

  loopSet_ = (val) -> depthLoop_ (l, k, eta) ->
    l[k] ?= if eta then Object.create(null) else val
    depthLoop_.continue

  allow: @::marksForAutosave loopSet_ true
  reject: @::marksForAutosave loopSet_ false

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
  WILDCARD_TYPE: ContextInfo::WILDCARD_TYPE

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

  check: (o, d, c) ->
    originIsWeb = o.schemeType == 'web'
    destinationIsWeb = d.schemeType == 'web'
    return null if @_restrictToWeb and not (originIsWeb and destinationIsWeb)
    return @checkWithSuperdomains o.host, d.host, c.simpleContentType
