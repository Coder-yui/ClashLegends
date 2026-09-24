# 格温音频来源与当前映射

当前运行配置：[audio 域](../../../../scripts/data/cards/gwen.gd)。缺项与验收状态见 [音频覆盖表](../../../../docs/AUDIO_CARD_MAP.md)。

素材来自外部 LoL 原始音库的已选事件，只读提取后归档 WAV；本次整理未从待开发队列迁移音频。保留原事件层叠与源增益，额外裁剪、变速、混音和哈希以清单中的 processing/来源字段为准，不批量归一化。

中剪与终剪使用已核验层叠，中央命中差异随真实判定。

## 当前事件入口

| 形态/阵营 | 配置的事件与声音池 |
| --- | --- |
| 基础 | `deploy:voice`、 `active_0:hit_first`、`active_0:hit_first_center`、`active_0:hit_last`、`active_0:hit_last_center`、`active_0:sustain`、`active_1:hit_first`、`active_1:hit_first_center`、`active_1:hit_last`、`active_1:hit_last_center`、`active_1:hit_middle`、`active_1:hit_middle_center`、`active_1:sustain`、`active_2:hit_first`、`active_2:hit_first_center`、`active_2:hit_last`、`active_2:hit_last_center`、`active_2:hit_middle`、`active_2:hit_middle_center`、`active_2:sustain`、`active_3:hit_first`、`active_3:hit_first_center`、`active_3:hit_last`、`active_3:hit_last_center`、`active_3:hit_middle`、`active_3:hit_middle_center`、`active_3:sustain`、`death`、`resource_full`、`attack_swing`、`attack_hit`、`attack_hit_by_segment` |

## 源文件与加工证据

- [event_manifest.json](event_manifest.json)：文件/变体、原始事件与加工来源。

部署时从英雄专属锁定音效、“你要找裁缝吗？”、“剪刀飞快”中等权随机播放一个，避免连续重复；仅接入部署事件，不在行走或普攻时另播这些台词。

新增来源：共享原始库中的中文英雄 WAD、客户端 game-data 选择语音及专属锁定音效；只读提取，未使用网站音频作为运行资源。具体台词、单变体媒体 ID、哈希及校验依据见清单。

早期映射、试听决定及撤回方案见 [历史记录](../../../../docs/archive/2026-09-13/audio/gwen.md)。原始模型和声音属于 Riot 素材，本项目用于学习；离线 WAV 不声称完整复现 Wwise 的实时条件和随机系统。

## 丝缕缠流（2026-09-22）

W施放来自原动画表Spell2的SoundEvent；激活/环境层来自原W_buffactivate事件（含原随机激活层及延迟0.1秒环境层），按本技能4秒截取，不额外归一化；结束使用W_buffdeactivate。原始BNK、TXTP和未裁剪WAV留在本地素材库；哈希及路径见event_manifest新增记录。结界固定音轨独立于Spell2动作取消；未实现LoL搬移、本人/其他玩家专用混音及全部随机分支，不声称原版完整运行时混音复现。
