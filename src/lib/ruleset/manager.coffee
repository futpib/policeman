
{ TextEncoder, OS } = Cu.import 'resource://gre/modules/osfile.jsm'

{ path: file_path } = require 'file'
{
  remove
  move
  zip
  cache
  XMLHttpRequest
} = require 'utils'

{ registry: formatRegistry } = require 'ruleset/format-registry'
{ temporaryRuleSet } = require 'ruleset/temporary'
{ persistentRuleSet } = require 'ruleset/persistent'

{ updating } = require 'updating'
{ prefs } = require 'prefs'

codeBasedRuleSets = [
  'user_persistent',
  'user_temporary',
]

updating.from '0.19pre0', ->
  ###
  Chrome domain notion removed since requests from and to internal schemes
  are allowed by default.
  ###
  CHROME_DOMAIN = '_CHROME_DOMAIN_'
  for rs in [temporaryRuleSet, persistentRuleSet]
    for [o, d, t] in rs.toTable()
      if CHROME_DOMAIN in [o, d]
        rs.revoke o, d, t

embeddedRuleSets = [
  'default',
  'compatibility',
  'allow_from_file_to_file_and_web',
  'allow_any',
  'reject_any',
  'allow_same_site',
  'allow_same_second_level_domain',
  'i2p_sandbox',
  'onion_sandbox',
  'https_half_open_sandbox',
].concat codeBasedRuleSets

prefs.define ENABLED_IDS_PREF = 'manager.enabledRuleSets',
  default: [
    'default',
    'compatibility',
    'allow_from_file_to_file_and_web',
    'user_temporary',
    'user_persistent',
    'allow_same_second_level_domain',
    'reject_any',
  ]
  # filter for known ids (unknown ids may appear as a result of synchronization)
  get: (list) ->
    installed = prefs.get INSTALLED_PATH_BY_ID_PREF
    return list.filter (id) -> id of installed
  sync: true

updating.from '0.14', ->
  ###
  After 0.14 parts of 'default' ruleset were split into 'compatibility' and
  'allow_from_file_to_file_and_web' rulesets, lets enable them, so update
  does not break anything
  ###
  prefs.mutate ENABLED_IDS_PREF, (enabled) ->
    enabled.splice 1, 0, 'compatibility', 'allow_from_file_to_file_and_web'
    return enabled

addEmbedded = (obj) ->
  for id in embeddedRuleSets
    unless id of obj
      obj[id] = null
  return obj

prefs.define INSTALLED_PATH_BY_ID_PREF = 'manager.installedPathsByIds2',
  default: {}
  get: (o) -> addEmbedded o

updating.from '0.18.1', ->
  ###
  'manager.installedPathsByIds' pref renamed to 'manager.installedPathsByIds2'
  and instead of absolute paths relative are stored now (relative to Fx profile)

  Left old pref alone to not break downgrading (pre-release users might want it)
  ###
  prefs.define OLD_INSTALLED_PATH_BY_ID_PREF = 'manager.installedPathsByIds',
    default: {}
    get: (o) -> addEmbedded o
  newInstalled = prefs.get INSTALLED_PATH_BY_ID_PREF
  for id, path of prefs.get OLD_INSTALLED_PATH_BY_ID_PREF
    if id in embeddedRuleSets
      newInstalled[id] = null
    else
      newInstalled[id] = path.split(/[\/\\]/).pop() # filename only
  prefs.set INSTALLED_PATH_BY_ID_PREF, newInstalled

prefs.define SUSPENDED_PREF = 'manager.suspended',
  default: false
  sync: true


cachedRulesetConstructor = cache
  hash: (id, uri) -> uri
  version: (id, uri) ->
    if id in embeddedRuleSets # embedded ones can not change, return a constant
      return 1
    try
      return file_path.toFile(uri).lastModifiedTime
    catch e
      return Math.random()
  function: (id, uri) -> formatRegistry.parseByLocalUrl uri


rulesetFiles = new class
  refCountByPath = Object.create null

  rulesetDir = OS.Path.normalize \
              OS.Path.join OS.Constants.Path.profileDir, 'policeman', 'rulesets'

  filenamesafe = (str) -> str.replace /[^0-9A-Za-z._-]/g, '_'
  filenameRnd_ = -> Math.random().toString(36).slice(2)
  filenameRnd = (n=1) ->
    s = ''
    s += filenameRnd_() for i in [1..n]
    return s

  uniqueRelativePath = (prefix) ->
    prefix_ = if prefix is undefined then '' else filenamesafe(prefix) + '.'
    trial = 0
    while trial += 1
      relPath = "#{ prefix_ }#{ filenameRnd trial }.ruleset"
      return relPath unless relPath of refCountByPath

  getFullPath: (relPath) -> OS.Path.join rulesetDir, relPath
  getEmbeddedUrl: (id) -> file_path.toString \
                  file_path.join file_path.defaults, 'rulesets', "#{id}.ruleset"

  encoder = new TextEncoder
  save: (string, desiredName='') -> # Promise<path>
    # Returns a Promise of a string which is a path relative to `rulesetDir`
    # where the `string` argument was written.
    relPath = uniqueRelativePath desiredName
    path = @getFullPath relPath
    OS.File.writeAtomic(
      path,
      encoder.encode(string),
      tmpPath: "#{path}.tmp"
    ).then(-> relPath)

  load: (id, relPath=undefined) ->
    if id in embeddedRuleSets
      # TODO Something (XHR?) + Promise
      return cachedRulesetConstructor id, @getEmbeddedUrl id
    else
      # TODO OS.File + Promise
      return cachedRulesetConstructor id, @getFullPath relPath

  acquire: (relPath) ->
    relPath = OS.Path.normalize relPath
    refCountByPath[relPath] ?= 0
    refCountByPath[relPath] += 1

  release: (relPath) ->
    unless relPath of refCountByPath
      throw new Error "Releasing unknown path #{ JSON.stringify path }"
    refCountByPath[relPath] -= 1
    if refCountByPath[relPath] < 1
      delete refCountByPath[relPath]
      path = @getFullPath relPath
      (OS.File.remove path).then null, ->
        log "files: release #{ JSON.stringify path }: Failed to remove the file."


exports.Manager = class Manager
  embeddedRuleSets: embeddedRuleSets
  codeBasedRuleSets: codeBasedRuleSets

  constructor: (installed, enabled) ->
    @_installedPathsByIds = Object.create null
    @_installedMetadataById = Object.create null

    for id, path of installed
      try
        @install id, path
      catch e
        log.warn 'Could not install ruleset id:', id, 'path:', path,
                 'due to the following error:', e

    @_enabledRuleSetsIds = [] # order defines priority
    @_enabledRuleSetsById = Object.create null

    for id in enabled
      try
        @enable id
      catch e
        log.warn 'Could not enable ruleset id:', id,
                 'due to the following error:', e
        try
          @uninstall id
          log.info 'Ruleset id:', id,
                   'was uninstalled due to malfunctioning'

  codeBasedIdToObject =
    'user_temporary': temporaryRuleSet
    'user_persistent': persistentRuleSet

  _newRuleSetById: (id) ->
    if codeBasedIdToObject.hasOwnProperty id
      return codeBasedIdToObject[id]
    if id in embeddedRuleSets
      return rulesetFiles.load id
    unless id of @_installedPathsByIds
      throw new Error "Ruleset '#{id}' is not installed"
    return rulesetFiles.load id, @_installedPathsByIds[id]

  installed: (id) -> id of @_installedPathsByIds

  install: (id, relPath) ->
    return if @installed id

    isEmbeddedId = id in embeddedRuleSets

    pathAcquired = no
    if relPath and not isEmbeddedId
      pathAcquired = yes
      rulesetFiles.acquire relPath

    @_installedPathsByIds[id] = relPath

    try
      rs = @_newRuleSetById id
      @_installedMetadataById[id] = rs.getMetadata()
    catch e
      # ruleset is broken; restore our previous state
      if pathAcquired
        rulesetFiles.release relPath
      delete @_installedPathsByIds[id]
      delete @_installedMetadataById[id]
      throw e

    if isEmbeddedId
      @_installedMetadataById[id].sourceUrl ?= rulesetFiles.getEmbeddedUrl id
    else
      @_installedMetadataById[id].sourceUrl ?= \
              OS.Path.toFileURI rulesetFiles.getFullPath relPath

  uninstall: (id) ->
    return unless @installed id
    if id in embeddedRuleSets
      throw new Error "Can't uninstall embedded ruleset '#{id}'"
    if (path = @_installedPathsByIds[id])
      rulesetFiles.release path
    @disable id
    delete @_installedPathsByIds[id]
    delete @_installedMetadataById[id]

  downloadInstall: (url, listeners={}) ->
    dispatch = (event, args...) ->
      if event in ['start', 'progress', 'error', 'abort', 'success'] \
      and event of listeners
        listeners[event] args...

    xhr = new XMLHttpRequest
    aborted = no
    abort = (-> aborted = yes; xhr.abort(); dispatch 'abort')
    progressDetermined = yes
    xhr.addEventListener 'progress', (e) ->
      if progressDetermined and e.lengthComputable
        dispatch 'progress', {
          phase: 'load',
          progress: (e.loaded / e.total),
        }
      else if progressDetermined
        dispatch 'progress', {phase: 'load'}
        progressDetermined = no
    xhr.addEventListener 'error', (event) ->
      dispatch 'error', new Error 'Download error.'
    xhr.addEventListener 'load', =>
      dispatch 'progress', {phase: 'parse'}
      return if aborted
      try
        # TODO go async
        str = xhr.responseText
        id = formatRegistry.parse(str).id
      catch err
        log 'downloadInstall', url, 'Failed parsing downloaded file', err
        dispatch 'error', err
        return
      dispatch 'progress', {phase: 'save'}
      return if aborted
      rulesetFiles.save(str, id).then(((path) =>
        try
          @install id, path
        catch err
          log 'downloadInstall', url, 'Failed installing ruleset', id, err
          dispatch 'error', err
          return
        dispatch 'success', {id}
      ), ((e) =>
        log "downloadInstall #{ JSON.stringify url }:
            Failed saving ruleset, error: #{ e }.
            Ruleset '#{id}' not installed."
        dispatch 'error'
      ))
    dispatch 'start', {abort}
    try
      xhr.open "GET", url
      xhr.send()
    catch err
      log 'downloadInstall', url, 'failed sending GET request', err
      dispatch 'error', err



  getInstalledUrlsByIds: ->
    r = Object.create null
    r[k] = v for k, v of @_installedPathsByIds
    return r
  getMetadata: (id) -> @_installedMetadataById[id]
  getInstalledMetadata: -> (@getMetadata id for id of @_installedMetadataById)

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

  check: ([origin, dest, ctx]) ->
    for id in @_enabledRuleSetsIds
      decision = @_enabledRuleSetsById[id].check origin, dest, ctx
      if decision != null
        return decision
    return null


class Snapshot extends Manager
  constructor: (@_model) ->
    super @_model.getInstalledUrlsByIds(), @_model.getEnabledIds()
  somethingChanged: ->
    modelInstalledUrlById = @_model.getInstalledUrlsByIds()
    currentInstalledUrlById = @getInstalledUrlsByIds()
    allIds = {}
    allIds[i] = true for i of modelInstalledUrlById
    allIds[i] = true for i of currentInstalledUrlById

    modelEnabledIds = @_model.getEnabledIds()
    currentEnabledIds = @getEnabledIds()

    return not (
      (modelEnabledIds.length == currentEnabledIds.length) \
      and zip(modelEnabledIds, currentEnabledIds).every(([a,b]) -> a == b) \
      and (
        (modelInstalledUrlById[i] == currentInstalledUrlById[i]) for i of allIds
      ).reduce((a, b) -> a and b)
    )
  # Since files are kinda reference counted, every snapshot has to realease all
  # files when it's no longer used. Snapshot shall not be used after a call to
  # destroy, although it is not enforced.
  destroy: ->
    for id, path of @getInstalledUrlsByIds()
      if path and not (id in embeddedRuleSets)
        rulesetFiles.release path


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


class SuspendableManager extends Manager
  constructor: ->
    super arguments...
    @_suspended = prefs.get SUSPENDED_PREF
    prefs.onChange SUSPENDED_PREF, =>
      @_suspended = prefs.get SUSPENDED_PREF

  check: ->
    return true if @_suspended
    return super arguments...

  suspended: -> @_suspended
  toggleSuspended: -> prefs.set SUSPENDED_PREF, not @_suspended
  suspend: -> prefs.set SUSPENDED_PREF, true
  unsuspend: -> prefs.set SUSPENDED_PREF, false


class SavableSnapshotableManager extends SuspendableManager
  constructor: ->
    super (prefs.get INSTALLED_PATH_BY_ID_PREF), (prefs.get ENABLED_IDS_PREF)

    prefs.onChange INSTALLED_PATH_BY_ID_PREF, @_onInstalledPrefChange.bind @
    prefs.onChange ENABLED_IDS_PREF, @_onEnabledPrefChange.bind @

    onShutdown.add @save.bind @

  _loadInstalledIds: (newInstalledUrlById) ->
    for id, url of newInstalledUrlById
      unless @installed id, url
        @install id, url
    for id, url of @getInstalledUrlsByIds()
      unless newInstalledUrlById[id] == url
        @uninstall id, url

  _loadEnabledIds: (newEnabledIds) ->
    for id, i in newEnabledIds
      @enable id, i
    for id in @getEnabledIds()
      unless id in newEnabledIds
        @disable id

  _onInstalledPrefChange: ->
    @_loadInstalledIds prefs.get INSTALLED_PATH_BY_ID_PREF

  _onEnabledPrefChange: ->
    @_loadEnabledIds prefs.get ENABLED_IDS_PREF

  save: ->
    prefs.set ENABLED_IDS_PREF, @_enabledRuleSetsIds
    prefs.set INSTALLED_PATH_BY_ID_PREF, @_installedPathsByIds

  # this is for ui to play with and then load when user hits "Save" or smth
  snapshot: -> new SanityCheckedSnapshot @
  loadSnapshot: (shot) ->
    @_loadInstalledIds shot.getInstalledUrlsByIds()
    @_loadEnabledIds shot.getEnabledIds()
    @save()


exports.manager = new SavableSnapshotableManager
