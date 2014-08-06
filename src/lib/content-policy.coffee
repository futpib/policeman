
catMan = Cc["@mozilla.org/categorymanager;1"].getService Ci.nsICategoryManager

{ manager } = require 'ruleset/manager'
{ OriginInfo, DestinationInfo, ContextInfo } = require 'request-info'
{ memo } = require 'request-memo'
{ cache } = require 'request-cache'
{ blockedElements } = require 'blocked-elements'

registrar = Cm.QueryInterface Ci.nsIComponentRegistrar

policy =
  classDescription: "Policeman Content Policy Component"
  classID: Components.ID "{9208dac0-38ad-4bce-a0b5-f7c6ba9b0f7a}"
  contractID: "@futpib.addons.mozilla.org/policeman-content-policy;1"
  xpcom_categories: ["content-policy"]

  init: ->
    @register()
    onShutdown.add @unregister.bind @

  register: ->
    registrar.registerFactory @classID, @classDescription, @contractID, @

    for category in @xpcom_categories
      catMan.addCategoryEntry category, @contractID, @contractID, false, true

  unregister: ->
    for category in @xpcom_categories
      catMan.deleteCategoryEntry category, @contractID, false

    # This needs to run asynchronously, see ff bug 753687
    Services.tm.currentThread.dispatch \
      (=> registrar.unregisterFactory @classID, @),
      Ci.nsIEventTarget.DISPATCH_NORMAL

  # nsIContentPolicy interface implementation
  shouldLoad: (contentType, destUri, originUri, \
               context, mime, extra, principal) ->

    origin = new OriginInfo originUri
    dest = new DestinationInfo destUri
    ctx = new ContextInfo originUri, destUri, context, contentType, mime, principal

    [os, ds, cs] = [origin.stringify(), dest.stringify(), ctx.stringify()]

    if null == (decision = cache.lookup os, ds, cs)
      decision = manager.check origin, dest, ctx
      cache.add os, ds, cs, decision
    memo.add origin, dest, ctx, decision
    blockedElements.process origin, dest, ctx, decision

    if decision
      return Ci.nsIContentPolicy.ACCEPT
    else
      return Ci.nsIContentPolicy.REJECT_OTHER

  # nsIFactory interface implementation
  createInstance: (outer, iid) ->
    if outer
      throw Cr.NS_ERROR_NO_AGGREGATION;
    return @QueryInterface(iid);

  # nsISupports interface implementation
  QueryInterface: XPCOMUtils.generateQI([Ci.nsIContentPolicy, Ci.nsIFactory])

policy.init()
