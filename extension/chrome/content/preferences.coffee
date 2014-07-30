
{ tabs } = require 'tabs'

onLoad = ->
  iframe = $ 'iframe#subview'

  onHashChange = (e) ->
    for anchor in $('#subpref-links-container').childNodes
      if ('#' + anchor.getAttribute('hash')) == window.top.location.hash
        if iframe.contentDocument.location.href != anchor.getAttribute 'href'
          iframe.contentDocument.location.replace anchor.getAttribute 'href'
        return
    iframe.contentDocument.location.replace 'chrome://policeman/content/preferences-general.xul'

  window.addEventListener 'hashchange', onHashChange
  do onHashChange

