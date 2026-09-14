"""Import verified building events from read-only LoL banks; no gameplay edits."""
from pathlib import Path
import hashlib,json,re,subprocess,wave,tempfile
ROOT=Path(__file__).resolve().parents[2]
LIB=Path('/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工')
INDEX={}
for folder in [LIB/'card_audio_batch/azir/txtp',LIB/'card_audio_batch/yorick/txtp',LIB/'shared_audio_review/txtp']:
 for p in sorted(folder.glob('*.txtp')):
  m=re.search(r'CAkEvent\[\d+\] (\d+)',p.read_text())
  if m:INDEX.setdefault(int(m[1]),[]).append(p)
def event_hash(name):
 h=2166136261
 for c in name.lower().encode():h=((h*16777619)^c)&0xffffffff
 return h
manifest=[]
def export(event,card,limit=4):
 choices=INDEX[event_hash(event)];named=[p for p in choices if p.name.startswith(event)]
 choices=named or choices;pool=[]
 for i,source in enumerate(choices[:limit],1):
  dest=ROOT/'assets/audio/units'/card/(event.lower()+f'_r{i}.wav')
  subprocess.run(['/opt/homebrew/bin/vgmstream-cli','-i','-o',str(dest),str(source)],check=True,stdout=subprocess.DEVNULL)
  processing='vgmstream-cli -i; source event gain retained; no normalization; loop rendered as one cycle; no death truncation'
  if event == 'Play_sfx_Azir_AzirObeliskSound_OnBuffCast':
   # Keep existing one-second deployment. Compress the native Spawn window only;
   # the completion layer at source 3.5s maps to ~0.705s and its tail stays natural.
   with tempfile.TemporaryDirectory() as temp:
    adapted=Path(temp)/'spawn.wav'
    graph='[0:a]asplit[a][b];[a]atrim=end=4.9666667,asetpts=PTS-STARTPTS,atempo=2,atempo=2,atempo=1.241666675,apad,atrim=duration=1[head];[b]atrim=start=4.9666667,asetpts=PTS-STARTPTS[tail];[head][tail]concat=n=2:v=0:a=1[out]'
    subprocess.run(['/opt/homebrew/bin/ffmpeg','-v','error','-y','-i',str(dest),'-filter_complex',graph,'-map','[out]','-c:a','pcm_s16le',str(adapted)],check=True)
    dest.write_bytes(adapted.read_bytes())
   processing+='; native Spawn first 4.9666667s fitted to 1s with pitch-preserving atempo; remaining tail uncompressed'
  if event == 'Play_sfx_Azir_AzirObeliskSound_OnBuffDeactivate':
   with tempfile.TemporaryDirectory() as temp:
    adapted=Path(temp)/'death.wav'
    subprocess.run(['/opt/homebrew/bin/ffmpeg','-v','error','-y','-i',str(dest),'-af','atrim=end=2,asetpts=PTS-STARTPTS,atempo=1.333333333333,apad,atrim=duration=1.5','-c:a','pcm_s16le',str(adapted)],check=True)
    dest.write_bytes(adapted.read_bytes())
   processing+='; first 2s only, pitch-preserving compression to exactly 1.5s; no death fade envelope'
  with wave.open(str(dest)) as wav:duration=wav.getnframes()/wav.getframerate()
  manifest.append({'file':str(dest.relative_to(ROOT)),'event':event,'event_id':event_hash(event),'source_txtp':str(source),'duration':duration,'media_ids':sorted(set(re.findall(r'Source (\d+)',source.read_text()))),'processing':processing,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
  pool.append('res://'+str(dest.relative_to(ROOT)))
 return {'pool':pool,'volume_db':0.0,'bus':'Combat'}
def patch_events(card,events):
 p=ROOT/'scripts/data/cards'/f'{card}.gd';s=p.read_text();begin=f'\t\t\t\t# BEGIN BUILDING AUDIO {card}';end=f'\t\t\t\t# END BUILDING AUDIO {card}'
 block=begin+'\n'+''.join('\t\t\t\t'+json.dumps(key)+': '+json.dumps(value)+',\n' for key,value in events.items())+end
 if begin in s:s=re.sub(re.escape(begin)+'.*?'+re.escape(end),lambda _:block,s,flags=re.S)
 else:s=s.replace('"events": {','"events": {\n'+block,1)
 p.write_text(s)
if __name__=='__main__':
 sun={
 'deploy:start':export('Play_sfx_Azir_AzirObeliskSound_OnBuffCast','sun_disc'),
 'death':export('Play_sfx_Azir_AzirObeliskSound_OnBuffDeactivate','sun_disc'),
 'attack_launch':export('Play_sfx_Env_TurretBasicAttack_missilelaunch','sun_disc'),
 }
 cast=export('Play_sfx_Env_map11_ChaosTurretChampionBasicAttack_cast','sun_disc')
 hit=export('Play_sfx_Env_TurretBasicAttack_hit','sun_disc')
 sun['attack_launch']['volume_db']=-6.0
 patch_events('sun_disc',sun)
 p=ROOT/'scripts/data/cards/sun_disc.gd';s=p.read_text();begin='\t\t\t# BEGIN DISC ATTACK AUDIO';end='\t\t\t# END DISC ATTACK AUDIO'
 fields={'attack_swing':[cast['pool'],cast['pool']],'attack_hit':hit['pool'],'attack_swing_volume_db':-6.0,'attack_hit_volume_db':-6.0}
 block=begin+'\n'+''.join('\t\t\t'+json.dumps(k)+': '+json.dumps(v)+',\n' for k,v in fields.items())+end
 if begin in s:s=re.sub(re.escape(begin)+'.*?'+re.escape(end),lambda _:block,s,flags=re.S)
 else:s=s.replace('"audio": {','"audio": {\n'+block,1)
 p.write_text(s)
 patch_events('tombstone',{'idle:sustain':export('Play_sfx_Yorick_YorickWWallLife_OnBuffActivate','tombstone',1)})
 for card in ['sun_disc','tombstone']:
  (ROOT/'assets/audio/units'/card/'building_event_manifest.json').write_text(json.dumps([e for e in manifest if '/'+card+'/' in e['file']],ensure_ascii=False,indent=2)+'\n')
