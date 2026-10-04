# 腕豪音频来源与当前映射

> 2026-10-04 原版增益重导：当前文件与加工参数以 `assets/audio/original_gain_manifest.json` 为准；下面历史文字中的额外增益、制作余量及旧哈希说明已被本次重导替代。工具主增益、后期固定增益和事件播放补偿均为 0 dB；原事件内部增益保留。


当前运行配置：[audio 域](../../../../scripts/data/cards/sett.gd)。缺项与验收状态见 [音频覆盖表](../../../../docs/AUDIO_CARD_MAP.md)。

素材来自外部 LoL 原始音库的已选事件，只读提取后归档 WAV；本次整理未从待开发队列迁移音频。保留原事件层叠与源增益，额外裁剪、变速、混音和哈希以清单中的 processing/来源字段为准，不批量归一化。

## 当前事件入口

| 形态/阵营 | 配置的事件与声音池 |
| --- | --- |
| 基础 | `active:hit`、`active:hit_center`、`active:sustain`、`active_strong:hit`、`active_strong:hit_center`、`active_strong:sustain`、`death`、`deploy:start`、`attack_swing`、`attack_hit`、`attack_hit_by_segment` |

## 源文件与加工证据

- [event_manifest.json](event_manifest.json)：文件/变体、原始事件与加工来源。

早期映射、试听决定及撤回方案见 [历史记录](../../../../docs/archive/2026-09-13/audio/sett.md)。原始模型和声音属于 Riot 素材，本项目用于学习；离线 WAV 不声称完整复现 Wwise 的实时条件和随机系统。
