# 聚合脉冲音频

[← 聚合脉冲](../convergent_pulse.md) · [总索引](../README.md)

| 时机 | 原版事件 | 变体 |
| --- | --- | --- |
| 正式施法 | Play_sfx_OrianaDetonateCommand_OnCast | 3 |
| 中心蓄能启动 | Play_sfx_Orianna_OriannaDetonateCommand_buffactivate | 2 |
| 每个成功命中目标 | Play_sfx_Orianna_OriannaDetonateCommand_hit | 3 |

来自Orianna基础皮肤SFX事件银行。wwiser显式-gv=0dB生成，重新解码并保留原事件层叠增益；游戏事件0dB，走Combat公共压缩总线。不加英雄语音，普通与强化共用声音。空放仍播放施法及中心层，未成功命中不播放目标命中声；双方通过可靠卡牌事件播放，暂停与清场沿用公共音频生命周期。

逐变体TXTP、媒体及哈希见 assets/audio/units/convergent_pulse/event_manifest.json。离线事件还原不宣称完整复刻Wwise实时滤波与RTPC。
