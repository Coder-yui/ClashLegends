# 太阳圆盘音频来源与当前映射

当前运行配置：[audio 域](../../../../scripts/data/cards/sun_disc.gd)。缺项与验收状态见 [音频覆盖表](../../../../docs/AUDIO_CARD_MAP.md)。

素材来自外部 LoL 原始音库的已选事件，只读提取后归档 WAV；本次整理未从待开发队列迁移音频。保留原事件层叠与源增益，额外裁剪、变速、混音和哈希以清单中的 processing/来源字段为准，不批量归一化。

日耀庇护只配置 shield:cast，不配置获盾声。生成音前段适配部署，普攻三层保留额外 −6 dB；消失音为原始前两秒以 atempo=4/3 压至 1.5 秒，不套普通单位死亡包络。

## 当前事件入口

| 形态/阵营 | 配置的事件与声音池 |
| --- | --- |
| 基础 | `attack_launch`、`death`、`deploy:start`、`shield:cast`、`attack_swing`、`attack_hit` |

## 源文件与加工证据

- [building_event_manifest.json](building_event_manifest.json)：文件/变体、原始事件与加工来源。
- [event_expansion_manifest.json](event_expansion_manifest.json)：文件/变体、原始事件与加工来源。

早期映射、试听决定及撤回方案见 [历史记录](../../../../docs/archive/2026-09-13/audio/sun_disc.md)。原始模型和声音属于 Riot 素材，本项目用于学习；离线 WAV 不声称完整复现 Wwise 的实时条件和随机系统。
