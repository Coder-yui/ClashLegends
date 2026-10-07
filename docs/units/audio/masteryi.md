# 剑圣 · 音频接入

> 当前增益基准（2026-10-04）：声音已从原版源事件重新导出，关闭工具 auto；文件制作增益和播放补偿均为 0 dB。裁剪、变速、包络及事件时机保留。本页旧调校段落中的额外 dB、统一制作余量属于重导前记录，已由此基准替代；原事件内部各层增益仍保留。详见[重导交付](../../archive/2026-10-07/deliveries/2026-10-04_原版增益音频重导.md)。


[← 返回剑圣总览](../masteryi.md) · [总索引](../README.md)

## 当前配置与触发入口

下表记录当前声音配置及预期触发节点，试听链接用于查看素材；不代表本次已逐项实机试听。实际触发、取消与听感分别验收，共通边界见[声音合同](../../status/PRESENTATION.md#音频按声音归属取消不能按整个单位静音)。

## 声音与试听

| 发生时机 | 已接变体 | 音量调整 | 试听示例 |
| --- | --- | --- | --- |
| 普通攻击出手 | 12 | 0 dB | [试听 1](../../../assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack2_oncast_r1.wav) · [试听 2](../../../assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack2_oncast_r2.wav) |
| 普通攻击命中 | 16 | 0 dB | [试听 1](../../../assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r1_d.wav) · [试听 2](../../../assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r2_d.wav) |
| 普通攻击分段命中 | 17 | 0 dB | [试听 1](../../../assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r1_d.wav) · [试听 2](../../../assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r2_d.wav) |
| 增益结束 | 1 | 0 dB | [试听 1](../../../assets/audio/units/masteryi/play_sfx_masteryi_highlander_onbuffdeactivate.wav) |
| 增益开始 | 1 | 0 dB | [试听 1](../../../assets/audio/units/masteryi/play_sfx_masteryi_highlander_onbuffactivate.wav) |
| 增益持续 | 1 | 0 dB | [试听 1](../../../assets/audio/units/masteryi/play_sfx_masteryi_highlander_trail.wav) |
| 死亡 | 1 | 0 dB | [试听 1](../../../assets/audio/units/masteryi/play_sfx_masteryi_death3d_cast.wav) |
| 部署语音 | 1 | 0 dB | [Play_vo_MasterYi_Attack2DGeneral](../../../assets/audio/units/masteryi/play_vo_masteryi_attack2dgeneral_r2_en_us.wav) |

0 dB 表示不额外加减音量，不代表所有原声听起来一样响。表中给出代表性试听，完整原始素材仍保留在来源记录中。

## 使用边界与待补项

部署动画为 `Respawn`，使用原始 `Play_vo_MasterYi_Attack2DGeneral` 事件的一段未压缩渲染。

## 怎么听

在开发工作台选中对象，先用上面的链接了解素材，再到实战页观察同一动作的出手与命中。持续声音还要检查中断、死亡和清场后是否及时停止；蓝红版本分别检查。

## 素材来源

- [来源与处理记录](../../../assets/audio/units/masteryi/README.md)

[← 返回单位总览](../masteryi.md)
