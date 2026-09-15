"""Find Chinese LoL voice lines using text metadata and local source audio.
Never downloads website audio or imports assets. See tools/audio/README.md.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request

LIBRARY = Path(__file__).resolve().parents[2] / 'ClashLegends-开发素材库'
API = 'https://api.buguoguo.cn/lol-voice/v1/champions'


def output_path(value):
    path = Path(value).resolve()
    if not path.is_relative_to(LIBRARY.resolve()):
        raise ValueError('Output must be inside ClashLegends-开发素材库')
    return path


def write_json(path, value):
    with path.open('x') as out:
        json.dump(value, out, ensure_ascii=False, indent=2)
        out.write('\n')


def metadata_matches(info, skin, query):
    """Website IDs are transcript keys, NOT guaranteed local WEM media IDs."""
    hits = []
    for kind, text in info.get('select', {}).items():
        if query in text:
            hits.append({'text': text, 'client_kind': kind})
    for event, descriptor in skin.get('events', {}).items():
        for key in descriptor.get('voices', []):
            text = skin.get('transcript', {}).get(key, {}).get('text', '')
            if query in text or query in descriptor.get('name', ''):
                hits.append({'text': text, 'event': event, 'category': descriptor.get('name'), 'website_key': key})
    return hits


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    catalog = sub.add_parser('catalog', help='Fetch only public transcript/event JSON; no audio')
    catalog.add_argument('--champion-id', type=int, required=True)
    catalog.add_argument('--skin', default='000')
    catalog.add_argument('--output', type=output_path, required=True)
    query = sub.add_parser('search', help='Search saved catalog or local ASR index')
    query.add_argument('--index', type=Path, required=True)
    query.add_argument('--text', required=True)
    render = sub.add_parser('render-event', help='Render all variants from already extracted local banks/WEM')
    render.add_argument('--source', type=Path, required=True)
    render.add_argument('--init', type=Path, required=True)
    render.add_argument('--event', required=True)
    render.add_argument('--output', type=output_path, required=True)
    render.add_argument('--wwiser', default='wwiser')
    render.add_argument('--vgmstream', default='vgmstream-cli')
    asr = sub.add_parser('transcribe', help='Local MLX Whisper search aid; listen to verify matches')
    asr.add_argument('--directory', type=Path, required=True)
    asr.add_argument('--output', type=output_path, required=True)
    asr.add_argument('--glob', default='*.wav', help='Select candidate WAV files')
    asr.add_argument('--model', default='mlx-community/whisper-small-mlx')
    args = parser.parse_args()
    if args.command == 'catalog':
        urls = [f'{API}/{args.champion_id}', f'{API}/{args.champion_id}/{args.skin}?GameVersion=latest']
        bodies = []
        for url in urls:
            with urllib.request.urlopen(url, timeout=30) as response:
                payload = json.load(response)
            if payload.get('code') != 0:
                raise RuntimeError(payload.get('message', 'Metadata unavailable'))
            bodies.append(payload['body'])
        write_json(args.output, {'metadata_sources': urls, 'info': bodies[0], 'skin': bodies[1]})
    elif args.command == 'search':
        index = json.loads(args.index.read_text())
        hits = metadata_matches(index['info'], index['skin'], args.text) if isinstance(index, dict) else [row for row in index if args.text in row.get('text', '')]
        print(json.dumps(hits, ensure_ascii=False, indent=2))
    elif args.command == 'render-event':
        source = args.source.resolve()
        banks = sorted(source.rglob('*.bnk'))
        if not banks or not (source/'wem').is_dir() or not args.init.is_file():
            raise ValueError('Requires local banks, wem directory and matching init.bnk')
        args.output.mkdir(parents=True, exist_ok=False)
        names = args.output/'wwnames.txt'
        names.write_text(args.event + '\n')
        with (args.output/'render.log').open('w') as log:
            subprocess.run([args.wwiser, str(args.init.resolve()), *map(str, banks), '-nl', str(names), '-g', '-gra', '-gd', '-go', str(args.output/'txtp'), '-gw', str(source/'wem'), '-d', 'none', '-gf', args.event], cwd=args.output, stdout=log, stderr=log, check=True)
            (args.output/'wav').mkdir()
            records = []
            for txtp in sorted((args.output/'txtp').glob('*.txtp')):
                text = re.sub(r'(?m)^(\s*)(/[^\n]+?)(?= #|\n)', lambda m: m[1] + os.path.relpath(m[2], txtp.parent), txtp.read_text())
                txtp.write_text(text)
                wav = args.output/'wav'/txtp.with_suffix('.wav').name
                subprocess.run([args.vgmstream, '-W', '4', '-i', '-o', str(wav), str(txtp)], stdout=log, stderr=log, check=True)
                records.append({'file': str(wav), 'event': args.event, 'txtp': str(txtp), 'sha256': hashlib.sha256(wav.read_bytes()).hexdigest()})
            if not records:
                raise RuntimeError('No event variants resolved; inspect render.log')
            write_json(args.output/'manifest.json', records)
    else:
        import mlx_whisper
        records = []
        for path in sorted(args.directory.glob(args.glob)):
            result = mlx_whisper.transcribe(str(path), path_or_hf_repo=args.model, language='zh', temperature=0, condition_on_previous_text=False)
            row = {'file': str(path.resolve()), 'text': result['text'], 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'model': args.model, 'verified_by_listening': False}
            records.append(row)
            print(json.dumps(row, ensure_ascii=False), flush=True)
        write_json(args.output, records)


if __name__ == '__main__':
    main()
