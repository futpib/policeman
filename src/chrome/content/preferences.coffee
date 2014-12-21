
{ tabs } = require 'tabs'

onLoad = ->
  iframe = $ 'iframe#subview'

  onHashChange = (e) ->
    hashFound = no
    for anchor in $('#subpref-links-container').childNodes
      anchor.style.fontWeight = 'normal'
      if ('#' + anchor.getAttribute('hash')) == window.top.location.hash
        hashFound = yes
        anchor.style.fontWeight = 'bold'
        if iframe.contentDocument.location.href != anchor.getAttribute 'href'
          iframe.contentDocument.location.replace anchor.getAttribute 'href'
    if not hashFound
      $('#subpref-links-container a[hash="general"]').style.fontWeight = 'bold'
      iframe.contentDocument.location.replace 'chrome://policeman/content/preferences-general.xul'

  window.addEventListener 'hashchange', onHashChange
  do onHashChange

  $('#version-number').value = addonData.version

  $('#help-link').addEventListener 'click', (e) ->
    e.preventDefault()
    tabs.open e.currentTarget.href

