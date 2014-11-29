

{ tabs } = require 'tabs'

{
  WeakSet
  Handlers
  createElement
  removeChildren
} = require 'utils'


exports.Description = class Description
  LIST_PREFIX: 'list_'
  EVENT_PREFIX: 'event_'
  DATA_PREFIX: 'data_'

  clone = (o) ->
    c = Object.create null
    c[k] = v for k, v of o
    return c

  _wrapIntoArray: (k) ->
    if @has k
      unless (@get k) instanceof Array
        @mutate k, (v) -> [v]
    else
      @set k, []

  constructor: (obj) ->
    @_obj = clone obj
    for k, v of @_obj
      listPrefexes = [
        @LIST_PREFIX,
        @EVENT_PREFIX,
      ]
      if listPrefexes.some((prefix) -> k.startsWith prefix)
        @_wrapIntoArray k

  default: (k, v) ->
    return if k of @_obj
    @set k, v
  has: (k) -> k of @_obj
  get: (k) -> @_obj[k]
  set: (k, v) -> @_obj[k] = v
  mutate: (k, f) -> @set k, f @get k

  raw: -> clone @_obj

  push: (k, v) ->
    @_wrapIntoArray k
    @mutate k, (a) -> a.push v; return a
  unshift: (k, v) ->
    @_wrapIntoArray k
    @mutate k, (a) -> a.unshift v; return a


prototypeChain = (obj) ->
  list = []
  while obj
    list.push obj
    obj = Object.getPrototypeOf obj
  return list


elementMethod = em = (cls, method) -> (elem, args...) ->
  e = elem
  for proto in prototypeChain this
    if cls::__ownsElement e
      return method.call this, e, args...
    if Object.hasOwnProperty.call proto, '__unwrap'
      e = proto.__unwrap e
    break if not e
  throw new Error "Couldn't unwrap element #{elem} for element method #{method}
                  of #{cls}"


exports.Widget = Widget = new class
  __ownElements = new WeakSet
  __ownsElement: (elem) -> __ownElements.has elem
  __unwrap: (elem) -> null

  _elementToData: new WeakMap

  getData: em @, (elem, args...) ->
    data = @_elementToData.get elem
    switch args.length
      when 0
        return data
      when 1
        [ key ] = args
        return data[key]

  setData: em @, (elem, args...) ->
    switch args.length
      when 1
        [ newData ] = args
        @_elementToData.set elem, newData
      when 2
        [ key, value ] = args
        data = @_elementToData.get elem
        data[key] = value

  mutateData: em @, (elem, key, f) ->
    @setData elem, key, (f @getData elem, key)

  create: (doc, descr) ->
    {
      tagName
      id
      list_class
      list_style
      style

      appendTo
    } = rawdescr = descr.raw()

    elem = createElement doc, tagName

    __ownElements.add elem

    elem.id = id if id
    if list_class then elem.classList.add cls for cls in list_class
    if list_style or style
      style_ = (list_style or []).join ';'
      style_ += ';' + (style or '')
      elem.setAttribute 'style', style_

    @setData elem, Object.create null

    for k, v of rawdescr
      if k.startsWith descr.EVENT_PREFIX
        event = k.slice descr.EVENT_PREFIX.length
        for listener in v
          elem.addEventListener event, listener
      else if k.startsWith descr.DATA_PREFIX
        dataKey = k.slice descr.DATA_PREFIX.length
        @setData elem, dataKey, v

    if appendTo then appendTo.appendChild elem

    return elem


exports.Button = Button = new class extends Widget.constructor
  create: (doc, descr) ->
    descr.default 'tagName', 'hbox'
    descr.push 'list_class', 'policeman-popup-button'

    that = this
    if commandList = descr.get 'list_command'
      descr.push 'event_click', ->
        return if that.disabled this
        for c in commandList
          try
            c.apply this, arguments
          catch e
            log.error 'Error executing command event of Button', e

    btn = super arguments...

    btn.appendChild innerBox = createElement doc, 'hbox',
      class: 'policeman-popup-button-inner'

    innerBox.appendChild lbl = createElement doc, 'label',
      class: 'policeman-popup-button-label'
      value: descr.get 'label'

    if tip = descr.get 'tooltiptext'
      btn.setAttribute 'tooltiptext', tip

    if descr.get 'disabled'
      @disable btn
    else
      @enable btn

    return btn

  disable: em @, (btn) -> btn.setAttribute 'disabled', 'true'
  enable: em @, (btn) -> btn.setAttribute 'disabled', 'false'
  disabled: em @, (btn) -> btn.getAttribute('disabled') == 'true'

  setLabel: em @, (btn, str) ->
    lbl = btn.getElementsByClassName('policeman-popup-button-label')[0]
    lbl.setAttribute 'value', str
  getLabel: em @, (btn) ->
    btn.getElementsByClassName('policeman-popup-button-label')[0].value


exports.LinkButton = LinkButton = new class extends Button.constructor
  create: (doc, descr) ->
    descr.push 'list_class', 'policeman-popup-link-button'

    reuse = descr.get 'reuse'
    if url = descr.get 'url'
      descr.unshift 'list_command', -> tabs.open url, reuse

    return super arguments...


exports.DataRotationButton = DataRotationButton = new class extends Button.constructor
  create: (doc, descr) ->
    descr.push 'list_class', 'policeman-popup-data-rotation-button'

    valuesLabels = descr.get 'valuesLabels'

    that = this
    descr.unshift 'list_command', (e) ->
      if e.button == 0 # left
        that._next this
      else if e.button == 2 # right
        that._prev this

    btn = super arguments...

    @setData btn, '_valuesLabels', valuesLabels
    @setData btn, '_valuesLabelsLength', valuesLabels.length

    @setIndex btn, 0

    return btn

  _next: em @, (btn) ->
    length = @getData btn, '_valuesLabelsLength'
    i = @getIndex btn
    i = (i + 1) % length
    @setData btn, '_currentIndex', i
    @_update btn

  _prev: em @, (btn) ->
    length = @getData btn, '_valuesLabelsLength'
    i = @getIndex btn
    i -= 1
    i = length-1 if i < 0
    @setData btn, '_currentIndex', i
    @_update btn

  _update: em @, (btn) ->
    i = @getIndex btn
    valuesLabels = @getData btn, '_valuesLabels'
    @setData btn, '_currentValue', valuesLabels[i][0]
    Button.setLabel btn, valuesLabels[i][1]

  setIndex: em @, (btn, i) ->
    length = @getData btn, '_valuesLabelsLength'
    i = Math.min length-1, Math.max 0, i
    @setData btn, '_currentIndex', i
    @_update btn
  getIndex: em @, (btn) ->
    @getData btn, '_currentIndex'

  setValue: em @, (btn, value) ->
    valuesLabels = @getData btn, '_valuesLabels'
    i = valuesLabels.findIndex ([v, _]) -> v == value
    @setIndex btn, i
  getValue: em @, (btn) ->
    @getData btn, '_currentValue'

  setLabel: em @, (btn, label) ->
    valuesLabels = @getData btn, '_valuesLabels'
    i = valuesLabels.findIndex ([_, l]) -> l == label
    @setIndex btn, i


exports.CheckButton = CheckButton = new class extends Button.constructor
  create: (doc, descr) ->
    descr.push 'list_class', 'policeman-popup-check-button'

    that = this
    descr.unshift 'list_command', ->
      if that.checked this then that.uncheck this else that.check this

    btn = super arguments...

    if descr.get 'checked'
      @check btn
    else
      @uncheck btn

    return btn

  check: em @, (btn) -> btn.setAttribute 'checked', 'true'
  uncheck: em @, (btn) -> btn.setAttribute 'checked', 'false'
  checked: em @, (btn) -> (btn.getAttribute 'checked') == 'true'


exports.ContainerPopulation = class ContainerPopulation
  constructor: (@_descr) ->
    @_containerId = @_descr.get 'containerId'

  getContainer: (doc) -> doc.getElementById @_containerId

  populate: (doc) ->
  purge: (doc) ->
    removeChildren @getContainer doc
  update: (doc) ->
    @purge doc
    @populate doc


exports.RadioGroup = class RadioGroup extends ContainerPopulation
  RadioButton: new class extends Button.constructor
    create: (doc, descr) ->
      descr.push 'list_class', 'policeman-popup-radio-button'

      radioGroup = descr.get 'radioGroup'
      descr.unshift 'list_command', ->
        radioGroup.select @

      btn = super arguments...

      @_unselect btn
      return btn

    _select: em @, (btn) -> btn.setAttribute 'selected', 'true'
    _unselect: em @, (btn) -> btn.setAttribute 'selected', 'false'
    _selected: em @, (btn) -> (btn.getAttribute 'selected') == 'true'

  constructor: (descr) ->
    super arguments...
    @onSelection = new Handlers

  select: (btn) ->
    return if @RadioButton._selected btn
    doc = btn.ownerDocument
    for b in @getContainer(doc).childNodes
      @RadioButton._unselect b
    @RadioButton._select btn
    @onSelection.execute btn, @

  getSelectedBtn: (doc) ->
    for b in @getContainer(doc).childNodes
      return b if @RadioButton._selected b
    return undefined

