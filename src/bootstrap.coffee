
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

  { ReverseHandlers } = requireScope.require 'utils'
  onShutdown = new ReverseHandlers
  # require makes handlers available in scripts it loads
  requireScope.setShutdownHandlers onShutdown

  requireScope.require 'content-policy'
  requireScope.require 'ui/ui'
  { updating } = requireScope.require 'updating'
  updating.finalize '0.13'


shutdown = (data, reason) ->
  do onShutdown.execute

  onShutdown = null
  requireScope = null

uninstall = (data, reason) ->
