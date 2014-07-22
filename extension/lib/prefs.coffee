

prefService = Cc["@mozilla.org/preferences-service;1"].getService Ci.nsIPrefService
policemanBranch = "extensions.policeman"

class Preferences
  TYPE_BOOLEAN: 0
  TYPE_INTEGER: 1
  TYPE_STRING:  2
  TYPE_JSON:    3

  typeGetterMap: ['getBoolPref', 'getIntPref', 'getCharPref', 'getCharPref']
  typeSetterMap: ['setBoolPref', 'setIntPref', 'setCharPref', 'setCharPref']

  constructor: (branch) ->
    @_nameToType = {}
    @_nameToDefault = {}
    @_nameToGetterHook = {}
    @_nameToSetterHook = {}

    @_changeHandlers = {}

    branch = branch + '.' unless branch.endsWith('.')
    @_branch = prefService.getBranch branch
    @_branchName = branch
    @_branch.addObserver '', this, false
    onShutdown.add () => @_branch.removeObserver '', this

  observe: (_branch, topic, name) ->
    if name of @_changeHandlers
      do h for h in @_changeHandlers[name]

  define: (name, type, default_, hooks={}) ->
    @_nameToType[name] = type
    @_nameToDefault[name] = default_
    unless name in @_branch.getChildList '', {}
      @set name, default_
    if 'get' of hooks
      @_nameToGetterHook[name] = hooks.get
    if 'set' of hooks
      @_nameToSetterHook[name] = hooks.set

  get: (name) ->
    unless name of @_nameToType
      throw Error "prefs.get: undefined pref '#{name}'"
    unless @_branch.prefHasUserValue name
      default_ = @_nameToDefault[name]
      if name of @_nameToGetterHook
        return @_nameToGetterHook[name] default_
      return default_
    type = @_nameToType[name]
    getter = @typeGetterMap[type]
    value = @_branch[getter](name)
    if type == @TYPE_JSON
      value = JSON.parse value
    if name of @_nameToGetterHook
      value = @_nameToGetterHook[name] value
    return value

  set: (name, value) ->
    unless name of @_nameToType
      throw Error "prefs.set: undefined pref '#{name}'"
    type = @_nameToType[name]
    setter = @typeSetterMap[type]
    if name of @_nameToSetterHook
      value = @_nameToSetterHook[name] value
    if type == @TYPE_JSON
      value = JSON.stringify value
    @_branch[setter](name, value)

  mutate: (name, f) ->
    @set name, (f @get name)

  onChange: (name, handler) ->
    if name of @_changeHandlers
      @_changeHandlers[name].push handler
    else
      @_changeHandlers[name] = [handler]

  branch: (name) ->
    name = name + '.' unless name.endsWith('.')
    return new Preferences @_branchName + name

exports.prefs = prefs = new Preferences policemanBranch

prefs.define 'version',
  prefs.TYPE_STRING,
  '0.1'


