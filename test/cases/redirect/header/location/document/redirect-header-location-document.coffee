
testRedirectHeaderLocationDocument = ->
  ctrl = mozmill.getBrowserController()

  ctrl.open 'http://127.0.0.1:18080'
  try ctrl.waitForPageLoad 1000

  location = ctrl.tabs.activeTab.location

  if location.href != 'http://127.0.0.1:18080/initial-location'
    assert.notEqual location.href, 'http://127.0.0.1:18080/',
            'Legit (same-host) redirect blocked'
    assert.notEqual location.href, 'http://127.0.0.2:18080/redirected-location',
            'Redirect blocking failed'
