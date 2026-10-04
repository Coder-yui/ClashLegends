# 卡牌大师 · 音频接入

> 当前增益基准（2026-10-04）：声音已从原版源事件重新导出，关闭工具 auto；文件制作增益和播放补偿均为 0 dB。裁剪、变速、包络及事件时机保留。本页旧调校段落中的额外 dB、统一制作余量属于重导前记录，已由此基准替代；原事件内部各层增益仍保留。详见[重导交付](../../deliveries/2026-10-04_原版增益音频重导.md)。


[← 返回卡牌大师总览](../twisted_fate.md) · [总索引](../README.md)

## 目前能听到什么

传送声从 1.3 秒准备阶段的起点播放，取原声前 1.75 秒，不改变播放速度，也不在模型出现时再播一次。工作台里额外保留的五组传送候选只供试听。

## 声音与试听

| 发生时机 | 已接变体 | 音量调整 | 试听示例 |
| --- | --- | --- | --- |
| 普通攻击出手 | 14 | 0 dB | [试听 1](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_cast_r1.wav) · [试听 2](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_cast_r2.wav) |
| 普通攻击命中 | 3 | 0 dB | [试听 1](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onhit_r1_d.wav) · [试听 2](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onhit_r2_d.wav) |
| 普通攻击分段命中 | 15 | 0 dB | [试听 1](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_hit_r1.wav) · [试听 2](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_hit_r2.wav) |
| 普通攻击分段发射 | 7 | 0 dB | [试听 1](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_missilelaunch_r1.wav) · [试听 2](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_missilelaunch_r2.wav) |
| 死亡 | 3 | 0 dB | [试听 1](../../../assets/audio/units/twisted_fate/play_vo_twistedfate_death3d_r1_zh_cn.wav) · [试听 2](../../../assets/audio/units/twisted_fate/play_vo_twistedfate_death3d_r2_zh_cn.wav) |
| 传送准备 | 3 | 0 dB | [试听 1](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_gate_marker_r1_first_1_75s.wav) · [试听 2](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_gate_marker_r2_first_1_75s.wav) |
| 万能牌 · 命中 | 1 | 0 dB | [试听 1](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_sealfatemissile_onhit_r.wav) |
| 万能牌 · 发射 | 4 | 0 dB | [试听 1](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_sealfatemissile_onmissilelaunch_r1.wav) · [试听 2](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_sealfatemissile_onmissilelaunch_r2.wav) |
| 万能牌 · 持续过程 | 3 | 0 dB | [试听 1](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_wildcards_oncast_r1.wav) · [试听 2](../../../assets/audio/units/twisted_fate/play_sfx_twistedfate_wildcards_oncast_r2.wav) |

0 dB 表示不额外加减音量，不代表所有原声听起来一样响。表中给出代表性试听，完整原始素材仍保留在来源记录中。

## 使用边界与待补项

传送准备音轨`pre_deploy:start`共1.75秒，覆盖1.3秒出生前传送及0.45秒实体部署。当前由卡牌位置事件播放，没有单位动作所有者；实体出生后受冰冻/凝滞，其尾音仍自然播放。该声音已明确为独立传送结果，允许播完；保持现有声音实现。普通实体部署音的取消规则不能直接套用此轨道。工作台里的其他传送引导声仅供试听，不叠加到正式部署。

## 怎么听

在开发工作台选中对象，先用上面的链接了解素材，再到实战页观察同一动作的出手与命中。持续声音还要检查中断、死亡和清场后是否及时停止；蓝红版本分别检查。

## 素材来源

- [来源与处理记录](../../../assets/audio/units/twisted_fate/README.md)

[← 返回单位总览](../twisted_fate.md)
