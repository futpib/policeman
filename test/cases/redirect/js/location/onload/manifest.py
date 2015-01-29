
def before(data):
  handler = data.httpd.PathHandler({
    '/': {
      'Content': '''
        <!doctype html>
        <html>
          <body onload="document.location = 'http://127.0.0.1:18080/initial-location'">
          </body>
        </html>
      '''
    },
    '/initial-location': {
      'Content': '''
        <!doctype html>
        <html>
          <body onload="document.location = 'http://127.0.0.2:18080/redirected-location'">
          </body>
        </html>
      '''
    },
    '/redirected-location': {},
  })

  data.httpd.push_handler(handler)

def after(data):
  data.httpd.pop_handler()
