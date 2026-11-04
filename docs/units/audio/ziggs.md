# 爆破鬼才：声音

[返回单位](../ziggs.md) · [返回总索引](../README.md)

| 时机 | 原版事件 |
| --- | --- |
| 部署 | 客户端115号英雄中文选人语音（1.98秒） |
| 两套普攻起手 | ZiggsBasicAttack / ZiggsBasicAttack2 OnCast，各3变体 |
| 两套普攻发射 | 对应OnMissileLaunch，各3变体 |
| 普攻落地爆炸 | ZiggsBasicAttack OnHit，3变体，每次落地一次 |
| 强化起手 | ZiggsQ OnCast，3变体 |
| 第一跳发射 | ZiggsQSpell OnMissileLaunch，3变体 |
| 后续两跳发射 | ZiggsQSpell2 / ZiggsQSpell3 OnMissileLaunch，各1变体 |
| 强化待发建立 | ZiggsShortFuse OnBuffActivate，3变体；仍有强化次数时刷新不重复触发 |
| 强化落地爆炸 | ZiggsQ hit，3变体，每次落地一次，不按受伤人数叠加 |
| 死亡 | Death3D cast音效与中文Death3D语音（3变体） |

技能开启时播放原版被动待发获得音，Q起手与发射声音仍随接下来的投掷发生。行走不接声音；没有借用其他技能替代事件。原始事件增益保持0dB额外补偿；死亡超过1.5秒时保留前1.5秒，最后0.5秒线性淡出。相同PCM合并文件，保留两套动作各自映射和来源。正式27个WAV、1个OGG，事件池不超过3个变体。

在途声音以出手时卡牌与阵营归属派发；爆炸声由真实落地事件触发，即使落点无人也有地面爆炸声；它不表示敌人受伤，不再另播逐目标命中声。暂停、清场由统一音频系统管理。声音文件、TXTP、媒体编号与处理见[来源清单](../../../assets/audio/units/ziggs/event_manifest.json)。实际录音与验收范围见[交付记录](../../deliveries/2026-11-03_爆破鬼才新卡.md)。
