

{ tabs } = require 'tabs'

{ manager } = require 'ruleset/manager'


class SubpageLink
  HREF_HASH_RE = /\/([^\/\.]+)\.xul$/
  select: (link) -> link.style.fontWeight = 'bold'
  deselect: (link) -> link.style.fontWeight = 'normal'
  hash: (link) -> '#' + link.href.match(HREF_HASH_RE)[1]


onLoad = ->
  iframe = $ 'iframe#subview'

  for link in $$ '#subpref-links-container a'
    link.addEventListener 'click', do (link=link) -> (e) ->
      for otherAnchor in $$ '#subpref-links-container a'
        SubpageLink::deselect otherAnchor
      hash = SubpageLink::hash link
      window.top.location.hash = hash
      SubpageLink::select link

  do -> # navigate to initial hash or to a default page
    for link in $$ '#subpref-links-container a'
      hash = SubpageLink::hash link
      if window.top.location.hash == hash
        SubpageLink::select link
        iframe.contentDocument.location.replace link.href
        return
    defaultLink = $ '#default-subpref-link'
    SubpageLink::select defaultLink
    iframe.contentDocument.location.replace defaultLink.href


  $('#version-number').value = addonData.version

  $('#help-link').addEventListener 'click', (e) ->
    e.preventDefault()
    tabs.open e.currentTarget.href

  if not (manager.enabled('user_persistent') or manager.enabled('user_temporary'))
    for elem in $$ '.user-rulesets-preferences'
      elem.hidden = yes

  if not manager.enabled 'user_persistent'
    for elem in $$ '.persistent-ruleset-preferences'
      elem.hidden = yes
