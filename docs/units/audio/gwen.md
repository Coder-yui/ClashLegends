# 格温 · 音频接入

[← 返回格温总览](../gwen.md) · [总索引](../README.md)

## 目前能听到什么

各充能层数共用剪切类别：起剪、中间剪、终剪，以及中央命中的加强声音。只有实际命中才播放命中声，不能因预览动作重复而叠加。

## 声音与试听

| 发生时机 | 已接变体 | 音量调整 | 试听示例 |
| --- | --- | --- | --- |
| 部署 | 3 | 0 dB | [英雄锁定音效](../../../assets/audio/units/gwen/champion_lockin_sfx_887.wav) · [你要找裁缝吗？](../../../assets/audio/units/gwen/play_vo_gwen_attack2dgeneral_r17_zh_cn.wav) · [剪刀飞快](../../../assets/audio/units/gwen/play_vo_gwen_attack2dgeneral_r20_zh_cn.wav) |
| 普通攻击出手 | 6 | -3 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_cast_r1.wav) · [试听 2](../../../assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_cast_r2.wav) |
| 普通攻击命中 | 3 | -5 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r1.wav) · [试听 2](../../../assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r2.wav) |
| 普通攻击分段命中 | 6 | -5 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_hit_r1.wav) · [试听 2](../../../assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_hit_r2.wav) |
| 快刀乱剪 · 起剪命中 | 3 | 0 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav) · [试听 2](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav) |
| 快刀乱剪 · 起剪中央命中 | 3 | 3 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav) · [试听 2](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav) |
| 快刀乱剪 · 终剪命中 | 3 | 0 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r1.wav) · [试听 2](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r2.wav) |
| 快刀乱剪 · 终剪中央命中 | 1 | 0 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_center_r.wav) |
| 快刀乱剪 · 持续过程 | 4 | 0 dB | [试听 1](../../../assets/audio/units/gwen/gwen_q_active_0.wav) · [试听 2](../../../assets/audio/units/gwen/gwen_q_active_1.wav) |
| 快刀乱剪 · 中间剪命中 | 3 | 0 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r1.wav) · [试听 2](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r2.wav) |
| 快刀乱剪 · 中间剪中央命中 | 3 | 3 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r1.wav) · [试听 2](../../../assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r2.wav) |
| 死亡 | 3 | 0 dB | [试听 1](../../../assets/audio/units/gwen/play_vo_gwen_death3d_r1_zh_cn.wav) · [试听 2](../../../assets/audio/units/gwen/play_vo_gwen_death3d_r2_zh_cn.wav) |
| 充能已满 | 3 | 0 dB | [试听 1](../../../assets/audio/units/gwen/play_sfx_gwen_gwenq_max_stacks_buffactivate_r1.wav) · [试听 2](../../../assets/audio/units/gwen/play_sfx_gwen_gwenq_max_stacks_buffactivate_r2.wav) |

0 dB 表示不额外加减音量，不代表所有原声听起来一样响。表中给出代表性试听，完整原始素材仍保留在来源记录中。

## 使用边界与待补项

部署时从英雄专属锁定音效、“你要找裁缝吗？”、“剪刀飞快”中等权随机播放一个，避免连续重复；仅接入部署事件，不在行走或普攻时另播这些台词。被动附加伤害与满层回血没有单独加一层声音，跟随普攻和剪切播放。

## 怎么听

在开发工作台选中对象，先用上面的链接了解素材，再到实战页观察同一动作的出手与命中。持续声音还要检查中断、死亡和清场后是否及时停止；蓝红版本分别检查。

## 素材来源

- [来源与处理记录](../../../assets/audio/units/gwen/README.md)

[← 返回单位总览](../gwen.md)

## 丝缕缠流

- `Spell2`开始随机播放原版 `Play_sfx_Gwen_GwenW_cast` 的3个已提取变体之一。
- 结界建立播放原版 `GwenW_buffactivate` 的激活/环境层叠，选用前4秒、保留原始增益。声音固定在结界中心，独立于施法动作；圈内行走、眩晕和冰冻不停止结界音。
- 自然到期或格温出圈停止持续音，并播放原版 `GwenW_buffdeactivate` 的2个变体之一；死亡、清场、退出对局清理持续音。
- 没有接入原版移动结界、二次施法搬移或穿越边界提示音，因为本技能没有搬移机制。当前混音需用户确认听感，实机播放与生命周期验证见本次交付。
