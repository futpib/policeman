
def before(data):
  handler = data.httpd.PathHandler({
    '/': {
      'Status': 301,
      'Location': 'http://127.0.0.1:18080/1',
    },
    '/1': {
      'Status': 301,
      'Location': 'http://127.0.0.2:18080/2',
    },
    '/2': {
      'Status': 301,
      'Location': 'http://127.0.0.3:18080/3',
    },
    '/3': {},
  })

  data.httpd.push_handler(handler)

def after(data):
  data.httpd.pop_handler()
