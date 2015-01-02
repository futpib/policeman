
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

{ windows } = require 'windows'
{ tabs } = require 'tabs'
{ memo } = require 'request-memo'
{ manager } = require 'ruleset/manager'
{ DomainDomainTypeRS } = require 'ruleset/code-ruleset'

{
  wrapsSuperWidget
  Description
  Widget
  Button
  LinkButton
  DataRotationButton
  CheckButton
  ContainerPopulation
  RadioGroup
  elementMethod: em
} = require 'ui/popup-tk2'

{ aboutPages } = require 'ui/about-policeman'

{ Color } = require 'color'
{ prefs } = require 'prefs'

{ l10n } = require 'l10n'


WILDCARD_TYPE = DomainDomainTypeRS::WILDCARD_TYPE
CHROME_DOMAIN = DomainDomainTypeRS::CHROME_DOMAIN
USER_AVAILABLE_CONTENT_TYPES = DomainDomainTypeRS::USER_AVAILABLE_CONTENT_TYPES


POSITIVE_COLOR_PREF = 'ui.popup.positiveBackgroundColor'
NEGATIVE_COLOR_PREF = 'ui.popup.negativeBackgroundColor'


colorGetter = (c) -> new Color c
colorSetter = (c) -> c.toCssString()
prefs.define POSITIVE_COLOR_PREF,
  default: '#0f02'
  get: colorGetter
  set: colorSetter
prefs.define NEGATIVE_COLOR_PREF,
  default: '#f002'
  get: colorGetter
  set: colorSetter

positiveBackgroundColor = prefs.get POSITIVE_COLOR_PREF
prefs.onChange POSITIVE_COLOR_PREF, ->
  positiveBackgroundColor = prefs.get POSITIVE_COLOR_PREF
negativeBackgroundColor = prefs.get NEGATIVE_COLOR_PREF
prefs.onChange NEGATIVE_COLOR_PREF, ->
  negativeBackgroundColor = prefs.get NEGATIVE_COLOR_PREF


class DomainSelectionButtons extends RadioGroup
  class DomainTree
    makeNode = (obj={}) ->
      node = {
        label: undefined,
        hits: 0,
        allowHits: 0,
        rejectHits: 0,
        directHits: 0,
        descendantDirectHits: 0,
        children: [],
      }
      for k, v of obj
        node[k] = v
      return node

    constructor: ->
      # noname root domain
      @root = makeNode {label:''}

    hit: (domain, decision) ->
      tree = [@root]
      labels = if domain then domain.split('.').concat '' else ['']
      track = []
      while (label = labels.pop()) != undefined
        target = tree.find (n) -> n.label == label # find node for label
        if not target # or create it
          target = makeNode {label}
          tree.push target
        target.hits += 1
        if decision
          target.allowHits += 1
        else
          target.rejectHits += 1
        if labels.length
          track.push target
          tree = target.children
        else
          if not target.directHits
            while (ancestor = track.pop()) != undefined
              ancestor.descendantDirectHits += 1
          target.directHits += 1
      return

    noop = ->
    walkIn: (in_, tree=[@root]) ->
      for n in tree
        in_ n, @walkIn(in_, n.children)
    walk: (pre, post=noop, tree=[@root]) ->
      for n in tree
        skip = pre n
        if not skip
          @walk pre, post, n.children
        post n

    extractSndLvl = (label) ->
      sup = superdomains label, 2
      return sup[sup.length - 1]
    SECONDLEVEL_ROOT_WHITELIST = Object.create null
    SECONDLEVEL_ROOT_WHITELIST[domain] = true for domain in [
      'ac.uk'
      'co.uk'
      'gov.uk'
      'judiciary.uk'
      'ltd.uk'
      'me.uk'
      'mod.uk'
      'net.uk'
      'nhs.uk'
      'nic.uk'
      'org.uk'
      'parliament.uk'
      'plc.uk'
      'police.uk'
      'sch.uk'
    ]
    OMIT_DESCENDANTS_THRESHOLD = 8
    OMIT_DESCENDANTS_DEPTH = 2 # do not omit second and first level domains
    shouldOmitDescendants = (node, depth) ->
      (node.descendantDirectHits > OMIT_DESCENDANTS_THRESHOLD) \
      and (depth > OMIT_DESCENDANTS_DEPTH) \
      and (not (depth == 3) or \ # depth of 3 implies not being whitelisted
           not (extractSndLvl node.label) of SECONDLEVEL_ROOT_WHITELIST)

    get: (domain) ->
      labels = if domain then domain.split('.').concat '' else ['']
      tree = [@root]
      while (label = labels.pop()) != undefined
        target = tree.find (n) -> n.label == label
        return undefined if not target
        tree = target.children
      return target

    getHitDomains: ->
      reducedTree = [root = makeNode {domain: '', hits: @root.hits}]

      nodesStack = [root]
      labels = []
      @walk ((node) ->
        labels.unshift node.label
        depth = labels.length
        omit = shouldOmitDescendants node, depth
        if node.directHits or omit
          rnode = makeNode {
            domain: labels.join('.').slice(0, -1) # slice off trailing '.'
            hits: node.hits
            allowHits: node.allowHits
            rejectHits: node.rejectHits
          }
          nodesStack[0].children.push rnode
          nodesStack.unshift rnode if not omit
        return omit
      ), ((node) ->
        depth = labels.length
        if node.directHits and not shouldOmitDescendants node, depth
          nodesStack.shift()
        labels.shift()
      )

      @walkIn ((n) -> n.children.sort (a, b) -> b.hits - a.hits), reducedTree

      result = []
      indentation = 0
      @walk ((n) ->
        indentation += 1
        result.push [
          indentation,
          n.domain,
          n.allowHits,
          n.rejectHits,
        ]
        return false
      ), ((n) ->
        indentation -= 1
      ), root.children

      return result

  RadioButton = wrapsSuperWidget new class extends RadioGroup::RadioButton.constructor
    __unwrap: (elem) -> elem.firstChild

    create: (doc, descr) ->
      allowHits = descr.get 'allowHits'
      rejectHits = descr.get 'rejectHits'
      totalHits = allowHits + rejectHits
      allowRatio = if totalHits then allowHits/totalHits else 1

      descr.default 'label', descr.get 'domain'
      descr.default 'data_domain', descr.get 'domain'
      descr.default 'tooltiptext', l10n(
          'popup_domain.tip', allowHits, rejectHits, Math.round allowRatio*100)
      descr.default 'indentation', 0

      descr.push 'list_style', "
        background: #{
          positiveBackgroundColor.mix(
            negativeBackgroundColor, allowRatio
          ).toCssString()
        };
        margin-left: #{ descr.get 'indentation' }em;
      "

      rbtn = super doc, descr

      btn = RadioButton.__createOwnElement doc, 'hbox'

      btn.appendChild rbtn

      btn.appendChild createElement doc, 'spacer',
        class: 'policeman-popup-domain-button-hits-spacer'
        flex: 1

      btn.appendChild createElement doc, 'hbox',
        class: 'policeman-popup-button-hits policeman-popup-button-allow-hits'
        _children_:
          label:
            value: descr.get 'allowHits'

      btn.appendChild box = createElement doc, 'hbox',
        class: 'policeman-popup-button-hits policeman-popup-button-reject-hits'
        _children_:
          label:
            value: descr.get 'rejectHits'

      return btn
  RadioButton: RadioButton

  constructor: ->
    super arguments...
    @onSelection.add (btn) =>
      @selectedDomain = @RadioButton.getData btn, 'domain'

  populate: (doc) ->
    tree = new DomainTree
    for [o, d, c, decision] in memo.getByTab tabs.getCurrent()
      continue if decision is null
      domain = @_chooseDomain o, d, c, decision
      continue if not domain
      tree.hit domain, decision

    fragment = doc.createDocumentFragment()

    selectionRestored = no

    anyDomainStats = tree.get ''
    fragment.appendChild anyBtn = @RadioButton.create doc, new Description
      container: this
      label: l10n 'popup_any_domain'
      domain: ''
      allowHits: anyDomainStats.allowHits
      rejectHits: anyDomainStats.rejectHits

    for [indentation, domain, allowHits, rejectHits] in tree.getHitDomains()
      continue if domain == CHROME_DOMAIN
      fragment.appendChild btn = @RadioButton.create doc, new Description {
        container: this,
        domain, allowHits, rejectHits, indentation,
      }
      if (not selectionRestored) and (@selectedDomain == domain)
        @select btn
        selectionRestored = true

    chromeDomainStats = tree.get CHROME_DOMAIN
    if chromeDomainStats
      fragment.appendChild btn = @RadioButton.create doc, new Description
        container: this
        label: @_chromeDomainLabel
        domain: CHROME_DOMAIN
        allowHits: chromeDomainStats.allowHits
        rejectHits: chromeDomainStats.rejectHits
      if (not selectionRestored) and (@selectedDomain == CHROME_DOMAIN)
        @select btn
        selectionRestored = true

    if not selectionRestored
      @select anyBtn

    @getContainerElement(doc).appendChild fragment

  filter: (requestInfo) ->
    if requestInfo.schemeType == 'web'
      if not @selectedDomain
        yes
      else if @selectedDomain == CHROME_DOMAIN
        no
      else
        isSuperdomain @selectedDomain, requestInfo.host
    else if requestInfo.schemeType == 'internal'
      if not @selectedDomain
        no
      else if @selectedDomain == CHROME_DOMAIN
        yes
      else
        no
    else
      no

  _chooseDomain: -> throw new Error 'Subclass must supply "_chooseDomain" method.'


originSelection = new (class extends DomainSelectionButtons
  _chooseDomain: (o, d, c, decision) ->
    if o.schemeType == 'web'
      return o.host
    else if o.schemeType == 'internal'
      return CHROME_DOMAIN
    else
      return false

  populate: (doc) ->
    location = tabs.getCurrent().linkedBrowser.contentWindow.location
    @selectedDomain = location.hostname
    super doc

  _chromeDomainLabel: l10n 'popup_chrome_origin'

) new Description containerId: 'policeman-popup-origins-container'

destinationSelection = new (class extends DomainSelectionButtons
  _chooseDomain: (o, d, c, decision) ->
    if originSelection.filter o
      if d.schemeType == 'web'
        return d.host
      else if d.schemeType == 'internal'
        return CHROME_DOMAIN
      else
        return false
    else
      return false

  _chromeDomainLabel: l10n 'popup_chrome_destination'

) new Description containerId: 'policeman-popup-destinations-container'


localizeOrigin = (o) ->
  if o == CHROME_DOMAIN
    return l10n 'popup_chrome_origin'
  else if not o
    return l10n 'popup_rule_any_domain'
  else
    return o

localizeDestination = (d) ->
  if d == CHROME_DOMAIN
    return l10n 'popup_chrome_destination'
  else if not d
    return l10n 'popup_rule_any_domain'
  else
    return d

CONTENT_TYPE_FILTER_OTHER = '_popup_OTHER_'
CONTENT_TYPE_FILTER_ALL   = WILDCARD_TYPE
CONTENT_TYPE_FILTER_NONE  = '_popup_NONE_'

categorizeRequest = (o, d, c) ->
  if popup.contentTypes.enabled c.contentType
    return c.contentType
  return CONTENT_TYPE_FILTER_OTHER

localizeContentTypeFilter = (type) ->
    # CONTENT_TYPE_FILTER_NONE handled by rejectedFilter and allowedFilter
    if type == CONTENT_TYPE_FILTER_ALL
      return l10n 'popup_filter_all'
    else if type == CONTENT_TYPE_FILTER_OTHER
      return l10n 'popup_filter_other'
    else
      return l10n 'content_type.title.plural.' + type

localizeType = (type) ->
  return l10n 'content_type.lower.plural.' + type


class FilterButtons extends RadioGroup
  constructor: (descr) ->
    @_decision = descr.get 'decision'
    super arguments...
    @onSelection.add (btn) =>
      @selectedFilter = @RadioButton.getData btn, 'filter'

  populate: (doc) ->
    stats = {}
    stats[CONTENT_TYPE_FILTER_OTHER] = 0
    stats[t] = 0 for t in USER_AVAILABLE_CONTENT_TYPES
    for [o, d, c, decision] in memo.getByTab tabs.getCurrent()
      if  (decision == @_decision) \
      and (originSelection.filter o) \
      and (destinationSelection.filter d)
        category = categorizeRequest o, d, c
        stats[category] += 1
        stats[CONTENT_TYPE_FILTER_ALL] += 1

    filters = doc.createDocumentFragment()
    for type in [] \
                 .concat(popup.contentTypes.enabledList()) \
                 .concat([CONTENT_TYPE_FILTER_OTHER])
      label = localizeContentTypeFilter type
      hitCount = stats[type]
      if (type == CONTENT_TYPE_FILTER_ALL) \
      or popup.filters.enabledEmpty() \
      or hitCount
        filters.appendChild btn = @RadioButton.create doc, new Description
          container: this
          label: "#{label} (#{hitCount})"
          data_filter: type
          disabled: not hitCount
          list_command: do (type=type) -> ->
            for rulesetEdit in [temporaryRulesetEdit, persistentRulesetEdit]
              RulesetEditButtons::CustomRuleWidget.setType \
                  rulesetEdit.getCustomRuleWidget(doc), type
        @select btn if @selectedFilter == type

    @getContainerElement(doc).appendChild filters

rejectedFilter = new (class extends FilterButtons
  populate: (doc) ->
    @getContainerElement(doc).appendChild none = @RadioButton.create doc, new Description
      container: this
      label: l10n 'popup_filter_rejected_none'
      data_filter: CONTENT_TYPE_FILTER_NONE
    super doc
    @select none if (@selectedFilter == CONTENT_TYPE_FILTER_NONE) \
                 or (not @getSelectedBtn doc)
) new Description
  containerId: 'policeman-popup-rejected-requests-filters-container'
  decision: false


allowedFilter = new (class extends FilterButtons
  populate: (doc) ->
    @getContainerElement(doc).appendChild none = @RadioButton.create doc, new Description
      container: this
      label: l10n 'popup_filter_allowed_none'
      data_filter: CONTENT_TYPE_FILTER_NONE
    super doc
    @select none if (@selectedFilter == CONTENT_TYPE_FILTER_NONE) \
                 or (not @getSelectedBtn doc)
) new Description
  containerId: 'policeman-popup-allowed-requests-filters-container'
  decision: true


class RequestList extends ContainerPopulation
  RequestWidget: new class extends Widget.constructor
    contextPropertyToTitle =
      nodeName: 'request_context_node'
      contentType: 'request_context_content_type'
      mime: 'request_context_mime_type'
      id: 'request_context_id'
      className: 'request_context_class_name'
    for p, t of contextPropertyToTitle
      contextPropertyToTitle[p] = l10n t

    create: (doc, descr) ->
      descr.set 'tagName', 'hbox'
      descr.push 'list_class', 'policeman-popup-request'

      box = super arguments...

      {
        origin
        destination
        context
        decision
      } = descr.raw()

      box.appendChild originLabel = createElement doc, 'label',
        class: 'text-link policeman-popup-request-label policeman-popup-request-origin-label'
        value: if origin.schemeType == 'web' \
            then origin.host else origin.prePath
        tooltiptext: origin.spec
        href: origin.spec

      contextSummary = ""
      for property, title of contextPropertyToTitle
        if value = context[property]
          contextSummary += "#{ title } #{ value }\n"

      box.appendChild arrowLabel = createElement doc, 'label',
        class: 'policeman-popup-request-label policeman-popup-request-arrow-label'
        value: l10n if decision then 'popup_arrow' else 'popup_arrow_with_stroke'
        tooltiptext: contextSummary

      box.appendChild destLabel = createElement doc, 'label',
        class: 'text-link policeman-popup-request-label policeman-popup-request-destination-label'
        value: destination.spec
        tooltiptext: destination.spec
        href: destination.spec
        crop: 'center'
        flex: 1

      return box

  requests: -> throw new Error "Subclass should supply 'requests' method."

  populate: (doc) ->
    fragment = doc.createDocumentFragment()
    for [o, d, c, decision] in @requests()
      fragment.appendChild @RequestWidget.create doc, new Description
        container: this
        origin: o
        destination: d
        context: c
        decision: decision
    @getContainerElement(doc).appendChild fragment

class FilteredRequestList extends RequestList
  constructor: (descr) ->
    @filterButtons = descr.get 'filterButtons'
    super arguments...
  requests: ->
    requests = memo.getByTab(tabs.getCurrent()).filter ([o, d, c]) ->
      (originSelection.filter o) \
      and (destinationSelection.filter d)
    return requests if @filterButtons.selectedFilter == CONTENT_TYPE_FILTER_ALL
    return requests.filter ([o, d, c, decision]) =>
      @filterButtons.selectedFilter == categorizeRequest(o, d, c)

allowedList = new (class extends FilteredRequestList
  requests: ->
    super().filter ([o,d,c,decision]) -> decision is true
) new Description
  containerId: 'policeman-popup-allowed-requests-container'
  filterButtons: allowedFilter

rejectedList = new (class extends FilteredRequestList
  requests: ->
    super().filter ([o,d,c,decision]) -> decision is false
) new Description
  containerId: 'policeman-popup-rejected-requests-container'
  filterButtons: rejectedFilter

class RulesetEditButtons extends ContainerPopulation
  constructor: (descr) ->
    @_rulesetId = descr.get 'rulesetId'
    super arguments...

  localizeDomain = (d) -> if d == CHROME_DOMAIN
        l10n 'popup_rule_chrome_domain'
      else if not d
        l10n 'popup_rule_any_domain'
      else
        d

  PassiveRuleWidget: new class extends Widget.constructor
    create: (doc, descr) ->
      {
        tooltiptext
        origin
        destination
        type
        decision
      } = descr.raw()

      descr.push 'list_class', 'policeman-popup-rule'
      descr.push 'list_class', 'policeman-popup-rule-' + if decision \
        then 'allow' \
        else 'reject'

      descr.set 'tagName', 'hbox'

      box = super arguments...

      if tooltiptext
        box.setAttribute 'tooltiptext', tooltiptext

      box.appendChild label = createElement doc, 'label',
        class: 'policeman-popup-rule-label'
        value: l10n "popup_#{if decision then 'allow' else 'reject'}_rule",
                  (localizeDomain origin),
                  (localizeDomain destination),
                  (localizeType type)

      return box

  ModifiableRuleWidget = wrapsSuperWidget new class extends @::PassiveRuleWidget.constructor
    __unwrap: (elem) -> elem.firstChild

    create: (doc, descr) ->
      {
        ruleset
        origin
        destination
        type
        decision

        container
      } = descr.raw()

      rule = super arguments...

      box = ModifiableRuleWidget.__createOwnElement doc, 'hbox',
        class: 'policeman-popup-rule-widget'

      box.appendChild rule

      box.appendChild createElement doc, 'spacer',
        flex: 1

      if ruleset.id == 'user_persistent'
        moveToRuleset = manager.get 'user_temporary'
        moveToWidget = temporaryRulesetEdit
        moveButtonLabel = l10n 'popup_persistent_rule_to_temporary'
      else
        moveToRuleset = manager.get 'user_persistent'
        moveToWidget = persistentRulesetEdit
        moveButtonLabel = l10n 'popup_temporary_rule_to_persistent'
      if moveToRuleset
        box.appendChild moveToOtherButton = Button.create doc, new Description
          container: container
          label: moveButtonLabel
          list_command: =>
            popup.autoreload.require doc
            ruleset.revoke origin, destination, type
            moveToRuleset[if decision then 'allow' else 'reject'] origin, destination, type
            @getContainer(box).update doc
            moveToWidget.update doc

      box.appendChild removeButton = Button.create doc, new Description
        container: container
        label: l10n 'popup_delete_rule'
        list_command: =>
          popup.autoreload.require(doc)
          ruleset.revoke origin, destination, type
          @getContainer(box).update doc

      return box
  ModifiableRuleWidget: ModifiableRuleWidget

  CustomRuleWidget: new class extends Widget.constructor
    create: (doc, descr) ->
      {
        ruleset
        origin
        destination

        container
      } = descr.raw()

      descr.set 'tagName', 'hbox'
      descr.push 'list_class', 'policeman-popup-custom-rule-box'

      box = super arguments...

      box.appendChild createElement doc, 'label',
        value: l10n 'popup_custom_rule.0'
        class: 'policeman-popup-label-aligned-like-button'

      allow = ['allow', l10n 'popup_custom_rule.allow']
      reject = ['reject', l10n 'popup_custom_rule.reject']
      box.appendChild allowRejectBtn = DataRotationButton.create doc, new Description
        valuesLabels: if manager.enabled('reject_any') \
            then [allow, reject] \ # whitelist mode
            else [reject, allow]   # blacklist mode
        style: 'background: ' + if manager.enabled('reject_any') \
            then positiveBackgroundColor.toCssString()
            else negativeBackgroundColor.toCssString()
        list_command: =>
          if 'reject' == DataRotationButton.getValue allowRejectBtn
            allowRejectBtn.style.background = negativeBackgroundColor.toCssString()
          else
            allowRejectBtn.style.background = positiveBackgroundColor.toCssString()

      box.appendChild createElement doc, 'label',
        value: l10n 'popup_custom_rule.1'
        class: 'policeman-popup-label-aligned-like-button'

      box.appendChild typeButton = DataRotationButton.create doc, new Description
        valuesLabels: ([t, l10n('popup_custom_rule.2') + ' ' + localizeType(t)] \
                for t in popup.contentTypes.enabledList())

      @setData box, '_typeButton', typeButton

      box.appendChild createElement doc, 'label',
        value: l10n 'popup_custom_rule.3'
        class: 'policeman-popup-label-aligned-like-button'

      box.appendChild originBtn = DataRotationButton.create doc, new Description
        valuesLabels: ([o, localizeOrigin o] \
                      for o in superdomains(origin, 2).concat(''))
        tooltiptext: l10n 'popup_domain_rotation_button.tip'

      box.appendChild createElement doc, 'label',
        value: l10n 'popup_custom_rule.4'
        class: 'policeman-popup-label-aligned-like-button'

      box.appendChild destinationBtn = DataRotationButton.create doc, new Description
        valuesLabels: ([d, localizeDestination d] \
                      for d in superdomains(destination, 2).concat(''))
        tooltiptext: l10n 'popup_domain_rotation_button.tip'

      box.appendChild createElement doc, 'label',
        value: l10n 'popup_custom_rule.5'
        class: 'policeman-popup-label-aligned-like-button'

      box.appendChild createElement doc, 'spacer',
        flex: 1
        orient: 'vertical'

      box.appendChild Button.create doc, new Description
        container: container
        label: l10n 'popup_add_rule'
        list_command: =>
          popup.autoreload.require(doc)
          allowReject = DataRotationButton.getValue allowRejectBtn
          origin_ = DataRotationButton.getValue originBtn
          destination_ = DataRotationButton.getValue destinationBtn
          type_ = DataRotationButton.getValue typeButton
          ruleset[allowReject] origin_, destination_, type_
          @getContainer(box).update doc

      return box

    setType: em @, (widget, type) ->
      typeButton = @getData widget, '_typeButton'
      DataRotationButton.setValue typeButton, type

  populate: (doc) ->
    rs = manager.get @_rulesetId
    return if not rs

    selectedOrigin = originSelection.selectedDomain
    selectedDestination = destinationSelection.selectedDomain

    fragment = doc.createDocumentFragment()

    rules = createElement doc, 'vbox',
      class: 'policeman-existing-rules'

    enabledTypes = popup.contentTypes.enabledList()

    if selectedOrigin and selectedDestination
      # show rules that apply to selected origin and destination only
      rs.superdomainsCheckOrder selectedOrigin, selectedDestination, (o, d) =>
        for t in enabledTypes
          decision = rs.lookup o, d, t
          if decision isnt null
            rules.appendChild @ModifiableRuleWidget.create doc, new Description
              container: this
              ruleset: rs
              origin: o
              destination: d
              type: t
              decision: decision
        return
    else
      # show rules that influenced anything in the current tab
      # filtered by selected origin or destination if any
      # ordered by priority
      chooseDomain = (requestInfo) ->
        if requestInfo.schemeType == 'web'
          requestInfo.host
        else if requestInfo.schemeType == 'internal'
          CHROME_DOMAIN
        else
          ''
      rulesSet = Object.create null # origin -> dest -> type -> index
      rulesList = [] # [[o, d, t, decision]]
      index = 0
      for [o, d, c, decision] in memo.getByTab tabs.getCurrent()
        continue if selectedOrigin and not (originSelection.filter o)
        continue if selectedDestination and not (destinationSelection.filter d)
        originDomain = chooseDomain o
        destinationDomain = chooseDomain d
        rs.superdomainsCheckOrder originDomain, destinationDomain, (o, d) =>
          for t in enabledTypes
            decision = rs.lookup o, d, t
            continue if decision is null
            defaults rulesSet, o, Object.create null
            defaults rulesSet[o], d, Object.create null
            if t of rulesSet[o][d]
              delete rulesList[rulesSet[o][d][t]]
              rulesList[index] = [o, d, t, decision]
            else
              rulesList[index] = [o, d, t, decision]
            rulesSet[o][d][t] = index
            index += 1
          return
      for x in rulesList
        continue unless x
        [origin, destination, type, decision] = x
        rules.appendChild @ModifiableRuleWidget.create doc, new Description {
          container: this
          ruleset: rs
          origin
          destination
          type
          decision
        }

    fragment.appendChild rules

    fragment.appendChild createElement doc, 'separator',
      class: 'thin'

    fragment.appendChild @CustomRuleWidget.create doc, new Description
      container: this
      ruleset: rs
      origin: selectedOrigin
      destination: selectedDestination

    @getContainerElement(doc).appendChild fragment

  getCustomRuleWidget: (doc) ->
    return @getContainerElement(doc).getElementsByClassName('policeman-popup-custom-rule-box')[0]


temporaryRulesetEdit = new (class extends RulesetEditButtons
  populate: (doc) ->
    super doc

    rs = manager.get @_rulesetId
    doc.getElementById('policeman-popup-temporary-ruleset-container') \
            .hidden = not rs
    return if not rs

    container = doc.getElementById('policeman-popup-temporary-ruleset-purge-container')
    if not rs.isEmpty()
      container.appendChild Button.create doc, new Description
        label: l10n 'popup_revoke_all_temporary'
        list_command: =>
          popup.autoreload.require(doc)
          rs.revokeAll()
          @update doc

  purge: (doc) ->
    super doc

    container = doc.getElementById('policeman-popup-temporary-ruleset-purge-container')
    removeChildren container

) new Description
  containerId: 'policeman-popup-temporary-edit-container'
  rulesetId: 'user_temporary'

persistentRulesetEdit = new (class extends RulesetEditButtons
  populate: (doc) ->
    super doc
    doc.getElementById('policeman-popup-persistent-ruleset-container') \
            .hidden = not manager.enabled @_rulesetId
) new Description
  containerId: 'policeman-popup-persistent-edit-container'
  rulesetId: 'user_persistent'


footerCheckButtons = new (class extends ContainerPopulation
  populate: (doc) ->
    fragment = doc.createDocumentFragment()

    fragment.appendChild CheckButton.create doc, new Description
      id: 'policeman-popup-reload-button'
      label: l10n 'popup_reload_page'
      checked: popup.autoreload.enabled()
      list_command: (e) =>
        if CheckButton.checked e.currentTarget
          popup.autoreload.enable()
        else
          popup.autoreload.disable()

    fragment.appendChild CheckButton.create doc, new Description
      label: l10n 'popup_suspend_operation'
      checked: manager.suspended()
      list_command: (e) ->
        if CheckButton.checked e.currentTarget
          manager.suspend()
        else
          manager.unsuspend()
        popup.autoreload.require(doc)

    if temporary = manager.get 'user_temporary'
      currentTab = tabs.getCurrent()
      fragment.appendChild CheckButton.create doc, new Description
        label: l10n 'popup_suspend_operation_on_current_tab'
        checked: temporary.isAllowedTab currentTab
        list_command: (e) ->
          if CheckButton.checked e.currentTarget
            temporary.allowTab currentTab
          else
            temporary.revokeTab currentTab
          popup.autoreload.require(doc)

    @getContainerElement(doc).appendChild fragment

) new Description containerId: 'policeman-popup-footer-left'


PopupLinkButton = new class extends LinkButton.constructor
  create: (doc, descr) ->
    descr.push 'list_command', -> popup.hide doc
    return super arguments...


footerLinkButtons = new (class extends ContainerPopulation
  populate: (doc) ->
    fragment = doc.createDocumentFragment()

    fragment.appendChild createElement doc, 'label',
      id: 'policeman-popup-label-version-number'
      class: 'policeman-popup-label-aligned-like-button'
      value: addonData.version
      flex: 1
      crop: 'end'

    fragment.appendChild PopupLinkButton.create doc, new Description
      label: l10n 'popup_open_help'
      reuse: true
      url: 'https://github.com/futpib/policeman/wiki/Help'

    fragment.appendChild PopupLinkButton.create doc, new Description
      label: l10n 'popup_open_preferences'
      reuse: true
      url: aboutPages.PREFERENCES_USER

    @getContainerElement(doc).appendChild fragment

) new Description containerId: 'policeman-popup-footer-right'


statusIndicator =
  id: 'policeman-popup-status-indicator-container'

  updateStarted: (doc) ->
    doc.getElementById(@id).hidden = false

  updateFinished: (doc) ->
    doc.getElementById(@id).hidden = true


prefs.define AUTORELOAD_PREF = 'ui.popup.autoReloadPageOnHiding',
  default: false
  sync: true

exports.popup = popup =
  id: 'policeman-popup'

  styleURI: Services.io.newURI 'chrome://policeman/skin/popup.css', null, null

  init: ->
    @addUI(w) for w in windows.list
    windows.onOpen.add @addUI.bind @
    windows.onClose.add @removeUI.bind @
    onShutdown.add => @removeUI(w) for w in windows.list

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

  onOpenEvent: (e) ->
    btn = e.currentTarget
    doc = btn.ownerDocument
    @open doc, btn

  open: (doc, anchor=null) ->
    panel = doc.getElementById @id
    panel.openPopup anchor, 'bottomright topright', 0, 0, no, no

  hide: (doc) ->
    panel = doc.getElementById @id
    panel.hidePopup()

  onShowing: (e) ->
    doc = e.currentTarget.ownerDocument
    @autoreload.onShowing doc
    @updateUI doc
    @_visible = true

  onHiding: (e) ->
    doc = e.currentTarget.ownerDocument
    @cleanupUI doc
    if @autoreload.enabled() and @autoreload.required()
      tabs.reload tabs.getCurrent()
    @_visible = false

  addUI: (win) ->
    doc = win.document
    overlayQueue.add doc, 'chrome://policeman/content/popup.xul', =>
      panel = doc.getElementById @id
      panel.addEventListener 'popupshown', @onShowing.bind @
      panel.addEventListener 'popuphidden', @onHiding.bind @

    loadSheet doc.defaultView, @styleURI

  removeUI: (win) ->
    doc = win.document
    removeNode doc.getElementById @id
    removeSheet doc.defaultView, @styleURI

  updateUI: (doc) ->
    originSelection.update doc
    footerCheckButtons.update doc
    footerLinkButtons.update doc

    statusIndicator.updateFinished doc

  cleanupUI: (doc) ->
    destinationSelection.purge doc
    rejectedFilter.purge doc
    allowedFilter.purge doc
    temporaryRulesetEdit.purge doc
    persistentRulesetEdit.purge doc
    rejectedList.purge doc
    allowedList.purge doc

    statusIndicator.updateStarted doc

  autoreload:
    _reloadRequired: false
    enabled: -> prefs.get AUTORELOAD_PREF
    enable: -> prefs.set AUTORELOAD_PREF, true
    disable: -> prefs.set AUTORELOAD_PREF, false
    required: -> @_reloadRequired
    require: (doc) ->
      @_reloadRequired = true
    onShowing: (doc) ->
      @_reloadRequired = false

  contentTypes: new class
    ENABLED_CONTENT_TYPES_PREF = 'ui.popup.enabledContentTypes'

    _enabled: Object.create null

    constructor: ->
      prefs.define ENABLED_CONTENT_TYPES_PREF,
        default: {
          '_ANY_': yes
          'IMAGE': yes
          'MEDIA': yes
          'STYLESHEET': yes
          'SCRIPT': yes
          'OBJECT': yes
          'SUBDOCUMENT': yes
        }
        get: (enabled) ->
          enabled['_ANY_'] = yes
          return enabled
        sync: true
      @_enabled = prefs.get ENABLED_CONTENT_TYPES_PREF
      onShutdown.add => prefs.set ENABLED_CONTENT_TYPES_PREF, @_enabled

    enabled: (type) -> !! @_enabled[type]
    enable: (type) -> @_enabled[type] = yes
    disable: (type) ->
      return if type == WILDCARD_TYPE
      delete @_enabled[type]
    enabledList: ->
      list = []
      for t in USER_AVAILABLE_CONTENT_TYPES
        if @enabled t
          list.push t
      return list

  filters: new class
    SHOW_ZERO_FILTERS_PREF = 'ui.popup.filters.showZeroFilters'

    _showZeroFilters: true

    constructor: ->
      prefs.define SHOW_ZERO_FILTERS_PREF,
        default: false
        sync: true
      @_showZeroFilters = prefs.get SHOW_ZERO_FILTERS_PREF
      prefs.onChange SHOW_ZERO_FILTERS_PREF, (value) => @_showZeroFilters = value

    enabledEmpty: -> prefs.get SHOW_ZERO_FILTERS_PREF
    enableEmpty:  -> prefs.set SHOW_ZERO_FILTERS_PREF, true
    disableEmpty: -> prefs.set SHOW_ZERO_FILTERS_PREF, false

do popup.init
