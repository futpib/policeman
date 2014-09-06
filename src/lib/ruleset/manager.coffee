
{ TextEncoder, OS } = Cu.import 'resource://gre/modules/osfile.jsm'
XMLHttpRequest = Components.Constructor("@mozilla.org/xmlextras/xmlhttprequest;1", "nsIXMLHttpRequest")

{ path: file_path } = require 'file'
{ remove, move, zip, cache, defaults } = require 'utils'

{ rulesetFromLocalUrl, rulesetFromString } = require 'ruleset/ruleset'
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
  default: [
    'default',
    'user_temporary',
    'user_persistent',
    'allow_same_site',
    'allow_same_second_level_domain',
    'reject_any',
  ]

addEmbedded = (obj) ->
  for id in embeddedRuleSets
    unless id of obj
      if id in codeBasedRuleSets
        obj[id] = null
      else
        obj[id] = file_path.toString file_path.join file_path.defaults, 'rulesets', "#{id}.ruleset"
  return obj

prefs.define 'manager.installedPathsByIds',
  default: {}
  get: (o) -> addEmbedded o

prefs.define 'manager.suspended',
  default: false


cachedRulesetConstructor = cache ((uri) -> uri), ((uri) ->
  try
    return file_path.toFile(uri).lastModifiedTime
  catch e
    return Math.random()
), rulesetFromLocalUrl


files = new class
  refCountByPath = Object.create null

  scope = OS.Path.join OS.Constants.Path.profileDir, 'policeman', 'rulesets'
  acquire: (path) ->
    if scope != OS.Path.dirname path
      throw new Error "#{JSON.stringify path} is out of
          #{JSON.stringify scope} directory"
    defaults refCountByPath, path, 0
    refCountByPath[path] += 1

  filenamesafe = (str) -> str.replace /[^A-Za-z._-]/g, '_'
  filenameRnd_ = -> Math.random().toString(36).slice(2)
  filenameRnd = (n=1) ->
    s = ''
    s += filenameRnd_() for i in [1..n]
    return s
  uniquePath: (prefix) ->
    prefix_ = if prefix is undefined then '' else filenamesafe(prefix) + '.'
    trial = 0
    while trial += 1
      path = OS.Path.join scope, "#{ prefix_ }#{ filenameRnd trial }.ruleset"
      return path unless path of refCountByPath

  release: (path) ->
    unless path of refCountByPath
      throw new Error "Releasing unknown path #{ JSON.stringify path }"
    refCountByPath[path] -= 1
    if refCountByPath[path] < 1
      delete refCountByPath[path]
      (OS.File.remove path).then null, ->
        log "files: release #{ JSON.stringify path }: Failed to remove the file."


exports.Manager = class Manager
  embeddedRuleSets: embeddedRuleSets
  codeBasedRuleSets: codeBasedRuleSets

  constructor: (installed, enabled) ->
    @_installedPathsByIds = Object.create null
    @_installedMetadataById = Object.create null

    @install id, url for id, url of installed

    @_enabledRuleSetsIds = [] # order defines priority
    @_enabledRuleSetsById = Object.create null

    @enable id for id in enabled

  codeBasedIdToObject =
    'user_temporary': temporaryRuleSet
    'user_persistent': persistentRuleSet

  _newRuleSetById: (id) ->
    if codeBasedIdToObject.hasOwnProperty id
      return codeBasedIdToObject[id]
    unless id of @_installedPathsByIds
      throw new Error "Ruleset '#{id}' is not installed"
    return cachedRulesetConstructor @_installedPathsByIds[id]

  installed: (id, path=undefined) ->
    if path isnt undefined
      return @_installedPathsByIds[id] == path
    return id of @_installedPathsByIds
  install: (id, path) ->
    return if @installed id, path
    @uninstall id if @installed id
    if path and not (id in embeddedRuleSets)
      files.acquire path
    @_installedPathsByIds[id] = path
    rs = @_newRuleSetById id
    @_installedMetadataById[id] = rs.getMetadata()
    @_installedMetadataById[id].sourceUrl = path
  uninstall: (id, path=undefined) ->
    return unless @installed id, path
    if id in embeddedRuleSets
      throw new Error "Can't uninstall embedded ruleset '#{id}'"
    if (path = @_installedPathsByIds[id])
      files.release path
    @disable id
    delete @_installedPathsByIds[id]
    delete @_installedMetadataById[id]

  encoder = new TextEncoder
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
    xhr.addEventListener 'error', -> dispatch 'error'
    xhr.addEventListener 'load', =>
      dispatch 'progress', {phase: 'parse'}
      return if aborted
      try
        # TODO go async
        str = xhr.responseText
        id = rulesetFromString(str).id
      catch err
        log 'downloadInstall', url, 'Failed parsing downloaded file', err
        dispatch 'error'
        return
      dispatch 'progress', {phase: 'save'}
      return if aborted
      path = files.uniquePath id
      OS.File.writeAtomic(path, encoder.encode(str),
                          tmpPath: "#{path}.tmp").then((=>
        try
          @install id, path
        catch err
          log 'downloadInstall', url, 'Failed installing ruleset', id, err
          dispatch 'error'
          return
        dispatch 'success', {id}
      ), (=>
        log "downloadInstall #{ JSON.stringify url }:
            Failed writing to #{ JSON.stringify path }.
            Ruleset '#{id}' not installed."
        dispatch 'error'
      ))
    dispatch 'start', {abort}
    try
      xhr.open "GET", url
      xhr.send()
    catch err
      log 'downloadInstall', url, 'failed sending GET request', err
      dispatch 'error'



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

  check: (origin, dest, ctx) ->
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
        files.release path


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
    @_suspended = prefs.get 'manager.suspended'
    prefs.onChange 'manager.suspended', =>
      @_suspended = prefs.get 'manager.suspended'

  check: ->
    return true if @_suspended
    return super arguments...

  suspended: -> @_suspended
  toggleSuspended: -> prefs.set 'manager.suspended', not @_suspended
  suspend: -> prefs.set 'manager.suspended', true
  unsuspend: -> prefs.set 'manager.suspended', false


class SavableSnapshotableManager extends SuspendableManager
  constructor: ->
    super (prefs.get 'manager.installedPathsByIds'), (prefs.get 'manager.enabledRuleSets')

    prefs.onChange 'manager.installedPathsByIds', @_onInstalledPrefChange.bind @
    prefs.onChange 'manager.enabledRuleSets', @_onEnabledPrefChange.bind @

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
    @_loadInstalledIds prefs.get 'manager.installedPathsByIds'

  _onEnabledPrefChange: ->
    @_loadEnabledIds prefs.get 'manager.enabledRuleSets'

  save: ->
    prefs.set 'manager.enabledRuleSets', @_enabledRuleSetsIds
    prefs.set 'manager.installedPathsByIds', @_installedPathsByIds

  # this is for ui to play with and then load when user hits "Save" or smth
  snapshot: -> new SanityCheckedSnapshot @
  loadSnapshot: (shot) ->
    @_loadInstalledIds shot.getInstalledUrlsByIds()
    @_loadEnabledIds shot.getEnabledIds()
    @save()


exports.manager = new SavableSnapshotableManager
