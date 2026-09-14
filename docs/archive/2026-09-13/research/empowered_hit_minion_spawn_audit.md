# 盖伦、提莫强化命中与兵线生成音复核

> 阶段记录，归档于 2026-09-13。下文保留当时的判断和修订过程；当前实现以逐卡定义、卡牌手册及 [开发状态](../../../DEV_PLAN.md) 为准。

2026-09-13，当前本机基础皮肤/共享音库；本轮未修改实战配置。

## 盖伦

基础事件清单含 GarenQAttack_OnCast、GarenQ_OnCast、Q Buff 起止，没有找到独立 GarenQAttack_OnHit / GarenQ_OnHit。当前 empowered_swing 已使用 Play_sfx_Garen_GarenQAttack_OnCast，并非普通挥击。该事件为两组随机音层：第一组 −16 dB，第二组 −18 dB 且延迟 0.23 秒，已完整保留。第二组媒体与所查普通命中池不同；仅据该延迟不能把它武断定义为独立真实命中事件。

项目 Q 攻击文件与已解码的原版完整组合文件逐字节相同；真实命中仍复用普通命中池。结论：保持现有配置，不再额外加一个假定的 Q hit，更不使用 R 或暴击代替。这是对当前基础素材的结论，不断言所有皮肤/历史版本都无独立事件。

来源：/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/garen_base_audio/wwnames.txt 与 txtp/Play_sfx_Garen_GarenQAttack_OnCast {r}.txtp；项目 scripts/data/cards/garen.gd。

## 提莫

原版确有独立 Play_sfx_Teemo_TeemoQ_OnHit，事件 ID 4091846019，媒体 41272196 / 63286599，两个变体，源事件增益 −16 dB。

项目 empowered_hit 已指向两个 teemoq_onhit WAV，并且 GameAudioManager.play_attack_source 在 empowered=true 时优先使用此池；不是普通命中回退。两文件 SHA-256 与来源 manifest 一致。结论：已经按原版配置，无需改。

来源：card_audio_batch/teemo/txtp/Play_sfx_Teemo_TeemoQ_OnHit {r1/r2}.txtp；项目 teemo.gd 与 assets/audio/units/teemo/event_manifest.json。

## 兵线生成

找到 Play_sfx_SRU_Spawn_MinionsSpawn_cast（ShortID 546694519），来自共享 npc_global_minions_sfx 音库；Common 地图事件清单明确列出同名 Play/Stop。三个变体的可达媒体为 691552716 / 716449542 / 146970335，源事件增益 −25 dB。

它是兵线生成 SFX，可作为小兵部署的共用候选，不是四种兵各自的专属出生声。另有 Play_vo_Announcer_@voice@_MinionSpawn 播报，未拿播报代替部署音。

重新用 wwiser -gv 0dB 生成 TXTP，关闭自动 master 音量补偿；vgmstream 解码为原增益 WAV，未归一化、未截短。已导出以下三个可听样例，暂未接入游戏：

- [变体 1 · 1.764 秒](</Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/minion_spawn_review/Play_sfx_SRU_Spawn_MinionsSpawn_cast {r1}.wav>)
- [变体 2 · 1.634 秒](</Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/minion_spawn_review/Play_sfx_SRU_Spawn_MinionsSpawn_cast {r2}.wav>)
- [变体 3 · 1.906 秒](</Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/minion_spawn_review/Play_sfx_SRU_Spawn_MinionsSpawn_cast {r3}.wav>)

来源证据：/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/02-候选讨论/音频/来源批次/missing_audio_review/common.rito 第 2853 / 2866 行；生成清单和哈希在 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/minion_spawn_review/manifest.json。此前“没找到小兵出生素材”的范围结论由此次找到共享兵线生成事件补充，不再列为完全缺素材。
