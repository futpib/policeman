
def before(data):
  handler = data.httpd.PathHandler({
    '/': {
      'Refresh': '0; url=http://127.0.0.1:18080/initial-location',
    },
    '/initial-location': {
      'Refresh': '0; url=http://127.0.0.2:18080/redirected-location',
    },
    '/redirected-location': {},
  })

  data.httpd.push_handler(handler)

def after(data):
  data.httpd.pop_handler()
