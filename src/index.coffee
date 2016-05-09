
{
  classes:    Cc
  interfaces: Ci
  utils:      Cu
  manager:    Cm
  results:    Cr
} = Components

Cu.import 'resource://gre/modules/Services.jsm'

Cu.import 'resource://gre/modules/devtools/Console.jsm'
log = console.log.bind console

Cu.import 'resource://gre/modules/AddonManager.jsm'

onShutdown = null
requireScope = null

install = (data, reason) ->

startup = (data, reason) ->
  requireScope = {}
  Services.scriptloader.loadSubScript \
        "#{ data.resourceURI.spec }lib/require.js",
        requireScope

  requireScope.setAddonData data
  # require needs resourceURI too for the same purpose

  { ReverseHandlers } = requireScope.require 'lib/utils'
  onShutdown = new ReverseHandlers
  # require makes handlers available in scripts it loads
  requireScope.setShutdownHandlers onShutdown

  requireScope.require 'lib/content-policy'
  requireScope.require 'lib/ui/ui'

  AddonManager.getAddonByID data.id, (addon) ->
    { updating } = requireScope.require 'lib/updating'
    updating.finalize addon.version


shutdown = (data, reason) ->
  do onShutdown.execute

  onShutdown = null
  requireScope = null

uninstall = (data, reason) ->
