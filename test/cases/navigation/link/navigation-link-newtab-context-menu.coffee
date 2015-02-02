
testNavigationLinkNewtabContextMenu = ->
  ctrl = mozmill.getBrowserController()

  menu = ctrl.getMenu '#contentAreaContextMenu'
  openLinkInNewTab = ->
    linkMenu = menu.open findElement.ID(ctrl.tabs.activeTab, 'link')
    linkMenu.click '#context-openlinkintab'
    linkMenu.close()

  ctrl.open 'http://127.0.0.1:18080'
  try ctrl.waitForPageLoad 1000

  assert.equal ctrl.tabs.activeTab.location.href,
            'http://127.0.0.1:18080/',
            'Failed opening a tab'

  openLinkInNewTab()

  ctrl.tabs.selectTabIndex ctrl.tabs.activeTabIndex + 1
  try ctrl.waitForPageLoad 1000

  assert.equal ctrl.tabs.activeTab.location.href,
            'http://127.0.0.1:18080/samehost-location',
            'Opening a same-host link in new tab failed'

  openLinkInNewTab()

  ctrl.tabs.selectTabIndex ctrl.tabs.activeTabIndex + 1
  try ctrl.waitForPageLoad 1000

  assert.equal ctrl.tabs.activeTab.location.href,
            'http://127.0.0.2:18080/foreign-location',
            'Opening a foreign-host link in new tab failed'
