
import os
import mimetypes


class Content(object):
    def __init__(self, args):
        self._content_dir = os.path.join(args.tests_dir[0], 'content')

    def __getitem__(self, path):
        return open(os.path.join(self._content_dir, path), 'rb').read()

    def anythingOfType(self, mime):
        for root, dirs, files in os.walk(self._content_dir):
            for file in files:
                path = os.path.join(root, file)
                type, encoding = mimetypes.guess_type(path)
                if type == mime:
                    return open(path, 'rb').read()
        raise KeyError("Coundn't find a file with '%s' type" % mime)
