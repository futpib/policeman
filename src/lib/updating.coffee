
{
  Handlers
  versionComparator
} = require 'lib/utils'
{ prefs } = require 'lib/prefs'


exports.updating = updating = new class
  prefs.define 'version',
    default: '0.1'

  currentVersion = prefs.get 'version'

  onUpdate = new Handlers

  from: (fromVersion, f) -> onUpdate.add (curV, newV) ->
    return unless versionComparator.lt fromVersion, newV
    f arguments...

  finalize: (newVersion) ->
    return unless versionComparator.gt newVersion, currentVersion
    onUpdate.execute(currentVersion, newVersion)
    prefs.set 'version', newVersion

