#!/usr/bin/env python3
"""Serve a local Pantheon review gallery and persist its rejection checklist."""
import argparse
import json
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class ReviewHandler(SimpleHTTPRequestHandler):
    lock = threading.Lock()

    def reply(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path != '/api/selections':
            return super().do_GET()
        with self.lock:
            path = Path(self.directory) / 'selections.json'
            self.reply(200, json.loads(path.read_text()) if path.exists() else {'rejected': []})

    def do_POST(self):
        if self.path != '/api/selections':
            return self.reply(404, {'error': 'Unknown endpoint'})
        origin = self.headers.get('Origin')
        if origin and origin != 'http://' + self.headers.get('Host', ''):
            return self.reply(403, {'error': 'Local review only'})
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length < 65536:
                raise ValueError('Invalid selection size')
            data = json.loads(self.rfile.read(length))
            ids = data['rejected']
            manifest = json.loads((Path(self.directory) / 'manifest.json').read_text())
            known = {i['id']: i for i in manifest['items'] if i['kind'] in ('layer', 'prop')}
            if not isinstance(ids, list) or any(not isinstance(i, str) or i not in known for i in ids):
                raise ValueError('Unknown review item')
            ids = sorted(set(ids))
            payload = {'version': 1, 'rejected': ids, 'items': [
                {'id': i, 'system': known[i]['system'], 'emitter': known[i]['emitter']} for i in ids]}
            with self.lock:
                path = Path(self.directory) / 'selections.json'
                temporary = path.with_suffix('.tmp')
                temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n')
                temporary.replace(path)
            self.reply(200, payload)
        except (ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
            self.reply(400, {'error': str(error)})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path)
    parser.add_argument('--port', type=int, default=8768)
    args = parser.parse_args()
    handler = partial(ReviewHandler, directory=str(args.directory.resolve()))
    server = ThreadingHTTPServer(('127.0.0.1', args.port), handler)
    print(f'Review: http://127.0.0.1:{args.port}/', flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
