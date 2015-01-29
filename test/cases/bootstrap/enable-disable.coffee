
testEnableDisable = ->
  Cu.import "resource://gre/modules/AddonManager.jsm"

  getAddonCallback = no
  disabledCallback = no
  enabledCallback = no

  requireComponentIsLoaded = ->
    # this is a good indicator of require.coffee being loaded
    return !! try Cc["@futpib.addons.mozilla.org/policeman-internals;1"] \
                          .getService().wrappedJSObject

  AddonManager.addAddonListener listener =
    onDisabled: (addon) ->
      return unless addon.id == policeman.id
      disabledCallback = yes

    onEnabled: (addon) ->
      return unless addon.id == policeman.id
      enabledCallback = yes

  addon = null

  AddonManager.getAddonByID policeman.id, (addon_) ->
    addon = addon_
    assert.ok addon.isActive, 'addon.isActive'
    getAddonCallback = yes

  assert.waitFor (-> getAddonCallback),
          'Waiting for AddonManager.getAddonByID callback'

  addon.userDisabled = yes

  assert.waitFor (-> disabledCallback),
          'Waiting for addon to become disabled'

  assert.waitFor (-> ! requireComponentIsLoaded()),
          'Waiting for require.coffee to unload after addon is disabled'

  addon.userDisabled = no

  assert.waitFor (-> enabledCallback),
          'Waiting for addon to become enabled'

  assert.waitFor (-> requireComponentIsLoaded()),
          'Waiting for require.coffee to load after addon is enabled'

  AddonManager.removeAddonListener listener
