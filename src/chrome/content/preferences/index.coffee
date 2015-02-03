

{ tabs } = require 'tabs'

{ manager } = require 'ruleset/manager'


class SubpageLink
  HREF_HASH_RE = /\/([^\/\.]+)\.xul$/
  select: (link) -> link.style.fontWeight = 'bold'
  deselect: (link) -> link.style.fontWeight = 'normal'
  hash: (link) -> '#' + link.href.match(HREF_HASH_RE)[1]


onLoad = ->
  iframe = $ 'iframe#subview'

  links = $$ '#subpref-links-container label.text-link'

  for link in links
    link.addEventListener 'click', do (link=link) -> (e) ->
      for otherLink in links
        SubpageLink::deselect otherLink
      hash = SubpageLink::hash link
      location.hash = hash
      SubpageLink::select link

  do updateFrameLocation = -> # navigate to initial hash or to a default page
    for otherLink in links
      SubpageLink::deselect otherLink
    for link in links
      hash = SubpageLink::hash link
      if location.hash == hash
        SubpageLink::select link
        iframe.contentDocument.location.replace link.href
        return
    defaultLink = $ '#default-subpref-link'
    SubpageLink::select defaultLink
    iframe.contentDocument.location.replace defaultLink.href

  addEventListener 'hashchange', (e) ->
    frameHash = SubpageLink::hash iframe.contentDocument.location
    if frameHash != location.hash
      do updateFrameLocation

  $('#version-number').value = addonData.version

  if not (manager.enabled('user_persistent') or manager.enabled('user_temporary'))
    for elem in $$ '.user-rulesets-preferences'
      elem.hidden = yes

  if not manager.enabled 'user_persistent'
    for elem in $$ '.persistent-ruleset-preferences'
      elem.hidden = yes
