
testRedirectHeaderLocationDouble = ->
  ###
  This is a test for proper redirect origin URI detection.
  The server is configured (in manifest.py) to perform two HTTP redirects:
    127.0.0.1 → 127.0.0.2 → 127.0.0.3
  Policeman is configured to allow 1 → 2 and 1 → 3 but not 2 → 3.
  A better implementation should not allow the 2 → 3 redirect while our
  implementation records the last 2 → 3 redirect as 1 → 3 (since nsIChannel
  only holds it's original URI and it's current URI without intermediate ones,
  see 'lib/request-info.coffee')
  ###

  ctrl = mozmill.getBrowserController()

  temp = policeman.require('ruleset/manager').manager.get('user_temporary')

  temp.allow  '127.0.0.1', '127.0.0.3'
  temp.allow  '127.0.0.1', '127.0.0.2'
  temp.reject '127.0.0.2', '127.0.0.3'

  ctrl.open 'http://127.0.0.1:18080'
  try ctrl.waitForPageLoad 1000

  location = ctrl.tabs.activeTab.location

  assert.notEqual location.href, 'http://127.0.0.3:18080/3',
          'Double redirect blocking failed'
