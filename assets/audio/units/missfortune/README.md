# 赏金猎人音频来源与当前映射

当前运行配置：[audio 域](../../../../scripts/data/cards/missfortune.gd)。缺项与验收状态见 [音频覆盖表](../../../../docs/AUDIO_CARD_MAP.md)。

素材来自外部 LoL 原始音库的已选事件，只读提取后归档 WAV；本次整理未从待开发队列迁移音频。保留原事件层叠与源增益，额外裁剪、变速、混音和哈希以清单中的 processing/来源字段为准，不批量归一化。

## 当前事件入口

| 形态/阵营 | 配置的事件与声音池 |
| --- | --- |
| 基础 | `active_buff:end`、`active_buff:start`、`active_buff:sustain`、`attack_launch`、`attack_missile_cast`、`death`、`first_strike:cast`、`first_strike:hit_location`、`first_strike:missile_cast`、`first_strike:missile_launch`、`attack_swing`、`attack_hit`、`first_strike_hit` |

## 源文件与加工证据

- [event_manifest.json](event_manifest.json)：文件/变体、原始事件与加工来源。

早期映射、试听决定及撤回方案见 [历史记录](../../../../docs/archive/2026-09-13/audio/missfortune.md)。原始模型和声音属于 Riot 素材，本项目用于学习；离线 WAV 不声称完整复现 Wwise 的实时条件和随机系统。
