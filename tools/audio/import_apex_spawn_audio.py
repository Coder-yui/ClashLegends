"""Import Q turret spawn SFX, not champion QUlt voice; original library stays read-only."""
from pathlib import Path
import hashlib, json, re, subprocess, wave
ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('/Users/czh/Tools/lol-asset-tools/card_audio_batch/heimerdinger/txtp')
DEST = ROOT / 'assets/audio/units/apex_turret'
EVENT = 'Play_sfx_HeimerTYellow_HeimerdingerQSpawnDestroyAudio_OnBuffActivate'
manifest_path = DEST/'event_manifest.json'
manifest = [e for e in json.loads(manifest_path.read_text()) if e['event'] != 'Play_vo_Heimerdinger_HeimerdingerQUlt_cast3D']
pool = []
for index in range(1,4):
    txtp = SOURCE / f'{EVENT} {{r{index}}} {{d}}.txtp'
    output = DEST / f'{EVENT.lower()}_r{index}.wav'
    subprocess.run(['/opt/homebrew/bin/vgmstream-cli','-i','-o',str(output),str(txtp)],check=True,stdout=subprocess.DEVNULL)
    pool.append('res://'+str(output.relative_to(ROOT)))
    with wave.open(str(output)) as wav: duration = wav.getnframes()/wav.getframerate()
    manifest = [e for e in manifest if e['file'] != output.name]
    manifest.append({'file':output.name,'event':EVENT,'event_id':4008859642,'source_txtp':str(txtp),
        'media_ids':[5681745,266734436,14511344], 'duration':duration,
        'processing':'Q turret spawn event, selected random variant; vgmstream-cli -i, original -9 dB event gain, no normalization',
        'selection_note':'Q (HeimerTYellow) turret spawn reused for big turret; no dedicated RQ spawn event verified. Media IDs list event-reachable sources.',
        'sha256':hashlib.sha256(output.read_bytes()).hexdigest()})
from death_audio_envelope import apply_death_envelope
death_event = EVENT.replace('OnBuffActivate', 'OnBuffDeactivate')
death_pool = []
for index in range(1,4):
    txtp = SOURCE / f'{death_event} {{r{index}}}.txtp'
    output = DEST / f'{death_event.lower()}_r{index}.wav'
    subprocess.run(['/opt/homebrew/bin/vgmstream-cli','-i','-o',str(output),str(txtp)],check=True,stdout=subprocess.DEVNULL)
    death_pool.append('res://'+str(output.relative_to(ROOT)))
    with wave.open(str(output)) as wav: duration = wav.getnframes()/wav.getframerate()
    entry = {'file':output.name,'event':death_event,'event_id':int(re.search(r'CAkEvent\[\d+\] (\d+)',txtp.read_text())[1]),
             'source_txtp':str(txtp),'duration':duration,'media_ids':[703650768,281129591,998471615],
             'processing':'Q turret destroy event, selected random variant; vgmstream-cli -i, original -21 dB event gain, no normalization',
             'sha256':hashlib.sha256(output.read_bytes()).hexdigest()}
    apply_death_envelope(output, entry)
    manifest = [e for e in manifest if e['file'] != output.name] + [entry]
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
p=ROOT/'scripts/data/cards/apex_turret.gd';s=p.read_text()
s='\n'.join(line for line in s.split('\n') if '"deploy:voice"' not in line)
if '"deploy:start"' not in s:s=s.replace('"events": {','"events": {\n\t\t\t\t"deploy:start": '+json.dumps({'pool':pool,'volume_db':0.0,'bus':'Combat'})+',',1)
if '"death": {"pool"' not in s:s=s.replace('"events": {','"events": {\n\t\t\t\t"death": '+json.dumps({'pool':death_pool,'volume_db':0.0,'bus':'Combat'})+',',1)
p.write_text(s)
p=ROOT/'tools/audio/card_audio_plan.json';d=json.loads(p.read_text());plan=d['apex_turret'];plan['events']['deploy:start']=EVENT;plan['events']['death']=death_event
plan['notes']=plan['notes'].replace(' 通用导入后运行 tools/import_apex_rq_voice.py 补入原始中文 RQ 部署语音。','')
plan['notes']+=' 部署使用 Q 炮台 Spawn SFX，不使用英雄 VO；待机保留 RQ 引擎。' if 'Spawn SFX' not in plan['notes'] else ''
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
