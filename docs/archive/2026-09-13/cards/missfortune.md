> 整理前快照，归档于 2026-09-13；含已被后续段落替代的数值与判断。当前入口见 [卡牌手册](../../../units/missfortune.md)。

# 赏金猎人（`missfortune`）

当前定义：[`scripts/data/cards/missfortune.gd`](../../../../scripts/data/cards/missfortune.gd)，使用 gameplay / visual / card_art / audio 四域；通用接入与验收见 [卡牌设计](../../../CARD_DESIGN.md)。

## 1. 属性数据

| 属性 | 数值 |
| --- | --- |
| 类型 / 费用 / 可选 | 单位 / 3 / 是 |
| 描述 | 远程双枪射手，对每个敌方目标的首次攻击造成1.5倍伤害；主动技大步流星可短时提升移速与攻速。 |
| 生命值 / 普攻伤害 | 380 / 62 |
| 攻击距离 | 165 |
| 移速 | 60 px/s（中） |
| 攻击间隔 / 首次命中 | 0.95 s / 0.12 s |
| 体型 / 权威半径 / 表现半径 | 中 / 18 / 22.5 |
| 质量 / 视野 | 3 / 230 |
| 空中单位 / 仅攻击建筑 / 可攻击空中 | 否 / 否 / 是 |
| 部署时间 | 1.0 s（默认值） |
| 弹体 | 500 px/s，`orb`；表现高度 52 |
| 溅射 / 击退 | 0 / 0 |
| 阵营颜色 | `Color(0.80, 0.35, 0.60)` |

费用和伤害是本次接入采用的初始平衡值，后续只需修改 `scripts/data/card_db.gd`。

## 2. 被动

### 先声夺人（`first_strike_damage_multiplier = 1.5`）

- 对每个敌方目标（单位、建筑、塔均适用）的首次普通攻击造成 `1.5` 倍伤害（62 → 93）。
- 由攻击者按目标逐一记录已命中集合：同一目标后续攻击恢复基础伤害；击杀后更换新目标时，新目标重新享受首击倍率。
- 远程弹体在出手 tick 固化该次伤害，倍率与弹体一同飞行；换目标不重置其他目标的记录。
- 卡牌详情页被动栏显示为"先声夺人"。

## 3. 主动技能：大步流星

**大步流星**（`kind = buff`）

- 当前主动技能数值：消耗 `0` 金币；每个赏金猎人最多使用 `1` 次；每次使用后冷却 `5.0 s`。
- 立即结算（`impact_delay = 0`，无施法窗口、无主动专属动作、无施法锁定）。
- 持续 `3.0 s`：移速倍率 `1.5`（60 → 90 px/s），攻速倍率 `1.3`（攻击间隔倍率约为 `10/13`），伤害倍率 `1.0`（伤害数值保持基础值）。
- 生效期间移动表现由通用 `haste_move` 机制切换为 `Run2`，攻击动画播放速度实时跟随攻速倍率；技能结束自动恢复。
- 按钮在部署完成后可用；点击后与出牌共用 `0.5 s` Command Buffer，再由权威 Cast Start 立即生效并扣除使用次数。

## 4. 美术素材

- 正式包装场景：`res://assets/units/missfortune/missfortune_view.tscn`。
- 源素材已从 `待开发卡牌美术素材/赏金猎人.glb` 移动到 `assets/units/missfortune/source/missfortune.glb`，因此待开发队列少一个素材。
- 使用动画：部署 `Respawn`，待机 `Idle1_Base`，普通移动 `Run`，加速移动 `Run2`，普攻 `Attack1`/`Attack2` 循环，死亡 `Death`（表现时长 `0.8 s`）。
- `Attack1/2` 的出手点在动作前段（约 12% 处），`first_hit = 0.12 s` 按此调校；具体命中仍由固定 20Hz 权威模拟结算，动画不驱动伤害。
- 卡面：`res://assets/cards/missfortune_loading.jpg`，来自官方 Data Dragon 的基础皮肤加载图：<https://ddragon.leagueoflegends.com/cdn/img/champion/loading/MissFortune_0.jpg>。

## 5. 音频

- 状态：已接入当前玩法实际使用的普攻、远程离弦、真实命中、被动首次攻击完整音效链、LOL W“大步流星”和死亡事件；死亡长语音暂保留，后续单独处理。
- CardDB 配置：`scripts/data/card_db.gd` 的 `missfortune.audio`。
- 映射真相来源：[赏金猎人音频说明](../../../../assets/audio/units/missfortune/README.md)；白名单文件与原始事件/媒体映射见同目录 `event_manifest.json`。
- W 技能按 `MissFortuneViciousStrikes_OnCast` → `active_buff:start`、`OnBuffActivate` → `active_buff:sustain`、`OnBuffDeactivate` → `active_buff:end` 接入；持续层由通用单位音频生命周期在 Buff 结束、死亡或销毁时停止。
- 被动“先声夺人”按 `MissFortunePassiveAttack_OnCast` → `OnMissileCast` → `OnMissileLaunch` → `OnHit` + `OnHitLocation` 接入；攻击表现序号开始时就确定首击变体，命中尾段仍只在权威伤害结算成功后播放，并通过快照/RPC同步客户端。
- 首击弹体携带纯表现 `first_strike` 标记，绘制为紫色弹体外包一层橙红火光；火光不改变弹体半径、飞行速度、射程或命中判定。
- 普攻 `BasicAttack2_OnHit` 与 `BasicAttack_OnHit` 使用同一套事件图和候选媒体，因此由共享 `attack_hit` 池消费，不重复导入一份相同素材。
- 素材来源：原皮 SFX 来自 `MissFortune.wad.client`；死亡语音来自 `MissFortune.zh_CN.wad.client`。原包仅在项目外解析，项目内只保留 52 份已选 WAV；被动各阶段保留两个已验证的自然变体，命中位置层为单一事件。
- 导入：`python3 tools/audio/import_missfortune_audio.py`。素材仅供学习原型使用，其他用途需核实相应权限。
- 验证：`Godot --headless --path . --script tests/mechanics_check.gd` 全部通过；F5 场景启动无错误；`Godot --path . --script tools/demos/missfortune_audio_demo.gd` 实际触发普攻、离弦、命中、W 起手/持续/结束和死亡事件，并生成 `/tmp/clash_missfortune_audio.wav`。

## 音频接入（2026-09-11）

保留当前已接音频，见 [音频映射](../../../../assets/audio/units/missfortune/README.md)。完整动作对照、来源、自动验证及待人工试听项见 [全卡音频对照](../../../AUDIO_CARD_MAP.md)。本轮不改变既有 2D / 3D / 卡面状态；音频来自外部 LoL 原始库只读提取，未移动待开发队列素材。

## 原始动画表核对（2026-09-12）

普通 Run 对应原图 Run_Base；原图根据 MissFortuneStrutMax Buff 在 Run_Base/Run2 间切换，与项目的 haste_move 选择一致。新增 `Run/Run2 → Idle_In → Idle1_Base` 的停步收势，收势可被新普攻或移动打断，不增加任何移动/攻击锁定。原表未明确当前两种普攻之间的特殊混合，不把未使用 Crit/Spell1 的边套入普攻。部署 1 秒、死亡 0.8 秒及大步流星时序均保持。新增 Idle_In 无原表音频事件，当前音效入口不变。证据与待验清单见 [远程组审查](../research/animation_group_ranged.md)。

2026-09-13 全面音频复核：[逐项结果与验证](../research/hero_audio_completeness_audit.md)。当前可明确对应的普攻/被动/已接技能缺项已补入；不引入原版未实现技能或未经确认的条件音。
