
{
    Cu
} = require 'chrome'

Cu.import 'resource://gre/modules/AddonManager.jsm'

self = require 'sdk/self'

onShutdown = null

exports.main = ->
    require 'lib/content-policy'
    require 'lib/ui/ui'

    { ReverseHandlers } = require 'lib/utils'
    onShutdown = new ReverseHandlers

    AddonManager.getAddonByID self.id, (addon) ->
        { updating } = require 'lib/updating'
        updating.finalize addon.version


exports.onUnload = () ->
  do onShutdown.execute

  onShutdown = null
