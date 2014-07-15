
try
  { prefs } = require 'prefs'
  { manager } = require 'ruleset/manager'
  { createElement } = require 'utils'
  { l10n } = require 'l10n'

  load = ->
    $ = (s) -> document.querySelector s

    installedList =
      init: ->
        @$ = $ '#installed-rulesets-list'
        @update()

      update: ->
        while fc = @$.firstChild
          @$.removeChild fc

        for id in prefs.get 'installedRuleSets'
          rs = manager.getMetadata id
          item = createElement document, 'richlistitem',
            align: 'center'
          item.appendChild createElement document, 'label',
            class: 'ruleset-name'
            value: rs.name
          item.appendChild createElement document, 'label',
            class: 'ruleset-description'
            value: rs.description
            crop: 'end'
          item.appendChild createElement document, 'spacer',
            flex: 1
          item.appendChild createElement document, 'label',
            class: 'ruleset-version'
            value: rs.version

          remove = item.appendChild createElement document, 'button',
            class: 'ruleset-remove'
            label: l10n 'remove'
            icon: 'remove'
            disabled: id in manager.embeddedRuleSets # disabled for embedded
          remove.addEventListener 'command', do (id=id) -> ->
            manager.uninstall id
            installedList.update()

          @$.appendChild item

    installedList.init()

#     enabledList =
#       init: ->
#         @$ = $ '#installed-rulesets-list'
#         @update()
#
#       update: ->
#         while fc = @$.firstChild
#           @$.removeChild fc
#
#         for id in prefs.get 'enabledRuleSets'
#           rs = manager.getMetadata id
#           item = createElement document, 'richlistitem',
#             align: 'center'
#           item.appendChild createElement document, 'label',
#             class: 'ruleset-name'
#             value: rs.name
#           item.appendChild createElement document, 'label',
#             class: 'ruleset-description'
#             value: rs.description
#             crop: 'end'
#           item.appendChild createElement document, 'spacer',
#             flex: 1
#           item.appendChild createElement document, 'label',
#             class: 'ruleset-version'
#             value: rs.version
#
#           disable = item.appendChild createElement document, 'button',
#             class: 'ruleset-disable'
#             label: l10n 'disable'
#             icon: 'cancel'
#           disable.addEventListener 'command', do (id=id) -> ->
#             manager.disable id
#             enabledList.update()
#
#           @$.appendChild item
#
#     enabledList.init()

  window.addEventListener 'load', load
catch e
  log e
