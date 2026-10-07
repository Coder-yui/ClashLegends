# 防御塔 · 音频接入

> 当前增益基准（2026-10-04）：声音已从原版源事件重新导出，关闭工具 auto；文件制作增益和播放补偿均为 0 dB。裁剪、变速、包络及事件时机保留。本页旧调校段落中的额外 dB、统一制作余量属于重导前记录，已由此基准替代；原事件内部各层增益仍保留。详见[重导交付](../../archive/2026-10-07/deliveries/2026-10-04_原版增益音频重导.md)。


[← 返回防御塔总览](../princess_tower.md) · [总索引](../README.md)

## 目前能听到什么

蓝红双方有独立的开火、发射、命中、阶段破损和摧毁声音。阶段破损随生命变化触发，不因反复显示相同模型而重复播放。

## 声音与试听

| 发生时机 | 已接变体 | 音量调整 | 试听示例 |
| --- | --- | --- | --- |
| 红方 · 普通攻击命中 | 4 | 0 dB | [试听 1](../../../assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_hit_r1.wav) · [试听 2](../../../assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_hit_r2.wav) |
| 红方 · 开火起手 | 3 | 0 dB | [试听 1](../../../assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_cast_r1.wav) · [试听 2](../../../assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_cast_r2.wav) |
| 红方 · 炮弹发射 | 4 | 0 dB | [试听 1](../../../assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_missilelaunch_r1.wav) · [试听 2](../../../assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_missilelaunch_r2.wav) |
| 红方 · 第一阶段破损 | 1 | 0 dB | [试听 1](../../../assets/audio/world/chaos/play_sfx_env_chaosturret_break01_r1.wav) |
| 红方 · 第二阶段破损 | 1 | 0 dB | [试听 1](../../../assets/audio/world/chaos/play_sfx_env_chaosturret_break02_r1.wav) |
| 红方 · 死亡 | 1 | 0 dB | [试听 1](../../../assets/audio/world/chaos/play_sfx_env_chaosturret_break03_r1.wav) |
| 蓝方 · 普通攻击命中 | 2 | 0 dB | [试听 1](../../../assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_hit_r1.wav) · [试听 2](../../../assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_hit_r2.wav) |
| 蓝方 · 开火起手 | 3 | 0 dB | [试听 1](../../../assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_cast_r1.wav) · [试听 2](../../../assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_cast_r2.wav) |
| 蓝方 · 炮弹发射 | 3 | 0 dB | [试听 1](../../../assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_missilelaunch_r1.wav) · [试听 2](../../../assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_missilelaunch_r2.wav) |
| 蓝方 · 第一阶段破损 | 1 | 0 dB | [试听 1](../../../assets/audio/world/order/play_sfx_env_orderturret_break01_r1.wav) |
| 蓝方 · 第二阶段破损 | 1 | 0 dB | [试听 1](../../../assets/audio/world/order/play_sfx_env_orderturret_break02_r1.wav) |
| 蓝方 · 死亡 | 1 | 0 dB | [试听 1](../../../assets/audio/world/order/play_sfx_env_orderturret_break03_r1.wav) |

0 dB 表示不额外加减音量，不代表所有原声听起来一样响。表中给出代表性试听，完整原始素材仍保留在来源记录中。

## 使用边界与待补项

没有独立出生声；待机没有额外环境循环声。

## 怎么听

在开发工作台选中对象，先用上面的链接了解素材，再到实战页观察同一动作的出手与命中。持续声音还要检查中断、死亡和清场后是否及时停止；蓝红版本分别检查。

## 素材来源

- [来源与处理记录](../../../assets/audio/event_expansion_manifest.json)

[← 返回单位总览](../princess_tower.md)
