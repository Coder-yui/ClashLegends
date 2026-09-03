# 卡牌文档

本目录记录 `CardDB.all()` 当前登记的正式卡牌。数值以
[`scripts/data/card_db.gd`](../../scripts/data/card_db.gd) 为准；本目录只做可读归档，不能替代运行时数据。

## 卡牌清单

| card_id | 名称 | 类型 | 费用 | 文档 |
| --- | --- | --- | ---: | --- |
| `garen` | 盖伦 | 单位 | 5 | [garen.md](garen.md) |
| `xin` | 赵信 | 单位 | 4 | [xin.md](xin.md) |
| `ashe` | 艾希 | 单位 | 3 | [ashe.md](ashe.md) |
| `teemo` | 提莫 | 单位 | 2 | [teemo.md](teemo.md) |
| `gnar` | 纳尔 | 单位 | 4 | [gnar.md](gnar.md) |
| `melee_minion` | 近战兵 | 单位 | 1 | [melee_minion.md](melee_minion.md) |
| `ranged_minion` | 远程兵 | 单位 | 1 | [ranged_minion.md](ranged_minion.md) |
| `siege_minion` | 炮车兵 | 单位 | 3 | [siege_minion.md](siege_minion.md) |
| `super_minion` | 超级兵 | 单位 | 4 | [super_minion.md](super_minion.md) |
| `freeze` | 冰冻 | 法术 | 3 | [freeze.md](freeze.md) |
| `masteryi` | 剑圣 | 单位 | 3 | [masteryi.md](masteryi.md) |
| `gwen` | 格温 | 单位 | 4 | [gwen.md](gwen.md) |
| `sett` | 腕豪 | 单位 | 4 | [sett.md](sett.md) |
| `tombstone` | 墓碑 | 建筑 | 3 | [tombstone.md](tombstone.md) |
| `aurelionsol` | 龙王 | 单位 | 4 | [aurelionsol.md](aurelionsol.md) |
| `twisted_fate` | 卡牌大师 | 单位 | 4 | [twisted_fate.md](twisted_fate.md) |

共 16 张可选卡，当前均可进入选卡池。`imp`（小鬼）也登记在 `CardDB`，但通过 `selectable = false` 明确标记为墓碑使用的系统召唤物，不会进入选卡池；其数据和动画见 [imp.md](imp.md)。

各张卡的主动技能金币消耗、使用次数和冷却时间以 `CardDB` 当前条目及对应卡牌文档为准。冰冻是法术卡特例：放在主动槽时直接启用强化冰冻，强化额外花费为 `0`，次数随该张法术卡本次施放计算。

## 字段与动画约定

- 距离使用战场像素，时间使用秒，伤害/生命值使用数值点数。
- 移速同时列出 CardDB 原始值和七档名称；攻击间隔是两次普通攻击命中之间的权威模拟间隔，`first_hit` 是从攻击开始到首个命中节点的时间。
- `radius` 是权威碰撞、部署、寻路和攻击距离使用的半径；`visual_radius` 只影响表现占位、队伍圈和状态提示。
- 动画名保留素材 `AnimationPlayer` 中的原名。数组按顺序播放；`attack_hit`、`attack_recover`、`transitions` 等是攻击动作的后续或转场映射。
- `impact_delay` 是主动技能从 Cast Start 到 Gameplay Impact 的权威延迟，`cast_duration` 是施法锁定窗口。动画结束回调不负责伤害、移动、碰撞或状态结算。
- 文档所说“无主动专属动画”，表示该卡没有配置 `visual_animations.visual_actions`；技能仍可由纯逻辑效果或攻击通道的既有动画表现。
- 每个单位/建筑主动技能配置金币消耗、单个单位的最大使用次数和冷却时间；主动槽按钮显示当前金币与次数，冷却中的按钮显示剩余冷却。冰冻的强化效果直接跟随卡牌施放，不生成单位主动按钮。
- 主动槽按钮在携带技能的单位完成部署后可用；点击后进入 `10` Tick（`0.5 s`）Command Buffer，再开始技能自身的 Cast 时间线。文档中的“立即结算”表示 Cast Start 后 `impact_delay = 0`。
- 备战界面前两个卡位标记为主动位；对战手牌中的金色符印跟随对应 `card_id`，卡牌轮换时继续标记主动位卡牌。卡牌信息页展示主动技能的金币消耗和单个单位的使用次数。

## 当前动画混合策略

全局默认混合时间来自 `UnitModel3D`：`action_in = 0.08 s`、`action_out = 0.14 s`、`sequence = 0.04 s`、`locomotion = 0.10 s`、`death = 0.10 s`、`model_swap = 0.02 s`。`attack` 配置键的默认值为 `0.06 s`，普通攻击入口使用 `action_in`。卡牌的专用 `transitions` 和按段 `attack_to_move` 片段以 `sequence` 进入和离开；没有专用转场片段的动作使用对应的全局 `action_out` 或 `locomotion`。
