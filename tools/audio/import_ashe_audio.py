"""Copy only selected, already rendered original-skin events; keep provenance."""
import json
import re
import shutil
from pathlib import Path

SOURCE = Path('/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/ashe_base_audio')
DEST = Path(__file__).resolve().parents[2] / 'assets/audio/units/ashe'
EVENTS = [
    'AsheBasicAttack_OnCast', 'AsheBasicAttack_OnMissileLaunch', 'AsheBasicAttack_OnHit',
    'Volley_OnCast', 'VolleyAttackWithSound_OnMissileLaunch', 'VolleyAttack_OnHit',
]

def main():
    data = json.loads((SOURCE / 'event_map.json').read_text())
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = []
    for suffix in EVENTS:
        event = next(e for e in data['events'] if e['name'] == 'Play_sfx_Ashe_' + suffix)
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
