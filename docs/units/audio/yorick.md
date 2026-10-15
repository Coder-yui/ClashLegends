# 牧魂人音频

[返回牧魂人](../yorick.md) · [总索引](../README.md)

| 时机 | 原版来源与行为 |
| --- | --- |
| 部署 | 中文客户端83号英雄选人语音，原OGG，播放补偿-8dB |
| 普攻出手 | BasicAttack与BasicAttack2的OnCast，第三动作复用基础事件 |
| 普攻命中 | 对应OnHit，仅真实命中触发 |
| Q武装 | YorickQ_OnCast；QBuff_OnBuffActivate持续声跟随武装状态，出手/死亡/清场停止 |
| Q挥击 / 命中 | YorickQAttack_OnCast / YorickQAttack_hit |
| 死亡 | 仅Base_death音效；不播放death:voice |

每个独立随机池最多三个变体。wwiser显式-gv=0dB，重新解码保留事件内部增益；死亡音效超过1.5秒保留前1秒、末0.5秒线性淡出。事件映射与源哈希见assets/audio/units/yorick/event_manifest.json。

不播放未实现的召唤、W/E/R，也不播放走路声。素材、运行触发和最终人工听感分开验收；本次运行检查见[制作记录](../../deliveries/2026-10-15_牧魂人卡牌制作.md)。
