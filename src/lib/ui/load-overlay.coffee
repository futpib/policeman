
{
  removeNode
  XMLHttpRequest
} = require 'lib/utils'


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

    ###
    Remove text nodes. Some firefox code expects their absence. Particulary
    chrome://global/content/bindings/scrollbox.xml does (_canScrollToElement
    (which uses getComputedStyle, expecting element) is called on childNodes)
    TODO maybe we have to go farther and remove all non-element nodes
    TODO maybe report to mozilla
    ###
    toBeRemoved = []
    textWalker = xml.createTreeWalker xml, Ci.nsIDOMNodeFilter.SHOW_TEXT
    while textWalker.nextNode()
      toBeRemoved.push textWalker.currentNode
    toBeRemoved.forEach removeNode

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
