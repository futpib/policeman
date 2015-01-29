
def before(data):
  handler = data.httpd.PathHandler({
    '/': {
      'Content': '''
        <!doctype html>
        <html>
          <head>
            <meta http-equiv="refresh"
                  content="0;url=http://127.0.0.1:18080/initial-location" />
          </head>
          <body>
          </body>
        </html>
      ''',
    },
    '/initial-location': {
      'Content': '''
        <!doctype html>
        <html>
          <head>
            <meta http-equiv="refresh"
                  content="0;url=http://127.0.0.2:18080/redirected-location" />
          </head>
          <body>
            <a href="http://127.0.0.3:18080/navigated-location">Link</a>
          </body>
        </html>
      ''',
    },
    '/redirected-location': {
      'Content': '''
        <!doctype html>
        <html>
          <head>
          </head>
          <body>
            <a href="http://127.0.0.3:18080/navigated-location">Link</a>
          </body>
        </html>
      ''',
    },
    '/navigated-location': {},
  })

  data.httpd.push_handler(handler)

def after(data):
  data.httpd.pop_handler()
