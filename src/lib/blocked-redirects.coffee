

{ tabs } = require 'tabs'
{ RequestInfo } = require 'request-info'

{ redirectNotifications } = require 'ui/redirect-notifications'


class BlockedRedirectInfo extends RequestInfo
  constructor: ->
    super arguments...
    @browser = (tabs.getTabById @context._tabId).linkedBrowser

  restore: ->
    @browser.loadURI @destination.spec

exports.blockedRedirects = blockedRedirects =
  process: (request, decision) ->
    if  decision is false \
    and request.context.hints.redirect \
    and request.context.contentType == 'DOCUMENT' \
    and request.context._tabId
      redirect = new BlockedRedirectInfo request
      redirectNotifications.show redirect
