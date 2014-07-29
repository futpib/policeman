
{ path } = require 'file'
{ remove } = require 'utils'

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


exports.Manager = class Manager
  embeddedRuleSets: embeddedRuleSets
  codeBasedRuleSets: codeBasedRuleSets

  constructor: ->
    @_enabledRuleSetsIds = [] # order defines priority
    @_enabledRuleSetsById = {}

    @_installedRuleSetsIds = []
    @_installedRuleSetsMetadataById = {} # id -> {version:..., name:..., ...}

    prefs.onChange 'enabledRuleSets', @updateEnabled.bind @
    do @updateEnabled
    prefs.onChange 'installedRuleSets', @updateInstalled.bind @
    do @updateInstalled

  updateEnabled: ->
    @_enabledRuleSetsIds = prefs.get 'enabledRuleSets'
    for id in @_enabledRuleSetsIds
      @enable id
    for id of @_enabledRuleSetsById
      unless id in @_enabledRuleSetsIds
        @disable id

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
    if id of codeBasedIdToObject
      return codeBasedIdToObject[id]
    return new RuleSet @_uriById id

  updateInstalled: ->
    @_installedRuleSetsIds = prefs.get 'installedRuleSets'
    @_installedRuleSetsMetadataById = {}
    for id in @_installedRuleSetsIds
      rs = @_newRuleSetById id
      @_installedRuleSetsMetadataById[id] = {
        id: rs.id
        name: rs.name
        description: rs.description
        version: rs.version
      }

  isEnabled: (id) -> id of @_enabledRuleSetsById

  enable: (id) ->
    return if @isEnabled id
    rs = @_newRuleSetById id
    @_enabledRuleSetsById[id] = rs

  disable: (id) ->
    delete @_enabledRuleSetsById[id]

  get: (id) -> @_enabledRuleSetsById[id]

  install: (uri) ->
    throw 'ruleSetManager.install: TODO'
    prefs.mutate 'installedRuleSets', (list) -> list.push id; return list

  uninstall: (id) ->
    throw 'ruleSetManager.uninstall: TODO'
    prefs.mutate 'installedRuleSets', (list) -> list.filter (id_) -> id_ isnt id

  getMetadata: (id) ->
    return @_installedRuleSetsMetadataById[id]

  check: (origin, dest, ctx) ->
    for id in @_enabledRuleSetsIds
      decision = @_enabledRuleSetsById[id].check origin, dest, ctx
      if decision != null
        return decision
    return null

exports.manager = new Manager
