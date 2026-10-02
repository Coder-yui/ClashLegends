# 麦林炮手声音

[返回麦林炮手](../tristana.md) · [总索引](../README.md)

| 发生时机 | 当前声音 |
| --- | --- |
| 普攻真实发射 | 原版TristanaBasicAttack_OnMissileLaunch，3个随机变体 |
| 普攻真实命中 | 原版TristanaBasicAttack_OnHit；落空不发声 |
| 急速射击开始 | 原版TristanaQ_OnCast，3个变体 |
| 急速射击结束 | 原版TristanaQ_OnBuffDeactivate |
| 死亡 | 原版中文Death3D，3个变体；沿用统一死亡淡出 |
| 部署语音 | 随机播放“交火咯。”“预备，瞄准，射。”“碰不到我。”其中一句，Voice总线 |
| 移动 / 独立前摇 / Q持续底噪 | 有意静音；发射已提供炮声，未强加循环音 |

声音事件只消费权威或快照状态，不驱动射击。暂停与清场由通用声音管理器处理。素材文件、事件ID、源TXTP、处理及哈希见[音频资源清单](../../../assets/audio/units/tristana/event_manifest.json)。实战录音与主观试听状态见交付报告，事件触发不等于听感验收。
