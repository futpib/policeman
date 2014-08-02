 
# ###
# This class and subclasses represent viewpopup radiobutton groups
# that filter displayed requests based on some criteria (e.g. domain name)
# ###
# class Filter
#   constructor: (containerId, @defaultValue=null) ->
#     @id = containerId
#     @value = @defaultValue
#     @onChange = new Handlers
#     @onChange.add (e) =>
#       @value = e.target.getAttribute 'value'
#
#   addUI: (doc) ->
#     container = doc.getElementById @id
#     btn = container.firstChild
#     while btn = btn.nextSibling
#       btn.addEventListener 'command', @onChange.execute
#
#   removeUI: (doc) ->
#     container = doc.getElementById @id
#     btn = container.firstChild
#     while btn = btn.nextSibling
#       btn.removeEventListener 'command', @onChange.execute
#
#   updateUI: (doc, data) ->
#
#   filter: (data) -> throw new Error 'Subclass should supply "filter" method.'
#
#   wildcard: '*'
#
# ###
# Actually a source of data rather then filter.
# Retrieves requests data from memo.
# ###
# class ContextFilter extends Filter
#   filter: ->
#     switch @value
#       when 'app' then memo.getAllRequests()
#       when 'window' then memo.getRequestsByWindow windows.getCurrent()
#       when 'tab' then memo.getRequestsByTab tabs.getCurrent()
#       else throw new Error "Unexpected context filter '#{contextFilter}'"
#
# ###
# Passes only requests from selected origin domain
# ###
# class DomainFilter extends Filter
#   updateUI: (doc, data) -> # data = strOrigin -> strDest -> decision
#     log @id
#     container = doc.getElementById @id
#
#     @removeVaryingButtons doc, container
#
#     @addVaryingButtons doc, container, @generateButtonLabelsAndValues data
#
#   generateButtonLabelsAndValues: (data) ->
#     throw new Error 'Subclass should supply labels and values generator method.'
#
#   removeVaryingButtons: (doc, container) ->
#     doomed = (btn for btn in container.children when btn.hasAttribute 'varying')
#     for btn in doomed
#       btn.removeEventListener 'command', @onChange.execute
#       container.removeChild btn
#
#   addVaryingButtons: (doc, container, labelsToValues) ->
#     selectionRestored = false
#
#     for label, value of labelsToValues
#       btn = createElement doc, 'toolbarbutton',
#           class: 'subviewbutton'
#           type: 'radio'
#           group: @id
#           closemenu: 'none'
#           label: label
#           value: value
#           varying: true
#       if value == @value # restore previous selection
#         btn.setAttribute 'checked', 'true'
#         selectionRestored = true
#
#       btn.addEventListener 'command', @onChange.execute
#       container.appendChild btn
#
#     if not selectionRestored # check default radiobutton
#       for btn in container.children
#         if @defaultValue == btn.getAttribute 'value'
#           btn.setAttribute 'checked', 'true'
#           break
#
# class OriginDomainFilter extends DomainFilter
#   generateButtonLabelsAndValues: (data) ->
#     # TODO factor out common second-to-higher-level domains
#     # based on number of url under such domain
#
#     # TODO sorting by blocked hits count would be nice
#     # as well as displaying blocked/allowed counters
#
#     # get unique hosts
#     hosts = {}
#     for o of data
#       hosts[(new OriginInfo o).host] = true
#
#     labelsToValues = {}
#     for h of hosts
#       labelsToValues[h] = h
#
#     return labelsToValues
#
#   filter: (data) ->
#     return data if @value == Filter::wildcard
#
#     filtered = {}
#     for origin, destToDecision of data
#       if (new OriginInfo origin).host == @value
#         filtered[origin] = destToDecision
#     return filtered
#
# class DestDomainFilter extends DomainFilter
#   generateButtonLabelsAndValues: (data) ->
#     hosts = {}
#     for o, destToDecision of data
#       for d of destToDecision
#         hosts[(new DestInfo d).host] = true
#
#     labelsToValues = {}
#     for h of hosts
#       labelsToValues[h] = h
#
#     return labelsToValues
#
#   filter: (data) ->
#     return data if @value == Filter::wildcard
#
#     filtered = {}
#     for origin, destToDecision of data
#       filtered[origin] = {}
#       for dest, decision of destToDecision
#         if (new DestInfo dest).host == @value
#           filtered[origin][dest] = decision
#     return filtered
