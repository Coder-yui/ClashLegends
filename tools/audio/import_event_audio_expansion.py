"""Import verified event variants and candidate-only Spell4 auditions from local source banks."""
from pathlib import Path
import hashlib,json,re,subprocess,os
from death_audio_envelope import apply_death_envelope
ROOT=Path(__file__).resolve().parents[2]
BASE=Path('/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/card_audio_batch')
SHARED=Path('/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/shared_audio_review')
def event_hash(s):
 h=2166136261
 for c in s.lower().encode():h=((h*16777619)^c)&0xffffffff
 return h
index={}
for folder in [SHARED/'named_txtp',BASE/'twistedfate/txtp',BASE/'yorick/txtp',BASE/'azir/txtp']:
 for p in folder.glob('*.txtp'):
  m=re.search(r'CAkEvent\[\d+\] (\d+)',p.read_text())
  if m:index.setdefault(int(m[1]),[]).append(p)
manifest=[]
def pool(event,folder,death=False,limit=3):
 files=sorted(index.get(event_hash(event),[]),key=lambda p:p.name)
 if not files:print('MISSING',event,flush=True);return []
 paths=[]
 for i,txtp in enumerate(files[:limit],1):
  dest=(ROOT/'ClashLegends-开发素材库/02-候选讨论/音频'/folder.removeprefix('auditions/')) if folder.startswith('auditions/') else ROOT/'assets/audio'/folder;dest.mkdir(parents=True,exist_ok=True)
  output=dest/(event.lower()+f'_r{i}.wav')
  # Keep source bank relative paths usable for vgmstream, without editing source TXTP.
  converted=SHARED/'decode';converted.mkdir(exist_ok=True)
  text=txtp.read_text()
  def relative(m):
   source=Path(m[2]);source=source if source.is_absolute() else (txtp.parent/source).resolve()
   return m[1]+os.path.relpath(source,converted)
  text=re.sub(r'(?m)^(\s*)([^#\n]+?\.(?:bnk|wem))(?= #|\n)',relative,text)
  source_txtp=converted/(str(event_hash(event))+f'_{i}.txtp');source_txtp.write_text(text)
  subprocess.run(['/opt/homebrew/bin/vgmstream-cli','-i','-o',str(output),str(source_txtp)],check=True,stdout=subprocess.DEVNULL)
  import wave
  with wave.open(str(output)) as w:duration=w.getnframes()/w.getframerate()
  entry={'file':str(output.relative_to(ROOT)),'event':event,'event_id':event_hash(event),'source_txtp':str(txtp),'duration':duration,'media_ids':sorted(set(map(int,re.findall(r'Source (\d+)',text)))),'processing':'Original event layers and gain; selected outer random variants; vgmstream-cli -i, no normalization','sha256':hashlib.sha256(output.read_bytes()).hexdigest()}
  if death:apply_death_envelope(output,entry)
  manifest.append(entry);paths.append(str(output) if folder.startswith('auditions/') else 'res://'+str(output.relative_to(ROOT)))
 return paths
def event(paths):return {'pool':paths,'volume_db':0.0,'bus':'Combat'}
def set_audio(card,audio,merge=False):
 p=ROOT/'scripts/data/cards'/f'{card}.gd';s=p.read_text()
 if merge:
  # Existing imp audio remains; insert one new spawn event.
  cue,config=next(iter(audio['events'].items()))
  if f'"{cue}"' not in s:s=s.replace('"events": {','"events": {\n\t\t\t\t'+json.dumps(cue)+': '+json.dumps(config)+',',1)
 else:
  begin=f'\t\t# BEGIN EVENT AUDIO {card}';end=f'\t\t# END EVENT AUDIO {card}'
  block=begin+'\n\t\t"audio": '+json.dumps(audio,ensure_ascii=False,indent='\t').replace('\n','\n\t\t')+',\n'+end+'\n'
  if begin in s:s=re.sub(re.escape(begin)+'.*?'+re.escape(end)+'\n',lambda _:block,s,flags=re.S)
  else:s=s.replace('\t\t"card_art":',block+'\t\t"card_art":',1)
 p.write_text(s)
auditions={}
for label,name in [('R1·Destiny 施放','Destiny_OnCast'),('R1·Destiny 生效','Destiny_OnBuffActivate'),('R1·Destiny 结束','Destiny_OnBuffDeactivate'),('R2·Gate 引导','Gate_OnBuffActivate'),('R2·Gate 落点（完整原声）','Gate_marker')]:
 auditions[label]=event(pool('Play_sfx_TwistedFate_'+name,'auditions/twisted_fate',limit=20))
p=ROOT/'ClashLegends-开发素材库/02-候选讨论/音频/twisted_fate/试听清单.json';p.write_text(json.dumps([{'file':file,'cue':cue,'group':'twisted_fate'} for cue,event in auditions.items() for file in event['pool']],ensure_ascii=False,indent=2)+'\n')
set_audio('imp',{'events':{'spawn:start':event(pool('Play_sfx_Yorick_YorickQ_summon','units/imp',limit=5))}},True)
set_audio('tombstone',{'events':{'deploy:start':event(pool('Play_sfx_Yorick_YorickW_OnHitLocation','units/tombstone')),'death':event(pool('Play_sfx_Yorick_YorickW_death','units/tombstone',True,4))}})
set_audio('heal',{'events':{'spell:cast':event(pool('Play_sfx_SummonerHeal_OnCast','spells/heal'))}})
set_audio('sun_disc',{'events':{'shield:cast':event(pool('Play_sfx_3190Active_OnCast','units/sun_disc'))}})
for card,kind in [('melee_minion','Melee'),('ranged_minion','Ranged'),('siege_minion','Siege'),('super_minion','Super')]:
 teams=[]
 for team in ['Order','Chaos']:
  prefix=f'Play_sfx_SRU_{team}Minion{kind}_SRU_{team}Minion{kind}BasicAttack'
  cast=prefix+('_OnMissileCast' if kind=='Siege' and team=='Chaos' else '_OnCast')
  swings=[pool(cast,f'units/{card}/{team.lower()}')]
  hits=[pool(prefix+'_OnHit',f'units/{card}/{team.lower()}')]
  if kind=='Siege':
   swings.append(swings[0]);hits.append(hits[0])
  else:
   swings.append(pool(prefix+'2_OnCast',f'units/{card}/{team.lower()}'))
   hits.append(pool(prefix+'2_OnHit',f'units/{card}/{team.lower()}'))
  audio={'attack_hit_by_segment':hits,'attack_swing_volume_db':0.0,'attack_hit_volume_db':0.0}
  if kind=='Siege' and team=='Chaos':audio['events']={'attack_missile_cast':event(swings[0])}
  else:audio['attack_swing']=swings
  teams.append(audio)
 set_audio(card,{'team_overrides':teams})
world={}
for team in ['Order','Chaos']:
 folder='world/'+team.lower()
 base='Play_sfx_Env_map11_'+team+'TurretMinionBasicAttack'
 world['world_tower_'+team.lower()]={'audio':{'attack_hit':pool(base+'_hit',folder,limit=4),'attack_hit_volume_db':0.0,'events':{'attack:cast':event(pool(base+'_cast',folder)),'attack:launch':event(pool(base+'_missilelaunch',folder,limit=4)),'damage:stage1':event(pool('Play_sfx_ENV_'+team+'Turret_break01',folder)),'damage:stage2':event(pool('Play_sfx_ENV_'+team+'Turret_break02',folder)),'death':event(pool('Play_sfx_ENV_'+team+'Turret_break03',folder))}}}
 death='Play_sfx_Env_Global_EoG_'+team+'Nexus_death_'+('oc' if team=='Order' else 'cast')
 world['world_nexus_'+team.lower()]={'audio':{'events':{'spawn:start':event(pool('Play_sfx_Env_sruap_'+team.lower()+'_nexus_spawn',folder)),'idle:sustain':dict(event(pool('Play_sfx_Env_sruap_'+team.lower()+'_nexus_alive_loop',folder)),volume_db=0.0),'death':event(pool(death,folder))}}}
(ROOT/'scripts/data/world_audio.gd').write_text('extends RefCounted\n## 系统建筑音频；原始事件见 assets/audio/event_expansion_manifest.json。\nconst DEFINITIONS = '+json.dumps(world,ensure_ascii=False,indent='\t')+'\n')
(ROOT/'assets/audio/event_expansion_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Imported',len(manifest),'variants')

# Restore the later building integration after regenerating initial event blocks.
import runpy
runpy.run_path(str(ROOT/"tools/audio/import_sun_disc_tombstone_audio.py"), run_name="__main__")

runpy.run_path(str(ROOT/"tools/audio/import_match_audio.py"), run_name="__main__")
