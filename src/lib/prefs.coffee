

prefService = Cc["@mozilla.org/preferences-service;1"].getService Ci.nsIPrefService
policemanBranch = "extensions.policeman"


exports.PreferencesError = class PreferencesError extends Error
exports.UndefinedPreferenceError = class UndefinedPreferenceError extends PreferencesError
exports.InvalidValueError = class InvalidValueError extends PreferencesError


class Preferences
  PreferencesError: PreferencesError
  UndefinedPreferenceError: UndefinedPreferenceError
  InvalidValueError: InvalidValueError

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

    branch = branch + '.' if branch and not branch.endsWith('.')
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
    if 'get' of hooks
      @_nameToGetterHook[name] = hooks.get
    if 'set' of hooks
      @_nameToSetterHook[name] = hooks.set

  _assertDefined: (name) ->
    unless name of @_nameToType
      throw new UndefinedPreferenceError "Undefined preference '#{name}'"

  get: (name) ->
    @_assertDefined name
    unless @_branch.prefHasUserValue name
      default_ = @_nameToDefault[name]
      if name of @_nameToGetterHook
        getterHook = @_nameToGetterHook[name]
        try
          value = getterHook default_
        catch e
          if e instanceof InvalidValueError
            throw new PreferencesError "
              Getter for preference '#{name}' considers
              default value to be invalid."
          throw e
        return value
      return default_
    type = @_nameToType[name]
    getter = @typeGetterMap[type]
    value = @_branch[getter](name)
    if type == @TYPE_JSON
      value = JSON.parse value
    if name of @_nameToGetterHook
      getterHook = @_nameToGetterHook[name]
      try
        value = getterHook value
      catch e
        if e instanceof InvalidValueError
          value = @_nameToDefault[name]
        else
          throw e
    return value

  set: (name, value) ->
    @_assertDefined name
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


exports.ReadOnlyError = class ReadOnlyError extends PreferencesError

class ReadOnlyPreferences extends Preferences
  ReadOnlyError: ReadOnlyError
  set: (name) -> throw new ReadOnlyError "Trying to set read-only preference '#{name}'"


exports.prefs = prefs = new Preferences policemanBranch

prefs.define 'version',
  prefs.TYPE_STRING,
  '0.1'

exports.foreign = foreign = new ReadOnlyPreferences ''


