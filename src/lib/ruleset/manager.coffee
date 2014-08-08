
{ path } = require 'file'
{ remove, move, zip, cache } = require 'utils'

{ RuleSet } = require 'ruleset/ruleset'
{ temporaryRuleSet } = require 'ruleset/temporary'
{ persistentRuleSet } = require 'ruleset/persistent'

{ prefs } = require 'prefs'

codeBasedRuleSets = [
  'user_persistent',
  'user_temporary',
]

embeddedRuleSets = [
  'default',
  'allow_any',
  'reject_any',
  'allow_same_site',
  'allow_same_second_level_domain',
  'i2p_sandbox',
  'onion_sandbox',
].concat codeBasedRuleSets

prefs.define 'manager.enabledRuleSets',
  prefs.TYPE_JSON,
  ['default', 'user_temporary', 'user_persistent', 'allow_same_site', 'reject_any']

pushEmbedded = (list) ->
  for id in embeddedRuleSets
    unless id in list
      list.push id
  return list

prefs.define 'manager.installedRuleSets',
  prefs.TYPE_JSON,
  embeddedRuleSets,
    get: (l) -> pushEmbedded l

prefs.define 'manager.suspended',
  prefs.TYPE_BOOLEAN, false


cachedRulesetConstructor = cache ((uri) -> uri.spec), ((uri) ->
  path.toFile(uri).lastModifiedTime
), ((uri) ->
  new RuleSet uri
)


exports.Manager = class Manager
  embeddedRuleSets: embeddedRuleSets
  codeBasedRuleSets: codeBasedRuleSets

  constructor: (installed, enabled) ->
    @_installedRuleSetsIds = []
    @_installedMetadataById = Object.create null

    @install id for id in installed

    @_enabledRuleSetsIds = [] # order defines priority
    @_enabledRuleSetsById = Object.create null

    @enable id for id in enabled

  _uriById: (id) ->
    expectedFilename = id + '.ruleset'
    if id in @embeddedRuleSets and not (id in @codeBasedRuleSets)
      return path.join path.defaults, 'rulesets', expectedFilename
    if id in @_installedRuleSetsIds
      return path.join path.profile, 'rulesets', expectedFilename
    throw new Error "Can't find ruleset file for ruleset '#{id}'"

  codeBasedIdToObject =
    'user_temporary': temporaryRuleSet
    'user_persistent': persistentRuleSet

  _newRuleSetById: (id) ->
    if codeBasedIdToObject.hasOwnProperty id
      return codeBasedIdToObject[id]
    return cachedRulesetConstructor @_uriById id

  getMetadata: (id) -> @_installedMetadataById[id]

  installed: (id) -> id of @_installedMetadataById
  install: (id) ->
    return if @installed id
    @_installedRuleSetsIds.push id
    rs = @_newRuleSetById id
    @_installedMetadataById[id] = rs.getMetadata()
  uninstall: (id) ->
    return unless @installed id
    if id in embeddedRuleSets
      throw new Error "Can't uninstall embedded ruleset '#{id}'"
    @disable id
    remove @_installedRuleSetsIds, id
    delete @_installedMetadataById[id]

  getInstalledIds: -> @_installedRuleSetsIds.slice()
  getInstalledMetadata: -> (@getMetadata id for id in @getInstalledIds())

  enabled: (id) -> id of @_enabledRuleSetsById
  enable: (id, ix=Infinity) ->
    if @enabled id
      move @_enabledRuleSetsIds, id, ix
      return
    if not @installed id
      throw new Error "Can't enable ruleset '#{id}' because it's not installed"
    @_enabledRuleSetsIds.splice ix, 0, id
    @_enabledRuleSetsById[id] = @_newRuleSetById id
  disable: (id) ->
    return unless @enabled id
    remove @_enabledRuleSetsIds, id
    delete @_enabledRuleSetsById[id]

  getEnabledIds: -> @_enabledRuleSetsIds.slice()
  getEnabledMetadata: -> (@getMetadata id for id in @getEnabledIds())

  get: (id) -> @_enabledRuleSetsById[id]

  check: (origin, dest, ctx) ->
    return true if @_suspended
    for id in @_enabledRuleSetsIds
      decision = @_enabledRuleSetsById[id].check origin, dest, ctx
      if decision != null
        return decision
    return null


class Snapshot extends Manager
  constructor: (@_model) ->
    super @_model.getInstalledIds(), @_model.getEnabledIds()
  somethingChanged: ->
    modelInstalledIds = @_model.getInstalledIds()
    currentInstalledIds = @getInstalledIds()
    modelEnabledIds = @_model.getEnabledIds()
    currentEnabledIds = @getEnabledIds()
    return not (
      (modelEnabledIds.length == currentEnabledIds.length) \
      and zip(modelEnabledIds, currentEnabledIds).every(([a,b]) -> a == b) \
      and (modelInstalledIds.length == currentInstalledIds.length) \
      and (modelInstalledIds.every((i) -> i in currentInstalledIds)) \
      and (currentInstalledIds.every((i) -> i in modelInstalledIds))
    )


class SanityCheckedSnapshot extends Snapshot
  canDisable: (id) -> id != 'default'
  disable: (id) ->
    return unless @canDisable id
    super id
    if id in ['allow_any', 'reject_any']
      opposite = if id == 'allow_any' then 'reject_any' else 'allow_any'
      Snapshot::enable.call @, opposite

  enable: (id, ix) ->
    if id == 'default'
      ix = 0
    super id, ix
    if id in ['allow_any', 'reject_any']
      opposite = if id == 'allow_any' then 'reject_any' else 'allow_any'
      Snapshot::disable.call @, opposite
    move @_enabledRuleSetsIds, 'allow_any', Infinity
    move @_enabledRuleSetsIds, 'reject_any', Infinity

  canUninstall: (id) -> not (id in embeddedRuleSets)
  uninstall: (id) ->
    return unless @canUninstall
    super id


exports.manager = new class ManagerSingleton extends Manager
  constructor: ->
    @_suspended = false

    prefs.onChange 'manager.suspended', =>
      @_suspended = prefs.get 'manager.suspended'

    super (prefs.get 'manager.installedRuleSets'), (prefs.get 'manager.enabledRuleSets')

    prefs.onChange 'manager.installedRuleSets', @_onInstalledPrefChange.bind @
    prefs.onChange 'manager.enabledRuleSets', @_onEnabledPrefChange.bind @

  _loadInstalledIds: (newInstalledIds) ->
    for id in newInstalledIds
      unless @installed id
        @install id
    for id in @getInstalledIds()
      unless id in newInstalledIds
        @uninstall id

  _loadEnabledIds: (newEnabledIds) ->
    for id, i in newEnabledIds
      @enable id, i
    for id in @getEnabledIds()
      unless id in newEnabledIds
        @disable id

  _onInstalledPrefChange: ->
    @_loadInstalledIds prefs.get 'manager.installedRuleSets'

  _onEnabledPrefChange: ->
    @_loadEnabledIds prefs.get 'manager.enabledRuleSets'

  save: ->
    prefs.set 'manager.enabledRuleSets', @_enabledRuleSetsIds
    prefs.set 'manager.installedRuleSets', @_installedRuleSetsIds

  suspended: -> @_suspended
  toggleSuspended: -> prefs.set 'manager.suspended', not @_suspended
  suspend: -> prefs.set 'manager.suspended', true
  unsuspend: -> prefs.set 'manager.suspended', false

  # this is for ui to play with and then load when user hits "Save" or smth
  snapshot: -> new SanityCheckedSnapshot @
  loadSnapshot: (shot) ->
    @_loadInstalledIds shot.getInstalledIds()
    @_loadEnabledIds shot.getEnabledIds()
    @save()
