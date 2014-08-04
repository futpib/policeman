
###
Requests and decisions cache.
Operates on stringified request info objects.
###
exports.cache = cache =
  init: ->
  lookup: (origin, dest, context) -> null
  add: (origin, dest, context, decision) -> null

do cache.init
