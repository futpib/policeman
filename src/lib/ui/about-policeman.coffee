
registrar = Cm.QueryInterface Ci.nsIComponentRegistrar

{
  runAsync
} = require 'utils'


exports.aboutPages =
  PREFERENCES: 'about:policeman'
  PREFERENCES_GENERAL: 'about:policeman#general'
  PREFERENCES_POPUP: 'about:policeman#popup'
  PREFERENCES_RULESETS: 'about:policeman#rulesets-manager'
  PREFERENCES_USER: 'about:policeman#user-rulesets'

aboutPolicemanModule =
  classDescription: "about:policeman"
  classID: Components.ID "{725c902f-c265-42d2-b757-bb402ab18fe2}"
  contractID: "@mozilla.org/network/protocol/about;1?what=policeman"

  ABOUT_PAGE_URL: "chrome://policeman/content/preferences.xul"

  init: ->
    try
      @register()
    catch e
      if e.result == Cr.NS_ERROR_FACTORY_EXISTS
        # too early to init now, the old version didn't finish removing itself
        runAsync @init.bind @
        return
      throw e
    onShutdown.add @unregister.bind @

  register: ->
    registrar.registerFactory @classID, @classDescription, @contractID, @

  unregister: ->
    # This needs to run asynchronously, see ff bug 753687
    runAsync (=> registrar.unregisterFactory @classID, @)

  # nsIAboutModule interface implementation
  getURIFlags: (aURI) ->
    return Ci.nsIAboutModule.ALLOW_SCRIPT

  newChannel: (aURI) ->
    ios = Cc["@mozilla.org/network/io-service;1"].getService Ci.nsIIOService
    channel = ios.newChannel @ABOUT_PAGE_URL, null, null
    channel.originalURI = aURI
    return channel

  # nsIFactory interface implementation
  createInstance: (outer, iid) ->
    if outer
      throw Cr.NS_ERROR_NO_AGGREGATION
    return @QueryInterface iid

  # nsISupports interface implementation
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIAboutModule, Ci.nsIFactory])

aboutPolicemanModule.init()

