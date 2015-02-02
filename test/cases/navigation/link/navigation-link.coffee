
testNavigationLink = ->
  ctrl = mozmill.getBrowserController()

  ctrl.open 'http://127.0.0.1:18080'

  try ctrl.waitForPageLoad 1000

  location = ctrl.tabs.activeTab.location

  assert.equal location.href, 'http://127.0.0.1:18080/',
            'Failed opening a tab'

  findElement.ID(ctrl.tabs.activeTab, 'link').click()

  try ctrl.waitForPageLoad 1000

  assert.equal location.href, 'http://127.0.0.1:18080/samehost-location',
            'Navigating to same host location failed'

  findElement.ID(ctrl.tabs.activeTab, 'link').click()

  try ctrl.waitForPageLoad 1000

  assert.equal location.href, 'http://127.0.0.2:18080/foreign-location',
            'Navigating to foreign location failed'
