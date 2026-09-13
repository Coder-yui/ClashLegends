"""Reusable localhost WAV audition server. No source files are modified."""
import argparse
import json
from pathlib import Path
import re
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[2]


def records(value):
    if isinstance(value, list):
        for item in value: yield from records(item)
    elif isinstance(value, dict):
        if isinstance(value.get('file'), str) or isinstance(value.get('path'), str):
            yield value
        else:
            for item in value.values(): yield from records(item)


def build_catalog(directories=(), manifests=(), cards=()):
    found = {}
    for folder in directories:
        folder = Path(folder).expanduser().resolve()
        if not folder.is_dir(): raise ValueError(f'Audio directory does not exist: {folder}')
        for path in sorted(folder.rglob('*.wav')):
            resolved = path.resolve()
            if resolved.is_relative_to(folder): found[resolved] = {}
    for manifest in manifests:
        manifest = Path(manifest).expanduser().resolve()
        for entry in records(json.loads(manifest.read_text())):
            name = entry.get('file', entry.get('path', ''))
            if not name.lower().endswith('.wav'): continue
            name = name.removeprefix('res://')
            path = Path(name).expanduser()
            if not path.is_absolute():
                local = manifest.parent / path
                path = local if local.is_file() else ROOT / path
            path = path.resolve()
            if not path.is_file(): raise ValueError(f'Manifest references missing WAV: {path}')
            found[path] = entry
    result = []
    for path, entry in sorted(found.items()):
        if cards and not any(card in path.parts for card in cards): continue
        with wave.open(str(path)) as stream:
            duration = stream.getnframes() / stream.getframerate()
        unit = path.parent.name
        if 'units' in path.parts:
            index = path.parts.index('units')
            if index + 1 < len(path.parts): unit = path.parts[index + 1]
        result.append({'id': len(result), 'group': str(entry.get('group', unit)),
                       'team': '蓝方' if 'order' in path.parts else ('红方' if 'chaos' in path.parts else ''),
                       'cue': str(entry.get('cue', entry.get('label', '素材试听'))),
                       'event': str(entry.get('event', '未提供事件标签；以实际接入配置为准')),
                       'file': path.name, 'path': str(path), 'duration': duration, 'url': f'/audio/{len(result)}'})
    if not result: raise ValueError('No WAV files matched the selected inputs.')
    return result


def byte_range(header, size):
    if not header: return None
    match = re.fullmatch(r'bytes=(\d*)-(\d*)', header)
    if not match or not any(match.groups()) or size <= 0: raise ValueError('Invalid range')
    left, right = match.groups()
    if not left:
        count = int(right)
        if count <= 0: raise ValueError('Invalid suffix range')
        return max(0, size - count), size - 1
    start = int(left); end = min(int(right) if right else size - 1, size - 1)
    if start > end: raise ValueError('Unsatisfiable range')
    return start, end


def make_handler(items):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self): self.respond(False)
        def do_HEAD(self): self.respond(True)
        def respond(self, head):
            route = self.path.split('?')[0]
            if route == '/':
                data = Path(__file__).with_name('index.html').read_bytes(); mime = 'text/html; charset=utf-8'
            elif route == '/catalog':
                data = json.dumps(items, ensure_ascii=False).encode(); mime = 'application/json; charset=utf-8'
            elif re.fullmatch(r'/audio/\d+', route) and int(route[7:]) < len(items):
                try: data = Path(items[int(route[7:])]['path']).read_bytes()
                except OSError: self.send_error(404); return
                mime = 'audio/wav'
            else:
                self.send_error(404); return
            total = len(data)
            try: selected = byte_range(self.headers.get('Range', ''), total) if mime == 'audio/wav' else None
            except ValueError:
                self.send_response(416); self.send_header('Content-Range', f'bytes */{total}'); self.end_headers(); return
            if selected:
                start, end = selected; data = data[start:end+1]
                self.send_response(206); self.send_header('Content-Range', f'bytes {start}-{end}/{total}')
            else: self.send_response(200)
            self.send_header('Accept-Ranges', 'bytes')
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            if not head: self.wfile.write(data)
        def log_message(self, *args): pass
    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, action='append', default=[], help='Recursively include WAVs; repeatable, supports external staging directories')
    parser.add_argument('--manifest', type=Path, action='append', default=[], help='JSON file with file/path entries; repeatable')
    parser.add_argument('--cards', nargs='+', default=[], help='Filter project audio by unit directory name')
    parser.add_argument('--port', type=int, default=18765)
    parser.add_argument('--catalog-only', action='store_true', help='Validate and print catalog without starting server')
    args = parser.parse_args()
    try:
        directories = args.directory or ([] if args.manifest else [ROOT / 'assets/audio'])
        items = build_catalog(directories, args.manifest, args.cards)
        if args.catalog_only:
            print(json.dumps(items, ensure_ascii=False, indent=2)); return
        server = ThreadingHTTPServer(('127.0.0.1', args.port), make_handler(items))
        print(f'音频试听：http://127.0.0.1:{server.server_port}/（{len(items)} 个声音；Ctrl+C 结束）', flush=True)
        try: server.serve_forever()
        except KeyboardInterrupt: pass
        finally: server.server_close()
    except (OSError, ValueError, wave.Error) as error: parser.exit(2, f'{error}\n')

if __name__ == '__main__': main()
