

{ tabs } = require 'tabs'
{ manager } = require 'ruleset/manager'
{
  Handlers
  Observer
  superdomains
  createElement
  removeChildren
} = require 'utils'
{ overlayQueue } = require 'ui/overlay-queue'
{ prefs } = require 'prefs'

{ l10n } = require 'l10n'


prefs.define 'ui.popup.autoReloadPageOnHiding',
  prefs.TYPE_BOOLEAN, false

reloadPageCheckbox =
  id: 'policeman-reload-page'
  containerId: 'policeman-reload-page-container'
  add: (doc) ->
    cb = doc.getElementById @id
    cb.addEventListener 'command', @command.bind @
  update: (doc) ->
    show = listeners.some (l) ->
      ('wantsPageReload' of l) and l.wantsPageReload()
    container = doc.getElementById @containerId
    container.setAttribute 'hidden', not show
    cb = doc.getElementById @id
    if prefs.get 'ui.popup.autoReloadPageOnHiding'
      cb.setAttribute 'checked', true
    else
      cb.removeAttribute 'checked'
  command: (e) ->
    prefs.set 'ui.popup.autoReloadPageOnHiding', e.target.checked


listeners = [
  {
    id: 'policeman-temp-allow-any'
    _initialState: null
    _finalState: null
    wantsPageReload: -> @_initialState != @_finalState
    add: (doc) ->
      doc.getElementById(@id).addEventListener 'command', do (that=@)-> (e) ->
        return unless manager.isEnabled 'temp'
        temp = manager.get 'temp'
        that._finalState = @checked
        reloadPageCheckbox.update doc
        if @checked
          temp.any.allow()
        else
          temp.any.revoke()
    update: (doc) ->
      return unless manager.isEnabled 'temp'
      temp = manager.get 'temp'
      cb = doc.getElementById(@id)
      anyAllowed = temp.any.isAllowed()
      @_initialState = @_finalState = anyAllowed
      if anyAllowed
        cb.setAttribute 'checked', true
      else
        cb.removeAttribute 'checked'
  }, {
    id: 'policeman-temp-allow-doc' # TODO
  }, {
    # this object represents all those 'Temp/Permanent allow domain' checkboxes
    _initialState: {} # domain -> bool
    _finalState: {}
    wantsPageReload: ->
      for j of @_initialState
        if @_initialState[j] != @_finalState[j]
          return true
      return false
    update: (doc, view, uri) -> # handles both temporary and permanent permissions
      web = uri.scheme in ['http', 'https']
      if web
        @_initialState = {}
        @_finalState = {}
        for pers_temp in ['temp', 'pers']
          container = doc.getElementById \
                    "policeman-#{pers_temp}-allow-domain-container"
          removeChildren container
          for dom in (superdomains uri.host)[..-2] # exclude top-level domain
            enabled = manager.isEnabled pers_temp
            if enabled
              rs = manager.get pers_temp
              allowed = rs.domain.isAllowed dom
              checkbox = createElement doc, 'checkbox',
                  label: l10n pers_temp + '_allow_domain', dom
                  tooltiptext: l10n pers_temp + '_allow_domain.tip', dom
                  checked: allowed
              @_initialState[dom] = @_finalState[dom] = allowed
              checkbox.addEventListener 'command', do (dom=dom, rs=rs, that=@) -> (e) ->
                that._finalState[dom] = @checked
                reloadPageCheckbox.update doc
                if @checked
                  rs.domain.allow dom
                else
                  rs.domain.revoke dom
              container.appendChild checkbox
      return
  }, {
    id: 'policeman-temp-permissions-container'
    update: (doc) ->
      container = doc.getElementById @id
      container.setAttribute 'hidden', not manager.isEnabled 'temp'
  }, {
    id: 'policeman-revoke-temp-permissions-container'
    update: (doc) ->
      container = doc.getElementById @id
      container.setAttribute 'hidden',
          not (manager.isEnabled 'temp') or (manager.get 'temp').isEmpty()
  }, {
    class: 'policeman-show-on-web'
    update: (doc, view, uri) ->
      web = uri.scheme in ['http', 'https']
      Array.prototype.forEach.call (view.getElementsByClassName @class),
          (elem) -> elem.setAttribute 'hidden', not web
  },
  # Has to be updated last, because it's initial state depends on a bunch of
  # checkboxes
  reloadPageCheckbox
]



exports.panelview = panelview =
  id: 'PanelUI-policeman'

  # called by customizableui (ui/toolbarbutton)
  onShowing: new Handlers
  onHiding: new Handlers
  # called by this panelview
  onAdd: new Handlers
  onRemove: new Handlers
  onUpdate: new Handlers

  init: ->
    @onShowing.add (e) =>
      @updateUI e.target.ownerDocument
      @visible = true
    @onHiding.add (e) =>
      if (prefs.get 'ui.popup.autoReloadPageOnHiding') \
      and listeners.some((l) -> ('wantsPageReload' of l) and l.wantsPageReload())
        tabs.getCurrent().linkedBrowser.contentWindow.document.location.reload()
      @visible = false

    tabs.onSelect.add (t) =>
      if @visible
        @updateUI t.ownerDocument

    for l in listeners
      for h, handlers of {add:@onAdd, remove:@onRemove, update:@onUpdate}
        if h of l
          handlers.add l[h].bind l

    return

  addUI: (doc) ->
    view = createElement doc, "panelview",
        id: @id
        flex: 1
    doc.getElementById("PanelUI-multiView").appendChild(view)

    overlayQueue.add doc, 'chrome://policeman/content/panelview.xul', =>
      @onAdd.execute doc, view

  removeUI: (doc) ->
    view = doc.getElementById @id
    @onRemove.execute doc, view
    view.parentNode.removeChild view

  updateUI: (doc) ->
    view = doc.getElementById @id
    uri = tabs.getCurrent().linkedBrowser.currentURI
    @onUpdate.execute doc, view, uri


do panelview.init
