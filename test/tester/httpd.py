#!/usr/bin/env python2


"""
Http server for testing.

Tests may add their own request handlers before running
(see `HandlerBase`, `push_handler` and `pop_handler`)
"""


from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
from SocketServer import ThreadingMixIn
from threading import Thread


class SimpleHandler(object):
    """
    Extend this in your test to pass to `httpd.push_handler`.
    """

    def __init__(self):
        self._headers = {
            'Content-type': 'text/html'
        }
        self._content = """
        <html>
            <head>
                <title>
                    Default request handler
                </title>
            </head>
            <body>
                <h1>
                    It works!
                </h1>
            </body>
        </html>
        """
        self._status = 200

    @staticmethod
    def _do_headers(handler, headers):
        for k, v in headers.items():
            handler.send_header(k, v)
        handler.end_headers()

    @staticmethod
    def _write_content(handler, content):
        if content is not None:
            handler.wfile.write(content)

    def do_HEAD(self, handler):
        handler.send_response(self._status)
        self._do_headers(handler, self._headers)

    def do_GET(self, handler):
        handler.send_response(self._status)
        self._do_headers(handler, self._headers)
        self._write_content(handler, self._content)

    def do_POST(self, handler):
        self.do_GET(handler)


class PathHandler(SimpleHandler):
    """
    Serves requests according to a description dictionary of the following form:
    {
        '/path' OR regexp: {
            'Status': 200,
            'Header': 'value',
            'Content': '<html>',
            ...
        },
        ...
    }
    """

    def __init__(self, descr):
        SimpleHandler.__init__(self)
        self._descr = descr

    @staticmethod
    def _match(pattern, path):
        if hasattr(pattern, 'match'):
            return bool(pattern.match(path))
        else:
            return pattern == path

    def _do_response(self, handler, response_descr):
        response_descr = dict(response_descr)

        response_descr.setdefault('Content-type', 'text/html')
        content = response_descr.pop('Content', self._content)
        status = int(response_descr.pop('Status', 200))

        handler.send_response(status)
        self._do_headers(handler, response_descr)
        self._write_content(handler, content)

    def do_GET(self, handler):
        for path_pattern, response_descr in self._descr.items():
            if self._match(path_pattern, handler.path):
                self._do_response(handler, response_descr)
                break


class HandlersStack(BaseHTTPRequestHandler):
    """
    Handler that delegates all the work to the top object in the handlers stack.
    """

    _handlers = [ SimpleHandler() ]

    def __init__(self, *a, **ka):
        BaseHTTPRequestHandler.__init__(self, *a, **ka)

    def do_POST(self): self._handlers[-1].do_POST(self)
    def do_HEAD(self): self._handlers[-1].do_HEAD(self)
    def do_GET(self): self._handlers[-1].do_GET(self)

    @classmethod
    def _push_handler(cls, handler):
        cls._handlers.append(handler)

    @classmethod
    def _pop_handler(cls):
        assert len(cls._handlers) > 1, "Can't pop last handler"
        cls._handlers.pop()

    @classmethod
    def _peek_handler(cls):
        return cls._handlers[0]

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """
    Handle requests in a separate thread.
    """

def run():
    """
    Starts the server
    """
    server = ThreadedHTTPServer(('', 18080), HandlersStack)
    server.serve_forever()

httpd = Thread(target=run)
httpd.daemon = True

def start():
    httpd.start()

def push_handler(handler):
    """
    Pushes a request handler onto the stack.
    Call this to change the server's behavior.
    (server responds with whatever topmost handler decides)
    """
    HandlersStack._push_handler(handler)

def pop_handler():
    """
    Pops a request handler from the stack.
    Call this when your test is done.
    """
    HandlersStack._pop_handler()

