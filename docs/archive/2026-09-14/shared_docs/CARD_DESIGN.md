> 2026-09-14 整理前快照，可能含已纠正的说明。当前入口见 [文档首页](../../../README.md)。

# CardDB 与卡牌机制设计

CardDB 是卡牌、系统召唤物、防御塔/水晶的权威数值与表现配置的唯一来源。普通卡牌不创建英雄专属 Unit 脚本；只有现有字段无法表达且规则可复用时才扩展系统。

## 定义、共享数据与运行状态

每张卡只维护 `scripts/data/cards/<card_id>.gd`，`definition()` 返回 `gameplay`、`visual`、`card_art` 和可选 `audio` 四域。在 `CardDB.DEFINITIONS` 添加一条 preload 即注册，原有字段名不变；CardDB 在第一次查询时合并并递归冻结字典/数组，此后 `all/get_card/get_unit_stats/has_card` 不重建库。`active_skills_for` 只复制该卡候选技能，给出战实例使用。

```gdscript
extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
    return {
        "gameplay": { # 必填战斗字段及复用机制，参照现有同类型卡
        },
        "visual": { # visual_scene_path(s)、visual_forward_yaw、visual_animations
        },
        "card_art": {}, # 默认自动发现；指定图时用 {"path": "res://..."}
        # "audio": {...}, # 只配置已存在且当前机制实际派发的声音
    }
```

`transformed_stats` 保留原有完整形态字典格式；模型和声音共同通过 `PresentationConfig.for_form` 选择，不能各写回退规则。共享定义不是 Unit 运行状态：Unit 持有 ControlState、AttackTimeline 和技能/生命/目标等实例状态；需改测试数据或部署覆盖时只复制该卡，不能写入缓存或每次查询复制整库。

字段白名单/常量在 `card_schema.gd`，校验在 `card_validator.gd`，统一调用 `CardDB.validate_all()`。新字段必须能在对应系统找到读取方。`tests/suites/maintenance_suite.gd` 的四域夹具证明定义、现有包装/动画、卡面和可选死亡音可一起接入，不注册额外正式卡牌。完整场景契约遍历所有注册卡，无须为复用卡增加 Main/Unit/动画/音频的英雄分支。

## 统一 API

- `get_card(card_id)`：未知 id 返回空 Dictionary。
- `has_card(card_id)`：存在性检查。
- `get_unit_stats(card_id)`：只返回可生成的单位/建筑；系统召唤物用 `selectable = false` 留在同一数据表。
- `selectable_ids()`：选卡/AI 卡池。
- `active_skills_for(card_id)`：主动候选的深拷贝。
- `validate_all()`：字段、结构、资源和机制校验；完整 mechanics 自动执行。

卡牌属性、被动与主动说明的纯展示转换在 `scripts/ui/card_details.gd`，DeckBuilder 只负责控件与选项状态；新增机制需要展示时更新该读取方或技能 description，不在 UI 复制一份卡牌数值。

不要在业务代码散落 `CardDB.all()[card_id]`；`all()` 只适合确实需要遍历全集的工具/界面。

## 类型与必要字段

`type` 只允许 `unit`、`building`、`spell`。所有卡需要 `name/cost/type/description/radius/color`。

单位战斗字段包括 `hp/damage/range/speed/interval/first_hit/size_tier/radius/visual_radius/mass/sight/is_air/building_only/can_attack_air`。七档 `size_tier` 必须与 CardDB 常量半径精确匹配，`visual_radius >= radius`。

建筑另需 `is_building = true`、正数 `footprint_tiles`、`speed = 0`、`lifespan`。`footprint_tiles` 只负责下牌格占用；实际移动寻路、绕行和防穿模统一使用 `radius` 定义的圆柱碰撞，两者不得互相反推。`lifespan_hp_decay = true` 时按 `max_hp / lifespan` 在固定模拟中匀速扣减生命，寿命结束时恰好归零，且自然衰减不算受击。`tower_ruin_foundation = true` 允许建筑中心落在已毁公主塔九格中的任意一格；其占地擦到但中心未落在塔墟时仍非法，主机固化这次部署的塔墟状态并取消该实例的寿命与衰减。周期召唤使用 `spawn_id/spawn_interval/spawn_count/spawn_side`，亡语召唤使用 `death_spawn_id/death_spawn_count`。召唤引用会在启动前校验。

法术必须声明 `spell_kind`。当前支持 `freeze`、`heal`，其权威执行集中在 `SpellSystem`；需要新法术语义时先在该系统实现并登记 kind，未知 kind 会被 Validator 和 `play_card()` 拒绝，不会扣费后静默失效。

## 已实现的通用机制字段

- 目标/攻击：`building_only`、`can_attack_air`、`is_continuous_attack`、`splash_radius`、`knockback`、`first_strike_damage_multiplier`（对每个敌方目标的首次普通攻击伤害倍率）。
- 弹体：`projectile_speed`、`projectile_visual`（`orb/arrow/needle/boomerang/ice_cone`）、高度、前向偏移、双方颜色。
- 状态/被动：部署横扫、命中回血、缠流、攻击节奏/伤害倍率、延迟追加刀、技能资源、强化下一次普攻、攻击次数致盲、护盾/减速/眩晕、主动 buff。
- 生命周期：部署时间、建筑寿命/周期召唤/亡语召唤；`death_replacement_id/death_replacement_charges` 可在单位死亡时按剩余次数生成替身，替身可用 `timed_revival_id/timed_revival_delay` 声明固定模拟时长后的满血复生；`timed_revival_death_replacement_charges` 可覆盖复生单位的死亡替身次数。`death_replacement_visual_transition` 与 `timed_revival_visual_transition` 只控制替身/复生的通用表现过渡（当前支持 `drop`、`rebirth`），不参与权威位置、碰撞或生命结算。
- 编队部署：单位卡可用 `deployment_count / deployment_spacing` 让一次落点与一个部署读条展开为确定性中心/环形编队；每名成员仍是独立 `Unit`。
- 双形态：命中次数、变形/还原时长、完整 `transformed_stats`。
- 表现：`visual_scene_path(s)`、`visual_forward_yaw`、`visual_animations`；这些不能参与权威判定。单位动画采用 locomotion + action 通道，专用转场和全局混合规则详见 `ANIMATION_STATE_SYSTEM.md`。
- 音频表现：`audio` 的攻击分段声音池、共享命中池及 `events`；由 GameAudioManager 读取，不参与权威判定。字段契约、真实触发范围、素材归档与验收见 `AUDIO_INTEGRATION.md`；不要把 validator 接受的事件名等同于所有技能都已实现发声入口。

主动 `kind` 当前允许 `nova`、`buff`、`summon`、`dual_form`、`frontal`、`forward_area`、`continuous_area`、`empowered_attack`、`attack_lifesteal`、`area_shield`。`area_shield` 以施法者表面距离选择半径内所有存活友方战斗对象，可覆盖地面、空中、建筑、自身、防御塔与水晶；护盾优先承受外部伤害，但限时建筑的自然寿命衰减仍直接扣除生命，生命归零时不会被护盾延命。`frontal` 可用 `fan` 或 `trapezoid` 表达锁定朝向的扇形/梯形命中；等宽的 `trapezoid` 可表达一次命中路径上所有敌人的穿透弹，`projectile_visual = laser` 仅绘制对应的飞行表现，不参与权威命中。`fan` 的外缘按圆弧半径判定，`center_width` 可在其中声明恒定宽度的中央强化长条，未配置时仍可用 `center_ratio` 表达按角度缩放的小扇区。`forward_area` 在锁定方向的前方圆形区域结算，并可排定固定模拟扩散的冲击波，`shockwave_full_only` 可将冲击波限定为满资源升级形态；若声明 `zone_duration/zone_tick_interval/zone_damage`，则会在技能落点创建与施法者解绑的固定区域，并按固定模拟脉冲读取可选减速字段；`continuous_area` 不保存固定落点，每个固定模拟脉冲都以施法者当前权威位置为中心，适合边移动边持续造成范围伤害；`empowered_attack` 只强化原攻击时间线中的下一次普攻，不重置攻速或另起攻击动作；`attack_lifesteal` 在此后每次真实普攻命中时按该击实际扣除的生命与 `heal_ratio` 回复生命（不含护盾吸收和过量伤害），持续到单位死亡，`max_health_ratio` 决定允许的溢出上限。主动默认只作用于持有者，`target_scope = deployment_group` 时作用于同一次卡牌部署中仍存活的编队成员，持有者死亡后技能资格转交同编队存活成员。再次部署会替换主动槽资格，但不会清除旧编队已经获得的持续效果。每个单位/建筑主动技能都配置 `cost`、`max_uses`、`cooldown`：命令进入 Host 的 Command Buffer 时扣除当前技能金币，技能在权威 Cast Start 时扣除一次使用次数并开始 CD；这些状态属于场上该技能实例，重新下卡生成新实例后重置。各张卡的具体数值由 CardDB 当前条目和对应卡牌文档记录。技能资格由 Main 校验，CommandSchedule 持有 Command Buffer 与 Cast/Impact 队列，Main 按 Tick 编排，Gameplay Impact 集中在 `ActiveSkillEffectSystem`。冰冻是法术卡特例，放在主动槽即启用强化效果，额外技能花费为 `0`，次数随该张卡的一次施放计算，不进入单位主动技能实例。治疗术是另一例法术强化：放在主动槽时启用强化治疗，额外技能花费为 `1`（即施放费用 +1，由 `active_cost_bonus` 声明），普通治疗只回复范围内友军单位且不作用于建筑，强化后全图友军单位按倍率回复并为范围内友军（含建筑卡、防御塔、水晶）添加护盾。新增 kind 必须同时实现权威效果、CardDB validator、必要快照/RPC、UI 描述和领域回归；不能只写数据。技能可提供纯表现用 `description`，避免 UI 出现英雄名分支。

`skill_resource_*` 只声明潜在规则；单位必须由主动槽实际携带 `uses_skill_resource` 的技能才启用、显示和积攒资源，同槽出现新单位时立即关闭。资源可按受伤、出手、真实命中或击杀敌方单位积攒；`skill_resource_decay_delay` 与 `skill_resource_decay_rate` 表示脱离这些战斗活动后的延迟和每秒衰减。技能在 Cast Start 固化层数/倍率并清空当前资源，释放后仍保留携带状态并可为下一次技能重新积攒，保证普通/满层动作选择与最终伤害来自同一快照。`resource_shield_max` 可把资源比例映射为护盾，`shield_on_cast_start` 让护盾在施法起始立即获得；配合 `shield_decay` 与 `shield_duration` 可表达持续衰减护盾。`skill_resource_full_color` 指定资源满层时的填充颜色；最大值为 2～10 的整数时，资源条按层分段显示，其余资源使用连续进度。`blind_charges` 随强化攻击命中写入目标，目标随后对应次数的普通攻击仍推进动作和冷却，但不产生伤害或命中特效。

一段动作需要多次普通攻击判定时，使用与攻击段对齐的 `attack_extra_hit_damage_multipliers / attack_extra_hit_delays`。每一刀都由固定模拟延迟结算并独立消费致盲，动画结束事件不能触发第二刀。

带施法窗口的主动可配置 `cast_duration`、`impact_delay`、`visual_action` 与 `cast_locks`。`cast_duration` 是 Cast Start 到 Cast End 的权威窗口，`impact_delay` 是 Cast Start 到 Gameplay Impact 的权威延迟，未写时为 0；`impact_delay` 必须满足 `0 <= impact_delay <= cast_duration`。locks 可独立包含 `movement / attack / facing`；未写时默认三项全锁，空数组表示不限制基础行为。使用全身 `visual_action` 时必须包含 `attack`，不能让权威普攻被全身动作遮住。Gameplay lock 不由动画推导，impact 时刻仍由固定模拟实现。

资源层数需要改变完整动作链时，可用 `resource_visual_actions` 为 0～满层逐档选择表现动作；同一次技能需要多次独立命中时，用等长的 `resource_hit_damage_sequences / resource_hit_delay_sequences` 为每档声明逐次伤害与相对 Cast Start 的固定时刻。满层结束回血使用 `full_resource_cast_end_heal`，由 Cast End 固定模拟结算，不读取动画完成事件。直接范围命中的 frontal 可声明 `cast_end_heal_requires_hit`，用同次施法独占 CastHitState 记录成功命中，任一剪命中才允许结束回血，空放或免疫不计入。

## 普通卡与特殊机制

普通卡：新增逐卡四域定义与注册项，通过 `play_card()` → `_spawn_unit()`，CardArt 自动发现卡面，3D 表现读取路径/动画配置。通用机制字段由 Unit 和 Battle 系统读取。

整卡交付按 `AGENT_WORKFLOW.md` 的四项制作阶段及联合验收执行；模型、卡面完成后还需检查音频。已有通用音频事件通常只需加素材与 CardDB.audio；缺少事件消费者时才按 `AUDIO_INTEGRATION.md` 扩展通用表现入口与测试。

特殊机制：先写不依赖英雄名的规则，再在通用系统中实现字段读取；如客户端必须显示或模拟该状态，更新 Snapshot/可靠事件；为领域套件增加断言；最后更新本手册与 validator 字段白名单。禁止 `if card_id == "hero"` 和英雄继承树。

## Validator 覆盖

当前会发现：非法类型/字段、必要战斗字段缺失、体型半径不匹配、弹体速度/类型/颜色错误、资源路径不存在、动画结构/未知键、建筑字段、未知法术 kind、失效召唤引用、双形态字段、未知主动 kind/必填项、主动动作映射、动作数组时长、施法时间关系和全身动作锁约束。

完整 mechanics 还会对全部单位/建筑/双形态统一实例化包装场景，检查真实动画名，并检查所有可选卡的自动卡面发现。普通卡使用通用场景/动画契约；特殊机制或特殊动画链在对应领域套件中增加断言。

音频 validator 检查声音池结构、攻击段数量、资源存在且为 AudioStream、事件字段/动作名及音量类型。它通过 PresentationEvents 核对已实现的机制派发能力，但不验证听感、声音中断效果或每个技能候选是否已经试听；这些按音频专项验收补齐。

`frontal/fan` 可选 `projectile_stop_on_hit = true`：要求正数 projectile_count、length、projectile_flight_duration，离弦时生成独立直线弹体，速度为 length / projectile_flight_duration。每箭命中首个敌方身体即消失，同次施法每目标最多一次伤害/附带效果；前排即使已受过该次伤害仍阻挡其他箭。默认 false 的其他扇形继续沿用范围结算。技能箭使用 counts_as_attack=false，不触发普攻命中收益；沿用现有弹体快照。

扇形主动的 `projectile_piercing: true` 启用真实穿透弹体，与 `projectile_stop_on_hit` 互斥；必须有正数 projectile_count / length / projectile_flight_duration。impact_delay 负责权威发射排程，弹体碰撞决定伤害，projectile_launch_delay 为表现时序参数，应与发射排程保持一致。一次施法共享受击目标集合，穿透不重复伤害同一目标；客户端只重放弹体快照与命中声音。

显式指定非标准碰撞半径时可设置 `gameplay.custom_radius = true`；`radius` 仍是唯一权威半径，必须满足原有正数校验，`size_tier` 保留档位标签。未声明时仍校验七档规范半径。冰鸟按用户要求使用 20 像素（0.5 格），不修改其他单位规范值。

## 生命、伤害与小数规则（2026-09-13）

完整分类、结算顺序、持续效果、吸血与全卡基准表见 [数值体系](../../../NUMERIC_SYSTEM.md)。数量字段由 schema 的 INTEGER_NUMBER_FIELDS 和 validator 约束；玩法时间最多两位小数，比例按百分数最多两位（12.50% 内部为 0.125）。动画原始裁剪点、音频排程和模拟累计余量保留精度。

生命、伤害、治疗、护盾的实际值始终为整数；兼容现有 API 的 float 容器只承载整数值。基础伤害的倍率算完后四舍五入，独立附加被动另行取整后相加。`on_hit_max_health_ratio` 对普通对象使用目标最大生命比例，`on_hit_tower_damage` 对防御塔/水晶使用固定值；基础强化不放大这个被动。直接命中的 frontal 可用 `applies_on_hit_passive` 逐次附带被动。

吸血只使用真实命中结果的 `health_lost`，不含护盾吸收和过量伤害；符合资格的附加被动包含在实际掉血中。范围吸血尚未设计，范围命中收益不传入虚构的单次伤害作为吸血基数。

龙王 `is_continuous_attack` 的 damage 单位为 DPS，按每来源/每目标累计余量后结算整数；55 DPS 连续有效命中一秒扣55，不再逐Tick独立取整成60。区域技能的 damage / zone_damage 则是每次脉冲伤害。建筑生命与衰减护盾同样保留累计余量；寿命归零强制结束，护盾不能延长建筑寿命。

万能牌这类穿透扇形弹体的范围提示使用 `projectile_fan` 表现形状，直接共用 ProjectileSystem 的弹道夹角、起点半径与长度，显示三条 6px 宽的弹体扫掠路径。它不代表两路径之间的区域也能命中；目标体型仍参与碰撞。沿用现有范围 RPC 字段，非穿透扇形提示保持原样。

## 持续 Buff 3D 表现

`visual.visual_active_buff_scene` 为可选 PackedScene 路径，其根必须继承 `ActiveBuffVisual3D`。由 `BattlePresentation3D` 传给 `UnitModel3D`，接口 `configure(visual_radius)` / `advance(active, delta)` 只读取权威或快照的 active_buff 状态。可提供 ShaderMaterial 身体覆盖层，与受击/冰冻材质串联，Buff 到期或死亡时清理；模型换形时重新实例化。该字段经过场景类型/接口校验，领域回归检查启停和材质恢复。首个实例是四种小兵共用的男爵之力。

远程单位可配置 `active_buff_projectile_visual = "baron_siege"`，由 ProjectileSystem 在发射瞬间读取 Buff 状态选择表现。字段须通过 card_validator；不改变弹速、半径、伤害与 Snapshot 结构。
