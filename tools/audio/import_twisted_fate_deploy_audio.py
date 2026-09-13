"""Keep the first 1.75 seconds of original Gate_marker variants without time compression."""
from pathlib import Path
import hashlib, json, subprocess, wave
ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('/Users/czh/Tools/lol-asset-tools/card_audio_batch/twistedfate/event_wav')
DEST = ROOT / 'assets/audio/units/twisted_fate'
manifest_path = DEST/'event_manifest.json'
manifest = json.loads(manifest_path.read_text())
for index in range(1,4):
    source = SOURCE / f'Play_sfx_TwistedFate_Gate_marker {{r{index}}}.wav'
    output = DEST / f'play_sfx_twistedfate_gate_marker_r{index}_first_1_75s.wav'
    with wave.open(str(source)) as wav:
        duration = wav.getnframes()/wav.getframerate()
        rate = wav.getframerate()
    filters = f'atrim=end_sample={round(rate*1.75)}'
    subprocess.run(['/opt/homebrew/bin/ffmpeg','-v','error','-y','-i',str(source),'-af',filters,'-c:a','pcm_s16le',str(output)],check=True)
    entry = {'file':output.name,'event':'Play_sfx_TwistedFate_Gate_marker','event_id':306882109,
             'source_preview':str(source),'source_txtp':str(SOURCE.parent/'txtp'/source.with_suffix('.txtp').name),
             'media_ids':[[16348301],[537911484],[916178773]][index-1], 'source_duration':duration,'duration':1.75,
             'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
             'processing':'First 1.75 seconds of original event, no time compression, no normalization, original gain retained.',
             'sha256':hashlib.sha256(output.read_bytes()).hexdigest()}
    manifest = [e for e in manifest if e['file'] != output.name] + [entry]
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
p=ROOT/'scripts/data/cards/twisted_fate.gd';s=p.read_text().replace('_last_1s.wav','_first_1_75s.wav').replace('_full_1_75s.wav','_first_1_75s.wav');p.write_text(s)
p=ROOT/'tools/audio/card_audio_plan.json';d=json.loads(p.read_text());plan=d['twisted_fate']
if 'import_twisted_fate_deploy_audio.py' not in plan['notes']:plan['notes']+=' 通用导入后运行 tools/audio/import_twisted_fate_deploy_audio.py，使用 Gate_marker 原声前 1.75 秒，不变速。'
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
