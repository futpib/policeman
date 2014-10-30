
{
  classes:    Cc
  interfaces: Ci
  utils:      Cu
  manager:    Cm
  results:    Cr
} = Components

Cu.import 'resource://gre/modules/Services.jsm'
Cu.import 'resource://gre/modules/XPCOMUtils.jsm'

require = do ->
  reqComp = Cc["@futpib.addons.mozilla.org/policeman-internals;1"] \
                                    .getService().wrappedJSObject
  return reqComp.require

Cu.import 'resource://gre/modules/devtools/Console.jsm'
log = console.log.bind console

$ = (s) -> document.querySelector s

{ createElement: _createElement } = require 'utils'
createElement = ->
  return _createElement document, arguments...

onLoad = ->

window.addEventListener 'load', ->
  try
    onLoad arguments...
  catch e
    log e
