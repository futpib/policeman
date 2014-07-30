
{
  Handlers
  removeNode
  removeChildren
  loadSheet
  removeSheet
  createElement
  superdomains
  isSuperdomain
  defaults
} = require 'utils'
{ overlayQueue } = require 'ui/overlay-queue'

{ tabs } = require 'tabs'
{ memo } = require 'request-memo'
{ manager } = require 'ruleset/manager'
{ DomainDomainTypeRS } = require 'ruleset/code-based'

{ Color } = require 'color'
{ prefs } = require 'prefs'

{ l10n } = require 'l10n'


WILDCARD_TYPE = DomainDomainTypeRS::WILDCARD_TYPE


POSITIVE_COLOR_PREF = 'ui.popup.positiveBackgroundColor'
NEGATIVE_COLOR_PREF = 'ui.popup.negativeBackgroundColor'


colorGetter = (c) -> new Color c
colorSetter = (c) -> c.toCssString()
prefs.define POSITIVE_COLOR_PREF,
  prefs.TYPE_STRING, '#0f02',
    get: colorGetter
    set: colorSetter
prefs.define NEGATIVE_COLOR_PREF,
  prefs.TYPE_STRING, '#f002',
    get: colorGetter
    set: colorSetter

positiveBackgroundColor = prefs.get POSITIVE_COLOR_PREF
prefs.onChange POSITIVE_COLOR_PREF, ->
  positiveBackgroundColor = prefs.get POSITIVE_COLOR_PREF
negativeBackgroundColor = prefs.get NEGATIVE_COLOR_PREF
prefs.onChange NEGATIVE_COLOR_PREF, ->
  negativeBackgroundColor = prefs.get NEGATIVE_COLOR_PREF


class Button
  create: (doc, description) ->
    {
      id
      label
      tooltiptext
      classList
      disabled
      click
      appendTo
      style
    } = description
    classList = classList or []

    lbl = createElement doc, 'label',
      class: 'policeman-popup-button-label'
      value: label
      style: 'cursor: inherit;'
    if tooltiptext
      lbl.setAttribute 'tooltiptext', tooltiptext

    innerBox = createElement doc, 'vbox',
      class: 'policeman-popup-button-box'
    box = createElement doc, 'vbox',
      class: (classList.concat ['policeman-popup-button']).join(' ')
      disabled: if disabled then 'true' else 'false'
      style: style or ''
    if id
      box.setAttribute 'id', id
    if click
      box.addEventListener 'click', do (that=@) -> ->
        return if that.disabled @
        click.apply @, arguments

    box.appendChild innerBox
    innerBox.appendChild lbl

    appendTo.appendChild box if appendTo

    return box

  disable: (btn) -> btn.setAttribute('disabled', 'true')
  enable: (btn) -> btn.setAttribute('disabled', 'false')
  disabled: (btn) -> btn.getAttribute('disabled') == 'true'

  setData: (btn, str) -> btn.setAttribute('data', str)
  getData: (btn) -> btn.getAttribute('data')

  setLabel: (btn, str) ->
    lbl = btn.getElementsByClassName('policeman-popup-button-label')[0]
    lbl.setAttribute 'value', str


class LinkButton extends Button
  create: (doc, description) ->
    defaults description, 'style', ''
    description.style += 'cursor: pointer;'
    btn = super doc, description
    reuse = not ('reuse' of description) or description.reuse
    if description.url
        btn.addEventListener 'click', ->
          tabs.open description.url, reuse
          popup.hide(doc)
    return btn


class DataRotationButton extends Button
  create: (doc, description) ->
    {
      valuesLabels
    } = description
    defaults description, 'classList', []
    description.classList.push 'policeman-popup-value-rotation-button'
    i = 0
    defaults description, 'label', valuesLabels[i][1]
    btn = Button::create doc, description
    @setData btn, valuesLabels[i][0]
    btn.addEventListener 'click', do (that=@) -> ->
      i += 1
      i = 0 if i >= valuesLabels.length
      that.setData @, valuesLabels[i][0]
      that.setLabel @, valuesLabels[i][1]
    return btn


class RadioButton extends Button
  create: (doc, description) ->
    defaults description, 'classList', []
    description.classList.push 'policeman-popup-radio-button'
    btn = super doc, description
    if 'data' of description
      @setData btn, description.data
    @unselect btn
    return btn

  select: (btn) -> btn.setAttribute('selected', 'true')
  unselect: (btn) -> btn.setAttribute('selected', 'false')
  selected: (btn) -> btn.getAttribute('selected') == 'true'


class CheckButton extends Button
  create: (doc, description) ->
    defaults description, 'classList', []
    description.classList.push 'policeman-popup-check-button'
    click = description.click
    description.click = do (that=@) -> ->
      that.toggle @
      click.call @, arguments
    btn = super doc, description
    if description.checked
      @check btn
    else
      @uncheck btn
    return btn

  check: (btn) -> btn.setAttribute('checked', 'true')
  uncheck: (btn) -> btn.setAttribute('checked', 'false')
  checked: (btn) -> btn.getAttribute('checked') == 'true'
  toggle: (btn) ->
    if @checked btn
      @uncheck btn
    else
      @check btn


class ContainerPopulation
  constructor: (@_containerId) ->
  populate: (doc) ->
  purge: (doc) ->
    removeChildren doc.getElementById @_containerId
  update: (doc) ->
    @purge doc
    @populate doc


class RadioButtons extends ContainerPopulation
  constructor: (containerId, @selectedData=null) ->
    super containerId
    @onSelection = new Handlers

  _createButton: (doc, description) ->
    btn = RadioButton::create doc, description
    btn.addEventListener 'click', do (group=this) -> ->
      return if RadioButton::disabled @
      group._select @
    return btn

  _select: (btn) ->
    doc = btn.ownerDocument
    for b in doc.getElementById(@_containerId).childNodes
      RadioButton::unselect b
    RadioButton::select btn
    @selectedData = RadioButton::getData btn
    @onSelection.execute btn, @selectedData, @


class DomainSelectionButtons extends RadioButtons
  class DomainTree
    constructor: ->
      # noname root domain
      @t = [{label: '', hit: no, descendantHits: 0, children: []}]
    hit: (domain) ->
      tree = @t
      labels = domain.split('.').concat ''
      track = []
      while (label = labels.pop()) != undefined
        target = tree.find (n) -> n.label == label # find node for label
        if not target # or create it
          target = {label: label, hit: no, descendantHits: 0, children: []}
          tree.push target
        if labels.length
          track.push target
          tree = target.children
        else
          if not target.hit
            target.hit = yes
            while (ancestor = track.pop()) != undefined
              ancestor.descendantHits += 1
      return
    noop = ->
    walk: (pre, post=noop, tree=@t) ->
      for n in tree
        skip = pre n
        if not skip
          @walk pre, post, n.children
        post n
    OMIT_DESCENDANTS_THRESHOLD = 2
    OMIT_DESCENDANTS_DEPTH = 2 # do not omit second and higher level domains
    shouldOmitDescendants = (node, depth) ->
      (node.descendantHits > OMIT_DESCENDANTS_THRESHOLD) \
      and (depth > OMIT_DESCENDANTS_DEPTH)
    getHittedDomains: ->
      result = []
      depth = 0
      indentation = 0
      labels = []
      @walk ((node) ->
        depth += 1
        labels.unshift node.label
        omit = shouldOmitDescendants node, depth
        if node.hit or omit
          indentation += 1
          result.push [
            indentation,
            labels.join('.').slice(0, -1) # slice off trailing '.'
          ]
          if omit
            return true
        return false
      ), ((node) ->
        labels.shift()
        if node.hit or (shouldOmitDescendants node, depth)
          indentation -= 1
        depth -= 1
      )
      return result

  _createButton: (doc, description) ->
    { allowHits, rejectHits } = description
    allowRatio = allowHits/(allowHits + rejectHits)

    defaults description, 'label', description.domain
    defaults description, 'data', description.domain
    defaults description, 'tooltiptext', l10n('popup_domain.tip',
                    allowHits, rejectHits, Math.round allowRatio*100)
    defaults description, 'style', ''

    description.style += "
      background: #{
        positiveBackgroundColor.mix(
          negativeBackgroundColor, allowRatio
        ).toCssString()
      };
      margin-left: #{ description.indentation or 0 }em;
    "

    btn = super doc, description

    return btn

  populate: (doc) ->
    domainToStats = {}
    tree = new DomainTree
    for [o, d, c, decision] in memo.getByTab tabs.getCurrent()
      continue if decision is null
      domain = @_chooseDomain o, d, c, decision
      continue if not domain
      tree.hit domain
      stat = if decision then 'allow' else 'reject'
      for d in superdomains domain
        defaults domainToStats, d, {allow:0, reject:0}
        domainToStats[d][stat] += 1

    return if not domainToStats['']

    fragment = doc.createDocumentFragment()

    selectionRestored = no

    fragment.appendChild anyBtn = @_createButton doc,
      label: l10n 'popup_any_domain'
      domain: ''
      allowHits: domainToStats[''].allow
      rejectHits: domainToStats[''].reject

    for [indentation, domain] in tree.getHittedDomains()
      fragment.appendChild btn = @_createButton doc,
        domain: domain
        allowHits: domainToStats[domain].allow
        rejectHits: domainToStats[domain].reject
        indentation: indentation
      if (not selectionRestored) and (@selectedData == domain)
        @_select btn
        selectionRestored = true

    if not selectionRestored
      @_select anyBtn

    doc.getElementById(@_containerId).appendChild fragment

  _chooseDomain: -> throw new Error 'Subclass must supply "_chooseDomain" method.'


originSelection = new (class extends DomainSelectionButtons
  _chooseDomain: (o, d, c, decision) ->
    if c.kind == 'web'
      return o.host
    else
      return false

  populate: (doc) ->
    location = tabs.getCurrent().linkedBrowser.contentWindow.location
    @selectedData = location.hostname
    super doc

) 'policeman-popup-origins-container'

destinationSelection = new (class extends DomainSelectionButtons
  _chooseDomain: (o, d, c, decision) ->
    if (c.kind == 'web') \
    and (isSuperdomain originSelection.selectedData, o.host)
      return d.host
    else
      return false
) 'policeman-popup-destinations-container'


categorizeRequest = (o, d, c) ->
  if c.contentType in ['IMAGE', 'STYLESHEET', 'SCRIPT']
    return c.contentType
  return 'OTHER'

class FilterButtons extends RadioButtons
  constructor: (containerId) ->
    super containerId, 'NONE'
  populate: (doc, decision) ->
    stats = { ALL:0, IMAGE:0, STYLESHEET:0, SCRIPT:0, OTHER:0 }
    for [o, d, c, decision_] in memo.getByTab tabs.getCurrent()
      if  (decision_ == decision) \
      and (c.kind == 'web') \
      and (isSuperdomain originSelection.selectedData, o.host) \
      and (isSuperdomain destinationSelection.selectedData, d.host)
        stats[categorizeRequest o, d, c] += 1
        stats.ALL += 1

    filters = doc.createDocumentFragment()
    for [label, value] in [
      ['popup_filter_all', 'ALL'],
      ['popup_filter_image', 'IMAGE'],
      ['popup_filter_stylesheet', 'STYLESHEET'],
      ['popup_filter_script', 'SCRIPT'],
      ['popup_filter_other', 'OTHER'],
    ]
      filters.appendChild btn = @_createButton doc,
        label: l10n label, stats[value]
        data: value
        disabled: not stats[value]
      @_select btn if @selectedData == value
    doc.getElementById(@_containerId).appendChild filters

rejectedFilter = new (class extends FilterButtons
  populate: (doc) ->
    filters = doc.getElementById @_containerId
    filters.appendChild none = @_createButton doc,
      label: l10n 'popup_filter_rejected_none'
      data: 'NONE'
    @_select none if @selectedData == 'NONE'
    super doc, false
) 'policeman-popup-rejected-requests-filters-container'


allowedFilter = new (class extends FilterButtons
  populate: (doc) ->
    filters = doc.getElementById @_containerId
    filters.appendChild none = @_createButton doc,
      label: l10n 'popup_filter_allowed_none'
      data: 'NONE'
    @_select none if @selectedData == 'NONE'
    super doc, true
) 'policeman-popup-allowed-requests-filters-container'


class RequestList extends ContainerPopulation
  createItem: (doc, description) ->
    {
      origin
      destination
      context
      decision
    } = description

    originLbl = createElement doc, 'label',
      class: 'text-link policeman-popup-request-label policeman-popup-request-origin-label'
      value: origin.host
      tooltiptext: origin.spec
      href: origin.spec

    contextSummary = ""
    if context.nodeName
      contextSummary += \
        "#{ l10n('request_context_node') } #{ context.nodeName }\n"
    if context.contentType
      contextSummary += \
        "#{ l10n 'request_context_content_type' } #{ context.contentType }\n"
    if context.mime
      contextSummary += \
        "#{ l10n 'request_context_mime_type' } #{ context.mime }\n"
    arrowLbl = createElement doc, 'label',
      class: 'policeman-popup-request-label policeman-popup-request-arrow-label'
      value: l10n if decision then 'popup_arrow' else 'popup_arrow_with_stroke'
      tooltiptext: contextSummary

    destLbl = createElement doc, 'label',
      class: 'text-link policeman-popup-request-label policeman-popup-request-destination-label'
      value: destination.spec
      tooltiptext: destination.spec
      href: destination.spec
      crop: 'center'

    box = createElement doc, 'hbox',
      class: 'policeman-popup-request'

    box.appendChild originLbl
    box.appendChild arrowLbl
    box.appendChild destLbl

    return box

  requests: -> throw new Error "Subclass should supply 'requests' method."

  populate: (doc) ->
    fragment = doc.createDocumentFragment()
    for [o, d, c, decision] in @requests()
      fragment.appendChild @createItem doc,
        origin: o
        destination: d
        context: c
        decision: decision
    doc.getElementById(@_containerId).appendChild fragment

class FilteredRequestList extends RequestList
  constructor: (containerId, @filterButtons) ->
    super containerId
  requests: ->
    requests = memo.getByTab(tabs.getCurrent()).filter ([o, d, c]) ->
      (c.kind == 'web') \
      and (isSuperdomain originSelection.selectedData, o.host) \
      and (isSuperdomain destinationSelection.selectedData, d.host)
    return requests if @filterButtons.selectedData == 'ALL'
    return requests.filter ([o, d, c, decision]) =>
      @filterButtons.selectedData == categorizeRequest(o, d, c)

allowedList = new (class extends FilteredRequestList
  requests: ->
    super().filter ([o,d,c,decision]) -> decision is true
) 'policeman-popup-allowed-requests-container', allowedFilter

rejectedList = new (class extends FilteredRequestList
  requests: ->
    super().filter ([o,d,c,decision]) -> decision is false
) 'policeman-popup-rejected-requests-container', rejectedFilter

localizeTypeLookup =
  IMAGE: l10n 'popup_type_image'
  STYLESHEET: l10n 'popup_type_stylesheet'
  SCRIPT: l10n 'popup_type_script'
localizeTypeLookup[WILDCARD_TYPE] = l10n 'popup_type_wildcard'
localizeType = (t) -> localizeTypeLookup[t]

class RulesetEditButtons extends ContainerPopulation
  constructor: (containerId, @_rulesetId) ->
    super containerId

  _createRuleWidget: (doc, description) ->
    {
      tooltiptext
      classList
      origin
      destination
      decision
      type
    } = description
    classList = classList or []

    origin = origin or l10n 'popup_rule_any_domain'
    destination = destination or l10n 'popup_rule_any_domain'

    box = createElement doc, 'vbox',
      class: classList.join(' ') \
        + ' policeman-popup-rule' \
        + (if decision then ' policeman-popup-rule-allow' else '') \
        + (if decision == false then ' policeman-popup-rule-reject' else '')
    if tooltiptext
      box.setAttribute 'tooltiptext', tooltiptext

    subbox = createElement doc, 'vbox'

    lbl = createElement doc, 'label',
      class: 'policeman-popup-rule-label'
      value: l10n "popup_#{if decision then 'allow' else 'reject'}_rule", origin, destination, localizeType type

    subbox.appendChild lbl
    box.appendChild subbox

    return box

  _createDeleteButton: (doc, description={}) ->
    defaults description, 'label', l10n 'popup_delete_rule'
    btn = Button::create doc, description
    return btn

  _createAddButton: (doc, description={}) ->
    defaults description, 'label', l10n 'popup_add_rule'
    btn = Button::create doc, description
    return btn

  _createCustomRuleWidget: (doc, description) ->
    {
      ruleset
      origin
      destination
    } = description

    customRuleBox = createElement doc, 'hbox',
      class: 'policeman-popup-custom-rule-box'

    customRuleBox.appendChild createElement doc, 'label',
      value: l10n 'popup_custom_rule.0'
      class: 'policeman-popup-label-aligned-like-button'

    customRuleBox.appendChild allowRejectBtn = DataRotationButton::create doc,
      valuesLabels: [
        ['allow', l10n 'popup_custom_rule.allow'],
        ['reject', l10n 'popup_custom_rule.reject'],
      ]

    customRuleBox.appendChild createElement doc, 'label',
      value: l10n 'popup_custom_rule.1'
      class: 'policeman-popup-label-aligned-like-button'

    customRuleBox.appendChild typeBtn = DataRotationButton::create doc,
      valuesLabels: ([t, l10n('popup_custom_rule.2') + ' ' + localizeType(t)] \
              for t in [WILDCARD_TYPE, 'IMAGE', 'STYLESHEET', 'SCRIPT'])

    customRuleBox.appendChild createElement doc, 'label',
      value: l10n 'popup_custom_rule.3'
      class: 'policeman-popup-label-aligned-like-button'

    customRuleBox.appendChild originBtn = DataRotationButton::create doc,
      valuesLabels: ([d, d or l10n 'popup_rule_any_domain'] \
                        for d in superdomains(origin, 2).concat(''))
      tooltiptext: l10n 'popup_domain_rotation_button.tip'

    customRuleBox.appendChild createElement doc, 'label',
      value: l10n 'popup_custom_rule.4'
      class: 'policeman-popup-label-aligned-like-button'

    customRuleBox.appendChild destinationBtn = DataRotationButton::create doc,
      valuesLabels: ([d, d or l10n 'popup_rule_any_domain'] \
                        for d in superdomains(destination, 2).concat(''))
      tooltiptext: l10n 'popup_domain_rotation_button.tip'

    customRuleBox.appendChild createElement doc, 'label',
      value: l10n 'popup_custom_rule.5'
      class: 'policeman-popup-label-aligned-like-button'

    customRuleBox.appendChild createElement doc, 'spacer',
      flex: 1
      orient: 'vertical'

    customRuleBox.appendChild Button::create doc,
      label: l10n 'popup_add_rule'
      click: =>
        popup.requestPageReload(doc)
        allowReject = DataRotationButton::getData allowRejectBtn
        origin_ = DataRotationButton::getData originBtn
        destination_ = DataRotationButton::getData destinationBtn
        type_ = DataRotationButton::getData typeBtn
        ruleset[allowReject] origin_, destination_, type_
        @update doc

    return customRuleBox

  _createRuleWidgetWithRemoveBtn: (doc, container, rs, o, d, t) =>
      hbox = createElement doc, 'hbox'
      decision = rs.checkWithoutSuperdomains o, d, t
      return if decision is null
      hbox.appendChild @_createRuleWidget doc,
        origin: o
        destination: d
        type: t
        decision: decision
      hbox.appendChild createElement doc, 'spacer',
        flex: 1
        orient: 'vertical'
      hbox.appendChild @_createDeleteButton doc,
        click: =>
          popup.requestPageReload(doc)
          rs.revoke o, d, t
          @update doc
      container.appendChild hbox

  populate: (doc) ->
    rs = manager.get @_rulesetId
    return if not rs

    selectedOrigin = originSelection.selectedData
    selectedDestination = destinationSelection.selectedData

    fragment = doc.createDocumentFragment()

    # Existing rules
    rules = createElement doc, 'vbox',
      class: 'policeman-existing-rules'

    supportedTypes = ['IMAGE', 'STYLESHEET', 'SCRIPT', WILDCARD_TYPE]

    if selectedOrigin and selectedDestination
      for type in supportedTypes
        rs.checkOrder selectedOrigin, selectedDestination, type, (o, d, t) =>
          @_createRuleWidgetWithRemoveBtn doc, rules, rs, o, d, t
          return undefined
    else
      checkThem = {} # origin -> dest -> type -> true
      for [o, d, c, decision] in memo.getByTab tabs.getCurrent()
        continue if c.kind != 'web'
        continue if selectedOrigin and not (isSuperdomain selectedOrigin, o.host)
        continue if selectedDestination and not (isSuperdomain selectedDestination, d.host)
        for type in supportedTypes
          rs.checkOrder o.host, d.host, type, (o, d, t) =>
            defaults checkThem, o, {}
            defaults checkThem[o], d, {}
            defaults checkThem[o][d], t, true
            return undefined
      for odom, dests of checkThem
        for ddom, types of dests
          for type in supportedTypes
            if types[type]
              @_createRuleWidgetWithRemoveBtn doc, rules, rs, odom, ddom, type

    fragment.appendChild rules

    fragment.appendChild createElement doc, 'separator',
      class: 'thin'

    # Add custom rule
    fragment.appendChild @_createCustomRuleWidget doc,
      ruleset: rs
      origin: selectedOrigin
      destination: selectedDestination

    doc.getElementById(@_containerId).appendChild fragment


temporaryRulesetEdit = new (class extends RulesetEditButtons
  populate: (doc) ->
    super doc

    rs = manager.get @_rulesetId
    return if not rs

    container = doc.getElementById('policeman-popup-temporary-ruleset-purge-container')
    if not rs.isEmpty()
      container.appendChild Button::create doc,
        label: l10n 'popup_revoke_all_temporary'
        click: =>
          popup.requestPageReload(doc)
          rs.revokeAll()
          @update doc

  purge: (doc) ->
    super doc

    container = doc.getElementById('policeman-popup-temporary-ruleset-purge-container')
    removeChildren container

) 'policeman-popup-temporary-edit-container', 'user_temporary'

persistentRulesetEdit = new (class extends RulesetEditButtons
) 'policeman-popup-persistent-edit-container', 'user_persistent'


footerCheckButtons = new (class extends ContainerPopulation
  enableReload: (doc) ->
    CheckButton::enable doc.getElementById 'policeman-popup-reload-button'
  populate: (doc) ->
    fragment = doc.createDocumentFragment()

    fragment.appendChild CheckButton::create doc,
      id: 'policeman-popup-reload-button'
      disabled: 'true'
      label: l10n 'popup_reload_page'
      checked: popup.autoreload.enabled()
      click: ->
        if CheckButton::checked @
          popup.autoreload.enable()
        else
          popup.autoreload.disable()

    fragment.appendChild CheckButton::create doc,
      label: l10n 'popup_suspend_operation'
      checked: manager.suspended()
      click: ->
        if CheckButton::checked @
          manager.suspend()
        else
          manager.unsuspend()

    doc.getElementById(@_containerId).appendChild fragment

) 'policeman-popup-footer-left'


footerLinkButtons = new (class extends ContainerPopulation
  populate: (doc) ->
    fragment = doc.createDocumentFragment()

    fragment.appendChild LinkButton::create doc,
      label: l10n 'popup_open_help'
      reuse: true
      url: 'chrome://policeman/content/TODO_help' # TODO

    fragment.appendChild LinkButton::create doc,
      label: l10n 'popup_open_preferences'
      reuse: true
      url: 'chrome://policeman/content/preferences.xul#user-rulesets'

    doc.getElementById(@_containerId).appendChild fragment

) 'policeman-popup-footer-right'


prefs.define AUTORELOAD_PREF = 'ui.popup.autoReloadPageOnHiding',
  prefs.TYPE_BOOLEAN, false

exports.popup = popup =
  id: 'policeman-popup'

  styleURI: Services.io.newURI 'chrome://policeman/skin/popup.css', null, null

  _reloadRequired: false

  init: ->
    tabs.onSelect.add (t) =>
      if @_visible
        @cleanupUI t.ownerDocument
        @updateUI t.ownerDocument

    originSelection.onSelection.add (btn) ->
      destinationSelection.update btn.ownerDocument
    destinationSelection.onSelection.add (btn) ->
      rejectedFilter.update btn.ownerDocument
      allowedFilter.update btn.ownerDocument
      temporaryRulesetEdit.update btn.ownerDocument
      persistentRulesetEdit.update btn.ownerDocument
    rejectedFilter.onSelection.add (btn) ->
      rejectedList.update btn.ownerDocument
    allowedFilter.onSelection.add (btn) ->
      allowedList.update btn.ownerDocument

  onToobarbuttonCommand: (e) ->
    btn = e.target
    doc = btn.ownerDocument
    @open doc, btn

  open: (doc, anchor=null) ->
    panel = doc.getElementById @id
    panel.openPopup anchor, 'bottomcenter topright', 0, 0, no, no

  hide: (doc) ->
    panel = doc.getElementById @id
    panel.hidePopup()

  onShowing: (e) ->
    @_reloadRequired = false
    @updateUI e.target.ownerDocument
    @_visible = true

  onHiding: (e) ->
    @cleanupUI e.target.ownerDocument
    if @_reloadRequired and prefs.get 'ui.popup.autoReloadPageOnHiding'
      tabs.reload tabs.getCurrent()
    @_visible = false

  requestPageReload: (doc) ->
    @_reloadRequired = true
    footerCheckButtons.enableReload(doc)

  addUI: (doc) ->
    overlayQueue.add doc, 'chrome://policeman/content/popup.xul', =>
      panel = doc.getElementById @id
      panel.addEventListener 'popupshown', @onShowing.bind @
      panel.addEventListener 'popuphidden', @onHiding.bind @

    loadSheet doc.defaultView, @styleURI

  removeUI: (doc) ->
    removeNode doc.getElementById @id
    removeSheet doc.defaultView, @styleURI

  updateUI: (doc) ->
    originSelection.update doc
    footerCheckButtons.update doc
    footerLinkButtons.update doc

  cleanupUI: (doc) ->
    destinationSelection.purge doc
    rejectedFilter.purge doc
    allowedFilter.purge doc
    temporaryRulesetEdit.purge doc
    persistentRulesetEdit.purge doc
    rejectedList.purge doc
    allowedList.purge doc

  autoreload:
    enabled: -> prefs.get AUTORELOAD_PREF
    enable: -> prefs.set AUTORELOAD_PREF, true
    disable: -> prefs.set AUTORELOAD_PREF, false


do popup.init
