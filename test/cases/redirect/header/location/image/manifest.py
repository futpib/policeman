
def before(data):
  handler = data.httpd.PathHandler({
    '/': {
      'Content': '''
        <img id="image">
      ''',
    },
    '/image.png': {
      'Status': 301,
      'Location': 'http://127.0.0.2:18080/image2.png',
      'Content-Type': None,
      'Content': None,
    },
    '/image2.png': {
      'Content-Type': 'image/png',
      'Content': data.content.anythingOfType('image/png')
    },
  })

  data.httpd.push_handler(handler)

def after(data):
  data.httpd.pop_handler()
