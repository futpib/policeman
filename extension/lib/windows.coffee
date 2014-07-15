
{ Handlers } = require 'utils'

exports.windows = windows = # keeps track of browser windows
  onOpen: new Handlers # actually executed on window's content loaded
  onClose: new Handlers

  list: []

  init: ->
    wmListener =
      onOpenWindow: (xulWin) =>
        domWin = xulWin.QueryInterface(Ci.nsIInterfaceRequestor)
                .getInterface(Ci.nsIDOMWindow)

        loaded = =>
          domWin.removeEventListener "DOMContentLoaded", loaded
          if domWin.document.documentElement.getAttribute("windowtype") \
                == "navigator:browser"
            @onOpen.execute domWin
        domWin.addEventListener "DOMContentLoaded", loaded

      onCloseWindow: (xulWin) =>
        domWin = xulWin.QueryInterface(Ci.nsIInterfaceRequestor)
                .getInterface(Ci.nsIDOMWindow)
        if domWin.document.documentElement.getAttribute("windowtype") \
              == "navigator:browser"
          @onClose.execute domWin

    Services.wm.addListener wmListener
    onShutdown.add -> Services.wm.removeListener wmListener

    enumerator = Services.wm.getEnumerator "navigator:browser"
    @list.push(enumerator.getNext()) while enumerator.hasMoreElements()

    @onOpen.add (w) => @list.push w
    @onClose.add (w) => @list = @list.filter (w_) -> w_ isnt w

  getCurrent: -> Services.wm.getMostRecentWindow 'navigator:browser'

do windows.init
