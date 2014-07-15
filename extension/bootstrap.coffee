
{
  classes:    Cc
  interfaces: Ci
  utils:      Cu
  manager:    Cm
  results:    Cr
} = Components

Cu.import 'resource://gre/modules/Services.jsm'

console = Cc["@mozilla.org/consoleservice;1"].getService Ci.nsIConsoleService
log = (args...) ->
  console.logStringMessage "policeman: bootstrap: #{args}"

tryer = (f) ->
  return ->
    try
      f arguments...
    catch e
      log "tryer:
              error: #{ e } \n
              file: '#{ e.fileName }' \n
              line: #{ e.lineNumber } \n
              stack: #{ e.stack }"

onShutdown = null
requireScope = null

install = tryer (data, reason) -> log 'install'

startup = tryer (data, reason) ->
  log 'startup'

  requireScope = {}
  Services.scriptloader.loadSubScript \
        "#{ data.resourceURI.spec }lib/require.jsm",
        requireScope

  requireScope.setAddonData data
  # require needs resourceURI too for the same purpose

  { ReverseHandlers } = requireScope.require 'utils'
  onShutdown = new ReverseHandlers
  # require makes handlers available in scripts it loads
  requireScope.setShutdownHandlers onShutdown

  requireScope.require 'content-policy'
  requireScope.require 'ui/ui'


shutdown = tryer (data, reason) ->
  log 'shutdown'

  do onShutdown.execute

  onShutdown = null
  requireScope = null

uninstall = tryer (data, reason) -> log 'uninstall'
