
{ Observer } = require 'utils'

# bug 330458 workaround
# https://bugzilla.mozilla.org/show_bug.cgi?id=330458

exports.overlayQueue = new class extends Observer
  _queue: []
  _urlToCallback: {}
  _pending: false

  constructor: ->
    super 'xul-overlay-merged', @observe.bind @
    onShutdown.add @unregister.bind @

  add: (doc, url, callback=null) ->
    @_queue.push [doc, url]
    @_urlToCallback[url] = callback if callback
    do @merge

  merge: ->
    return if @_pending
    return if not @_queue.length
    [doc, url] = @_queue.pop()
    @_pending = true
    doc.loadOverlay url, @

  observe: (uri) ->
    url = uri.QueryInterface(Ci.nsIURI).spec
    if url of @_urlToCallback
      try
        do @_urlToCallback[url]
      catch e
        log "xul-overlay-merged callback for '#{url}':
              error: #{ e } \n
              file: '#{ e.fileName }' \n
              line: #{ e.lineNumber } \n
              stack: #{ e.stack }"
    delete @_urlToCallback[url]
    @_pending = false
    do @merge
