# CardDB 与卡牌机制设计

CardDB 是卡牌数值、通用机制参数和表现配置的唯一来源。普通卡牌不创建英雄专属 Unit 脚本；只有现有字段无法表达且规则可复用时才扩展系统。

## 统一 API

- `get_card(card_id)`：未知 id 返回空 Dictionary。
- `has_card(card_id)`：存在性检查。
- `get_unit_stats(card_id)`：同时处理正式卡与系统召唤物 imp。
- `selectable_ids()`：选卡/AI 卡池。
- `active_skills_for(card_id)`：主动候选的深拷贝。
- `validate_all()`：字段、结构、资源和机制校验；完整 mechanics 自动执行。

不要在业务代码散落 `CardDB.all()[card_id]`；`all()` 只适合确实需要遍历全集的工具/界面。

## 类型与必要字段

`type` 只允许 `unit`、`building`、`spell`。所有卡需要 `name/cost/type/description/radius/color`。

单位战斗字段包括 `hp/damage/range/speed/interval/first_hit/size_tier/radius/visual_radius/mass/sight/is_air/building_only/can_attack_air`。七档 `size_tier` 必须与 CardDB 常量半径精确匹配，`visual_radius >= radius`。

建筑另需 `is_building = true`、正数 `footprint_tiles`、`speed = 0`、`lifespan`；召唤建筑可用 `spawn_interval/spawn_count/spawn_side/death_spawn_id/death_spawn_count`。法术的当前通用入口是 `_cast_spell()`；现有 freeze 需要 `duration`，主动强化使用 `active_slow_duration/active_slow_multiplier`。

## 已实现的通用机制字段

- 目标/攻击：`building_only`、`can_attack_air`、`is_continuous_attack`、`splash_radius`、`knockback`。
- 弹体：`projectile_speed`、`projectile_visual`（`orb/arrow/needle/boomerang`）、高度、前向偏移、双方颜色。
- 状态/被动：部署横扫、命中回血、缠流、攻击节奏/伤害倍率、护盾/减速/眩晕、主动 buff。
- 生命周期：部署时间、建筑寿命/周期召唤/亡语召唤。
- 双形态：命中次数、变形/还原时长、完整 `transformed_stats`。
- 表现：`visual_scene_path(s)`、`visual_forward_yaw`、`visual_animations`；这些不能参与权威判定。

主动 `kind` 当前只允许 `nova`、`buff`、`summon`、`dual_form`。新增 kind 必须同时实现权威执行、CardDB validator、必要快照/RPC、UI 描述和回归；不能只写数据。

## 普通卡与特殊机制

普通卡：新增 CardDB 条目，通过 `play_card()` → `_spawn_unit()`，CardArt 自动发现卡面，3D 表现读取路径/动画配置。通常不改 Main/Unit。

特殊机制：先写不依赖英雄名的规则，再在通用系统中实现字段读取；如客户端必须显示或模拟该状态，更新 Snapshot/可靠事件；为领域套件增加断言；最后更新本手册与 validator 字段白名单。禁止 `if card_id == "hero"` 和英雄继承树。

## Validator 覆盖

当前会发现：非法类型/字段、必要战斗字段缺失、体型半径不匹配、弹体速度/类型/颜色错误、资源路径不存在、动画结构/未知键、建筑字段、双形态字段、未知主动 kind/必填项，以及“数据字段存在但没有已知读取方”。新增普通卡应先让 validator 通过，再做实机平衡/表现验收。
