# CardDB 与卡牌机制设计

CardDB 是卡牌、系统召唤物、防御塔/水晶的权威数值与表现配置的唯一来源。普通卡牌不创建英雄专属 Unit 脚本；只有现有字段无法表达且规则可复用时才扩展系统。

## 统一 API

- `get_card(card_id)`：未知 id 返回空 Dictionary。
- `has_card(card_id)`：存在性检查。
- `get_unit_stats(card_id)`：只返回可生成的单位/建筑；系统召唤物用 `selectable = false` 留在同一数据表。
- `selectable_ids()`：选卡/AI 卡池。
- `active_skills_for(card_id)`：主动候选的深拷贝。
- `validate_all()`：字段、结构、资源和机制校验；完整 mechanics 自动执行。

不要在业务代码散落 `CardDB.all()[card_id]`；`all()` 只适合确实需要遍历全集的工具/界面。

## 类型与必要字段

`type` 只允许 `unit`、`building`、`spell`。所有卡需要 `name/cost/type/description/radius/color`。

单位战斗字段包括 `hp/damage/range/speed/interval/first_hit/size_tier/radius/visual_radius/mass/sight/is_air/building_only/can_attack_air`。七档 `size_tier` 必须与 CardDB 常量半径精确匹配，`visual_radius >= radius`。

建筑另需 `is_building = true`、正数 `footprint_tiles`、`speed = 0`、`lifespan`。`footprint_tiles` 只负责下牌格占用；实际移动寻路、绕行和防穿模统一使用 `radius` 定义的圆柱碰撞，两者不得互相反推。`lifespan_hp_decay = true` 时按 `max_hp / lifespan` 在固定模拟中匀速扣减生命，寿命结束时恰好归零，且自然衰减不算受击。`tower_ruin_foundation = true` 允许建筑中心落在已毁公主塔九格中的任意一格；其占地擦到但中心未落在塔墟时仍非法，主机固化这次部署的塔墟状态并取消该实例的寿命与衰减。周期召唤使用 `spawn_id/spawn_interval/spawn_count/spawn_side`，亡语召唤使用 `death_spawn_id/death_spawn_count`。召唤引用会在启动前校验。

法术必须声明 `spell_kind`。当前支持 `freeze`，其权威执行集中在 `SpellSystem`；需要新法术语义时先在该系统实现并登记 kind，未知 kind 会被 Validator 和 `play_card()` 拒绝，不会扣费后静默失效。

## 已实现的通用机制字段

- 目标/攻击：`building_only`、`can_attack_air`、`is_continuous_attack`、`splash_radius`、`knockback`、`first_strike_damage_multiplier`（对每个敌方目标的首次普通攻击伤害倍率）。
- 弹体：`projectile_speed`、`projectile_visual`（`orb/arrow/needle/boomerang/ice_cone`）、高度、前向偏移、双方颜色。
- 状态/被动：部署横扫、命中回血、缠流、攻击节奏/伤害倍率、延迟追加刀、技能资源、强化下一次普攻、攻击次数致盲、护盾/减速/眩晕、主动 buff。
- 生命周期：部署时间、建筑寿命/周期召唤/亡语召唤；`death_replacement_id/death_replacement_charges` 可在单位死亡时按剩余次数生成替身，替身可用 `timed_revival_id/timed_revival_delay` 声明固定模拟时长后的满血复生；`timed_revival_death_replacement_charges` 可覆盖复生单位的死亡替身次数。`death_replacement_visual_transition` 与 `timed_revival_visual_transition` 只控制替身/复生的通用表现过渡（当前支持 `drop`、`rebirth`），不参与权威位置、碰撞或生命结算。
- 编队部署：单位卡可用 `deployment_count / deployment_spacing` 让一次落点与一个部署读条展开为确定性中心/环形编队；每名成员仍是独立 `Unit`。
- 双形态：命中次数、变形/还原时长、完整 `transformed_stats`。
- 表现：`visual_scene_path(s)`、`visual_forward_yaw`、`visual_animations`；这些不能参与权威判定。单位动画采用 locomotion + action 通道，专用转场和全局混合规则详见 `ANIMATION_STATE_SYSTEM.md`。

主动 `kind` 当前允许 `nova`、`buff`、`summon`、`dual_form`、`frontal`、`forward_area`、`continuous_area`、`empowered_attack`、`attack_lifesteal`、`area_shield`。`area_shield` 以施法者表面距离选择半径内所有存活友方战斗对象，可覆盖地面、空中、建筑、自身、防御塔与水晶；护盾优先承受外部伤害，但限时建筑的自然寿命衰减仍直接扣除生命，生命归零时不会被护盾延命。`frontal` 可用 `fan` 或 `trapezoid` 表达锁定朝向的扇形/梯形命中；等宽的 `trapezoid` 可表达一次命中路径上所有敌人的穿透弹，`projectile_visual = laser` 仅绘制对应的飞行表现，不参与权威命中。`fan` 的外缘按圆弧半径判定，`center_width` 可在其中声明恒定宽度的中央强化长条，未配置时仍可用 `center_ratio` 表达按角度缩放的小扇区。`forward_area` 在锁定方向的前方圆形区域结算，并可排定固定模拟扩散的冲击波，`shockwave_full_only` 可将冲击波限定为满资源升级形态；若声明 `zone_duration/zone_tick_interval/zone_damage`，则会在技能落点创建与施法者解绑的固定区域，并按固定模拟脉冲读取可选减速字段；`continuous_area` 不保存固定落点，每个固定模拟脉冲都以施法者当前权威位置为中心，适合边移动边持续造成范围伤害；`empowered_attack` 只强化原攻击时间线中的下一次普攻，不重置攻速或另起攻击动作；`attack_lifesteal` 在此后每次真实普攻命中时按该击伤害与 `heal_ratio` 回复生命，持续到单位死亡，`max_health_ratio` 决定允许的溢出上限。主动默认只作用于持有者，`target_scope = deployment_group` 时作用于同一次卡牌部署中仍存活的编队成员，持有者死亡后技能资格转交同编队存活成员。再次部署会替换主动槽资格，但不会清除旧编队已经获得的持续效果。每个单位/建筑主动技能都配置 `cost`、`max_uses`、`cooldown`：命令进入 Host 的 Command Buffer 时扣除当前技能金币，技能在权威 Cast Start 时扣除一次使用次数并开始 CD；这些状态属于场上该技能实例，重新下卡生成新实例后重置。各张卡的具体数值由 CardDB 当前条目和对应卡牌文档记录。技能资格、Command Buffer 与 Cast/Impact 时间线由 Main 编排，Gameplay Impact 集中在 `ActiveSkillEffectSystem`。冰冻是法术卡特例，放在主动槽即启用强化效果，额外技能花费为 `0`，次数随该张卡的一次施放计算，不进入单位主动技能实例。新增 kind 必须同时实现权威效果、CardDB validator、必要快照/RPC、UI 描述和领域回归；不能只写数据。技能可提供纯表现用 `description`，避免 UI 出现英雄名分支。

`skill_resource_*` 只声明潜在规则；单位必须由主动槽实际携带 `uses_skill_resource` 的技能才启用、显示和积攒资源，同槽出现新单位时立即关闭。资源可按受伤、出手、真实命中或击杀敌方单位积攒；`skill_resource_decay_delay` 与 `skill_resource_decay_rate` 表示脱离这些战斗活动后的延迟和每秒衰减。技能在 Cast Start 固化层数/倍率并清空当前资源，释放后仍保留携带状态并可为下一次技能重新积攒，保证普通/满层动作选择与最终伤害来自同一快照。`resource_shield_max` 可把资源比例映射为护盾，`shield_on_cast_start` 让护盾在施法起始立即获得；配合 `shield_decay` 与 `shield_duration` 可表达持续衰减护盾。`skill_resource_full_color` 指定资源满层时的填充颜色；最大值为 2～10 的整数时，资源条按层分段显示，其余资源使用连续进度。`blind_charges` 随强化攻击命中写入目标，目标随后对应次数的普通攻击仍推进动作和冷却，但不产生伤害或命中特效。

一段动作需要多次普通攻击判定时，使用与攻击段对齐的 `attack_extra_hit_damage_multipliers / attack_extra_hit_delays`。每一刀都由固定模拟延迟结算并独立消费致盲，动画结束事件不能触发第二刀。

带施法窗口的主动可配置 `cast_duration`、`impact_delay`、`visual_action` 与 `cast_locks`。`cast_duration` 是 Cast Start 到 Cast End 的权威窗口，`impact_delay` 是 Cast Start 到 Gameplay Impact 的权威延迟，未写时为 0；`impact_delay` 必须满足 `0 <= impact_delay <= cast_duration`。locks 可独立包含 `movement / attack / facing`；未写时默认三项全锁，空数组表示不限制基础行为。使用全身 `visual_action` 时必须包含 `attack`，不能让权威普攻被全身动作遮住。Gameplay lock 不由动画推导，impact 时刻仍由固定模拟实现。

资源层数需要改变完整动作链时，可用 `resource_visual_actions` 为 0～满层逐档选择表现动作；同一次技能需要多次独立命中时，用等长的 `resource_hit_damage_sequences / resource_hit_delay_sequences` 为每档声明逐次伤害与相对 Cast Start 的固定时刻。满层结束回血使用 `full_resource_cast_end_heal`，由 Cast End 固定模拟结算，不读取动画完成事件。

## 普通卡与特殊机制

普通卡：新增 CardDB 条目，通过 `play_card()` → `_spawn_unit()`，CardArt 自动发现卡面，3D 表现读取路径/动画配置。通用机制字段由 Unit 和 Battle 系统读取。

特殊机制：先写不依赖英雄名的规则，再在通用系统中实现字段读取；如客户端必须显示或模拟该状态，更新 Snapshot/可靠事件；为领域套件增加断言；最后更新本手册与 validator 字段白名单。禁止 `if card_id == "hero"` 和英雄继承树。

## Validator 覆盖

当前会发现：非法类型/字段、必要战斗字段缺失、体型半径不匹配、弹体速度/类型/颜色错误、资源路径不存在、动画结构/未知键、建筑字段、未知法术 kind、失效召唤引用、双形态字段、未知主动 kind/必填项、主动动作映射、动作数组时长、施法时间关系和全身动作锁约束。

完整 mechanics 还会对全部单位/建筑/双形态统一实例化包装场景，检查真实动画名，并检查所有可选卡的自动卡面发现。普通卡使用通用场景/动画契约；特殊机制或特殊动画链在对应领域套件中增加断言。
