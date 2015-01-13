
catMan = Cc["@mozilla.org/categorymanager;1"].getService Ci.nsICategoryManager

{ manager } = require 'ruleset/manager'
{
  OriginInfo, DestinationInfo, ContextInfo
  ChannelOriginInfo, ChannelDestinationInfo, ChannelContextInfo
} = require 'request-info'
{ memo } = require 'request-memo'
{ cache } = require 'request-cache'
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
    [os, ds, cs] = [origin.stringify(), dest.stringify(), ctx.stringify()]

    if null == (decision = cache.lookup os, ds, cs)
      decision = manager.check origin, dest, ctx
      cache.add os, ds, cs, decision

    memo.add origin, dest, ctx, decision
    blockedElements.process origin, dest, ctx, decision

    @onRequest.execute origin, dest, ctx, decision

    return decision

  # We store arguments object together with our request-info object
  # from the last call to `shouldLoad`. `observe` uses it to determine if it's
  # dealing with something that was already handled by shouldLoad.
  # NOTE There seems to be no explicit guarantees on the order of `shouldLoad`
  # and `observe` (with "http-on-modify-request" topic) calls anywhere in docs.
  # In fact, `observe` calls are not necessarily preceded by related `shouldLoad`
  # calls (that's why we need `observe` in the first place).
  # But we depend on that order here, so this may break some day.
  _lastShouldLoad: null

  # nsIContentPolicy interface implementation
  shouldLoad: (contentType, destUri, originUri, \
               context, mime, extra, principal) ->
    # Some things get past shouldLoad, notably favicon requests
    # Such requests are handled by `observe` below

    origin = new OriginInfo originUri
    dest = new DestinationInfo destUri
    ctx = new ContextInfo originUri, destUri, context, contentType, mime, principal

    decision = @_shouldLoad origin, dest, ctx

    @_lastShouldLoad = {
      contentType, destUri, originUri, context, mime, extra, principal,
      origin, dest, ctx,
      decision,
    }

    if decision
      return Ci.nsIContentPolicy.ACCEPT
    else
      return Ci.nsIContentPolicy.REJECT_OTHER

  # nsIObserver interface implementation
  observe: (subject, topic, data) ->
    switch topic
      when "http-on-modify-request"
        # TODO for some requests this gets executed immediately after `shouldLoad`
        # it may just mean that some checks are done twice, but it also could
        # be the case that the second check gives different result because
        # Channel*Info objects are poorer then their counterparts.
        # Nothing too wrong, but definitely some room for improvement.

        channel = subject.QueryInterface Ci.nsIHttpChannel

        decision = undefined

        if @_lastShouldLoad
          if channel.URI == @_lastShouldLoad.destUri
            # Got the same uri object as previous `shouldLoad` call.
            # Since `shouldLoad` gets far more info, let's say it knows better.
            decision = @_lastShouldLoad.decision
            @_lastShouldLoad = null

        if decision is undefined
          origin = new ChannelOriginInfo channel
          dest = new ChannelDestinationInfo channel
          ctx = new ChannelContextInfo channel

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
