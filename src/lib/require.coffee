
# the only module loaded directly by bootstrap.js (using loadSubScript)
# others are loaded via require

{
  classes:    Cc
  interfaces: Ci
  utils:      Cu
  manager:    Cm
  results:    Cr
} = Components

Cu.import 'resource://gre/modules/Services.jsm'
Cu.import 'resource://gre/modules/XPCOMUtils.jsm'

Cu.import 'resource://gre/modules/devtools/Console.jsm'
log = console.log.bind console

addonData = null
onShutdown = null

# setAddonData and setShutdownHandlers are called by bootstrap.js ASAP

setAddonData = (d) ->
  addonData = d

setShutdownHandlers = (hs) ->
  onShutdown = hs
  requireComponent.init()

scopes = Object.create null
require = (module) ->
  unless module of scopes
    scopes[module] =
      Cc: Cc
      Ci: Ci
      Cr: Cr
      Cm: Cm
      Cu: Cu
      Services: Services
      XPCOMUtils: XPCOMUtils

      addonData: addonData

      require: require
      onShutdown: onShutdown
      log: log

      exports: Object.create null

    expectedLocation = "#{ addonData.resourceURI.spec }lib/#{ module }.js"
    Services.scriptloader.loadSubScript expectedLocation, scopes[module]

  return scopes[module].exports

# The sole purpose of this component is to make require available
# for code in xul pages.
registrar = Cm.QueryInterface Ci.nsIComponentRegistrar
requireComponent =
  classDescription: "Policeman internal component"
  classID: Components.ID "{73a44376-2a43-43df-9c26-cbbe6ff00561}"
  contractID: "@futpib.addons.mozilla.org/policeman-internals;1"

  init: ->
    @wrappedJSObject = @
    try
      @register()
    catch e
      if e.result == Cr.NS_ERROR_FACTORY_EXISTS
        # too early to init now, the old version didn't finish removing itself
        Services.tm.currentThread.dispatch (@init.bind @),
                                            Ci.nsIEventTarget.DISPATCH_NORMAL
        return
      throw e
    onShutdown.add @unregister.bind @

  register: ->
    registrar.registerFactory @classID, @classDescription, @contractID, @

  unregister: ->
    # This needs to run asynchronously, see ff bug 753687
    Services.tm.currentThread.dispatch \
      (=> registrar.unregisterFactory @classID, @),
      Ci.nsIEventTarget.DISPATCH_NORMAL

  require: require

  # nsIFactory interface implementation
  createInstance: (outer, iid) ->
    if outer
      throw Cr.NS_ERROR_NO_AGGREGATION;
    return @QueryInterface(iid);

  # nsISupports interface implementation
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIFactory])
