"""Copy only selected, already rendered original-skin events; keep provenance."""
from audio_manifest_merge import merge_audio_manifest
import json
import re
import shutil
from pathlib import Path
from death_audio_envelope import apply_death_envelope

SOURCE = Path('/Users/czh/Tools/lol-asset-tools/masteryi_base_audio')
DEST = Path(__file__).resolve().parents[2] / 'assets/audio/units/masteryi'
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
            if suffix == 'Death3D_cast':
                manifest[-1]['source_preview'] = str(source)
                apply_death_envelope(DEST / name, manifest[-1])
    manifest = merge_audio_manifest(DEST / 'event_manifest.json', manifest)
    (DEST / 'event_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(f'Copied {len(manifest)} event WAVs; original source unchanged.')


if __name__ == '__main__':
    main()
