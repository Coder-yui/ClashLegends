"""Extract only the verified Death3D event's three media from the zh_CN WPK."""
import json
import re
import struct
import subprocess
import shutil
from pathlib import Path
import xml.etree.ElementTree as ET
from death_audio_envelope import apply_death_envelope

TOOLS = Path('/Users/czh/Tools/lol-asset-tools')
SOURCE = TOOLS / 'verification/ashe_vo_zh'
BANK = SOURCE / 'assets/sounds/wwise2016/vo/en_us/characters/ashe/skins/base'
OUT = TOOLS / 'ashe_death_zh_audio'
DEST = Path(__file__).resolve().parents[2] / 'assets/audio/units/ashe'
EVENT = 'Play_vo_Ashe_Death3D'

def main():
    def values(node, name):
        return [int(f.get('value')) for f in node.findall(f'.//field[@name="{name}"]')]
    nodes = {values(n, 'ulID')[0]: n for n in ET.parse(SOURCE / 'events.xml').find('.//list[@name="listLoadedItem"]')}
    event_id = 2166136261
    for c in EVENT.lower().encode():
        event_id = ((event_id * 16777619) ^ c) & 0xffffffff
    media = set()
    seen = set()
    def walk(ident):
        if ident in seen:
            return
        seen.add(ident)
        node = nodes[ident]
        media.update(values(node, 'sourceID'))
        kind = node.get('name')
        key = 'ulActionID' if kind == 'CAkEvent' else 'idExt' if kind.startswith('CAkAction') else 'ulChildID'
        for child in values(node, key):
            walk(child)
    walk(event_id)
    assert media == {2639712284, 2320440732, 2413345029}
    blob = (BANK / 'ashe_base_vo_audio.wpk').read_bytes()
    magic, version, count = struct.unpack_from('<4sII', blob)
    assert magic == b'r3d2' and version == 1 and 12 + count * 4 <= len(blob)
    wem = OUT / 'wem'
    wem.mkdir(parents=True, exist_ok=True)
    found = set()
    for index in range(count):
        entry = struct.unpack_from('<I', blob, 12 + index * 4)[0]
        offset, size, chars = struct.unpack_from('<III', blob, entry)
        name = blob[entry+12:entry+12+chars*2].decode('utf-16-le')
        if name not in {f'{i}.wem' for i in media}:
            continue
        assert offset + size <= len(blob) and blob[offset:offset+4] == b'RIFF'
        (wem / name).write_bytes(blob[offset:offset+size])
        found.add(int(Path(name).stem))
    assert found == media
    names = OUT / 'wwnames.txt'
    names.write_text(EVENT + '\n')
    subprocess.run([str(TOOLS/'bin/wwiser'), str(TOOLS/'verification/garen/assets/sounds/wwise2016/sfx/shared/init.bnk'),
                    str(BANK/'ashe_base_vo_events.bnk'), str(BANK/'ashe_base_vo_audio.bnk'),
                    '-nl', str(names), '-g', '-gra', '-gv', '0dB', '-go', str(OUT/'txtp'),
                    '-gw', str(wem), '-d', 'none', '-gf', str(event_id)], check=True, cwd=OUT)
    rendered = OUT / 'event_wav'
    rendered.mkdir(exist_ok=True)
    manifest = []
    for txtp in sorted((OUT/'txtp').glob('*.txtp')):
        txtp.write_text(txtp.read_text().replace(str(wem)+'/', '../wem/'))
        wav = rendered / (txtp.stem + '.wav')
        subprocess.run(['/opt/homebrew/bin/vgmstream-cli', '-i', '-o', str(wav), str(txtp)], check=True, capture_output=True)
        name = re.sub('[^a-z0-9]+', '_', txtp.stem.lower()).strip('_') + '_zh_cn.wav'
        shutil.copy2(wav, DEST/name)
        manifest.append(dict(file=name, event=EVENT, event_id=event_id, media_ids=sorted(media),
                             source_preview=str(wav), source_package='Ashe.zh_CN.wad.client'))
        apply_death_envelope(DEST/name, manifest[-1])
    assert len(manifest) == 3
    (DEST/'death_event_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    print('Imported 3 verified death variants from zh_CN package.')

if __name__ == '__main__':
    main()
