#!/usr/bin/env python2


import os, subprocess
import imp

import argparse
import re

import mozmill
from mozmill.logger import LoggerListener

import httpd
from content import Content


MANIFEST_FILENAME = 'manifest.py'
DEFAULT_TESTS_DIR = './tests'
DEFAULT_FIREFOX_PATH = '/usr/bin/firefox'


class TesterData(object):
    def __init__(self, httpd, args):
        self.httpd = httpd
        self.args = args
        self.content = Content(args)
        self.name = None # current test name, set by run_tests

class TestManifest(dict):
    def __init__(self, **ka):
        dict.__init__(self, **ka)

        js_paths = []

        if hasattr(self.module, 'paths'):
            js_paths = self.module.paths

        if not js_paths:
            # find all the js files next to the manifest
            js_paths = [p for p in self.files if p.endswith('.js')]
            js_paths = [os.path.join(self.root, p) for p in js_paths]

        self.js_paths = map(os.path.abspath, js_paths)

        for attr in ['before', 'after', 'before_every', 'after_every']:
            if hasattr(self.module, attr):
                setattr(self, attr, getattr(self.module, attr))
            else:
                setattr(self, attr, (lambda *a, **ka: None))

    def __getattr__(self, key):
        try:
            dict.__getattr__(self, key)
        except AttributeError:
            return self[key]

    def __setattr__(self, key, value):
        try:
            dict.__setattr__(self, key, value)
        except AttributeError:
            return self[key]

def find_tests(data):
    cases_dir = os.path.join(data.args.tests_dir[0], 'cases')
    for root, dirs, files in os.walk(cases_dir):
        if MANIFEST_FILENAME in files:
            manifest_path = os.path.join(root, MANIFEST_FILENAME)
            yield TestManifest(
                module=imp.load_source('_test_', manifest_path),
                root=root,
                files=files,
            )

def run_tests(tests, data):
    logger = LoggerListener()

    m = mozmill.MozMill.create(
        binary=data.args.binary,
        handlers=[logger, ],
        profile_args={
            'addons': [data.args.addon_dir[0]],
            'preferences': {
                'network.http.use-cache': False,
                'devtools.chrome.enabled': True,
                'devtools.debugger.chrome-enabled': True,
                'devtools.debugger.remote-enabled': True,
            }
        },
        jsbridge_timeout=(24*60*60), # useful when debugging tests
    )

    for t in tests:
        t.before(data)
        for js in t.js_paths:
            data.name = os.path.basename(js).split('.')[0]

            t.before_every(data)
            m.run([dict(path=js)])
            t.after_every(data)
        t.after(data)

    results = m.finish()

def parse_args():
    epilog = """
    This script depends at least on the following things:
        mozmill                 Mozmill Gecko testing framework
    """
    parser = argparse.ArgumentParser(
        description='Policeman testing utility.',
        epilog=epilog,
    )

    parser.add_argument(
        'tests_dir',
        nargs=1,
        help="path to policeman tests directory (already translated to js)"
    )

    parser.add_argument(
        'addon_dir',
        nargs=1,
        help="path to policeman built addon directory"
    )

    parser.add_argument(
        '-b',
        '--binary',
        nargs=1,
        default=DEFAULT_FIREFOX_PATH,
        help="Firefox executable path (default: %s)" % DEFAULT_FIREFOX_PATH,
    )

    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()

    httpd.start()
    data = TesterData(httpd, args)

    tests = find_tests(data)
    run_tests(tests, data)
