# 虚空兽声音

[返回虚空兽](../void_spawn.md) · [音频流程](../../AUDIO_INTEGRATION.md)

使用本地 Map12.wad.client 中的 NPC_Global_VoidSpawn_SFX_audio/events.bnk。旧皮肤声明带 Jade_ 前缀，已通过Wwise事件ID核对到银行内无Jade_前缀的实际事件，不按文件名猜测。

| 时机 | 原版事件 | 变体数 |
| --- | --- | --- |
| 部署 | Play_sfx_S5_VoidSpawn_spawn_cast 第一变体 | 1 |
| 技能施放 | Play_sfx_S5_VoidSpawn_spawn_cast 第二变体，项目用途重分配 | 1 |
| 普通被杀 | Play_sfx_S5_VoidSpawnDeath_cast | 2 |
| 牺牲起跳 | Play_sfx_S5_VoidSpawnTowerBreak_spin | 3 |
| 固定落点爆炸 | Play_sfx_S5_VoidSpawnTowerBreak_OnHit | 2 |

起跳当刻播放spin，不叠加普通死亡声；0.8秒后OnHit爆炸声跟随独立结果，即使来源已释放或没有目标受伤也播放。出生和普通死亡沿用通用单位表现生命周期；起跳和落地复用可靠卡牌事件。清场不补播取消的爆炸。

wwiser显式主增益0dB、后期与游戏播放补偿0dB，保留原事件层增益；44.1kHz单声道，不逐文件归一化。先浮点解码再转PCM16，普通死亡按通用规范保留1.5秒，末0.5秒线性淡出。9个片段的来源、事件ID、TXTP和输出哈希见 assets/audio/units/void_spawn/event_manifest.json。

本卡不接普攻、走路声或部署语音。幽灵疾步音频已撤下；虚空强化使用出生第二变体，通过active:cast每次技能播放一次，不按成员重复派发。
