# 灵魂触手 · 音频

[← 返回灵魂触手](../soul_tentacle.md) · [总索引](../README.md)

| 动作 | 原版事件 |
| --- | --- |
| 出生 | IllaoiTentacleSpawn_buffactivate |
| 起手 | IllaoiTentacleAttack_OnBuffCast |
| 拍地，包括拍空 | IllaoiTentacleAttack_Ground_Hit |
| 实际命中 | IllaoiTentacleAttack_minion_hit |
| 强化开始 | IllaoiTentacleActive_OnBuffCast |

从原始Illaoi基础皮肤音频银行重新解码，wwiser主增益0dB，不归一化、不裁剪。每个事件最多3个随机变体；命中目前统一使用原版小兵命中事件，不按目标类型分配英雄命中变体。未找到已确认的独立触手死亡音效，保持静音；不加入俄洛伊本体语音，也不借用英雄R重击音。强化持续与结束音未接入，不能视为已复现原版完整状态音。

实战录音已生成供试听；主观听感未获用户确认。来源、媒体及哈希见[事件清单](../../../assets/audio/units/soul_tentacle/event_manifest.json)。
