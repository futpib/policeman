
{
  XMLHttpRequest
} = require 'utils'


###
Something similar to document.loadOverlay but less buggy

This saves us from maintaining a queue as a workaround for 330458 (subsequent
calls to loadOverlay fail) https://bugzilla.mozilla.org/show_bug.cgi?id=330458.
Also closes #122 (cookiekeeper conflict).
###

exports.loadOverlay = loadOverlay = (doc, url, callback) ->
  xhr = new XMLHttpRequest
  xhr.addEventListener 'load', ->
    xml = xhr.responseXML
    overlay = xml.getElementsByTagName('overlay')[0]
    for child in overlay.children
      target = doc.getElementById child.id
      while elem = child.firstChild
        child.removeChild elem
        target.appendChild elem
    if callback
      try
        callback.call null, url
      catch e
        log.error "loadOverlay callback for '#{url}' threw", e
  xhr.open 'GET', url
  xhr.send()
