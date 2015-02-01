

{ tabs } = require 'tabs'

{ redirectNotifications } = require 'ui/redirect-notifications'


class BlockedRedirectInfo
  constructor: (@origin, @destination, @context) ->
    @browser = (tabs.getTabById @context._tabId).linkedBrowser

  restore: ->
    @browser.loadURI @destination.spec

exports.blockedRedirects = blockedRedirects =
  process: (origin, destination, context, decision) ->
    if  decision is false \
    and context.hints.redirect \
    and context._tabId
      redirect = new BlockedRedirectInfo origin, destination, context
      redirectNotifications.show redirect
