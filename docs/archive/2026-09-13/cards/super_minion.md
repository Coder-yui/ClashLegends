> 整理前快照，归档于 2026-09-13；含已被后续段落替代的数值与判断。当前入口见 [卡牌手册](../../../units/super_minion.md)。

# 超级兵（`super_minion`）

当前定义：[`scripts/data/cards/super_minion.gd`](../../../../scripts/data/cards/super_minion.gd)，使用 gameplay / visual / card_art / audio 四域；通用接入与验收见 [卡牌设计](../../../CARD_DESIGN.md)。

## 1. 属性数据

| 属性 | 数值 |
| --- | --- |
| 类型 / 费用 / 可选 | 单位 / 4 / 是（显式配置） |
| 描述 | 强化型近战单位，生命和伤害更高，适合在一路形成突破。 |
| 生命值 / 普攻伤害 / 攻击距离 | 720 / 72 / 28 |
| 移速 | 60 px/s（中） |
| 攻击间隔 / 首次命中 | 1.15 s / 0.38 s |
| 体型 / 权威半径 / 表现半径 | 中 / 18 / 22.5 |
| 质量 / 视野 | 6 / 200 |
| 空中单位 / 仅攻击建筑 / 可攻击空中 | 否 / 否 / 否 |
| 部署时间 | 1.0 s（默认值） |
| 弹体 / 溅射 / 击退 | 无 / 0 / 0 |
| 阵营颜色 | `Color(0.52, 0.55, 0.62)` |

## 2. 被动

无独立被动字段。超级兵通过更高生命值、伤害和质量承担前排突破职责。

## 3. 主动技能

**男爵之力**（`kind = buff`）

- 当前主动技能数值：消耗 `2` 金币；每个超级兵最多使用 `1` 次；每次使用后冷却 `7.0 s`。
- 持续 `5.0 s`，移速倍率 `1.35`，伤害倍率 `1.35`。
- 同时获得 `140` 点护盾，护盾持续 `5.0 s`；护盾吸收伤害后才会减少生命值。
- 无施法窗口、无延迟和主动专属动画，效果立即生效。

## 4. 使用的动画

- 双阵营场景：`res://assets/units/super_minion/super_minion_order_view.tscn`、`res://assets/units/super_minion/super_minion_chaos_view.tscn`；数组顺序为 Order/蓝方、Chaos/红方；`visual_forward_yaw = 0`。
- 部署 / 待机 / 移动：`Idle1` / `Idle1` / `Run`。
- 普攻：`Attack1`、`Attack2`。
- 死亡：`Death_Base`，表现时长 `0.5 s`。
- `男爵之力`没有 `visual_action`，使用逻辑 Buff 与护盾表现。

## 音频接入（2026-09-11）

本轮保持静音，缺口与原因已记录。完整动作对照、来源、自动验证及待人工试听项见 [全卡音频对照](../../../AUDIO_CARD_MAP.md)。本轮不改变既有 2D / 3D / 卡面状态；音频来自外部 LoL 原始库只读提取，未移动待开发队列素材。

## 2026-09-12 原始动画表复核

已核对蓝红SRU原表，Attack1/2与Death_Base对应；共同死亡入口使用零混合，0.5秒时长保留。

来源、行号与保留理由见 [兵线与建筑对照](../research/animation_group_buildings_minions.md)。

## 2026-09-13 事件音频补充

普攻出手与实际命中已按 Order/Chaos 两个音库分别接入，分段与两段攻击动画对齐；来源保存 team/serial，死后在途弹体仍播放原阵营、原攻击段音效。独立出生、死亡与未核实的发射事件暂未接入，不配置替代音。

音频映射与剩余项见 [事件接入记录](../research/event_audio_expansion.md)。资源导入及完整 mechanics 回归通过，实际运行已录音；最终响度与尾音听感待人工复听。

共享生成音已接入 spawn:start：兵线和手牌部署共用三个原版 SRU_Spawn_MinionsSpawn_cast 变体，双阵营一致、首次挂接去重。详见 ../research/match_announcer_audio.md。

## 2026-09-13 男爵之力粒子适配

主动统一改名为“男爵之力”，保留原费用、次数和冷却；近战兵/超级兵保留已有增益，远程兵/炮车兵从瞬时范围技能改为短时增益。具体数值见上表，属于本项目适配，并非复刻 LoL 数值。

`visual_active_buff_scene` 使用 `res://assets/effects/baron_minion/super_minion.tscn`，改用小兵专用身体覆层、受击反馈与对应持续粒子，炮车兵另接原始强化炮弹出膛/飞行/命中。只消费权威或 Snapshot 的 Buff 状态，不改变模型缩放、权威半径、命中时序。

素材来自外部 LOL 原始库只读提取，不涉及待开发队列迁移；原配置、贴图哈希、复现范围与验收见 [男爵特效记录](../../../../assets/effects/baron_minion/README.md)。强化 start/sustain/end 音效仍未确认，暂未接入，不用其他技能声音替代。普通攻击及部署音沿用现有配置。
