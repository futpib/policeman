

{ windows } = require 'windows'
{ tabs } = require 'tabs'
{ memo } = require 'request-memo'
{ manager } = require 'ruleset/manager'
{
  Handlers
  Observer
  superdomains
  createElement
  removeChildren
  loadSheet
  removeSheet
} = require 'utils'
{ overlayQueue } = require 'ui/overlay-queue'

{ aboutPages } = require 'ui/about-policeman'

{ Color } = require 'color'
{ prefs } = require 'prefs'

{ l10n } = require 'l10n'


POSITIVE_BG_PREF = 'ui.panelview.positiveBgColor'
NEGATIVE_BG_PREF = 'ui.panelview.negativeBgColor'


colorGetter = (c) -> new Color c
colorSetter = (c) -> c.toCssString()
prefs.define POSITIVE_BG_PREF,
  default: '#0f02'
  get: colorGetter
  set: colorSetter
prefs.define NEGATIVE_BG_PREF,
  default: '#f002'
  get: colorGetter
  set: colorSetter

positiveBgColor = prefs.get POSITIVE_BG_PREF
prefs.onChange POSITIVE_BG_PREF, ->
  positiveBgColor = prefs.get POSITIVE_BG_PREF
negativeBgColor = prefs.get NEGATIVE_BG_PREF
prefs.onChange NEGATIVE_BG_PREF, ->
  negativeBgColor = prefs.get NEGATIVE_BG_PREF


prefs.define AUTORELOAD_PREF = 'ui.panelview.autoReloadPageOnHiding',
  default: false
  sync: true


class ContainerPopulation
  constructor: (@_containerId) ->
  populate: (doc) ->
  purge: (doc) ->
    removeChildren doc.getElementById @_containerId
  update: (doc) ->
    @purge doc
    @populate doc


class DestinationSubmenu
  create: (doc, description) ->
    {
      origins
      destination
      allow
      reject
    } = description
    allowRatio = allow/(allow+reject)
    menu = createElement doc, 'menu',
      class: 'subviewbutton'
      label: destination
      style: "background: #{
        positiveBgColor.mix(
          negativeBgColor, allowRatio
        ).toCssString()
      };"
    popup = createElement doc, 'menupopup'
    menu.appendChild popup

    temp = manager.get 'user_temporary'
    pers = manager.get 'user_persistent'

    for [rs, l] in [[temp, 'temporarily'], [pers, 'persistently']]
      if rs
        do (rs) ->
          for origin of origins
            do (origin) ->
              popup.appendChild createElement doc, 'menuitem',
                label: l10n "panelview_allow_origin_destination_#{l}", origin, destination
                event_command: ->
                  rs.allow origin, destination, rs.WILDCARD_TYPE
                  panelview.autoreload.require()

          popup.appendChild createElement doc, 'menuitem',
            label: l10n "panelview_allow_destination_#{l}", destination
            event_command: ->
              rs.allow '', destination, rs.WILDCARD_TYPE
              panelview.autoreload.require()

        if (rs == temp) and pers
          popup.appendChild createElement doc, 'menuseparator'

    return menu


affectedDestinations = new (class extends ContainerPopulation
  populate: (doc) ->
    dests = doc.getElementById @_containerId

    domains = {}
    for [o, d, c, decision] in memo.getByTab tabs.getCurrent()
      continue unless o.schemeType == d.schemeType == 'web'
      origin2lvl = superdomains(o.host, 2).reverse()[0]
      dest2lvl = superdomains(d.host, 2).reverse()[0]
      domains[dest2lvl] ?= {
        dest: dest2lvl
        origins: {}
        allow: 0
        reject: 0
      }
      domains[dest2lvl][if decision then 'allow' else 'reject'] += 1
      domains[dest2lvl].origins[origin2lvl] = true
    domains = (d for _, d of domains)
    dom.hits = dom.allow + dom.reject for dom in domains
    domains.sort(({hits:h1}, {hits:h2}) -> h2 - h1)

    for dom in domains
      dests.appendChild DestinationSubmenu::create doc,
        origins: dom.origins
        destination: dom.dest
        allow: dom.allow
        reject: dom.reject

  purge: (doc) ->
    dests = doc.getElementById @_containerId
    removeChildren dests

) 'policeman-panelview-affected-destinations-container'


suspendCheckbox =
  id: 'policeman-panelview-suspend-operation'
  setup: (doc) ->
    cb = doc.getElementById @id
    cb.addEventListener 'command', ->
      if @getAttribute('checked') == 'true'
        manager.suspend()
      else
        manager.unsuspend()
  update: (doc) ->
    cb = doc.getElementById @id
    cb.setAttribute 'checked', manager.suspended()

reloadCheckbox =
  id: 'policeman-panelview-reload-page'
  setup: (doc) ->
    cb = doc.getElementById @id
    cb.addEventListener 'command', ->
      if @getAttribute('checked') == 'true'
        panelview.autoreload.enable()
      else
        panelview.autoreload.disable()
  update: (doc) ->
    cb = doc.getElementById @id
    cb.setAttribute 'checked', prefs.get AUTORELOAD_PREF


preferencesButton =
  id: 'policeman-panelview-open-preferences'
  setup: (doc) ->
    btn = doc.getElementById @id
    btn.addEventListener 'command', ->
      tabs.open aboutPages.PREFERENCES_USER


exports.panelview = panelview =
  id: 'PanelUI-policeman'

  styleURI: Services.io.newURI 'chrome://policeman/skin/panelview.css', null, null

  init: ->
    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

    tabs.onSelect.add (t) =>
      if @visible
        @updateUI t.ownerDocument


  onOpenEvent: (e) ->
    btn = e.target
    doc = btn.ownerDocument
    ###
    XXX multiView.showSubView may not be a part of public API
    (couldn't find MDN mentioning it anywhere).
    Found it's use here:
    chrome://browser/content/browser.js#SocialStatus.showPopup ->
    chrome://browser/content/customizableui/panelUI.js#PanelUI.showSubView
    ###
    doc.getElementById('PanelUI-multiView').showSubView panelview.id, btn


  onShowing: (e) ->
    doc = e.target.ownerDocument
    @autoreload.onShowing doc
    @updateUI doc
    @visible = true

  onHiding: (e) ->
    doc = e.target.ownerDocument
    # The ViewHiding event fires before any oncommand handler requires autoreload
    # (autoreload.require()), so we have to delay autoreload.required test.
    Services.tm.currentThread.dispatch (=>
      if @autoreload.enabled() and @autoreload.required()
        tabs.reload tabs.getCurrent()
    ), Ci.nsIEventTarget.DISPATCH_NORMAL
    @cleanupUI doc
    @visible = false

  addUI: (win) ->
    doc = win.document
    view = createElement doc, "panelview",
        id: @id
        flex: 1
    view.addEventListener 'ViewShowing', @onShowing.bind @
    view.addEventListener 'ViewHiding', @onHiding.bind @
    doc.getElementById("PanelUI-multiView").appendChild(view)

    overlayQueue.add doc, 'chrome://policeman/content/panelview.xul', =>
      suspendCheckbox.setup doc
      reloadCheckbox.setup doc
      preferencesButton.setup doc

    loadSheet win, @styleURI

  removeUI: (win) ->
    doc = win.document
    view = doc.getElementById @id
    view.parentNode.removeChild view
    removeSheet win, @styleURI

  updateUI: (doc) ->
    suspendCheckbox.update doc
    reloadCheckbox.update doc
    affectedDestinations.update doc

  cleanupUI: (doc) ->

  autoreload:
    _reloadRequired: false
    enabled: -> prefs.get AUTORELOAD_PREF
    enable: -> prefs.set AUTORELOAD_PREF, true
    disable: -> prefs.set AUTORELOAD_PREF, false
    required: -> @_reloadRequired
    require: -> @_reloadRequired = true
    onShowing: -> @_reloadRequired = false



do panelview.init
