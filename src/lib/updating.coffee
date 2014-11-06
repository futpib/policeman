
{
  Handlers
  zip
} = require 'utils'
{ prefs } = require 'prefs'


exports.updating = updating = new class
  prefs.define 'version',
    default: '0.1'

  currentVersion = prefs.get 'version'

  versionUtils = new class
    toIntList = (v) -> v.split('.').map((x) -> parseInt x)
    normalizeLengthInplace = (as, bs) ->
      [long, short] = if as.length > bs.length then [as, bs] else [bs, as]
      short.unshift 0 while long.length > short.length
    gte = ([a, b]) -> a >= b
    lte = ([a, b]) -> a <= b
    eq  = ([a, b]) -> a == b
    every = (f) -> (as, bs) -> zip(as, bs).every(f)
    everyLTE = every lte
    everyGTE = every gte
    everyEQ  = every eq

    compare = (pairwiseCompare) -> (verA, verB) ->
      [as, bs] = [toIntList(verA), toIntList(verB)]
      normalizeLengthInplace as, bs
      return pairwiseCompare as, bs

    lte: compare everyLTE
    gte: compare everyGTE
    eq: compare everyEQ
    gt: -> not @lte arguments...
    lt: -> not @gte arguments...

  onUpdate = new Handlers

  from: (fromVersion, f) -> onUpdate.add (curV, newV) ->
    return unless versionUtils.lt fromVersion, newV
    f arguments...

  finalize: (newVersion) ->
    return unless versionUtils.gt newVersion, currentVersion
    onUpdate.execute(currentVersion, newVersion)
    prefs.set 'version', newVersion

