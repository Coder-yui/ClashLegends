# 盖伦音频来源与当前映射

当前运行配置：[audio 域](../../../../scripts/data/cards/garen.gd)。缺项与验收状态见 [音频覆盖表](../../../../docs/AUDIO_CARD_MAP.md)。

素材来自外部 LoL 原始音库的已选事件，只读提取后归档 WAV；本次整理未从待开发队列迁移音频。保留原事件层叠与源增益，额外裁剪、变速、混音和哈希以清单中的 processing/来源字段为准，不批量归一化。

## 当前事件入口

| 形态/阵营 | 配置的事件与声音池 |
| --- | --- |
| 基础 | `deploy:voice`、 `death`、`empowered_buff:end`、`empowered_buff:start`、`empowered_ready`、`empowered_swing`、`judgment:end`、`judgment:hit`、`judgment:start`、`judgment:sustain`、`attack_swing`、`attack_hit` |

## 源文件与加工证据

- [event_manifest.json](event_manifest.json)：文件/变体、原始事件与加工来源。

部署时从“人在塔在”“勇往直前”“保家卫国”中等权随机播放一个，避免连续重复；仅接入部署事件，不在行走或普攻时另播这些台词。

新增来源：共享原始库中的中文英雄 WAD、客户端 game-data 选择语音及专属锁定音效；只读提取，未使用网站音频作为运行资源。具体台词、单变体媒体 ID、哈希及校验依据见清单。

早期映射、试听决定及撤回方案见 [历史记录](../../../../docs/archive/2026-09-13/audio/garen.md)。原始模型和声音属于 Riot 素材，本项目用于学习；离线 WAV 不声称完整复现 Wwise 的实时条件和随机系统。
