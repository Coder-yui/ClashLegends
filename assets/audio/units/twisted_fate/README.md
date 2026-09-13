# 卡牌大师音频来源与当前映射

当前运行配置：[audio 域](../../../../scripts/data/cards/twisted_fate.gd)。缺项与验收状态见 [音频覆盖表](../../../../docs/AUDIO_CARD_MAP.md)。

素材来自外部 LoL 原始音库的已选事件，只读提取后归档 WAV；本次整理未从待开发队列迁移音频。保留原事件层叠与源增益，额外裁剪、变速、混音和哈希以清单中的 processing/来源字段为准，不批量归一化。

预部署使用 Gate_marker 原声前 1.75 秒，不压缩、不变速；实际部署总窗口为 1.3 + 0.45 秒，落地不重播。完整 Spell4 声音在独立 auditions 目录，仅供工作台试听。

## 当前事件入口

| 形态/阵营 | 配置的事件与声音池 |
| --- | --- |
| 基础 | `death`、`pre_deploy:start`、`wild_cards:hit`、`wild_cards:release`、`wild_cards:sustain`、`attack_swing`、`attack_hit`、`attack_launch_by_segment`、`attack_hit_by_segment` |

## 源文件与加工证据

- [event_manifest.json](event_manifest.json)：文件/变体、原始事件与加工来源。

早期映射、试听决定及撤回方案见 [历史记录](../../../../docs/archive/2026-09-13/audio/twisted_fate.md)。原始模型和声音属于 Riot 素材，本项目用于学习；离线 WAV 不声称完整复现 Wwise 的实时条件和随机系统。
