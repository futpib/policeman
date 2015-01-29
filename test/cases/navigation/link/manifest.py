
def before(data):
  handler = data.httpd.PathHandler({
    '/': {
      'Content': '''
        <!doctype html>
        <html>
          <body>
            <a id="link" href="http://127.0.0.1:18080/samehost-location">Link</a>
          </body>
        </html>
      ''',
    },
    '/samehost-location': {
      'Content': '''
        <!doctype html>
        <html>
          <body>
            <a id="link" href="http://127.0.0.2:18080/foreign-location">Link</a>
          </body>
        </html>
      ''',
    },
    '/foreign-location': {},
  })

  data.httpd.push_handler(handler)

def after(data):
  data.httpd.pop_handler()
