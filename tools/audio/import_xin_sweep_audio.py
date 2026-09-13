"""Import verified Xin R cast shout variants and the initial sweep only; raw source stays read-only."""
from pathlib import Path
import array, hashlib, json, shutil, wave
ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('/Users/czh/Tools/lol-asset-tools/xin_r_review')
DEST = ROOT / 'assets/audio/units/xin'
MANIFEST = DEST / 'event_manifest.json'
manifest = json.loads(MANIFEST.read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def register(entry):
    global manifest
    manifest = [x for x in manifest if x['file'] != entry['file']] + [entry]
# Use the verified combined OnCast onset; do not guess names for its two anonymous media layers.
original = Path('/Users/czh/Tools/lol-asset-tools/card_audio_batch/xinzhao/event_wav/Play_sfx_XinZhao_XinZhaoR_OnCast.wav')
output = DEST / 'play_sfx_xinzhao_xinzhaor_oncast_sweep.wav'
with wave.open(str(original)) as reader:
    params = reader.getparams()
    assert params.sampwidth == 2
    frames = round(params.framerate * .65)
    samples = array.array('h', reader.readframes(frames))
    fade_start = round(params.framerate * .55)
    for frame in range(fade_start, frames):
        gain = (frames - 1 - frame) / max(frames - 1 - fade_start, 1)
        for channel in range(params.nchannels):
            index = frame * params.nchannels + channel
            samples[index] = round(samples[index] * gain)
with wave.open(str(output), 'wb') as writer:
    writer.setparams(params)
    writer.writeframes(samples.tobytes())
register({'file': output.name, 'event': 'Play_sfx_XinZhao_XinZhaoR_OnCast', 'event_id': 489959008,
          'source_preview': str(original), 'source_sha256': sha(original), 'media_ids': [51886756,457923771],
          'duration': .65, 'processing': 'Keep combined event onset 0–0.65s; linear amplitude fade 0.55–0.65s. Initial sweep only; omit remaining tail. No normalization.', 'sha256': sha(output)})
voices=[]
for index in range(1,5):
    original=SOURCE / f'Play_vo_XinZhao_XinZhaoR_cast3D {{r{index}}}.wav'
    txtp=original.with_suffix('.txtp')
    output=DEST / f'play_vo_xinzhao_xinzhaor_cast3d_r{index}_zh_cn.wav'
    shutil.copyfile(original,output)
    voices.append('res://assets/audio/units/xin/'+output.name)
    with wave.open(str(output)) as reader:duration=reader.getnframes()/reader.getframerate()
    register({'file':output.name,'event':'Play_vo_XinZhao_XinZhaoR_cast3D','event_id':1678827506,
              'source_preview':str(original),'source_txtp':str(txtp),'media_ids':[375886638,1010102839,947326890,855580588][index-1:index],
              'source_package':'/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/XinZhao.zh_CN.wad.client',
              'duration':duration,'processing':'wwiser event TXTP selected random variant, vgmstream-cli -i; source event mix retained; no cut or normalization','sha256':sha(output)})
MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
p=ROOT/'scripts/data/cards/xin.gd';s=p.read_text().replace('play_sfx_xinzhao_xinzhaor_oncast.wav','play_sfx_xinzhao_xinzhaor_oncast_sweep.wav').replace('"active:sustain": {','"active:start": {')
voice_config=json.dumps({'pool':voices,'volume_db':0.0,'bus':'Voice'},ensure_ascii=False)
if '"deploy:voice"' not in s:
    s=s.replace('"events": {','"events": {\n\t\t\t\t"deploy:voice": '+voice_config+',\n\t\t\t\t"active:voice": '+voice_config+',',1)
p.write_text(s)
p=ROOT/'tools/audio/card_audio_plan.json';d=json.loads(p.read_text());plan=d['xin']
# Keep other current events from the card through a documented post-import call rather than replacing all pools here.
plan['notes']+=' R起手横扫和中文喊声由 tools/audio/import_xin_sweep_audio.py 在通用导入后应用；不接持续护卫音。' if 'import_xin_sweep_audio.py' not in plan['notes'] else ''
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print('Imported 0.65s sweep and four verified R cast shout variants')
