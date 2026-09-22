# 龙王 · 音频接入

[← 返回龙王总览](../aurelionsol.md) · [总索引](../README.md)

## 目前能听到什么

吐息有起始、持续与结束声音。普通星落与天瀑各有起手、过程和落地；只有天瀑有扩散波命中声音。原版未实现的技能声音不应混入。

## 声音与试听

| 发生时机 | 已接变体 | 音量调整 | 试听示例 |
| --- | --- | --- | --- |
| 部署（`Respawn3D`） | 1 | 0 dB | [试听](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_respawn3d_buffactivate.wav) |
| 星落/天瀑 · 落地 | 3 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolrmissile_hit_r1.wav) · [试听 2](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolrmissile_hit_r2.wav) |
| 星落/天瀑 · 起手 | 1 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolrmissile_missilelaunch.wav) |
| 星落/天瀑 · 持续过程 | 1 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr_oncast.wav) |
| 满层 / 强化版：星落/天瀑 · 落地 | 1 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr2missile_hit_super_s.wav) |
| 满层 / 强化版：星落/天瀑 · 起手 | 1 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr2missile_missilelaunch_super.wav) |
| 满层 / 强化版：星落/天瀑 · 持续过程 | 1 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr2_oncast.wav) |
| 满层 / 强化版：星落/天瀑 · 扩散波命中 | 3 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr_hit_shockwave_r1.wav) · [试听 2](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr_hit_shockwave_r2.wav) |
| 吐息结束 | 3 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_buffdeactivate_r1.wav) · [试听 2](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_buffdeactivate_r2.wav) |
| 吐息释放 | 3 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_missilecast_r1.wav) · [试听 2](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_missilecast_r2.wav) |
| 吐息开始 | 1 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_oncast.wav) |
| 吐息持续 | 1 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_missilelaunch.wav) |
| 死亡 | 3 | 0 dB | [试听 1](../../../assets/audio/units/aurelionsol/play_vo_aurelionsol_death3d_r1_zh_cn.wav) · [试听 2](../../../assets/audio/units/aurelionsol/play_vo_aurelionsol_death3d_r2_zh_cn.wav) |

0 dB 表示不额外加减音量，不代表所有原声听起来一样响。表中给出代表性试听，完整原始素材仍保留在来源记录中。

## 使用边界与待补项

部署音使用 LoL 原始 `Play_sfx_AurelionSol_Respawn3D_buffactivate`；本项目没有原版吐息蓄满爆发机制，因此不播放对应爆发声音。

## 怎么听

在开发工作台选中对象，先用上面的链接了解素材，再到实战页观察同一动作的出手与命中。持续声音还要检查中断、死亡和清场后是否及时停止；蓝红版本分别检查。

## 素材来源

- [来源与处理记录](../../../assets/audio/units/aurelionsol/README.md)

[← 返回单位总览](../aurelionsol.md)

星辰飞出声在权威创建时播放，归属独立结果；本体冻结或死亡不切断。施法本体持续声仍随技能动作取消，落地与冲击波命中声由独立结果触发。
