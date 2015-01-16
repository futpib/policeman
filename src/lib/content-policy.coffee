
catMan = Cc["@mozilla.org/categorymanager;1"].getService Ci.nsICategoryManager

{ manager } = require 'ruleset/manager'
{
  getShouldLoadInfoObjects
  getChannelInfoObjects
} = require 'request-info'
{ memo } = require 'request-memo'
{ blockedElements } = require 'blocked-elements'
{
  Handlers
  runAsync
} = require 'utils'

registrar = Cm.QueryInterface Ci.nsIComponentRegistrar
observerService = Cc["@mozilla.org/observer-service;1"]
                  .getService Ci.nsIObserverService

exports.policy = policy =
  classDescription: "Policeman Content Policy Component"
  classID: Components.ID "{9208dac0-38ad-4bce-a0b5-f7c6ba9b0f7a}"
  contractID: "@futpib.addons.mozilla.org/policeman-content-policy;1"
  categories: ["content-policy"]
  topics: ["http-on-modify-request"]

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

    for category in @categories
      catMan.addCategoryEntry category, @contractID, @contractID, false, true

    for topic in @topics
      observerService.addObserver @, topic, false

  unregister: ->
    for category in @categories
      catMan.deleteCategoryEntry category, @contractID, false

    # This needs to run asynchronously, see ff bug 753687
    runAsync (=> registrar.unregisterFactory @classID, @)

    for topic in @topics
      observerService.removeObserver @, topic

  onRequest: new Handlers

  # the main entry point for attemted requests
  _shouldLoad: (origin, dest, ctx) ->
    decision = manager.check origin, dest, ctx

    memo.add origin, dest, ctx, decision
    blockedElements.process origin, dest, ctx, decision

    @onRequest.execute origin, dest, ctx, decision


    return decision

  # nsIContentPolicy interface implementation
  shouldLoad: (contentType, destUri, originUri, \
               context, mime, extra, principal) ->
    # Some things get past shouldLoad, notably favicon requests
    # Such requests are handled by `observe` below

    [origin, dest, ctx] = getShouldLoadInfoObjects \
                contentType, destUri, originUri, context, mime, extra, principal

    decision = @_shouldLoad origin, dest, ctx

    if decision
      return Ci.nsIContentPolicy.ACCEPT
    else
      return Ci.nsIContentPolicy.REJECT_OTHER

  # nsIObserver interface implementation
  observe: (subject, topic, data) ->
    switch topic
      when "http-on-modify-request"
        # NOTE for some requests this gets executed immediately after `shouldLoad`
        # it may just mean that some checks are done twice, but it also could
        # be the case that the second check gives different result because
        # Channel*Info objects are different from their counterparts.

        channel = subject.QueryInterface Ci.nsIHttpChannel

        [origin, dest, ctx, ci] = getChannelInfoObjects channel
        decision = @_shouldLoad origin, dest, ctx


        if not decision
          channel.cancel Cr.NS_ERROR_UNEXPECTED

  # nsIFactory interface implementation
  createInstance: (outer, iid) ->
    if outer
      throw Cr.NS_ERROR_NO_AGGREGATION;
    return @QueryInterface(iid);

  # nsISupports interface implementation
  QueryInterface: XPCOMUtils.generateQI [
          Ci.nsIContentPolicy,
          Ci.nsIObserver,
          Ci.nsIFactory,
  ]

policy.init()
