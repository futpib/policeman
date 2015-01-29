
###
This file is included into every other *.coffee test file by the tester script.
###

setupModule = (m) ->
  m.policeman = new class
    id: 'policeman@futpib.addons.mozilla.org'

    require: ->
      internals = Cc["@futpib.addons.mozilla.org/policeman-internals;1"] \
                  .getService().wrappedJSObject
      return internals.require arguments...

  { console: m.console } = Cu.import 'resource://gre/modules/devtools/Console.jsm'
