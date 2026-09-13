"""Import Chinese default announcer and shared minion spawn; source banks stay read-only."""
from pathlib import Path
import json,re,subprocess,wave,hashlib,runpy
ROOT=Path(__file__).resolve().parents[2]
LIB=Path('/Users/czh/Tools/lol-asset-tools')
SELECT={
'victory':('胜利 · 已接入结尾','Play_vo_Announcer_Global_Female1_OnVictory'),
'defeat':('失败 · 已接入结尾','Play_vo_Announcer_Global_Female1_OnDefeat'),
'minions_spawn':('全军出击 · 已接入第5秒首波兵线','Play_vo_Announcer_Female1_MinionSpawn'),
'welcome':('欢迎来到召唤师峡谷 · 仅试听','Play_vo_Announcer_Female1_StartGameMessage1Map11'),
'start_warning':('开局准备提示 · 仅试听','Play_vo_Announcer_Female1_StartGameMessage2Map11'),
'first_blood':('第一滴血 · 仅试听','Play_vo_Announcer_Female1_FirstBloodYouYourTeam'),
'ally_kill':('友方击杀 · 仅试听','Play_vo_Announcer_Female1_KillChampionHeroHeroYourTeam'),
'enemy_kill':('敌方击杀 · 仅试听','Play_vo_Announcer_Female1_KillChampionHeroHeroEnemyTeam'),
'double_kill':('双杀 · 仅试听','Play_vo_Announcer_Female1_DoubleKillYouYourTeam'),
 'triple_kill':('三杀 · 仅试听','Play_vo_Announcer_Female1_TripleKillYouYourTeam'),
'quadra_kill':('四杀 · 仅试听','Play_vo_Announcer_Female1_QuadraKillYouYourTeam'),
'penta_kill':('五杀 · 仅试听','Play_vo_Announcer_Female1_PentaKillYouYourTeam'),
'killing_spree':('大杀特杀 · 仅试听','Play_vo_Announcer_Female1_KillingSpreeYouYourTeam'),
'rampage':('暴走 · 仅试听','Play_vo_Announcer_Female1_RampageYouYourTeam'),
'unstoppable':('无人能挡 · 仅试听','Play_vo_Announcer_Female1_UnstoppableYouYourTeam'),
'dominating':('主宰比赛 · 仅试听','Play_vo_Announcer_Female1_DominatingYouYourTeam'),
'godlike':('接近神 · 仅试听','Play_vo_Announcer_Female1_GodlikeYouYourTeam'),
'legendary':('超神 · 仅试听','Play_vo_Announcer_Female1_LegendaryYouYourTeam'),
'shutdown':('终结 · 仅试听','Play_vo_Announcer_Female1_ShutdownYouYourTeam'),
'ace_enemy':('敌方团灭 · 仅试听','Play_vo_Announcer_Female1_AceEnemyTeam'),
'ace_ally':('我方团灭 · 仅试听','Play_vo_Announcer_Female1_AceYourTeam'),
'tower_enemy':('敌方防御塔被摧毁 · 仅试听','Play_vo_Announcer_Female1_TurretLostEnemyTeam'),
'tower_ally':('我方防御塔被摧毁 · 仅试听','Play_vo_Announcer_Female1_TurretLostYourTeam'),
'inhibitor':('水晶兵营重生 · 仅试听','Play_vo_Announcer_Female1_InhibitorRespawnYourTeam'),
'disconnect':('友方掉线 · 仅试听','Play_vo_Announcer_Female1_PlayerDisconnectYourTeam'),
'reconnect':('友方重连 · 仅试听','Play_vo_Announcer_Female1_PlayerReconnectYourTeam'),
}
manifest=[];runtime={}
def export(source,event,dest,label,cue):
 dest.parent.mkdir(parents=True,exist_ok=True)
 subprocess.run(['/opt/homebrew/bin/vgmstream-cli','-i','-o',str(dest),str(source)],check=True,stdout=subprocess.DEVNULL)
 with wave.open(str(dest)) as w:d=w.getnframes()/w.getframerate()
 manifest.append({'file':str(dest.relative_to(ROOT)),'event':event,'cue':cue,'label':label,'duration':d,'source_txtp':str(source),'event_id':int(re.search(r'CAkEvent\[\d+\] (\d+)',source.read_text())[1]),'media_ids':re.findall(r'Source (\d+)',source.read_text()),'processing':'Chinese Map11 zh_CN default Female1 or shared spawn SFX; wwiser -gv 0dB; vgmstream-cli -i; no normalization/cut','sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
 return 'res://'+str(dest.relative_to(ROOT))
for cue,(label,event) in SELECT.items():
 files=sorted((LIB/'announcer_review/txtp').glob(event+'*.txtp'))
 if not files:raise RuntimeError('Missing '+event)
 pool=[export(p,event,ROOT/'assets/audio/announcer'/f'{cue}_r{i}.wav',label,cue) for i,p in enumerate(files[:3],1)]
 if cue in ['victory','defeat','minions_spawn']:runtime[cue]={'pool':pool,'volume_db':0.0}
(ROOT/'scripts/data/match_audio.gd').write_text('extends RefCounted\n## 中文默认播报，仅这三种事件进入实战。\nconst EVENTS = '+json.dumps(runtime,ensure_ascii=False,indent='\t')+'\n')
spawn=[]
for i,p in enumerate(sorted((LIB/'minion_spawn_review/txtp').glob('*.txtp')),1):spawn.append(export(p,'Play_sfx_SRU_Spawn_MinionsSpawn_cast',ROOT/'assets/audio/units/minion_shared'/f'spawn_r{i}.wav','小兵生成 · 兵线/部署共用','spawn:start'))
for card in ['melee_minion','ranged_minion','siege_minion','super_minion']:
 p=ROOT/'scripts/data/cards'/f'{card}.gd';s=p.read_text();cue='"spawn:start": '+json.dumps({'pool':spawn,'volume_db':0.0,'bus':'Combat'})
 # Each team override owns its events dictionary, including red siege missile cast.
 if '"spawn:start"' not in s:
  s=s.replace('"attack_hit_by_segment":', '"events": {'+cue+'},\n\t\t\t\t"attack_hit_by_segment":') if card!='siege_minion' else s.replace('"attack_hit_by_segment":','"events": {'+cue+'},\n\t\t\t\t"attack_hit_by_segment":',1)
  if card=='siege_minion':
   idx=s.index('"attack_missile_cast"');start=s.rfind('"events": {',0,idx);s=s[:start]+s[start:].replace('"events": {','"events": {'+cue+',',1)
 p.write_text(s)
(ROOT/'assets/audio/match_event_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Imported',len(manifest),'announcer/spawn samples')
