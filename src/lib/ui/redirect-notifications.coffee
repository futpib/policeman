

{ windows } = require 'windows'
{ manager } = require 'ruleset/manager'

{
  loadSheet
  removeSheet
} = require 'utils'

{ l10n } = require 'l10n'


exports.redirectNotifications = redirectNotifications = new class
  _styleURI: 'chrome://policeman/skin/redirect-notifications.css'

  constructor: ->
    @_addUI w for w in windows.list
    windows.onOpen.add @_addUI.bind @
    windows.onClose.add @_removeUI.bind @
    onShutdown.add => @_removeUI w for w in windows.list

  _addUI: (win) ->
    loadSheet win, @_styleURI

  _removeUI: (win) ->
    removeSheet win, @_styleURI

  _makeActionDescriptors: (redirect) ->
    actions = []
    temp = manager.get 'user_temporary'
    pers = manager.get 'user_persistent'
    if temp
      actions.push
          label: l10n 'redirect_notification_action_allow_once'
          accessKey: 'O'
          callback: ->
            temp.addClosure (o, d, c) ->
              if  c.contentType == 'DOCUMENT' \
              and d.spec == redirect.destination.spec
                temp.revokeClosure this
                return true
              return null
            redirect.restore()
    for [rs, rsLbl] in [[temp, 'temp'], [pers, 'pers']]
      domains = Object.create null
      domains[redirect.destination.host] = yes
      domains[redirect.destination.baseDomain] = yes
      for dest of domains
        actions.push
            label: l10n \
              "redirect_notification_action_#{rsLbl}_allow_domain_pair",
              redirect.origin.host, dest
            accessKey: actions.length.toString()
            callback: do (rs=rs, dest=dest) -> ->
              rs.allow redirect.origin.host, dest, 'DOCUMENT'
              redirect.restore()
    return actions

  show: (redirect) ->
    actions = @_makeActionDescriptors redirect
    window = redirect.browser.ownerDocument.defaultView
    window.PopupNotifications.show \
        redirect.browser,
        'policeman-redirect-notification-popup',
        l10n('redirect_notification_popup_message',
              redirect.origin.host, redirect.destination.host),
        null, # default anchor
        actions[0],
        actions.slice(1),
