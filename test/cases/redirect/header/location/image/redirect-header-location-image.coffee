
testRedirectHeaderLocationImage = ->
  ctrl = mozmill.getBrowserController()

  ctrl.open 'http://127.0.0.1:18080'
  ctrl.waitForPageLoad()

  img = ctrl.tabs.activeTab.getElementById 'image'

  error = no
  img.addEventListener 'error', -> error = yes

  img.src = 'http://127.0.0.1:18080/image.png'

  assert.waitFor (-> error),
          'Image redirect blocking failed',
          1000
