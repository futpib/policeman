
{ prefs } = require 'lib/prefs'

onLoad = ->
  $('#info-box').value = JSON.stringify (
    prefsDump: prefs._debug_dump()
  ), null, 2
