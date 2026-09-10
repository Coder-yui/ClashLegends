"""Copy only selected, already rendered original-skin events; keep provenance."""
import json
import re
import shutil
from pathlib import Path

SOURCE = Path('/Users/czh/Tools/lol-asset-tools/masteryi_base_audio')
DEST = Path(__file__).resolve().parents[1] / 'assets/audio/units/masteryi'
EVENTS = [
    'MasterYiBasicAttack_OnCast', 'MasterYiBasicAttack2_OnCast',
    'MasterYiDoubleStrike_OnCast', 'MasterYiBasicAttack_OnHit',
    'Highlander_OnBuffActivate', 'Highlander_OnBuffDeactivate',
    'Highlander_trail', 'Death3D_cast',
]


def main():
    data = json.loads((SOURCE / 'event_map.json').read_text())
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = []
    for suffix in EVENTS:
        event = next(e for e in data['events'] if e['name'] == 'Play_sfx_MasterYi_' + suffix)
        for relative in event['event_wav']:
            source = SOURCE / relative
            name = re.sub(r'[^a-z0-9]+', '_', source.stem.lower()).strip('_') + '.wav'
            shutil.copy2(source, DEST / name)
            manifest.append({'file': name, 'event': event['name'], 'event_id': event['id'],
                             'source_preview': relative, 'media_ids': event['media_ids']})
    (DEST / 'event_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(f'Copied {len(manifest)} event WAVs; original source unchanged.')


if __name__ == '__main__':
    main()
