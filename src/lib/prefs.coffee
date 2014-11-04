

prefService = Cc["@mozilla.org/preferences-service;1"].getService Ci.nsIPrefService
policemanBranch = "extensions.policeman"


exports.PreferencesError = class PreferencesError extends Error
exports.UndefinedPreferenceError = class UndefinedPreferenceError extends PreferencesError


class Preferences
  PreferencesError: PreferencesError
  UndefinedPreferenceError: UndefinedPreferenceError

  _typePrefGetterMap:
    boolean: 'getBoolPref'
    integer: 'getIntPref'
    string:  'getCharPref'
    object:  'getCharPref'
    unicode: 'getComplexValue'
    uobject: 'getComplexValue'
  _typePrefSetterMap:
    boolean: 'setBoolPref'
    integer: 'setIntPref'
    string:  'setCharPref'
    object:  'setCharPref'
    unicode: 'setComplexValue'
    uobject: 'setComplexValue'
  _complexTypeInterfaceMap:
    unicode: Ci.nsISupportsString
    uobject: Ci.nsISupportsString
  _jsonTypes:
    object: yes
    uobject: yes

  constructor: (branch) ->
    @_nameToType = Object.create null
    @_nameToDefault = Object.create null

    branch = branch + '.' if branch and not branch.endsWith('.')
    @_branch = prefService.getBranch branch
    @_branchName = branch

  _inferType: (default_) -> switch t = typeof default_
    when 'boolean' then 'boolean'
    when 'string'  then 'string'
    when 'number'  then (if default_ % 1 == 0 then 'integer' else 'object')
    when 'undefined', 'object' then 'object'
    else throw new PreferencesError "
                    Can't guess how to store value of type '#{t}'.
                    Please supply explicit type."

  define: (name, description={}) ->
    {
      type
      default: default_
    } = description
    if type and not (type of @_typePrefGetterMap)
      throw new PreferencesError "Unknown type '#{type}'. Try one of
                                  #{ Object.keys(@_typePrefGetterMap) }."
    @_nameToType[name] = type or @_inferType default_
    @_nameToDefault[name] = default_
    @_initDefault name, default_ unless @_branch.prefHasUserValue name
    return name

  _getRaw: (name) ->
    @_assertDefined name
    type = @_nameToType[name]
    getter = @_typePrefGetterMap[type]
    if type of @_complexTypeInterfaceMap
      value = @_branch[getter] name, @_complexTypeInterfaceMap[type]
    else
      value = @_branch[getter] name
    return value

  _setRaw: (name, value) ->
    @_assertDefined name
    type = @_nameToType[name]
    setter = @_typePrefSetterMap[type]

    if @_complexTypeInterfaceMap[type] is Ci.nsISupportsString
      unless value instanceof Ci.nsISupportsString
        value_ = Cc["@mozilla.org/supports-string;1"]
                .createInstance(Ci.nsISupportsString)
        value_.data = value
        value = value_

    if type of @_complexTypeInterfaceMap
      @_branch[setter] name, @_complexTypeInterfaceMap[type], value
    else
      @_branch[setter] name, value

  _initDefault: (name, value) ->
    type = @_nameToType[name]
    value = JSON.stringify value if type of @_jsonTypes
    @_setRaw name, value

  _assertDefined: (name) ->
    unless name of @_nameToType
      throw new UndefinedPreferenceError "Undefined preference '#{name}'"

  _default: (name) -> @_nameToDefault[name]

  get: (name) ->
    @_assertDefined name
    type = @_nameToType[name]

    try
      value = @_getRaw name
      if type of @_jsonTypes
        value = JSON.parse value
    catch e
      log "Error getting preference '#{name}':", e,
          "Using default value"
      value = @_default name
    return value

  set: (name, value) ->
    @_assertDefined name
    type = @_nameToType[name]

    value = JSON.stringify value if type of @_jsonTypes

    @_setRaw name, value

  mutate: (name, f) ->
    @set name, (f @get name)

  branch: (name) ->
    name = name + '.' unless name.endsWith('.')
    return new @::constructor @_branchName + name


class ObservablePreferences extends Preferences
  constructor: ->
    super arguments...

    @_changeHandlers = Object.create null

    observer = observe: => @_observe arguments...
    @_branch.addObserver '', observer, false
    onShutdown.add => @_branch.removeObserver '', observer

  _observe: (_branch, topic, name) ->
    if name of @_changeHandlers
      do h for h in @_changeHandlers[name]

  onChange: (name, handler) ->
    if name of @_changeHandlers
      @_changeHandlers[name].push handler
    else
      @_changeHandlers[name] = [handler]


FinalPreferencesClass = class HookedPreferences extends ObservablePreferences
  constructor: ->
    super arguments...

    @_nameToGetterHook = Object.create null
    @_nameToSetterHook = Object.create null

  define: (name, description={}) ->
    {
      get
      set
    } = description
    @_nameToGetterHook[name] = get if get
    @_nameToSetterHook[name] = set if set
    return super arguments...

  id = (x) -> x
  _getterHook: (name) -> @_nameToGetterHook[name] or id
  _setterHook: (name) -> @_nameToSetterHook[name] or id

  get: (name) ->
    value = super name
    hook = @_getterHook name
    return hook value

  set: (name, value) ->
    hook = @_setterHook name
    value = hook value
    super name, value


exports.ReadOnlyError = class ReadOnlyError extends PreferencesError

class ReadOnlyPreferences extends FinalPreferencesClass
  ReadOnlyError: ReadOnlyError
  _initDefault: ->
  set: (name) ->
    throw new ReadOnlyError "Trying to set read-only preference '#{name}'"


exports.prefs = prefs = new FinalPreferencesClass policemanBranch

exports.foreign = foreign = new ReadOnlyPreferences ''


