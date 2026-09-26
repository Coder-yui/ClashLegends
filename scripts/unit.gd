extends Node2D
class_name Unit

# 战场注册时分配的出生身份；不使用对象地址或场景树位置排序。
var combat_source_id := 0
## 通用战斗单位：近战/远程/空中/建筑卡。
## 目标优先级对齐皇室战争：视野内选择最近的合法单位/建筑，塔作为无仇恨时的行军目标；
## 行军途中出现的建筑可重新拉走部队，远处建筑不会隔着全场产生仇恨。
## 无仇恨时沿左右路线推进；直线路段直接移动，仅在被塔/建筑挡住或追击
## 视野目标时使用 A*，跨河仍只能经过桥梁。
## 战斗逻辑由 main 以固定 20Hz tick（sim_tick）驱动，与渲染帧率解耦；
## 渲染层每帧在前后两个模拟位置间插值，画面保持流畅。
## 联机时客户端单位由 main 的快照插值驱动（net_target_pos），不跑本地模拟。

signal died
signal visual_hit
## 瞬时表现通知，不写入动作锁、攻击时间线或朝向。
signal presentation_cue(cue: StringName)
signal action_cancelled(payload: Dictionary)
var action_cancel_serial := 0
var cancelled_visual_serial := -1
var cancelled_deployment := false
var basic_attack_sequence := 0
var last_action_cancellation: Dictionary = {}
## 权威形态改变后通知 3D 表现替换模型；表现层不能反向修改形态。
signal form_changed(form_index: int)

const SIM_DT := 1.0 / 20.0
## 权威移动把人物视为竖直圆柱；俯视碰撞只需计算其圆形底面，完全不读取 3D 网格。
const COLLISION_SHAPE := &"cylinder"
const PATH_REACH := 8.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const REPATH_INTERVAL := 0.25
const MARCH_REPATH_INTERVAL := 0.8
const DEFAULT_SIGHT_RANGE := 220.0
const HIT_FLASH_EVENT_COOLDOWN := 0.18
const CAST_LOCK_MOVEMENT := &"movement"
const CAST_LOCK_ATTACK := &"attack"
const CAST_LOCK_FACING := &"facing"
const DEFAULT_CAST_LOCKS: Array[StringName] = [CAST_LOCK_MOVEMENT, CAST_LOCK_ATTACK, CAST_LOCK_FACING]
## 横扫击退的短暂表现时长，不参与命中或位移判定。
const SWEEP_EFFECT := preload("res://scripts/presentation/sweep_effect_2d.gd")
const SWEEP_FX_DURATION := SWEEP_EFFECT.DURATION
const HEALTH_BAR_HEAD_GAP := 3.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const HEALTH_BAR_HEIGHT := 4.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const SKILL_RESOURCE_BAR_HEIGHT := 2.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const SKILL_RESOURCE_BAR_GAP := 1.5 * CardDB.CHARACTER_SCALE_MULTIPLIER
const SKILL_RESOURCE_UNFILLED_COLOR := Color(0.96, 0.96, 1.0, 0.96)
const SUMMON_SEPARATION := 2.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
# 建筑卡召唤小鬼的确定性方向偏移（按序轮转，不引入随机数）
const SPAWN_DIRECTIONS := [
	Vector2.RIGHT, Vector2(0.70710678, 0.70710678), Vector2.DOWN, Vector2(-0.70710678, 0.70710678),
	Vector2.LEFT, Vector2(-0.70710678, -0.70710678), Vector2.UP, Vector2(0.70710678, -0.70710678),
]

var terrain_traversal := TerrainTraversalState.new()
var skill_dash_active := false
var skill_dash_moved_tick := -1
var attack_timeline := AttackTimeline.new()
var control := ControlState.new()
var net_id := -1
var battle_context: BattleContext
## 每次由主动位卡牌部署时分配一次；-1 表示该实例没有携带主动技能。
var active_ability_id := -1
## 0/1 分别对应备战卡组的第 1/2 主动槽；同槽新实例会覆盖旧实例资格。
var active_ability_slot := -1
## 携带的主动技能来源卡；异构编队的成员仍使用自己的单位卡做表现，但主动资格来自编队卡。
var active_skill_card_id := ""
## 同一次卡牌命令展开出的编队共享此 id；单体与召唤物为 -1。
var deployment_group_id := -1
var card_id := ""
var team := 0
var hp := 100.0
var max_hp := 100.0
var attack_passive_multipliers: Array = []
var death_form := DeathFormState.new()
var net_explosive_shield := false

var attack_lifesteal_ratios: Array = []
var form_lifetime := 0.0
var form_lifetime_left := 0.0
var form_lifetime_after_transition := false
var form_speed_boost_duration := 0.0
var form_speed_boost_multiplier := 1.0
var form_refresh_on_kill := false
var on_hit_max_health_ratio := 0.0
var on_hit_tower_damage := 0.0
var _lifespan_decay_remainder := 0.0
var _continuous_damage_stream := BattleNumbers.DamageStream.new()
var damage := 10.0
var attack_range := 20.0
var attack_interval := 1.0
var move_speed := 60.0
var body_radius := 14.0
var visual_radius := 14.0
var mass := 4.0
var sight_range := DEFAULT_SIGHT_RANGE
var is_air := false
var is_building := false:
	set(value):
		is_building = value
		_sync_structure_group()
var building_only := false
var can_attack_air := true
var continuous_attack := false
var color := Color.DIM_GRAY
var has_model_art := false
var show_team_ring := true
var deploy_time := 1.0
var first_hit_time := 0.2
var passive_first_hit_time := -1.0
var empowered_first_hit := -1.0
var projectile_speed := 0.0
# 权威弹体几何；与 projectile_visual_* 完全独立。
var projectile_spawn_at_edge := false
var projectile_spawn_offset := 0.0
var projectile_collision_radius := 4.0
var active_buff_projectile_visual := &""
var projectile_visual := &"orb"
var projectile_visual_height := 0.0
## 纯表现用的武器前向发射偏移；权威弹体仍从单位地面原点推进和判定。
var projectile_visual_forward_offset := 0.0
## 弹体尺寸与命中样式只参与绘制；权威到达判定仍使用 ProjectileSystem 的固定半径。
var projectile_visual_scale := 1.0
var projectile_impact_visual := &""
var projectile_color := Color.DIM_GRAY
var splash_radius := 0.0
var attack_knockback := 0.0
# 持续攻击光柱是纯表现数据；权威伤害仍由 continuous_attack 的固定 tick 结算。
var continuous_beam_color := Color(0.95, 0.6, 0.2, 0.8)
var continuous_beam_start_width := 3.0
var continuous_beam_end_width := 3.0
var continuous_beam_origin_height := 0.0
var continuous_beam_forward_offset := 0.0
var continuous_beam_origin_world_position := Vector2.ZERO
var continuous_beam_origin_tracks_model := false
# 部署范围击退：赵信当前将其表现为新月护卫；radius<=0 表示未启用。
# 只击退不造成伤害，击退距离由 apply_knockback 的质量因子衰减。
var deploy_sweep_radius := 0.0
var deploy_sweep_damage := 0.0
var deploy_sweep_knockback := 0.0
var deploy_sweep_duration := 0.25
var deploy_sweep_mass_factor_max := 1.4
# 命中回血：每 heal_every_hits 次普攻命中回复 heal_amount 生命（赵信三段循环的第三击）。
var heal_every_hits := 0
var heal_amount := 0.0
var structure_rush := StructureRushState.new()
var charge_time := 0.0
var charge_speed_multiplier := 1.0
var charge_damage_multiplier := 1.0
## 连招攻击节奏：每次命中后到下一次命中的间隔（秒），按数组循环；空数组表示每个周期间隔固定为 attack_interval。
## 例如 [0.28, 1.05, 0.28, 1.05] 表示快速两拳后停顿、再快速两拳后停顿。
var attack_pattern: Array = []
## 连招伤害倍率：按每次命中的顺序循环；空数组表示每拳使用 damage 原值。
var attack_damage_multipliers: Array = []
## 先声夺人：对每个敌方目标的首次普通攻击伤害倍率；1.0 表示未启用。
var first_strike_damage_multiplier := 1.0
## 已被本单位普攻命中的目标 instance_id 集合，用于判定"首次攻击"。
var _first_strike_hit_target_ids := {}
## 某一段普通攻击可在权威延迟后追加额外刀数；内层数组与 attack 动画段一一对应。
var attack_extra_hit_damage_multipliers: Array = []
var attack_extra_hit_delays: Array = []
## 每N次命中后可在没有圈内目标时提前转走并清除间隔；0禁用。
var attack_recovery_cancel_every_hits := 0
## 可复用的主动技能资源。当前腕豪用它表达豪意；权威值不由白条或动画反推。
var skill_resource_max := 0.0
var skill_resource_value := 0.0
var skill_resource_attack_gain := 0.0
var skill_resource_hit_gain := 0.0
var skill_resource_kill_gain := 0.0
var skill_resource_damage_gain_multiplier := 0.0
var skill_resource_decay_delay := 0.0
var skill_resource_decay_rate := 0.0
var skill_resource_full_color := SKILL_RESOURCE_UNFILLED_COLOR
var skill_resource_enabled := false
var _configured_skill_resource_max := 0.0
var _configured_skill_resource_attack_gain := 0.0
var _configured_skill_resource_hit_gain := 0.0
var _configured_skill_resource_kill_gain := 0.0
var _configured_skill_resource_damage_gain_multiplier := 0.0
var _configured_skill_resource_decay_delay := 0.0
var _configured_skill_resource_decay_rate := 0.0
## 双形态单位配置。0 为初始形态，1 为 transformed_stats；命中次数可让两形态循环切换。
var transform_after_hits := 0
var revert_after_hits := 0
var transform_hit_count := 0
var form_index := 0
var attack_wave: Dictionary = {}
var transformed_stats: Dictionary = {}
var _base_form_stats: Dictionary = {}
## 形态数值在命中瞬间切换；这段固定计时只锁自主攻击，仍允许按新形态寻路移动。
var form_transition_timer := 0.0
var transform_duration := 0.0
var active_transform_duration := 0.0
var revert_duration := 0.0
var form_change_serial := 0
var pending_form_generation := -1
## 主动技能施放窗口与权限分离。默认锁移动/普攻/朝向；技能可用 cast_locks
## 独立放开任一权限，避免把“正在施法”硬编码成一种互斥战斗状态。
var active_skill_cast_serial := 0
var cancelled_skill_cast_serial := -1
var active_skill_cast_timer := 0.0
var active_skill_cast_facing := Vector2.ZERO
var active_skill_cast_locks: Array[StringName] = []

## 预留的减攻速控制状态；高原血统在 Buff 期间会忽略它。
var restoration_fx_timer := 0.0 # 纯表现秒数，不进入权威快照
var shields := ShieldState.new()
var shield_hp: float:
	get: return shields.total_hp()
var shield_max_hp: float:
	get: return shields.total_capacity()
var shield_timer: float:
	get: return shields.longest_remaining()
var bleeding := BleedState.new()
var bleed_definition: Dictionary = {}
var empowered_execute: Dictionary = {}
var buffs := StatusInstances.new()
var target_protection := TargetProtectionState.new()
var active_buff_timer: float:
	get: return maxf(buffs.remaining(&"buff"), buffs.remaining(&"blood_rage"))
var active_speed_multiplier: float:
	get: return buffs.strongest(&"buff", &"speed", 1.0)
var active_damage_multiplier: float:
	get: return buffs.strongest(&"buff", &"damage", 1.0) * buffs.strongest(&"blood_rage", &"damage", 1.0)
var active_attack_speed_multiplier: float:
	get: return maxf(buffs.strongest(&"buff", &"attack_speed", 1.0), buffs.strongest(&"hit_haste", &"attack_speed", 1.0))
var active_buff_ignores_movement_slow: bool:
	get: return buffs.any_flag(&"buff", &"ignore_movement_slow")
var active_buff_ignores_attack_speed_slow: bool:
	get: return buffs.any_flag(&"buff", &"ignore_attack_speed_slow")
## 强化下一次普攻不另起攻击计时，只在原本的下一次命中节点消费。
var empowered_attack_ready := false
var empowered_attack_damage_multiplier := 1.0
var empowered_attack_speed_multiplier := 1.0
var empowered_attack_blind_charges := 0
var blind_attack_charges := 0
## 通用普攻击中吸血。主动赋予后持续到该单位死亡，不因主动槽被新编队替换而清除。
var attack_lifesteal_ratio := 0.0
var attack_lifesteal_max_health_ratio := 1.0

# 联机客户端插值字段（main 快照写入）
var net_target_pos: Vector2

# 建筑卡专用
## 只用于下牌占地；移动、寻路和攻击距离始终使用 body_radius 的圆柱碰撞。
var footprint_tiles := Vector2i.ONE
var lifespan := 0.0
## 可选的建筑寿命表现：按初始最大生命/寿命匀速扣减，仍由固定模拟驱动。
var lifespan_hp_decay := false
## 由主机在生成时固化并可靠同步。只声明“这次部署位于已毁防御塔九格内”，
## 不负责找塔；权威寿命规则与纯表现废墟显隐分别读取该不可变状态。
var built_on_tower_ruin := false
var spawn_id := ""
var spawn_interval := 0.0
var spawn_count := 1
var spawn_side := ""
var death_spawn_id := ""
var death_spawn_count := 0
## 通用一次性死亡替身：原单位死亡时立即生成指定单位（例如凤凰→蛋）。
var death_replacement_id := ""
var death_replacement_charges := 0
var death_replacement_visual_transition := ""
## 通用存活计时复生：单位在计时结束前未死亡时，生成指定单位并自身退出（例如蛋→凤凰）。
var timed_revival_id := ""
var timed_revival_delay := 0.0
var timed_revival_death_replacement_charges := -1
var timed_revival_visual_transition := ""
var _timed_revival_left := 0.0
## 仅供表现层读取的生成过渡；由死亡替身/计时复生入口传入，不参与权威模拟。
var visual_spawn_transition: StringName = &""
var _skip_death_visual := false
var nav_cells: Array = []

var _target: Node2D = null
var _attacking := false
var _attack_visual_serial := 0
var net_attack_elapsed := 0.0
var net_movement_rate := 1.0
var net_action_permissions := 0
var _body_facing_direction := Vector2.ZERO
var lifecycle_birth_tick := -1
var _presentation_state: UnitPresentationState
## 持续攻击的目标表现标识；原地换目标时推进序号，让两端播放换目标衔接。
var _continuous_visual_target_id := 0
var _attack_visual_pending := false
## 当前攻击表现序号是否采用赏金猎人首次攻击音效链；仅表现读取，不参与伤害判定。
var _attack_visual_first_strike := false
var _attack_hit_index := 0
## 挥击总数：与表现层攻击动画序号同步推进，用于命中回血按三段循环取模。
var _attack_swing_count := 0
var _empowered_attack_visual_serial := 0
var _pending_extra_attacks: Array[Dictionary] = []
var _sweep_fx_timer := 0.0
var _hit_flash_event_cooldown := 0.0
var _death_visual_emitted := false
var _deploy_timer := 0.0
var _lifespan_left := 0.0
var _spawn_timer := 0.0
var _spawn_counter := 0
var _initial_summons_spawned := false

var _path := PackedVector2Array()
var _path_index := 0
var _repath_cd := 0.0
var _path_target: Node2D = null
var _path_goal := Vector2(INF, INF)
var _move_intent := Vector2.ZERO
var _move_direction := Vector2.ZERO
var _avoidance_turn := 0.0
## 本 Tick 由击退或先锋自主冲撞接管意图；不是未实现的强制位移能力。
var _forced_movement := false
var knockback := KnockbackState.new()
var _knockback_velocity: Vector2:
	get: return knockback.velocity
var _knockback_timer: float:
	get: return knockback.remaining
var _charge_timer := 0.0
var _charged := false
var _skill_resource_combat_timer := 0.0
var _just_deployed := false
var net_visual_state := 1
var net_attack_visual_serial := 0
var net_attack_visual_first_strike := false
var net_shield_ratio := 0.0
var net_shield_capacity_ratio := 0.0
var net_slow_active := false
var net_attack_speed_slow_active := false
var net_stun_active := false
var net_form_index := 0
var net_form_change_serial := 0
var net_visual_action_serial := 0
var net_visual_action_name := &""
var net_visual_action_duration := 0.0
var net_visual_action_time_left := 0.0
var net_locomotion_state := 1
var net_blood_rage := 0.0
var net_hit_haste_full := false
var net_empowered_attack_ready := false
var net_empowered_attack_visual_serial := 0
var net_skill_resource_ratio := 0.0
var net_skill_resource_enabled := false
var net_active_speed_multiplier := 1.0
var net_active_attack_speed_multiplier := 1.0
var net_active_buff_active := false
var net_facing_direction := Vector2.ZERO
## 主机快照同步当前普攻目标是否为建筑，供客户端选择对应动作；不参与伤害判定。
var net_attacking_structure := false
var net_has_continuous_target := false
var net_continuous_target_pos := Vector2.ZERO
var net_continuous_target_air_id := -1
## 仅由表现代理切换：进入吐息循环后显示，进入动画和退出攻击时隐藏。
var continuous_beam_visible := false
var _visual_action_serial := 0
var _visual_action_name := &""
var _visual_action_duration := 0.0
var _visual_action_time_left := 0.0
## 血条绘制中心；实际位置由屏幕空间头顶锚点计算。
var _health_bar_center := Vector2.ZERO
var _health_bar_screen_center := Vector2.ZERO
var _health_bar_head_screen := Vector2.ZERO

# 渲染插值：sim 为 20Hz，渲染在上一模拟位置与当前位置间过渡
var _prev_pos := Vector2.ZERO
var _vis_offset := Vector2.ZERO
var _status_effect_offset := Vector2.ZERO # 3D 代理投影的离地平面，仅用于附着表现
var _status_effect_phase := 0.0
var _status_last_position := Vector2(INF, INF)
var _status_visual_velocity := Vector2.ZERO

func set_battle_context(context: BattleContext) -> void:
	battle_context = context

func setup(p_team: int, stats: Dictionary, _p_name: String) -> void:
	_base_form_stats = stats.duplicate(true)
	attack_wave.clear()
	if stats.has("attack_wave_damage"):
		for field in ["damage", "delay", "tail_distance", "near_width", "max_scale", "speed", "visual", "visual_height"]:
			attack_wave[field] = stats.get("attack_wave_" + field, 0.0)
	terrain_traversal.configure(stats)
	team = p_team
	hp = BattleNumbers.quantity(stats.hp)
	max_hp = hp
	attack_passive_multipliers = stats.get("attack_passive_multipliers", []).duplicate()
	attack_lifesteal_ratios = stats.get("attack_lifesteal_ratios", []).duplicate()
	form_lifetime = float(stats.get("form_lifetime", 0.0))
	form_lifetime_after_transition = bool(stats.get("form_lifetime_after_transition", false))
	form_speed_boost_duration = float(stats.get("form_speed_boost_duration", 0.0))
	form_speed_boost_multiplier = float(stats.get("form_speed_boost_multiplier", 1.0))
	form_refresh_on_kill = bool(stats.get("form_refresh_on_kill", false))
	bleed_definition = {}
	if stats.has("bleed_max_stacks"):
		for field in ["bleed_damage_per_second", "bleed_duration", "bleed_max_stacks", "blood_rage_duration", "blood_rage_damage_multiplier"]:
			bleed_definition[field] = stats[field]
	on_hit_max_health_ratio = float(stats.get("on_hit_max_health_ratio", 0.0))
	on_hit_tower_damage = BattleNumbers.quantity(float(stats.get("on_hit_tower_damage", 0.0)))
	_lifespan_decay_remainder = 0.0
	_continuous_damage_stream = BattleNumbers.DamageStream.new()
	damage = BattleNumbers.quantity(stats.damage)
	attack_range = stats.range
	attack_interval = snappedf(stats.interval, 0.01)
	move_speed = snappedf(stats.speed, 0.01)
	body_radius = stats.radius
	visual_radius = stats.get("visual_radius", body_radius)
	_health_bar_center = Vector2(0.0, -visual_radius - HEALTH_BAR_HEAD_GAP - HEALTH_BAR_HEIGHT * 0.5)
	mass = stats.get("mass", maxf(1.0, body_radius / 3.0))
	sight_range = stats.get("sight", DEFAULT_SIGHT_RANGE)
	color = stats.get("color", Color.DIM_GRAY)
	show_team_ring = stats.get("show_team_ring", true)
	projectile_color = color
	var projectile_colors: Array = stats.get("projectile_colors", [])
	if team >= 0 and team < projectile_colors.size():
		projectile_color = projectile_colors[team]
	is_air = stats.get("is_air", false)
	# 单位 2D 层（血条/状态圈）必须盖在防御塔 2D 层之上：塔层 z_index=10，
	# 地面单位取 11、空中单位取 12；否则贴塔/水晶作战的单位血条会被建筑血条挡住。
	z_index = 12 if is_air else 11
	is_building = stats.get("is_building", false)
	footprint_tiles = stats.get("footprint_tiles", Vector2i.ONE)
	building_only = stats.get("building_only", false)
	can_attack_air = stats.get("can_attack_air", true)
	continuous_attack = stats.get("is_continuous_attack", false)
	deploy_time = stats.get("deploy_time", 1.0)
	first_hit_time = stats.get("first_hit", minf(attack_interval * 0.5, 0.4))
	passive_first_hit_time = float(stats.get("passive_first_hit", -1.0))
	empowered_first_hit = float(stats.get("empowered_first_hit", -1.0))
	projectile_speed = stats.get("projectile_speed", 0.0)
	projectile_spawn_at_edge = bool(stats.get("projectile_spawn_at_edge", false))
	projectile_spawn_offset = float(stats.get("projectile_spawn_offset", 0.0))
	projectile_collision_radius = float(stats.get("projectile_collision_radius", 4.0))
	active_buff_projectile_visual = StringName(stats.get("active_buff_projectile_visual", ""))
	projectile_visual = StringName(stats.get("projectile_visual", "orb"))
	projectile_visual_height = stats.get("projectile_visual_height", 0.0)
	projectile_visual_forward_offset = stats.get("projectile_visual_forward_offset", 0.0)
	projectile_visual_scale = stats.get("projectile_visual_scale", 1.0)
	projectile_impact_visual = StringName(stats.get("projectile_impact_visual", ""))
	splash_radius = stats.get("splash_radius", 0.0)
	attack_knockback = stats.get("knockback", 0.0)
	continuous_beam_color = stats.get("continuous_beam_color", continuous_beam_color)
	continuous_beam_start_width = stats.get("continuous_beam_start_width", continuous_beam_start_width)
	continuous_beam_end_width = stats.get("continuous_beam_end_width", continuous_beam_end_width)
	continuous_beam_origin_height = stats.get("continuous_beam_origin_height", continuous_beam_origin_height)
	continuous_beam_forward_offset = stats.get("continuous_beam_forward_offset", continuous_beam_forward_offset)
	deploy_sweep_radius = stats.get("deploy_sweep_radius", 0.0)
	deploy_sweep_damage = stats.get("deploy_sweep_damage", 0.0)
	deploy_sweep_knockback = stats.get("deploy_sweep_knockback", 0.0)
	deploy_sweep_duration = stats.get("deploy_sweep_duration", 0.25)
	deploy_sweep_mass_factor_max = stats.get("deploy_sweep_mass_factor_max", 1.4)
	heal_every_hits = stats.get("heal_every_hits", 0)
	heal_amount = stats.get("heal_amount", 0.0)
	structure_rush.configure(stats)
	charge_time = stats.get("charge_time", 0.0)
	charge_speed_multiplier = stats.get("charge_speed_multiplier", 1.0)
	charge_damage_multiplier = stats.get("charge_damage_multiplier", 1.0)
	attack_pattern = stats.get("attack_pattern", [])
	attack_damage_multipliers = stats.get("attack_damage_multipliers", [])
	first_strike_damage_multiplier = maxf(float(stats.get("first_strike_damage_multiplier", 1.0)), 0.0)
	attack_extra_hit_damage_multipliers = stats.get("attack_extra_hit_damage_multipliers", [])
	attack_extra_hit_delays = stats.get("attack_extra_hit_delays", [])
	attack_recovery_cancel_every_hits = int(stats.get("attack_recovery_cancel_every_hits", 0))
	_configured_skill_resource_max = maxf(float(stats.get("skill_resource_max", 0.0)), 0.0)
	_configured_skill_resource_attack_gain = maxf(float(stats.get("skill_resource_attack_gain", 0.0)), 0.0)
	_configured_skill_resource_hit_gain = maxf(float(stats.get("skill_resource_hit_gain", 0.0)), 0.0)
	_configured_skill_resource_kill_gain = maxf(float(stats.get("skill_resource_kill_gain", 0.0)), 0.0)
	_configured_skill_resource_damage_gain_multiplier = maxf(float(stats.get("skill_resource_damage_gain_multiplier", 0.0)), 0.0)
	_configured_skill_resource_decay_delay = maxf(float(stats.get("skill_resource_decay_delay", 0.0)), 0.0)
	_configured_skill_resource_decay_rate = maxf(float(stats.get("skill_resource_decay_rate", 0.0)), 0.0)
	skill_resource_full_color = stats.get("skill_resource_full_color", SKILL_RESOURCE_UNFILLED_COLOR)
	skill_resource_max = 0.0
	skill_resource_value = 0.0
	skill_resource_attack_gain = 0.0
	skill_resource_hit_gain = 0.0
	skill_resource_kill_gain = 0.0
	skill_resource_damage_gain_multiplier = 0.0
	skill_resource_decay_delay = 0.0
	skill_resource_decay_rate = 0.0
	skill_resource_enabled = false
	shields.clear()
	transform_after_hits = maxi(int(stats.get("transform_after_hits", 0)), 0)
	revert_after_hits = maxi(int(stats.get("revert_after_hits", 0)), 0)
	transform_duration = maxf(float(stats.get("transform_duration", 0.0)), 0.0)
	active_transform_duration = maxf(float(stats.get("active_transform_duration", transform_duration)), 0.0)
	revert_duration = maxf(float(stats.get("revert_duration", 0.0)), 0.0)
	transformed_stats = stats.get("transformed_stats", {}).duplicate(true)
	form_index = 0
	net_form_index = 0
	form_change_serial = 0
	net_form_change_serial = 0
	var tower_ruin_exempt := built_on_tower_ruin and bool(stats.get("tower_ruin_foundation", false))
	lifespan = 0.0 if tower_ruin_exempt else stats.get("lifespan", 0.0)
	lifespan_hp_decay = false if tower_ruin_exempt else bool(stats.get("lifespan_hp_decay", false))
	spawn_id = String(stats.get("spawn_id", ""))
	spawn_interval = stats.get("spawn_interval", 0.0)
	spawn_count = maxi(int(stats.get("spawn_count", 1)), 1)
	spawn_side = String(stats.get("spawn_side", ""))
	death_spawn_id = String(stats.get("death_spawn_id", ""))
	death_spawn_count = maxi(int(stats.get("death_spawn_count", 0)), 0)
	death_replacement_id = String(stats.get("death_replacement_id", ""))
	death_replacement_charges = maxi(int(stats.get("death_replacement_charges", 0)), 0)
	death_replacement_visual_transition = String(stats.get("death_replacement_visual_transition", ""))
	timed_revival_id = String(stats.get("timed_revival_id", ""))
	timed_revival_delay = maxf(float(stats.get("timed_revival_delay", 0.0)), 0.0)
	timed_revival_death_replacement_charges = int(stats.get("timed_revival_death_replacement_charges", -1))
	timed_revival_visual_transition = String(stats.get("timed_revival_visual_transition", ""))
	_timed_revival_left = timed_revival_delay
	_lifespan_left = lifespan
	_spawn_timer = spawn_interval
	_deploy_timer = deploy_time
	net_target_pos = global_position
	_prev_pos = global_position
	_update_fallback_health_bar_anchor()

func _sync_structure_group() -> void:
	if not is_inside_tree(): return
	if is_building:
		add_to_group("combat_structures")
	else:
		remove_from_group("combat_structures")

func _ready() -> void:
	add_to_group("combatants")
	_sync_structure_group()
	_update_fallback_health_bar_anchor()
	# 赵信的新月护卫就是部署动作本身：生成当帧结算一次，不等待部署锁定结束，
	# 也不让动画帧反向驱动权威效果。客户端仅显示同帧特效。
	if deploy_time > 0.0 and deploy_sweep_radius > 0.0 and (deploy_sweep_damage > 0.0 or deploy_sweep_knockback > 0.0):
		if _in_client_mode():
			_sweep_fx_timer = SWEEP_FX_DURATION
		elif not is_frozen():
			_perform_deploy_sweep()

func _process(delta: float) -> void:
	presentation_state().advance_health_bar(delta)
	_status_effect_phase = fposmod(_status_effect_phase + delta, preload("res://scripts/presentation/soft_control_effect.gd").LOOP_SECONDS)
	_update_status_visual_motion(delta)
	if movement_slow_visual() or attack_speed_slow_visual(): queue_redraw()
	if restoration_fx_timer > 0.0: queue_redraw()
	restoration_fx_timer = maxf(0.0, restoration_fx_timer - delta)
	_sweep_fx_timer = maxf(0.0, _sweep_fx_timer - delta)
	if _in_client_mode():
		# 客户端：朝快照目标位置平滑插值，血量/冰冻由 main 快照直接写入
		position = position.lerp(net_target_pos, minf(delta * 10.0, 1.0))
		# 客户端不跑权威横扫，只倒计时部署状态；击退与受伤结果由快照驱动。
		_deploy_timer = maxf(0.0, _deploy_timer - delta)
		if not has_model_art:
			_update_fallback_health_bar_anchor()
		queue_redraw()
		return
	if death_form.waiting():
		queue_redraw()
	if is_building or hp <= 0.0:
		queue_redraw() # 状态结束帧也清除建筑 / 死亡单位的附着提示。
		return
	# 主机/单机：使用 main 的统一模拟余量插值，不能让每个节点独立累计进度。
	_vis_offset = get_visual_screen_position() - position
	if not has_model_art:
		_update_fallback_health_bar_anchor()
	queue_redraw()

## 表现层的部署/移动/攻击组合状态。3D 动画控制器另外读取 locomotion，
## 再用攻击序号/visual_action 作为 action 通道覆盖它；动画无权决定攻击是否命中。
func get_visual_state_code() -> int:
	if _in_client_mode():
		return net_visual_state
	if _deploy_timer > 0.0:
		return 1 if cancelled_deployment else 0
	if _attacking:
		return 3
	return get_locomotion_visual_state_code()

## locomotion 只表达 Deploy/Idle/Move，不包含攻击或技能。
func get_locomotion_visual_state_code() -> int:
	if _in_client_mode():
		return net_locomotion_state
	if _deploy_timer > 0.0:
		return 1 if cancelled_deployment else 0
	if _forced_movement or _knockback_timer > 0.0:
		return 1
	if _move_intent.length_squared() > 0.01:
		return 2
	return 1

## 3D 与 2D 表现都直接读取同一个最终渲染位置，不依赖彼此的 _process 执行顺序。
func action_permissions() -> int:
	if hp <= 0.0: return 0
	if _in_client_mode(): return net_action_permissions
	var allowed := control.permissions()
	if not is_deployed() or structure_rush.skill_locked():
		allowed &= ~(ControlState.MOVE | ControlState.BASIC_ATTACK | ControlState.START_SKILL | ControlState.TURN)
	if death_form.used: allowed &= ~ControlState.START_SKILL
	if is_form_transitioning() or is_active_skill_casting():
		allowed &= ~ControlState.START_SKILL
	if is_form_transitioning() or is_active_skill_attack_locked():
		allowed &= ~ControlState.BASIC_ATTACK
	if is_active_skill_movement_locked() or is_building:
		allowed &= ~ControlState.MOVE
	if is_active_skill_facing_locked():
		allowed &= ~ControlState.TURN
	if _knockback_timer > 0.0:
		allowed &= ~(ControlState.MOVE | ControlState.BASIC_ATTACK | ControlState.START_SKILL | ControlState.TURN)
	if is_building or structure_rush.control_immune():
		allowed &= ~ControlState.EXTERNAL_MOTION
	return allowed

func get_action_permissions_visual() -> int:
	return action_permissions()

func presentation_state() -> UnitPresentationState:
	if _presentation_state == null:
		_presentation_state = UnitPresentationState.new(self)
	return _presentation_state

func get_attack_elapsed_visual() -> float:
	return net_attack_elapsed if _in_client_mode() else attack_timeline.visual_elapsed

func get_effective_movement_rate_visual() -> float:
	if _in_client_mode():
		return net_movement_rate
	return _effective_movement_multiplier()

func _effective_movement_multiplier() -> float:
	var rate := active_speed_multiplier
	if _charged:
		rate *= charge_speed_multiplier
	if empowered_attack_ready:
		rate *= empowered_attack_speed_multiplier
	if control.slow_timer > 0.0 and not active_buff_ignores_movement_slow:
		rate *= control.slow_multiplier
	return rate

## 表现读取有效减益本身，不从被增益抵消后的最终速率反推。
func movement_slow_visual() -> bool:
	if hp <= 0.0: return false
	if _in_client_mode(): return net_slow_active
	return control.slow_timer > 0.0 and control.slow_multiplier < 1.0 and not active_buff_ignores_movement_slow

func attack_speed_slow_visual() -> bool:
	if hp <= 0.0: return false
	if _in_client_mode(): return net_attack_speed_slow_active
	return control.attack_speed_slow_timer > 0.0 and control.attack_speed_slow_multiplier < 1.0 and not active_buff_ignores_attack_speed_slow

## 只测量已发生的渲染位移；意图、站立抖动、模型振翅或出生位置不算移动。
func _update_status_visual_motion(delta: float) -> void:
	var current := get_visual_screen_position()
	_status_visual_velocity = Vector2.ZERO
	if _status_last_position.is_finite() and delta > 0.00001:
		var displacement := current - _status_last_position
		if displacement.length() <= maxf(16.0, move_speed * delta * 4.0):
			_status_visual_velocity = displacement / delta
	_status_last_position = current

func movement_slow_effect_visible() -> bool:
	return movement_slow_visual() and get_locomotion_visual_state_code() == 2 and (get_action_permissions_visual() & ControlState.MOVE) != 0 and _status_visual_velocity.length_squared() > 4.0

func stun_visual() -> bool:
	return hp > 0.0 and (net_stun_active if _in_client_mode() else control.stun_timer > 0.0)

func stun_effect_origin() -> Vector2:
	# 置于模型头顶及血条上方，避免漩涡压住生命信息。缩放与画布翻转一起考虑。
	var transform_to_screen := get_global_transform_with_canvas()
	var scale_y := transform_to_screen.y.length()
	return transform_to_screen.affine_inverse() * (get_health_bar_screen_center() - Vector2(0.0, 13.0 * scale_y))

func set_status_effect_world_position(world_point: Vector2) -> void:
	_status_effect_offset = to_local(world_point) - _vis_offset

func status_effect_origin() -> Vector2:
	return _vis_offset + (_status_effect_offset if has_model_art else Vector2.ZERO)

func get_visual_screen_position() -> Vector2:
	if _in_client_mode():
		return global_position
	var alpha := 1.0
	if battle_context != null:
		alpha = battle_context.simulation_interpolation_alpha()
	return _prev_pos.lerp(global_position, alpha)

func get_attack_visual_serial() -> int:
	return net_attack_visual_serial if _in_client_mode() else _attack_visual_serial

func is_attack_visual_first_strike() -> bool:
	return net_attack_visual_first_strike if _in_client_mode() else _attack_visual_first_strike

func get_empowered_attack_visual_serial() -> int:
	return net_empowered_attack_visual_serial if _in_client_mode() else _empowered_attack_visual_serial

func is_empowered_attack_ready_visual() -> bool:
	if _in_client_mode():
		return net_empowered_attack_ready
	if not attack_passive_multipliers.is_empty():
		return float(attack_passive_multipliers[posmod(_attack_swing_count, attack_passive_multipliers.size())]) > 0.0
	return empowered_attack_ready

func get_skill_resource_ratio() -> float:
	if _in_client_mode():
		return clampf(net_skill_resource_ratio, 0.0, 1.0)
	if skill_resource_max <= 0.0:
		return 0.0
	return clampf(skill_resource_value / skill_resource_max, 0.0, 1.0)

func is_skill_resource_visible() -> bool:
	return net_skill_resource_enabled if _in_client_mode() else skill_resource_enabled

func get_active_buff_active_visual() -> bool:
	return net_active_buff_active if _in_client_mode() else active_buff_timer > 0.0

func get_active_speed_multiplier_visual() -> float:
	return net_active_speed_multiplier if _in_client_mode() else active_speed_multiplier

func get_active_attack_speed_multiplier_visual() -> float:
	return net_active_attack_speed_multiplier if _in_client_mode() else _effective_attack_speed_multiplier()

## 仅供表现层选择普通普攻或建筑普攻动作。目标类型由权威端判定并随快照同步。
func is_attacking_structure_visual() -> bool:
	if _in_client_mode():
		return net_attacking_structure
	return _attacking and _target != null and is_instance_valid(_target) and _is_struct(_target)

func get_form_index() -> int:
	return net_form_index if _in_client_mode() else form_index

func get_visual_action_serial() -> int:
	return net_visual_action_serial if _in_client_mode() else _visual_action_serial

func get_visual_action_name() -> StringName:
	return net_visual_action_name if _in_client_mode() else _visual_action_name

func get_visual_action_duration() -> float:
	return net_visual_action_duration if _in_client_mode() else _visual_action_duration

func get_visual_action_time_left() -> float:
	return net_visual_action_time_left if _in_client_mode() else _visual_action_time_left

## 主机记录一次纯表现动作；序号、名称和权威动作窗口会随快照同步。
## duration 只用于客户端对齐播放进度，动画依旧不能决定效果时刻。
func play_visual_action(action_name: StringName, duration: float = 0.0) -> void:
	_visual_action_name = action_name
	_visual_action_duration = maxf(BattleNumbers.decimal(duration), 0.0)
	_visual_action_time_left = _visual_action_duration
	_visual_action_serial += 1

func begin_active_skill_cast(duration: float, facing: Vector2, cast_locks: Array = DEFAULT_CAST_LOCKS) -> void:
	active_skill_cast_serial += 1
	active_skill_cast_timer = maxf(duration, 0.0)
	active_skill_cast_locks.clear()
	for configured_lock in cast_locks:
		var cast_lock := StringName(configured_lock)
		if cast_lock in DEFAULT_CAST_LOCKS and cast_lock not in active_skill_cast_locks:
			active_skill_cast_locks.append(cast_lock)
	if facing.length_squared() < 0.001:
		facing = Vector2.UP if team == 0 else Vector2.DOWN
	active_skill_cast_facing = facing.normalized()
	if (control.permissions() & ControlState.TURN) != 0:
		_body_facing_direction = active_skill_cast_facing
	if is_active_skill_attack_locked():
		_cancel_attack_for_cast()
	if is_active_skill_movement_locked():
		_move_intent = Vector2.ZERO

## 在 Cast Start 锁定本次资源倍率并清空旧资源。施法期间新获得的资源留给下一次技能，
## 从而保证强动画选择、权威伤害与联网表现始终来自同一个资源快照。
func consume_skill_resource_ratio() -> float:
	var ratio := get_skill_resource_ratio()
	skill_resource_value = 0.0
	queue_redraw()
	return ratio

func get_skill_resource_stacks() -> int:
	var resource_value := skill_resource_value
	if _in_client_mode():
		resource_value = clampf(net_skill_resource_ratio, 0.0, 1.0) * skill_resource_max
	return clampi(int(round(resource_value)), 0, int(round(skill_resource_max)))

func get_skill_resource_fill_color() -> Color:
	return skill_resource_full_color if is_equal_approx(get_skill_resource_ratio(), 1.0) else SKILL_RESOURCE_UNFILLED_COLOR

## 格温/龙王这类小整数资源使用分段白条；连续资源（例如瑟提豪意）仍画成连续进度。
func get_skill_resource_segment_count() -> int:
	if not is_skill_resource_visible():
		return 0
	var segment_count := int(round(skill_resource_max))
	return segment_count if segment_count >= 2 and segment_count <= 10 and is_equal_approx(skill_resource_max, float(segment_count)) else 0

## 卡牌数值可声明资源规则，但只有主动槽实际携带 uses_skill_resource 的实例才启用。
func configure_carried_active_skill(skill: Dictionary) -> void:
	if not bool(skill.get("uses_skill_resource", false)) or _configured_skill_resource_max <= 0.0:
		clear_carried_active_skill_resource()
		return
	skill_resource_enabled = true
	skill_resource_max = _configured_skill_resource_max
	skill_resource_attack_gain = _configured_skill_resource_attack_gain
	skill_resource_hit_gain = _configured_skill_resource_hit_gain
	skill_resource_kill_gain = _configured_skill_resource_kill_gain
	skill_resource_damage_gain_multiplier = _configured_skill_resource_damage_gain_multiplier
	skill_resource_decay_delay = _configured_skill_resource_decay_delay
	skill_resource_decay_rate = _configured_skill_resource_decay_rate
	_skill_resource_combat_timer = skill_resource_decay_delay
	queue_redraw()

func clear_carried_active_skill_resource() -> void:
	skill_resource_enabled = false
	skill_resource_max = 0.0
	skill_resource_value = 0.0
	skill_resource_attack_gain = 0.0
	skill_resource_hit_gain = 0.0
	skill_resource_kill_gain = 0.0
	skill_resource_damage_gain_multiplier = 0.0
	skill_resource_decay_delay = 0.0
	skill_resource_decay_rate = 0.0
	_skill_resource_combat_timer = 0.0
	queue_redraw()

func add_skill_resource(amount: float) -> void:
	if battle_context != null and (battle_context.damage_batch().collecting or battle_context.damage_batch().committing):
		battle_context.damage_batch().defer_benefit(func():
			if hp > 0.0: add_skill_resource(amount))
		return
	if skill_resource_max <= 0.0 or amount <= 0.0:
		return
	skill_resource_value = minf(skill_resource_value + amount, skill_resource_max)
	queue_redraw()

func mark_skill_resource_combat_activity() -> void:
	if not skill_resource_enabled:
		return
	_skill_resource_combat_timer = skill_resource_decay_delay

func _tick_skill_resource_decay(dt: float) -> void:
	if not skill_resource_enabled or skill_resource_value <= 0.0:
		return
	var decay_dt := dt
	if _skill_resource_combat_timer > 0.0:
		if dt <= _skill_resource_combat_timer:
			_skill_resource_combat_timer -= dt
			return
		decay_dt = dt - _skill_resource_combat_timer
		_skill_resource_combat_timer = 0.0
	if decay_dt > 0.0 and skill_resource_decay_rate > 0.0:
		skill_resource_value = maxf(0.0, skill_resource_value - skill_resource_decay_rate * decay_dt)

## 强化下一击刷新普攻周期；完整新前摇由本Tick的权威攻击入口开始。
func prepare_empowered_attack(damage_multiplier: float, speed_multiplier: float = 1.0, applied_blind_charges: int = 0) -> void:
	var was_attacking := _attacking
	cancel_basic_attack(&"empowered_reset")
	empowered_attack_ready = true
	empowered_attack_damage_multiplier = maxf(damage_multiplier, 0.0)
	# 保留既有移动加速规则：攻击中使用不额外获得追击加速。
	empowered_attack_speed_multiplier = 1.0 if was_attacking else maxf(speed_multiplier, 1.0)
	empowered_attack_blind_charges = maxi(applied_blind_charges, 0)
	attack_timeline.restart_visual()
	queue_redraw()

## 给此单位后续每次真正命中的普通攻击附加吸血；不会改写攻击计时或主动技能归属。
func apply_attack_lifesteal(heal_ratio: float, max_health_ratio: float = 1.0) -> void:
	attack_lifesteal_ratio = maxf(heal_ratio, 0.0)
	attack_lifesteal_max_health_ratio = maxf(max_health_ratio, 1.0)
	queue_redraw()

func apply_blind(attacks: int, interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	# 持续输出能力没有离散出手，致盲对此类攻击无作用。
	if hp <= 0.0 or continuous_attack or structure_rush.control_immune(): return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func():
			if hp > 0.0: apply_blind(attacks))
		return
	blind_attack_charges = maxi(blind_attack_charges, maxi(attacks, 0))
	queue_redraw()

func is_active_skill_movement_locked() -> bool:
	return active_skill_cast_timer > 0.0 and CAST_LOCK_MOVEMENT in active_skill_cast_locks

func is_active_skill_attack_locked() -> bool:
	return active_skill_cast_timer > 0.0 and CAST_LOCK_ATTACK in active_skill_cast_locks

func is_active_skill_facing_locked() -> bool:
	return active_skill_cast_timer > 0.0 and CAST_LOCK_FACING in active_skill_cast_locks

func _cancel_attack_for_cast() -> void:
	_attacking = false
	attack_timeline.cancel(true)
	_attack_visual_pending = false
	_attack_visual_first_strike = false
	_continuous_visual_target_id = 0
	set_continuous_beam_visible(false)

## 客户端只接受主机快照中的形态。战斗数值用于正确显示体型、血条和目标过滤，
## 当前生命会在同一份快照中由主机值覆盖，不在这里发放变身生命增量。
func sync_network_form(next_form_index: int, next_form_serial: int = 0) -> void:
	next_form_index = clampi(next_form_index, 0, 1)
	# 双向变形时用权威形态序号过滤晚到的旧快照，不能再按形态数字大小判断新旧。
	if next_form_serial < net_form_change_serial:
		return
	net_form_change_serial = next_form_serial
	net_form_index = next_form_index
	if form_index == net_form_index:
		return
	_apply_form(net_form_index, false, false)

func transform_to_mega(active_cast: bool = false) -> bool:
	# queue_free() 到帧末才真正释放节点；在途弹体等弱引用仍可能于同帧回调。
	# 死亡单位不能再改变权威形态，否则 form_changed 会替换正在播放 Death 的表现模型。
	if hp <= 0.0 or form_index != 0 or transformed_stats.is_empty():
		return false
	_apply_form(1, true)
	form_lifetime_left = form_lifetime
	_refresh_form_speed_boost()
	form_transition_timer = active_transform_duration if active_cast else transform_duration
	play_visual_action(&"transform_active" if active_cast else &"transform", form_transition_timer)
	return true

func transform_to_small() -> bool:
	if hp <= 0.0 or form_index != 1:
		return false
	_apply_form(0, false)
	form_lifetime_left = 0.0
	form_transition_timer = revert_duration
	play_visual_action(&"revert", form_transition_timer)
	return true

func _apply_form(next_form_index: int, grant_max_hp_increase: bool, advance_form_serial: bool = true) -> void:
	pending_form_generation = -1
	_pending_extra_attacks.clear()
	var next_stats: Dictionary = transformed_stats if next_form_index == 1 else _base_form_stats
	if next_stats.is_empty():
		return
	var old_max_hp := max_hp
	var old_body_radius := body_radius
	var was_air := is_air
	max_hp = BattleNumbers.quantity(float(next_stats.get("hp", max_hp)))
	if grant_max_hp_increase:
		hp = minf(hp + maxf(max_hp - old_max_hp, 0.0), max_hp)
	else:
		hp = minf(hp, max_hp)
	damage = BattleNumbers.quantity(float(next_stats.get("damage", damage)))
	attack_passive_multipliers = next_stats.get("attack_passive_multipliers", []).duplicate()
	attack_lifesteal_ratios = next_stats.get("attack_lifesteal_ratios", []).duplicate()
	if not attack_passive_multipliers.is_empty():
		_attack_hit_index = 0
		_attack_swing_count = 0
	on_hit_max_health_ratio = float(next_stats.get("on_hit_max_health_ratio", 0.0))
	on_hit_tower_damage = BattleNumbers.quantity(float(next_stats.get("on_hit_tower_damage", 0.0)))
	attack_range = float(next_stats.get("range", attack_range))
	attack_interval = snappedf(float(next_stats.get("interval", attack_interval)), 0.01)
	first_hit_time = float(next_stats.get("first_hit", first_hit_time))
	passive_first_hit_time = float(next_stats.get("passive_first_hit", -1.0))
	empowered_first_hit = float(next_stats.get("empowered_first_hit", -1.0))
	move_speed = snappedf(float(next_stats.get("speed", move_speed)), 0.01)
	body_radius = float(next_stats.get("radius", body_radius))
	visual_radius = float(next_stats.get("visual_radius", body_radius))
	mass = float(next_stats.get("mass", mass))
	sight_range = float(next_stats.get("sight", sight_range))
	is_air = bool(next_stats.get("is_air", is_air))
	building_only = bool(next_stats.get("building_only", building_only))
	can_attack_air = bool(next_stats.get("can_attack_air", can_attack_air))
	projectile_speed = float(next_stats.get("projectile_speed", projectile_speed))
	projectile_spawn_at_edge = bool(next_stats.get("projectile_spawn_at_edge", false))
	projectile_spawn_offset = float(next_stats.get("projectile_spawn_offset", 0.0))
	projectile_collision_radius = float(next_stats.get("projectile_collision_radius", 4.0))
	active_buff_projectile_visual = StringName(next_stats.get("active_buff_projectile_visual", ""))
	projectile_visual = StringName(next_stats.get("projectile_visual", projectile_visual))
	projectile_visual_height = float(next_stats.get("projectile_visual_height", projectile_visual_height))
	projectile_visual_forward_offset = float(next_stats.get("projectile_visual_forward_offset", projectile_visual_forward_offset))
	projectile_visual_scale = float(next_stats.get("projectile_visual_scale", projectile_visual_scale))
	projectile_impact_visual = StringName(next_stats.get("projectile_impact_visual", projectile_impact_visual))
	splash_radius = float(next_stats.get("splash_radius", splash_radius))
	attack_knockback = float(next_stats.get("knockback", attack_knockback))
	form_index = next_form_index
	net_form_index = next_form_index
	if advance_form_serial:
		form_change_serial += 1
		net_form_change_serial = form_change_serial
	else:
		form_change_serial = net_form_change_serial
	transform_hit_count = 0
	# 攻击形态和射程已经改变，旧前摇/后摇不能带入新形态；在途远程弹体仍由主机独立推进。
	_target = null
	_attacking = false
	attack_timeline.cancel(true)
	_attack_visual_pending = false
	_attack_visual_first_strike = false
	_path = PackedVector2Array()
	_path_index = 0
	cancel_charge()
	_health_bar_center = Vector2(0.0, -visual_radius - HEALTH_BAR_HEAD_GAP - HEALTH_BAR_HEIGHT * 0.5)
	form_changed.emit(form_index)
	# 放大碰撞半径后立即做一次地形/建筑安全修正；单位间重叠仍交给本 tick 的统一推挤。
	if (body_radius > old_body_radius or (was_air and not is_air)) and not _in_client_mode() and battle_context != null:
		battle_context.ensure_unit_form_resize_safe(self)
	queue_redraw()

func is_form_transitioning() -> bool:
	return form_transition_timer > 0.0

func is_structure_rushing() -> bool:
	if _in_client_mode():
		return get_visual_action_time_left() > 0.0 and get_visual_action_name() in [&"rush_prepare", &"rush_dash", &"rush_hit"]
	return structure_rush.locked()

## 主动技能入口使用这一谓词；客户端只读主机同步的权限位，不从当前动画
## 另跑冲撞状态机。普通 READY 的权限位仍由主机原样同步。
func is_active_skill_rush_locked() -> bool:
	if _in_client_mode():
		if float(structure_rush.config.get("rush_distance", 0.0)) <= 0.0:
			return false
		return is_deployed() and not is_frozen() and not is_stunned() and (get_action_permissions_visual() & (ControlState.MOVE | ControlState.BASIC_ATTACK)) == 0
	return structure_rush.skill_locked()

func is_active_skill_casting() -> bool:
	return active_skill_cast_timer > 0.0

## 3D 表现使用完整方向；客户端读取主机快照，保证前方技能动作朝向与权威判定一致。
func get_visual_facing_direction() -> Vector2:
	if _body_facing_direction.is_zero_approx():
		_body_facing_direction = Vector2.UP if team == 0 else Vector2.DOWN
	if _in_client_mode():
		return net_facing_direction.normalized() if not net_facing_direction.is_zero_approx() else _body_facing_direction
	if (action_permissions() & ControlState.TURN) != 0:
		_body_facing_direction = _desired_facing_direction()
	return _body_facing_direction

func _desired_facing_direction() -> Vector2:
	if structure_rush.locked() and structure_rush.direction.length_squared() > 0.001:
		return structure_rush.direction
	if is_active_skill_facing_locked() and active_skill_cast_facing.length_squared() > 0.001:
		return active_skill_cast_facing
	if _attacking and _target != null and is_instance_valid(_target):
		var attack_direction: Vector2 = global_position.direction_to(_target.global_position)
		if attack_direction.length_squared() > 0.001:
			return attack_direction
	if _move_direction.length_squared() > 0.001:
		return _move_direction.normalized()
	return Vector2.UP if team == 0 else Vector2.DOWN

## 持续吐息目标只供动画朝向和光柱端点使用；它不会反向参与索敌、射程或伤害。
func has_continuous_visual_target() -> bool:
	if not continuous_attack:
		return false
	if _in_client_mode():
		return net_visual_state == 3 and net_has_continuous_target
	return _attacking and _target != null and is_instance_valid(_target) and _target.hp > 0.0

func get_continuous_visual_target_position() -> Vector2:
	if _in_client_mode():
		return net_continuous_target_pos
	if not has_continuous_visual_target():
		return get_visual_screen_position()
	if _target is Unit:
		return (_target as Unit).get_visual_screen_position()
	return _target.global_position

func get_continuous_visual_target_air_id() -> int:
	if not has_continuous_visual_target() or not (_target is Unit) or not _target.is_air:
		return -1
	return _target.net_id

func get_continuous_beam_endpoint_position() -> Vector2:
	var target_screen := get_continuous_visual_target_position()
	var air_target: Unit
	if _in_client_mode():
		if net_continuous_target_air_id >= 0:
			for body in get_tree().get_nodes_in_group("combatants"):
				if body is Unit and body.net_id == net_continuous_target_air_id and body.is_air:
					air_target = body
					break
	elif _target is Unit and is_instance_valid(_target) and _target.is_air:
		air_target = _target
	if air_target == null:
		return target_screen
	var fallback := Vector2(0.0, -air_target.visual_radius)
	return air_target.get_visual_screen_position() + air_target.get_meta("projectile_model_offset", fallback)

func set_continuous_beam_visible(visible: bool) -> void:
	if continuous_beam_visible == visible:
		return
	continuous_beam_visible = visible
	queue_redraw()

func set_continuous_beam_origin_world_position(world_position: Vector2) -> void:
	continuous_beam_origin_world_position = world_position
	continuous_beam_origin_tracks_model = true
	queue_redraw()

## 固定 tick 模拟入口，由 main._sim_step 以 SIM_DT 驱动
func sim_tick(dt: float, natural_lifecycle_prepared: bool = false, statuses_prepared: bool = false) -> void:
	if hp <= 0.0 and not death_form.waiting():
		return
	if not natural_lifecycle_prepared:
		prepare_natural_lifecycle(dt)
	if hp <= 0.0 or is_queued_for_deletion():
		return
	_prune_pending_extra_attacks()
	if not statuses_prepared:
		_tick_active_statuses(dt)
		prepare_action_clocks(dt)
		_apply_pending_form()
	_hit_flash_event_cooldown = maxf(0.0, _hit_flash_event_cooldown - dt)
	if battle_context == null or skill_dash_moved_tick != battle_context.simulation_tick(): _prev_pos = position
	_move_intent = Vector2.ZERO
	_forced_movement = false
	if _knockback_timer > 0.0:
		_tick_knockback_movement(dt)
	# 卡牌生成后进入部署时间：自身不索敌、不移动、不攻击，但实体已经存在，
	# 会参与碰撞，也能被敌方索敌、命中、受伤和施加状态。
	if _deploy_timer > 0.0:
		_deploy_timer = maxf(0.0, _deploy_timer - dt)
		if _deploy_timer < 0.000001:
			_deploy_timer = 0.0
		# 冰冻时长从命中当帧开始消耗；不会在部署结束后再额外补一整段冻结。
		# “不能移动”只锁自主行军；碰撞与击退等外力仍可改变位置，保证部署实体
		# 被命中后的附带效果不会延迟到部署结束才突然补播。
		if _deploy_timer <= 0.0:
			_just_deployed = true
			if is_building:
				_spawn_initial_summons()
		queue_redraw()
		if _deploy_timer > 0.0 or _forced_movement:
			return
	if is_building:
		_building_tick(dt, true)
		if hp <= 0.0 or is_queued_for_deletion():
			return
	if control.frozen_timer > 0.0 or control.stun_timer > 0.0:
		if control.frozen_timer <= 0.0 and control.stun_timer <= 0.0:
			queue_redraw()
		_charge_timer = 0.0
		_charged = false
		return
	if _attacking and _attack_visual_serial > 0:
		attack_timeline.advance_visual(dt, _effective_attack_speed_multiplier())
	_tick_pending_extra_attacks(dt)
	if _forced_movement:
		_charge_timer = 0.0
		_charged = false
		return
	# 突进末端无合法空位时继续等待；不能在穿单位状态恢复普攻。
	if skill_dash_active: return
	# 攻击锁和移动锁彼此独立：移动施法会继续追击/行军，但在技能窗口内绝不普攻；
	# 只锁移动的技能仍可原地攻击。纯 Buff 可配置空 locks，完全不改变基础行为。
	if is_active_skill_attack_locked():
		_tick_attack_locked_cast_movement(dt)
		return
	if form_transition_timer > 0.0:
		_tick_form_transition_movement(dt)
		return
	if structure_rush.phase == StructureRushState.Phase.RECOVERY or structure_rush.tick(self, dt):
		return
	attack_timeline.tick_cooldown(dt)
	# 默认命中后必须完整收招；配置允许的连招段结束且没有圈内目标时可提前转走。
	# 冻结会在上方提前 return，因此同样会暂停后摇计时。
	if attack_timeline.recovery > 0.0:
		if attack_recovery_cancel_every_hits > 0 and _attack_hit_index > 0 and _attack_hit_index % attack_recovery_cancel_every_hits == 0:
			# 复用权威索敌规则：目标死亡/离圈时优先换打圈内目标；完全没有
			# 下一次攻击目标时才解除 Attack，避免表现层提前猜测目标状态。
			_update_target(false)
			var has_next_attack_target := (
				_attacking
				and _target != null
				and is_instance_valid(_target)
				and _target_is_attackable(_target)
				and _target_gap(_target) <= attack_range
			)
			if not has_next_attack_target:
				attack_timeline.cancel(true)
				_attacking = false
			else:
				attack_timeline.tick_recovery(dt)
				_attacking = true
				if attack_timeline.recovery > 0.0:
					return
		else:
			attack_timeline.tick_recovery(dt)
			_attacking = true
			if attack_timeline.recovery > 0.0:
				return
	# 已起手的一击保持前摇；普通射程只用于起手，宽限只在命中节点检查。
	var committed_attack := _attacking and not continuous_attack and (attack_timeline.windup > 0.0 or not _attack_visual_pending)
	_update_target(committed_attack)
	committed_attack = committed_attack and _attacking and _target_is_attackable(_target)
	if _target != null:
		if _target_gap(_target) <= attack_range or committed_attack:
			if not terrain_traversal.leave_for_attack(self): return
			if continuous_attack:
				var continuous_target_id := int(_target.get_instance_id())
				if continuous_target_id != _continuous_visual_target_id:
					_continuous_visual_target_id = continuous_target_id
					_attack_visual_serial += 1
					attack_timeline.restart_visual()
			if not _attacking:
				# 行军已清除旧间隔；重新进入正常射程从本刀前摇开始。
				# 原地转火等未进入行军的路径仍保留已有攻击节奏。
				attack_timeline.begin_windup(_next_attack_first_hit_time(), _effective_attack_speed_multiplier())
				_attack_visual_pending = true
			_attacking = true
			_path = PackedVector2Array()
			_path_index = 0
			_attack(dt)
			return
	_cancel_attack_and_chase(dt)

func _cancel_attack_and_chase(dt: float) -> void:
	_attacking = false
	_continuous_visual_target_id = 0
	attack_timeline.cancel(true)
	_attack_visual_pending = true
	if not is_active_skill_movement_locked():
		_chase(dt)

## 施法期间禁止普攻时仍可按策略移动。进入攻击范围后只停在待攻位置，
## 让 cast 窗口结束的同一权威 tick 可以立即开始普通攻击。
func _tick_attack_locked_cast_movement(dt: float) -> void:
	_cancel_attack_for_cast()
	_update_target(false)
	if _target != null and is_instance_valid(_target) and _target_gap(_target) <= attack_range:
		return
	if is_active_skill_movement_locked():
		return
	_chase(dt)

## 变形期间用新形态的视野/射程立即决策：圈外继续移动，圈内等待但不开始攻击。
func _tick_form_transition_movement(dt: float) -> void:
	_attacking = false
	attack_timeline.cancel()
	_attack_visual_pending = false
	_update_target(false)
	if _target != null and is_instance_valid(_target) and _target_gap(_target) <= attack_range:
		return
	_chase(dt)

func is_deployed() -> bool:
	return _deploy_timer <= 0.0

func cancel_charge() -> void:
	_charge_timer = 0.0
	_charged = false

func on_movement_applied(distance: float, dt: float) -> void:
	target_protection.check_position(global_position)
	if _forced_movement:
		cancel_charge()
		return
	if distance > 0.01:
		if charge_time > 0.0:
			_charge_timer = minf(_charge_timer + dt, charge_time)
			_charged = _charge_timer >= charge_time
	elif _move_intent.length_squared() > 0.001:
		# 有行进意图但被堵停，不能站在原地继续积攒冲锋。
		cancel_charge()

## 部署范围效果：赵信生成的瞬间以自身为中心发动新月护卫，伤害四周地面敌人。
## 建筑/防御塔可受伤；击退只对非建筑 Unit 生效，空中单位完全不受影响。
## 击退距离经 apply_knockback 的质量因子衰减；赵信将轻单位倍率封顶 1.0。
## 由主机/单机的 _ready 在生成当帧触发，客户端击退位移由快照插值驱动。
func _perform_deploy_sweep() -> void:
	if deploy_sweep_radius <= 0.0:
		return
	_sweep_fx_timer = SWEEP_FX_DURATION
	var any_landed := false
	var displacement_order: Array = battle_context.damage_batch().next_displacement_order(self) if battle_context != null else []
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == self or not is_instance_valid(c) or c.team == team or c.hp <= 0.0:
			continue
		if not CombatInteraction.allows(c, self): continue
		if c is Unit and (c as Unit).is_air:
			continue
		# 命中判定与法术/溅射一致：技能圆与目标碰撞圆相交即命中。
		if global_position.distance_to(c.global_position) > deploy_sweep_radius + c.body_radius:
			continue
		var was_alive: bool = c.hp > 0.0
		if deploy_sweep_damage > 0.0:
			any_landed = c.take_damage(deploy_sweep_damage, self, team, global_position) or any_landed
		if was_alive and c.hp <= 0.0:
			on_enemy_killed(c)
		if c is Unit and is_instance_valid(c) and c.hp > 0.0 and deploy_sweep_knockback > 0.0:
			(c as Unit).apply_knockback(global_position, deploy_sweep_knockback, deploy_sweep_duration, deploy_sweep_mass_factor_max, displacement_order)

	if any_landed and battle_context != null:
		battle_context.notify_unit_audio_event(self, &"deploy:hit", global_position)

func can_receive_knockback(origin: Vector2, distance: float, duration: float, mass_factor_max: float) -> bool:
	return hp > 0.0 and not structure_rush.control_immune() and not is_queued_for_deletion() and not is_building and origin.is_finite() and is_finite(distance) and distance > 0.0 and is_finite(duration) and duration > 0.0 and is_finite(mass_factor_max)

func apply_knockback(origin: Vector2, distance: float, duration: float = 0.2, mass_factor_max: float = 1.4, displacement_order: Array = [], interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	# 必须先校验再替换；拒绝的请求不得破坏旧位移。
	if not can_receive_knockback(origin, distance, duration, mass_factor_max): return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().submit_knockback(self, origin, distance, duration, mass_factor_max, displacement_order)
		return
	structure_rush.interrupt_preparation(self)
	# 当前没有异步位移完成回调。只替换状态，清掉旧 Tick 尚未消费的移动意图。
	_move_intent = Vector2.ZERO
	_forced_movement = false
	var direction := origin.direction_to(global_position)
	if direction.length_squared() < 0.001:
		direction = Vector2.DOWN if team == 0 else Vector2.UP
	var mass_factor := clampf(4.0 / maxf(mass, 1.0), 0.35, maxf(mass_factor_max, 0.35))
	knockback.replace(direction, distance * mass_factor, duration)
	cancel_basic_attack(&"knockback")

func _tick_knockback_movement(dt: float) -> void:
	# 最后一 Tick 只结算剩余时长，避免浮点余量让 0.25s 击退多走一个完整 20Hz Tick。
	_move_intent = knockback.advance(dt)
	_forced_movement = true

func _target_gap(target: Node2D) -> float:
	if target.has_method("surface_gap_to_circle"):
		return target.surface_gap_to_circle(global_position, body_radius)
	return maxf(0.0, global_position.distance_to(target.global_position) - body_radius - target.body_radius)

## 人物与建筑都使用权威圆柱的圆形底面；建筑部署方格只负责限制下牌。
func surface_gap_to_circle(center: Vector2, radius: float) -> float:
	if not is_building:
		return maxf(0.0, center.distance_to(global_position) - body_radius - radius)
	# 建筑的规则方格占地不参与攻击距离、寻路或防穿模计算。
	return maxf(0.0, center.distance_to(global_position) - body_radius - radius)

## 旧动作窗口在命令执行前推进一次；本边界新动作从下个边界开始推进。
func prepare_action_clocks(dt: float) -> void:
	target_protection.advance(dt, global_position)
	# 仅推进旧恢复锁；新撞击仍在后续行动阶段创建，下个边界才首次扣时。
	if structure_rush.phase == StructureRushState.Phase.RECOVERY:
		structure_rush.tick(self, dt)
	var age_form := form_index == 1 and form_lifetime_left > 0.0 and not (form_lifetime_after_transition and form_transition_timer > 0.0)
	# 生命周期与普通技能时钟不因硬控暂停。冰冻在施加入口取消施法。
	if _visual_action_time_left > 0.0:
		_visual_action_time_left = maxf(0.0, _visual_action_time_left - dt)
	if form_transition_timer > 0.0:
		form_transition_timer = maxf(0.0, form_transition_timer - dt)
		if form_transition_timer < 0.000001: form_transition_timer = 0.0
	if active_skill_cast_timer > 0.0:
		if is_active_skill_attack_locked():
			_cancel_attack_for_cast()
		active_skill_cast_timer = maxf(0.0, active_skill_cast_timer - dt)
		if active_skill_cast_timer < 0.000001:
			active_skill_cast_timer = 0.0
			active_skill_cast_facing = Vector2.ZERO
			active_skill_cast_locks.clear()
	# 限时形态按权威时间到期，硬控不延长增益或转换窗口。
	if age_form:
		form_lifetime_left = maxf(0.0, form_lifetime_left - dt)
		if form_lifetime_left <= 0.000001:
			transform_to_small()

## 固定名单中的自然寿命与定时复生；不在行动收集内迁移实体。
## 判断与 sim_tick 到达 _building_tick 的门禁一致，包括部署最后一个 Tick。
func prepare_natural_lifecycle(dt: float) -> void:
	if not _in_client_mode() and death_form.used:
		death_form.advance(self, dt)
	if hp <= 0.0 or is_queued_for_deletion(): return
	if battle_context != null and lifecycle_birth_tick == battle_context.simulation_tick(): return
	_tick_timed_revival(dt)
	if not is_building or hp <= 0.0 or is_queued_for_deletion(): return
	if _deploy_timer > 0.0:
		if maxf(_deploy_timer - dt, 0.0) >= 0.000001 or _knockback_timer > 0.0: return
	_tick_building_lifetime(dt)

func _tick_building_lifetime(dt: float) -> void:
	if lifespan > 0.0:
		var lifetime_step := minf(dt, _lifespan_left)
		_lifespan_left -= lifetime_step
		if lifespan_hp_decay and lifetime_step > 0.0:
			# 自然寿命衰减不算受击，不触发护盾、资源、闪白或攻击者击杀收益。
			_lifespan_decay_remainder += max_hp * lifetime_step / lifespan
			var decay := roundf(_lifespan_decay_remainder)
			_lifespan_decay_remainder -= decay
			hp = maxf(0.0, hp - decay)
			if hp <= 0.0:
				_die()
				return
		if _lifespan_left <= 0.0:
			hp = 0.0
			_die()
			return

func _building_tick(dt: float, natural_lifecycle_prepared: bool = false) -> void:
	if not natural_lifecycle_prepared:
		_tick_building_lifetime(dt)
	if hp <= 0.0 or is_queued_for_deletion(): return
	if not _initial_summons_spawned:
		_spawn_initial_summons()
	if spawn_interval > 0.0:
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			_spawn_timer += spawn_interval
			if not is_frozen() and not is_stunned():
				_spawn_batch()

func _spawn_initial_summons() -> void:
	if _initial_summons_spawned or spawn_interval <= 0.0:
		return
	_initial_summons_spawned = true
	if not is_frozen() and not is_stunned():
		_spawn_batch()

func _spawn_batch() -> void:
	if battle_context == null or spawn_id.is_empty():
		return
	var summon_stats := CardDB.get_unit_stats(spawn_id)
	if summon_stats.is_empty():
		push_error("周期召唤引用了不存在的单位：%s" % spawn_id)
		return
	var summon_radius := float(summon_stats.get("radius", 14.0))
	var count := maxi(spawn_count, 1)
	if spawn_side == "map_side":
		# 以地图中线决定产出侧：左半区始终在左侧，右半区始终在右侧。
		var side := Vector2.LEFT if global_position.x < battle_context.field_width() * 0.5 else Vector2.RIGHT
		var lateral_step := summon_radius * 2.0 + SUMMON_SEPARATION
		var first_lateral := -float(count - 1) * lateral_step * 0.5
		var spawn_distance := body_radius + summon_radius + SUMMON_SEPARATION
		for index in count:
			var lateral := first_lateral + float(index) * lateral_step
			var spawn_pos := global_position + side * spawn_distance + Vector2.UP * lateral
			battle_context.spawn_summoned(team, spawn_id, spawn_pos)
		_spawn_counter += count
		return
	for index in count:
		var direction: Vector2 = SPAWN_DIRECTIONS[_spawn_counter % SPAWN_DIRECTIONS.size()]
		var spawn_distance := body_radius + summon_radius + SUMMON_SEPARATION
		var spawn_pos: Vector2 = global_position + direction * spawn_distance
		_spawn_counter += 1
		battle_context.spawn_summoned(team, spawn_id, spawn_pos)

## 目标管理：攻击中的目标失效/超距时优先原地换打射程内最近合法目标；
## 只有没有替代目标时才退出 Attack 并按视野规则重新索敌/追击。
func _update_target(keep_windup_target: bool = false) -> void:
	# 前摇期间保留有效目标，距离留到命中节点判定；其他阶段按正常射程索敌。
	# 死亡、失效仍沿用原有替换目标规则。
	if _attacking:
		if _target_is_attackable(_target) and (_target_gap(_target) <= attack_range or keep_windup_target):
			return
		var in_range_retarget := _find_nearest_attackable_in_range()
		if in_range_retarget != null:
			# 这是 Attack -> Attack，不是一次强制打断。保留当前 windup/cooldown/recovery，
			# 让下一击沿用原有 cadence；击退、变形、技能锁等明确打断仍走各自的重置入口。
			_target = in_range_retarget
			_move_intent = Vector2.ZERO
			_path = PackedVector2Array()
			_path_index = 0
			_repath_cd = 0.0
			return
		_target = null
		_attacking = false
		attack_timeline.cancel()
		_path = PackedVector2Array()
		_path_index = 0
	# Godot 的已释放对象引用不等同于普通 null，任何 `is Type` 判断前都必须先清理。
	if not is_instance_valid(_target):
		_target = null
		_attacking = false
		attack_timeline.cancel()
		_path = PackedVector2Array()
		_path_index = 0
	if _target != null:
		var drop := false
		if not is_instance_valid(_target) or _target.hp <= 0.0:
			drop = true
		elif building_only and not _is_struct(_target):
			drop = true
		elif not can_attack_air and _target is Unit and (_target as Unit).is_air:
			drop = true
		elif not _target is Tower and _target_gap(_target) > sight_range:
			drop = true
		if drop:
			_target = null
			_attacking = false
			attack_timeline.cancel()
			_path = PackedVector2Array()
			_path_index = 0
	# 非攻击状态：视野内所有合法战斗对象统一按表面距离排序。
	# 没有视野目标时才回退到同路推塔，不让较远的小兵抢走更近的塔。
	var nearest := _find_nearest_distraction()
	if nearest == null:
		nearest = _find_nearest_tower()
	elif is_instance_valid(_target) and _target_is_attackable(_target) and _target_gap(_target) <= sight_range:
		# 同距保留当前目标，避免枚举顺序或浮点噪声导致来回转向。
		if _target_gap(_target) <= _target_gap(nearest) + 0.01:
			nearest = _target
	if nearest != _target:
		_target = nearest
		_path = PackedVector2Array()
		_path_index = 0
		_repath_cd = 0.0

func _target_is_attackable(target) -> bool:
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return false
	if not CombatInteraction.allows(target, self):
		return false
	if target == self or target.team == team:
		return false
	if building_only and not _is_struct(target):
		return false
	if not can_attack_air and target is Unit and (target as Unit).is_air:
		return false
	return true

## 攻击态无缝换目标专用：只限定距离，所有 team/hp/攻城/空中规则统一复用
## _target_is_attackable()，避免与常规索敌逐渐形成两套合法性判断。
func _find_nearest_attackable_in_range() -> Node2D:
	var best: Node2D = null
	var best_gap := INF
	for candidate in get_tree().get_nodes_in_group("combatants"):
		if not candidate is Node2D or not _target_is_attackable(candidate):
			continue
		var candidate_node := candidate as Node2D
		var gap := _target_gap(candidate_node)
		if gap <= attack_range and gap < best_gap:
			best = candidate_node
			best_gap = gap
	return best

func _is_struct(c: Node) -> bool:
	return c is Tower or (c is Unit and (c as Unit).is_building)

func _find_nearest_distraction() -> Node2D:
	var best: Node2D = null
	var best_dist := sight_range
	for c in get_tree().get_nodes_in_group("combatants"):
		if not c is Node2D or not _target_is_attackable(c):
			continue
		var dist := _target_gap(c)
		if dist <= best_dist:
			best = c
			best_dist = dist
	return best

func _find_nearest_tower() -> Node2D:
	var enemy_king: Tower = null
	var princess_towers: Array[Tower] = []
	var enemy_towers: Array[Tower] = []
	for c in get_tree().get_nodes_in_group("combatants"):
		if not c is Tower or c.team == team or c.hp <= 0.0:
			continue
		var tower := c as Tower
		enemy_towers.append(tower)
		if tower.is_king:
			enemy_king = tower
		else:
			princess_towers.append(tower)
	# 攻击范围内的塔按最近表面距离选择。这里明确包含水晶，且不检查 activated，
	# 所以公主塔仍存活、水晶仍休眠时，贴近水晶的单位也能直接攻击它。
	var in_range_towers: Array[Tower] = []
	for tower in enemy_towers:
		if _target_gap(tower) <= attack_range:
			in_range_towers.append(tower)
	if not in_range_towers.is_empty():
		return _nearest_tower_from(in_range_towers)
	# 没有塔进入攻击范围时，无仇恨行军仍严格保留当前左右半区：同路公主塔存活时
	# 先推同路，同路塔被摧毁后改推水晶，不能被另一侧仍存活的公主塔跨路吸走。
	if enemy_king == null:
		return _nearest_tower_from(princess_towers)
	var lane_sign := -1.0 if global_position.x < enemy_king.global_position.x else 1.0
	var same_lane: Array[Tower] = []
	for tower in princess_towers:
		var tower_lane_sign := -1.0 if tower.global_position.x < enemy_king.global_position.x else 1.0
		if tower_lane_sign == lane_sign:
			same_lane.append(tower)
	if not same_lane.is_empty():
		return _nearest_tower_from(same_lane)
	return enemy_king

func _nearest_tower_from(towers: Array[Tower]) -> Tower:
	var best: Tower = null
	var best_dist := INF
	for tower in towers:
		var dist := _target_gap(tower)
		if dist < best_dist:
			best = tower
			best_dist = dist
	return best

func _chase(dt: float) -> void:
	# 建筑共享通用索敌和攻击状态机，但永远不能为了圈外目标移动。
	if is_building:
		return
	if _target == null or not is_instance_valid(_target):
		return
	if is_air or terrain_traversal.enabled:
		_prepare_movement((_target.global_position - global_position).normalized(), dt)
		return
	# 绕过障碍后按当前位置接近射程边缘，不再追赶出发时计算的旧站位。
	if _try_direct_approach(dt):
		return
	# 没有视野仇恨时，塔只是推进方向。地面单位在宽松的低成本路线场上
	# 计算一次推进路径，并不持续跑 A*；只有目标或动态障碍改变才重算。
	if _target is Tower:
		_chase_march(dt)
		return
	_chase_target(dt)

func _try_direct_approach(dt: float) -> bool:
	if battle_context == null:
		return false
	var toward := _target.global_position - global_position
	if toward.length_squared() < 0.001:
		return false
	# 只检测到攻击站位；目标本身仍参与碰撞检查，不检测到其中心。
	var stop_distance: float = attack_range + body_radius + _target.body_radius
	var goal := _target.global_position - toward.normalized() * maxf(stop_distance - 0.01, 0.0)
	if not battle_context.is_ground_segment_walkable(global_position, goal, body_radius, self):
		return false
	_path = PackedVector2Array()
	_path_index = 0
	_path_goal = Vector2(INF, INF)
	_repath_cd = 0.0
	_prepare_movement(toward.normalized(), dt)
	return true

func _chase_march(dt: float) -> void:
	_repath_cd -= dt
	var needs_path := _path_target != _target or _path_goal.x == INF or _path_index >= _path.size()
	if not needs_path and _path_index < _path.size() and battle_context != null:
		needs_path = not battle_context.is_ground_segment_walkable(global_position, _path[_path_index], body_radius, self)
	if needs_path and _repath_cd <= 0.0:
		_recompute_path()
		_repath_cd = MARCH_REPATH_INTERVAL
	_follow_current_path(dt)

func _chase_target(dt: float) -> void:
	_repath_cd -= dt
	if _repath_cd <= 0.0 or _path_target != _target or _path_goal.x == INF:
		_recompute_path()
	_follow_current_path(dt)

func _follow_current_path(dt: float) -> void:
	if _path_index < _path.size():
		while global_position.distance_to(_path[_path_index]) < PATH_REACH:
			_path_index += 1
			if _path_index >= _path.size():
				break
	if _path_index < _path.size():
		_prepare_movement((_path[_path_index] - global_position).normalized(), dt)
	elif _target != null and _target_gap(_target) > attack_range:
		# A* 终点落在离散格心，可能比精确攻击圈多出几像素。所有目标都补齐最后一段，
		# 尤其不能让 Tower 在路径结束后停在射程外；连续碰撞仍会阻止单位穿入塔身。
		_prepare_movement((_target.global_position - global_position).normalized(), dt)

func _prepare_movement(direction: Vector2, _dt: float) -> void:
	if direction.length_squared() < 0.001:
		return
	# 路径拐点和路线汇入采用短暂方向插值，形成弧线感，避免突然水平切线。
	if _move_direction.length_squared() < 0.001:
		_move_direction = direction.normalized()
	else:
		var turn_weight := minf(_dt * 8.0, 1.0)
		_move_direction = _move_direction.lerp(direction.normalized(), turn_weight).normalized()
	var speed_multiplier := _effective_movement_multiplier()
	_move_intent = _move_direction * snappedf(move_speed * speed_multiplier, 0.01)

func _recompute_path() -> void:
	if _target == null:
		return
	# 终点选在目标攻击圈的迎敌侧，避免目标位于阻挡格时被固定偏到塔背后。
	var to_target: Vector2 = _target.global_position - global_position
	var stop_distance: float = attack_range + body_radius + _target.body_radius
	var goal: Vector2 = _target.global_position
	if to_target.length_squared() > 0.001:
		goal -= to_target.normalized() * maxf(stop_distance - PATH_REACH * 0.5, 0.0)
	_recompute_path_to(goal)

func _recompute_path_to(goal: Vector2) -> void:
	_repath_cd = REPATH_INTERVAL
	_path_target = _target
	_path_goal = goal
	_path = PackedVector2Array()
	_path_index = 0
	var nav_grid := _get_nav()
	if nav_grid == null:
		return
	var full: PackedVector2Array
	if battle_context != null:
		full = battle_context.find_ground_path(global_position, goal, _target, body_radius)
	else:
		full = nav_grid.find_path(global_position, goal)
	if full.size() >= 2:
		_path = full
		_path_index = 1

func _attack(dt: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_attacking = false
		return
	if attack_timeline.windup > 0.0:
		_try_start_attack_visual(maxf(attack_timeline.windup - dt, 0.0))
		attack_timeline.tick_windup(dt)
		if attack_timeline.windup > 0.0:
			return
	if continuous_attack:
		_deal_continuous_damage(damage * active_damage_multiplier * _effective_attack_speed_multiplier() * dt)
		return
	_try_start_attack_visual(attack_timeline.cooldown)
	if attack_timeline.cooldown <= 0.0:
		# 只在命中节点检查宽限；超距取消本次挥击，不伤害、不进入后摇。
		if _target_gap(_target) > attack_range + ArenaRules.ATTACK_RANGE_TOLERANCE:
			_cancel_attack_and_chase(dt)
			return
		# 连招节奏：若配置了 attack_pattern，则按本次命中后的间隔取值；否则固定为 attack_interval。
		var hit_index := _attack_hit_index
		var next_attack_gap := _next_attack_gap()
		attack_timeline.commit_hit(next_attack_gap)
		var base_hit_damage := damage * _attack_damage_multiplier(hit_index) * active_damage_multiplier * (charge_damage_multiplier if _charged else 1.0)
		var hit_damage := base_hit_damage
		var first_strike := _attack_visual_first_strike and first_strike_damage_multiplier != 1.0
		# 先声夺人：对每个目标的首次普攻附加伤害倍率；远程弹体在出手 tick 固化该次伤害。
		if first_strike_damage_multiplier != 1.0:
			var first_strike_target_id := _target.get_instance_id()
			if not _first_strike_hit_target_ids.has(first_strike_target_id):
				_first_strike_hit_target_ids[first_strike_target_id] = true
				hit_damage *= first_strike_damage_multiplier
				first_strike = true
		basic_attack_sequence += 1
		var attack_effects: Dictionary = {"attack_id": basic_attack_sequence, "cycle_id": _attack_visual_serial}
		if first_strike:
			# 效果随弹体携带到真实命中点；表现层不会在出手或预判 first_hit 时播放被动音。
			attack_effects["first_strike"] = true
		# 对空能力同时约束溅射层，避免对地炮弹借地面主目标误伤空军。
		if not can_attack_air:
			attack_effects["ground_only"] = true
		if not bleed_definition.is_empty():
			attack_effects["bleed_definition"] = bleed_definition
			attack_effects["bleed_full"] = buffs.remaining(&"blood_rage") > 0.0
		if empowered_attack_ready:
			if not empowered_execute.is_empty():
				var stacks: int = _target.bleeding.stacks(self)
				hit_damage = float(empowered_execute.damage) * active_damage_multiplier * (1.0 + stacks * float(empowered_execute.execute_damage_per_stack))
				attack_effects["execute_reset"] = true
				empowered_execute = {}
			hit_damage *= empowered_attack_damage_multiplier
			if empowered_attack_blind_charges > 0:
				attack_effects["blind_charges"] = empowered_attack_blind_charges
			empowered_attack_ready = false
			empowered_attack_damage_multiplier = 1.0
			empowered_attack_speed_multiplier = 1.0
			empowered_attack_blind_charges = 0
		# 挥击序号与表现层攻击动画序号同步推进，供命中回血按三段循环取模。
		_attack_swing_count += 1
		mark_skill_resource_combat_activity()
		add_skill_resource(skill_resource_attack_gain)
		var attack_form_index := form_index
		if projectile_speed <= 0.0 and battle_context != null and battle_context.damage_batch().collecting:
			attack_effects["delivery_callback"] = _settle_melee_delivery.bind(form_change_serial, _attack_visual_serial, true)
		var completed := _perform_attack_strike(_target, hit_damage, attack_effects)
		if completed:
			_queue_extra_attack_hits(hit_index, base_hit_damage, _target)
		else:
			_attack_hit_index = hit_index
			_attack_swing_count -= 1
		# 这一击若触发形态变化，新形态已清空旧攻击状态；不能再写回旧形态的后摇。
		if form_index != attack_form_index:
			return
		# 从命中点锁定到下一次攻击动作应当开始的时刻，即当前动作的后摇段。
		# 若目标仍在射程内，计时结束后无缝开始下一次前摇；若已离开，则此时才追击。
		attack_timeline.begin_recovery(next_attack_gap, _next_attack_first_hit_time(), _effective_attack_speed_multiplier())
		_attack_visual_pending = true
		cancel_charge()

## 连招间距：attack_pattern 为每次命中后到下一次命中的间隔，按数组顺序循环。
func _next_attack_gap() -> float:
	if attack_pattern.is_empty():
		_attack_hit_index += 1
		return snappedf(attack_interval / _effective_attack_speed_multiplier(), 0.01)
	var gap: float = float(attack_pattern[_attack_hit_index % attack_pattern.size()])
	_attack_hit_index += 1
	return maxf(snappedf(gap / _effective_attack_speed_multiplier(), 0.01), 0.01)

func _effective_attack_speed_multiplier() -> float:
	var multiplier := maxf(active_attack_speed_multiplier, 0.01)
	if control.attack_speed_slow_timer > 0.0 and not active_buff_ignores_attack_speed_slow:
		multiplier *= control.attack_speed_slow_multiplier
	return maxf(multiplier, 0.01)

## 前摇按尚未出手的循环段选取；命中间隔仍由 attack_interval 决定。
func _next_attack_first_hit_time() -> float:
	return empowered_first_hit if empowered_attack_ready and empowered_first_hit >= 0.0 else _attack_first_hit_for_segment(_attack_swing_count)

func _attack_first_hit_for_segment(segment: int) -> float:
	if passive_first_hit_time >= 0.0 and not attack_passive_multipliers.is_empty() and float(attack_passive_multipliers[posmod(segment, attack_passive_multipliers.size())]) > 0.0:
		return passive_first_hit_time
	return first_hit_time

## 表现读取已发布的攻击序号，不能用命中后已经前进的循环计数。
func get_attack_first_hit_time_visual() -> float:
	if empowered_first_hit >= 0.0 and get_attack_visual_serial() == get_empowered_attack_visual_serial():
		return empowered_first_hit
	return _attack_first_hit_for_segment(maxi(get_attack_visual_serial() - 1, 0))

func _attack_damage_multiplier(hit_index: int) -> float:
	if attack_damage_multipliers.is_empty():
		return 1.0
	return maxf(float(attack_damage_multipliers[hit_index % attack_damage_multipliers.size()]), 0.0)

## 每次攻击在命中前 first_hit_time 发出一次表现序号；对远程单位，这个时刻就是出手/离弦点。
## 表现层可以据此播放完整动作，但权威弹体仍只在下面的固定 tick 出手逻辑中生成。
func _try_start_attack_visual(time_until_hit: float) -> void:
	var hit_delay := _next_attack_first_hit_time()
	if continuous_attack or not _attack_visual_pending or time_until_hit > hit_delay / _effective_attack_speed_multiplier() + 0.001:
		return
	_attack_visual_pending = false
	_attack_visual_first_strike = false
	if first_strike_damage_multiplier != 1.0 and _target != null and is_instance_valid(_target):
		_attack_visual_first_strike = not _first_strike_hit_target_ids.has(_target.get_instance_id())
	_attack_visual_serial += 1
	# 可取消的连招以前用每次尝试的序号选片，取消一拳会令动作与伤害/间隔错位。
	# 序号仍严格递增（快照/声音去重不变），余数对齐尚未结算的权威拳段。
	if not attack_passive_multipliers.is_empty():
		_attack_visual_serial += posmod(_attack_swing_count - (_attack_visual_serial - 1), attack_passive_multipliers.size())
	elif not attack_pattern.is_empty():
		_attack_visual_serial += posmod(_attack_hit_index - (_attack_visual_serial - 1), attack_pattern.size())
	elif not attack_extra_hit_damage_multipliers.is_empty():
		_attack_visual_serial += posmod(_attack_hit_index - (_attack_visual_serial - 1), attack_extra_hit_damage_multipliers.size())
	elif heal_every_hits > 0:
		# 命中计数被动与已出手次数对齐；取消的前摇不占用被动攻击段。
		_attack_visual_serial += posmod(_attack_swing_count - (_attack_visual_serial - 1), heal_every_hits)
	# 固定 Tick 跨过前摇起点时保留已流逝部分；客户端按同一个基础速率进度 seek。
	attack_timeline.align_visual(hit_delay, time_until_hit, _effective_attack_speed_multiplier())
	if empowered_attack_ready:
		_empowered_attack_visual_serial = _attack_visual_serial

## 每次真实命中的独立附加量；中央/强化等基础倍率不影响它。
func on_hit_passive_damage(target: Node2D) -> float:
	if on_hit_max_health_ratio <= 0.0:
		return 0.0
	var multiplier := 1.0
	if not attack_passive_multipliers.is_empty():
		multiplier = float(attack_passive_multipliers[posmod(_attack_swing_count - 1, attack_passive_multipliers.size())])
	if target is Tower:
		return BattleNumbers.quantity(on_hit_tower_damage * multiplier)
	return BattleNumbers.quantity(maxf(float(target.max_hp), 0.0) * on_hit_max_health_ratio * multiplier)

func _deal_attack_damage(amount: float, effects: Dictionary = {}) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_deal_attack_damage_to(_target, amount, effects)

## 龙王等持续普攻与主动持续伤害共用 BattleContext 的权威伤害脉冲结算。
## 龙王仍由 _attack(dt) 以 damage*dt 驱动，并保留自身的溅射和普攻击中回调。
func _deal_continuous_damage(amount: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if battle_context != null:
		battle_context.apply_damage_pulse(self, _target, amount, splash_radius, global_position, true, form_index, {"continuous_damage": true, "splash_match_primary_air": card_id == "aurelionsol"})
		return
	var result := _continuous_damage_stream.hit(_target, amount, self, team, global_position)
	if result.landed:
		on_attack_landed(form_index, 0.0)

func _deal_attack_damage_to(target: Node2D, amount: float, effects: Dictionary = {}) -> bool:
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return false
	if battle_context != null:
		return battle_context.launch_attack(self, target, amount, projectile_speed, splash_radius, attack_knockback, projectile_color, effects)
	else:
		var was_alive: bool = target.hp > 0.0
		var result := BattleNumbers.hit(target, BattleNumbers.quantity(amount) + on_hit_passive_damage(target), self, team, global_position)
		var landed: bool = result.landed
		if landed:
			if target is Unit and int(effects.get("blind_charges", 0)) > 0:
				(target as Unit).apply_blind(int(effects.blind_charges))
			on_attack_landed(-1, float(result.health_lost))
			if was_alive and target.hp <= 0.0:
				on_enemy_killed(target)

		return landed

## 近战提交只是暂记段号；批次拒绝命中时撤回本段及依附追加刀。
## 形态已换代时不写回旧循环；致盲正式出手不进入伤害回执，保留消费例外。
func _settle_melee_delivery(delivered: bool, generation: int, cycle: int, advances_segment: bool) -> void:
	if delivered or generation != form_change_serial: return
	_attack_swing_count = maxi(_attack_swing_count - 1, 0)
	if advances_segment:
		_attack_hit_index = maxi(_attack_hit_index - 1, 0)
		_pending_extra_attacks.assign(_pending_extra_attacks.filter(func(pending): return int(pending.cycle_id) != cycle))

## 每一刀都独立消费一次致盲。剑圣 Passive 的第二刀因此确实算作第二次普通攻击。
func _perform_attack_strike(target: Node2D, amount: float, effects: Dictionary = {}) -> bool:
	if blind_attack_charges > 0:
		blind_attack_charges -= 1
		queue_redraw()
		return true
	# 远程单位在这里进入 BattleContext.launch_attack，弹体与出手 tick 同步；命中由弹体抵达后结算。
	return _deal_attack_damage_to(target, amount, effects)

func _queue_extra_attack_hits(hit_index: int, base_hit_damage: float, target: Node2D) -> void:
	if hit_index < 0 or attack_extra_hit_damage_multipliers.is_empty():
		return
	var segment := hit_index % attack_extra_hit_damage_multipliers.size()
	var configured_multipliers = attack_extra_hit_damage_multipliers[segment]
	var multipliers: Array = configured_multipliers if configured_multipliers is Array else [configured_multipliers]
	var configured_delays = attack_extra_hit_delays[segment] if segment < attack_extra_hit_delays.size() else []
	var delays: Array = configured_delays if configured_delays is Array else [configured_delays]
	for index in multipliers.size():
		var multiplier := maxf(float(multipliers[index]), 0.0)
		if multiplier <= 0.0:
			continue
		var delay := float(delays[index]) if index < delays.size() else 0.0
		_pending_extra_attacks.append({
			"target_ref": weakref(target), "cycle_id": _attack_visual_serial, "form_generation": form_change_serial,
			"presentation_source": PresentationConfig.attack_source(self),
			"damage": base_hit_damage * multiplier,
			"time_left": maxf(delay / _effective_attack_speed_multiplier(), 0.0),
		})

func _prune_pending_extra_attacks() -> void:
	if _pending_extra_attacks.is_empty(): return
	_pending_extra_attacks.assign(_pending_extra_attacks.filter(func(pending):
		var target = (pending.target_ref as WeakRef).get_ref()
		return is_instance_valid(target) and target.hp > 0.0 and not target.is_queued_for_deletion()))

func _tick_pending_extra_attacks(dt: float) -> void:
	if hp <= 0.0:
		_pending_extra_attacks.clear()
		return
	_prune_pending_extra_attacks()
	var waiting: Array[Dictionary] = []
	for pending in _pending_extra_attacks:
		pending.time_left = maxf(float(pending.time_left) - dt, 0.0)
		if float(pending.time_left) > 0.001:
			waiting.append(pending)
			continue
		var target = (pending.target_ref as WeakRef).get_ref()
		if not target is Node2D or not is_instance_valid(target) or target.hp <= 0.0:
			continue
		_attack_swing_count += 1
		mark_skill_resource_combat_activity()
		add_skill_resource(skill_resource_attack_gain)
		basic_attack_sequence += 1
		var effects := {"presentation_source": pending.presentation_source, "attack_id": basic_attack_sequence, "cycle_id": pending.get("cycle_id", _attack_visual_serial)}
		if projectile_speed <= 0.0 and battle_context != null and battle_context.damage_batch().collecting:
			effects["delivery_callback"] = _settle_melee_delivery.bind(form_change_serial, int(effects.cycle_id), false)
		if not _perform_attack_strike(target as Node2D, float(pending.damage), effects):
			_attack_swing_count = maxi(_attack_swing_count - 1, 0)
	_pending_extra_attacks.assign(waiting)

## 主机在伤害真正落到目标后调用，统一提交命中资源、形态计数与存活收益；
## 赵信等配置了命中回血的单位也在这里结算，未真正造成伤害的挥击不触发回复。
func on_attack_landed(attack_form_index: int = -1, landed_damage: float = 0.0, submitted_swing: int = -1, source_generation: int = -1) -> void:
	# 远程弹体可以在攻击者死亡后抵达；此时只保留已经结算给目标的伤害，
	# 不再给已退出战斗的攻击者计层、回血、充能或触发形态切换。
	if hp <= 0.0:
		return
	var landed_form := form_index if attack_form_index < 0 else attack_form_index
	# 在途小纳尔回旋镖不会在大形态下误算成大纳尔的 4 次近战命中。
	if landed_form != form_index or (source_generation >= 0 and source_generation != form_change_serial):
		return
	if transform_after_hits > 0 and form_index == 0:
		transform_hit_count += 1
		if transform_hit_count >= transform_after_hits:
			if is_frozen(): pending_form_generation = form_change_serial
			else: transform_to_mega()
	elif revert_after_hits > 0 and form_index == 1:
		transform_hit_count += 1
		if transform_hit_count >= revert_after_hits:
			if is_frozen(): pending_form_generation = form_change_serial
			else: transform_to_small()
	var definition := PresentationConfig.for_form(_base_form_stats, form_index)
	var max_stacks := int(definition.get("hit_haste_max_stacks", 0))
	if max_stacks > 0:
		var previous_speed := _effective_attack_speed_multiplier()
		var stacks := mini(int(buffs.strongest(&"hit_haste", &"stacks", 0.0)) + 1, max_stacks)
		buffs.apply(&"hit_haste", &"attack", float(definition.hit_haste_duration), {
			"stacks": stacks, "attack_speed": 1.0 + stacks * float(definition.hit_haste_per_stack)})
		_rescale_attack_phase(previous_speed)
	add_skill_resource(skill_resource_hit_gain)
	_try_heal_on_hit(submitted_swing)
	var cycle_ratio := 0.0
	if not attack_lifesteal_ratios.is_empty():
		var swing := submitted_swing if submitted_swing >= 0 else _attack_swing_count
		cycle_ratio = float(attack_lifesteal_ratios[posmod(swing - 1, attack_lifesteal_ratios.size())])
	_try_attack_lifesteal(landed_damage, cycle_ratio)

func _apply_pending_form() -> void:
	if pending_form_generation < 0: return
	if hp <= 0.0 or pending_form_generation != form_change_serial:
		pending_form_generation = -1
		return
	if is_frozen(): return
	var valid := hp > 0.0 and pending_form_generation == form_change_serial
	pending_form_generation = -1
	if valid:
		if form_index == 0: transform_to_mega()
		else: transform_to_small()


func _refresh_form_speed_boost() -> void:
	if form_speed_boost_duration > 0.0:
		apply_active_buff(form_speed_boost_duration, form_speed_boost_multiplier, 1.0, 1.0, false, false, status_source("form_speed"))

## 满层附着表现使用专属状态，不能从受其他增益/减速影响的最终攻速反推。
func hit_haste_full_visual() -> bool:
	if hp <= 0.0: return false
	if _in_client_mode(): return net_hit_haste_full
	var maximum := int(PresentationConfig.for_form(_base_form_stats, form_index).get("hit_haste_max_stacks", 0))
	return maximum > 0 and buffs.remaining(&"hit_haste") > 0.0 and int(buffs.strongest(&"hit_haste", &"stacks", 0.0)) >= maximum

func blood_rage_time_left_visual() -> float:
	return net_blood_rage if _in_client_mode() else buffs.remaining(&"blood_rage")

func refresh_blood_rage() -> void:
	if hp <= 0.0 or bleed_definition.is_empty(): return
	var starting := buffs.remaining(&"blood_rage") <= 0.0
	buffs.apply(&"blood_rage", status_source("blood_rage"), float(bleed_definition.blood_rage_duration), {"damage": float(bleed_definition.blood_rage_damage_multiplier)})
	if starting and battle_context != null:
		battle_context.notify_unit_audio_event(self, &"blood_rage:start", global_position)

func on_enemy_killed(target: Node2D) -> void:
	# 与 on_attack_landed 同理，在途弹体可以晚于攻击者死亡完成击杀。
	if hp > 0.0 and target is Unit and target.team != team:
		add_skill_resource(skill_resource_kill_gain)
		if form_index == 1 and form_refresh_on_kill and form_lifetime_left > 0.0:
			form_lifetime_left = form_lifetime
			_refresh_form_speed_boost()
			if battle_context != null:
				battle_context.notify_unit_audio_event(self, &"form:refresh", get_visual_screen_position())
			_attack_swing_count = 0
			_attack_hit_index = 0
			_attack_visual_pending = true
			if passive_first_hit_time >= 0.0 and attack_timeline.recovery > 0.0:
				attack_timeline.begin_recovery(attack_timeline.cooldown, _next_attack_first_hit_time(), _effective_attack_speed_multiplier())

## 命中回血：每 heal_every_hits 次挥击中的命中回复 heal_amount 生命。
## 挥击序号与三段普攻动画循环对齐——第三击（Passive_AA_01）命中时回复。
func _try_heal_on_hit(submitted_swing: int = -1) -> void:
	if heal_every_hits <= 0 or heal_amount <= 0.0:
		return
	if (submitted_swing if submitted_swing >= 0 else _attack_swing_count) % heal_every_hits != 0:
		return
	var hp_before_heal := hp
	heal(heal_amount)
	if hp > hp_before_heal and battle_context != null:
		battle_context.notify_unit_audio_event(self, &"passive_heal", global_position)
	queue_redraw()

func _try_attack_lifesteal(landed_damage: float, cycle_ratio: float = 0.0) -> void:
	var ratio := attack_lifesteal_ratio + cycle_ratio
	if ratio <= 0.0 or landed_damage <= 0.0:
		return
	var hp_before_heal := hp
	var health_cap := BattleNumbers.quantity(max_hp * attack_lifesteal_max_health_ratio)
	hp = minf(hp + BattleNumbers.quantity(landed_damage * ratio), health_cap)
	_present_heal_gain(hp_before_heal)
	queue_redraw()

func cancel_skill_cast() -> void:
	cancelled_skill_cast_serial = active_skill_cast_serial
	_visual_action_time_left = 0.0
	_visual_action_name = &""
	active_skill_cast_timer = 0.0
	active_skill_cast_facing = Vector2.ZERO
	active_skill_cast_locks.clear()

func cancel_basic_attack(reason: StringName) -> void:
	action_cancel_serial += 1
	if reason in [&"freeze", &"death_form"]:
		cancelled_visual_serial = maxi(cancelled_visual_serial, get_visual_action_serial())
		cancelled_deployment = cancelled_deployment or _deploy_timer > 0.0
	last_action_cancellation = {"serial": action_cancel_serial, "reason": String(reason),
		"attack": get_attack_visual_serial(), "action": get_visual_action_serial(), "form": form_change_serial,
		"cancelled_action": cancelled_visual_serial, "cancelled_deployment": cancelled_deployment}
	# 先通知表现捕获当前姿势，再清理动作逻辑。
	action_cancelled.emit(last_action_cancellation)
	if battle_context != null:
		battle_context.notify_action_cancelled(self, last_action_cancellation)
	# 只清理旧动作，循环段、强化与已提交的结果独立保留。
	attack_timeline.cancel(true)
	_attacking = false
	_attack_visual_pending = true
	_attack_visual_first_strike = false
	_pending_extra_attacks.clear()
	_continuous_visual_target_id = 0
	set_continuous_beam_visible(false)
	_path = PackedVector2Array()
	_path_index = 0
	_repath_cd = 0.0
	cancel_charge()

static func valid_action_cancellation(payload: Dictionary) -> bool:
	if payload.is_empty(): return true
	for key in ["serial", "attack", "action", "form"]:
		if not payload.get(key) is int or int(payload[key]) < 0: return false
	if payload.has("cancelled_action") and (not payload.cancelled_action is int or int(payload.cancelled_action) < -1): return false
	if payload.has("cancelled_deployment") and not payload.cancelled_deployment is bool: return false
	return payload.get("reason") is String and String(payload.reason) in ["freeze", "stun", "knockback", "death_form", "empowered_reset"]

func apply_action_cancellation(payload: Dictionary) -> void:
	if not valid_action_cancellation(payload) or int(payload.get("serial", 0)) <= action_cancel_serial:
		return
	action_cancel_serial = int(payload.serial)
	last_action_cancellation = payload.duplicate(true)
	cancelled_deployment = cancelled_deployment or bool(payload.get("cancelled_deployment", false))
	cancelled_visual_serial = maxi(cancelled_visual_serial, int(payload.get("cancelled_action", payload.action if String(payload.reason) == "freeze" else -1)))
	action_cancelled.emit(last_action_cancellation)


func status_source(effect: String = "") -> StringName:
	return StringName("unit:%d:%s" % [combat_source_id, effect])

func freeze(duration: float, source: StringName = &"legacy", interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	if hp <= 0.0 or not is_finite(duration) or duration <= 0.0 or structure_rush.control_immune(): return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): _receive_freeze(duration, source))
		return
	_receive_freeze(duration, source)

func _receive_freeze(duration: float, source: StringName) -> void:
	if hp <= 0.0: return
	get_visual_facing_direction()
	if control.refresh_freeze(duration, source):
		cancel_basic_attack(&"freeze")
		cancel_skill_cast()
	if duration > 0.0: structure_rush.interrupt_preparation(self)
	queue_redraw()

func stun(duration: float, source: StringName = &"legacy", interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	if hp <= 0.0 or not is_finite(duration) or duration <= 0.0 or structure_rush.control_immune(): return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): _receive_stun(duration, source))
		return
	_receive_stun(duration, source)

func _receive_stun(duration: float, source: StringName) -> void:
	if hp <= 0.0: return
	get_visual_facing_direction()
	if control.refresh_stun(duration, source):
		cancel_basic_attack(&"stun")
	if duration > 0.0: structure_rush.interrupt_preparation(self)
	queue_redraw()

func apply_slow(duration: float, multiplier: float, source: StringName = &"legacy", interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	if hp <= 0.0 or not is_finite(duration) or duration <= 0.0 or not is_finite(multiplier) or structure_rush.control_immune() or active_buff_ignores_movement_slow: return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): _receive_apply_slow(duration, multiplier, source))
		return
	_receive_apply_slow(duration, multiplier, source)

func _receive_apply_slow(duration: float, multiplier: float, source: StringName) -> void:
	if hp <= 0.0: return
	control.refresh_slow(duration, multiplier, source)
	queue_redraw()

## 预留给后续控制效果的减攻速入口；它与减速一样只改战斗计时，不改变动画权威。
func apply_attack_speed_slow(duration: float, multiplier: float, source: StringName = &"legacy", interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	if hp <= 0.0 or not is_finite(duration) or duration <= 0.0 or not is_finite(multiplier) or structure_rush.control_immune() or active_buff_ignores_attack_speed_slow: return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): _receive_apply_attack_speed_slow(duration, multiplier, source))
		return
	_receive_apply_attack_speed_slow(duration, multiplier, source)

func _receive_apply_attack_speed_slow(duration: float, multiplier: float, source: StringName) -> void:
	if hp <= 0.0: return
	var previous_speed := _effective_attack_speed_multiplier()
	control.refresh_attack_slow(duration, multiplier, source)
	_rescale_attack_phase(previous_speed)
	queue_redraw()

func apply_active_buff(duration: float, speed_multiplier: float, damage_multiplier: float, attack_speed_multiplier: float, ignores_movement_slow: bool = false, ignores_attack_speed_slow: bool = false, source: StringName = &"legacy", interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	if hp <= 0.0: return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): apply_active_buff(duration, speed_multiplier, damage_multiplier, attack_speed_multiplier, ignores_movement_slow, ignores_attack_speed_slow, source))
		return
	var previous_speed := _effective_attack_speed_multiplier()
	buffs.apply(&"buff", source, duration, {"speed": speed_multiplier, "damage": damage_multiplier,
		"attack_speed": attack_speed_multiplier, "ignore_movement_slow": ignores_movement_slow,
		"ignore_attack_speed_slow": ignores_attack_speed_slow})
	_rescale_attack_phase(previous_speed)
	queue_redraw()

func add_shield(amount: float, duration: float, decays: bool = false, source: StringName = &"legacy", interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): add_shield(amount, duration, decays, source))
		return
	if hp > 0.0:
		shields.add(amount, duration, decays, false, source)
		queue_redraw()

func add_restoration_shield(amount: float, duration: float, source: StringName = &"legacy", interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_effect(func(): add_restoration_shield(amount, duration, source))
		return
	if hp > 0.0:
		shields.add(amount, duration, false, true, source)
		queue_redraw()

func _restore_shield_health() -> void:
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_benefit(_restore_shield_health)
		return
	heal(maxf(max_hp - hp, 0.0))

## 所有真实回血共用同一表现；保留旧 RPC / 方法名以兼容现有联网入口。
func _present_heal_gain(previous_hp: float) -> void:
	if hp <= previous_hp or hp <= 0.0 or restoration_fx_timer > 0.0:
		return
	if battle_context != null:
		battle_context.present_restoration_heal(self)
	else:
		show_restoration_heal()

func show_restoration_heal() -> void:
	# 高频吸血合并到当前脉冲，不重置动画，避免一直停在透明首帧。
	if restoration_fx_timer > 0.0: return
	restoration_fx_timer = preload("res://scripts/presentation/restoration_heal_effect.gd").DURATION
	queue_redraw()


func has_explosive_shield() -> bool:
	return net_explosive_shield if _in_client_mode() else shields.has_expiry_effect()

func clear_shields() -> void:
	shields.clear()
	queue_redraw()

func _tick_active_statuses(dt: float) -> void:
	var previous_speed := _effective_attack_speed_multiplier()
	control.tick_hard_controls(dt)
	control.tick_slows(dt)
	if shields.tick(dt) and hp > 0.0:
		_restore_shield_health()
	for effect in shields.expired_effects:
		if hp > 0.0 and battle_context != null: battle_context.queue_shield_explosion(self, effect)
	shields.expired_effects.clear()
	buffs.advance(dt)
	_rescale_attack_phase(previous_speed)
	_tick_skill_resource_decay(dt)

## 将剩余时间转换到新有效速率，归一化阶段进度不变。
func _rescale_attack_phase(previous_speed: float) -> void:
	attack_timeline.rescale(previous_speed, _effective_attack_speed_multiplier())
	for pending in _pending_extra_attacks:
		pending.time_left = float(pending.time_left) * previous_speed / _effective_attack_speed_multiplier()

func is_frozen() -> bool:
	return control.frozen_timer > 0.0

func is_stunned() -> bool:
	return control.stun_timer > 0.0

func heal_with_overflow(amount: float, shield_ratio: float, duration: float, source: StringName, interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_benefit(func(): heal_with_overflow(amount, shield_ratio, duration, source))
		return
	if hp <= 0.0 or amount <= 0.0: return
	var before := hp
	heal(amount)
	var actual := maxf(hp - before, 0.0)
	add_shield(BattleNumbers.quantity(maxf(amount - actual, 0.0) * shield_ratio), duration, false, source)


func heal(amount: float, interaction: Dictionary = {}) -> void:
	if not CombatInteraction.allows_effect(self, interaction): return
	if battle_context != null and battle_context.damage_batch().collecting:
		battle_context.damage_batch().defer_benefit(func(): heal(amount))
		return
	if hp <= 0.0 or amount <= 0.0:
		return
	# 普通治疗不能突破基础上限，也不能把已经存在的溢出生命反向截回基础上限。
	var hp_before_heal := hp
	hp = maxf(hp, minf(hp + BattleNumbers.quantity(amount), max_hp))
	_present_heal_gain(hp_before_heal)
	queue_redraw()

func take_damage(amount: float, from: Node2D = null, source_team: int = -1, source_position: Vector2 = Vector2(INF, INF), attached: bool = false) -> bool:
	if not CombatInteraction.allows(self, from, source_team, source_position, attached): return false
	if battle_context != null and battle_context.damage_batch().collecting:
		return bool(battle_context.damage_batch().submit_damage(self, amount, from, source_team, source_position, attached).accepted)
	if hp <= 0.0:
		return false
	if amount > 0.0:
		mark_skill_resource_combat_activity()
	var remaining_damage := BattleNumbers.quantity(maxf(amount, 0.0))
	remaining_damage = shields.absorb(remaining_damage)
	if not shields.broken_effects.is_empty() and battle_context != null:
		battle_context.notify_unit_audio_event(self, &"explosive_shield:break", global_position)
	shields.broken_effects.clear()
	var hp_before := hp
	hp = maxf(roundf(hp - remaining_damage), 0.0)
	add_skill_resource(minf(maxf(hp_before, 0.0), remaining_damage) * skill_resource_damage_gain_multiplier)
	if hp <= 0.0:
		_die(death_spawn_count > 0)
	else:
		# 持续伤害可能每个 20Hz tick 都结算；限制纯表现事件频率，避免模型常亮和可靠 RPC 洪泛。
		if _hit_flash_event_cooldown <= 0.0:
			_hit_flash_event_cooldown = HIT_FLASH_EVENT_COOLDOWN
			notify_visual_hit()
			if net_id >= 0 and battle_context != null:
				battle_context.notify_unit_hit(net_id)
		queue_redraw()
	return true

## 只触发表现，不参与血量或硬直；主机通过可靠 RPC 在客户端重放同一次闪白。
func notify_visual_hit() -> void:
	visual_hit.emit()

## 供 main 的推挤逻辑调用：该位置对当前单位是否可行走
func is_walkable_at(pos: Vector2) -> bool:
	if terrain_traversal.enabled: return pos.x >= body_radius and pos.x <= ArenaRules.FIELD_W - body_radius and pos.y >= body_radius and pos.y <= ArenaRules.FIELD_H - body_radius
	if is_air:
		return true
	if battle_context != null:
		return battle_context.is_ground_position_walkable(pos, body_radius, self)
	var nav_grid := _get_nav()
	if nav_grid == null:
		return true
	return nav_grid.is_walkable(pos)

func _get_nav() -> NavGrid:
	return battle_context.navigation() if battle_context != null else null

func _in_client_mode() -> bool:
	return battle_context != null and battle_context.is_net_client()

func _die(trigger_death_effect: bool = false) -> void:
	bleeding.clear()
	target_protection.clear()
	hp = 0.0
	pending_form_generation = -1
	if battle_context != null and (battle_context.damage_batch().collecting or battle_context.damage_batch().committing):
		battle_context.damage_batch().defer_death(self, trigger_death_effect)
		return
	if is_queued_for_deletion(): return
	control.clear_on_death()
	if death_form.begin(self): return
	_pending_extra_attacks.clear()
	var has_death_replacement := not death_replacement_id.is_empty() and death_replacement_charges > 0
	var play_death_visual := not _skip_death_visual and not has_death_replacement
	_skip_death_visual = false
	remove_from_group("combatants")
	# 建筑卡死亡 → 解除导航网格占地
	if is_building and not nav_cells.is_empty():
		if battle_context != null:
			battle_context.unblock_nav_cells(nav_cells)
		nav_cells = []
	if has_death_replacement:
		death_replacement_charges -= 1
		_spawn_death_replacement()
	elif trigger_death_effect:
		_spawn_death_summons()
	# 表现层只保留一个无碰撞代理播放死亡动作；死亡替身/复生切换直接移除旧代理。
	if play_death_visual:
		notify_visual_death()
	# 联机单位死亡 → 主机可靠通知客户端播放死亡动作，并立即清理 net_id 映射。
	if net_id >= 0 and battle_context != null:
		battle_context.notify_unit_died(net_id, play_death_visual)
	queue_free()

## 蛋等地面复生单位使用固定 20Hz 计时；死亡替身和孵化都走 BattleContext，
## 主机/单机负责生成，客户端只接受可靠生成/死亡事件和快照。
func _tick_timed_revival(dt: float) -> void:
	if timed_revival_id.is_empty() or _timed_revival_left <= 0.0 or _in_client_mode():
		return
	_timed_revival_left = maxf(0.0, _timed_revival_left - dt)
	if _timed_revival_left > 0.001 or battle_context == null:
		return
	battle_context.notify_unit_audio_event(self, &"revival:end", global_position)
	var revival_id := timed_revival_id
	timed_revival_id = ""
	battle_context.spawn_summoned(team, revival_id, global_position, 0.0, timed_revival_visual_transition, timed_revival_death_replacement_charges)
	_skip_death_visual = true
	_die(false)

func _spawn_death_replacement() -> void:
	if _in_client_mode() or battle_context == null:
		return
	var replacement_stats := CardDB.get_unit_stats(death_replacement_id)
	if replacement_stats.is_empty():
		push_error("死亡替身引用了不存在的单位：%s" % death_replacement_id)
		return
	battle_context.notify_unit_audio_event(self, &"replacement:start", global_position)
	# 替身立即落地；其自身的 deploy_time/复生计时仍由替身 CardDB 条目决定。
	battle_context.spawn_summoned(team, death_replacement_id, global_position, 0.0, death_replacement_visual_transition)

func _spawn_death_summons() -> void:
	if death_spawn_count <= 0 or death_spawn_id.is_empty() or _in_client_mode():
		return
	if battle_context == null:
		return
	var summon_stats: Dictionary = CardDB.get_unit_stats(death_spawn_id)
	if summon_stats.is_empty():
		return
	var summon_radius := float(summon_stats.get("radius", 14.0))
	var spawn_distance := body_radius + summon_radius + SUMMON_SEPARATION
	for index in range(death_spawn_count):
		var direction: Vector2 = SPAWN_DIRECTIONS[index % SPAWN_DIRECTIONS.size()]
		var spawn_pos := global_position + direction * spawn_distance
		battle_context.spawn_summoned(team, death_spawn_id, spawn_pos)

## 可由客户端死亡 RPC / 快照缺席兜底调用；信号只发一次，避免重复死亡表现。
func notify_visual_death() -> void:
	if _death_visual_emitted:
		return
	_death_visual_emitted = true
	died.emit()

## 3D 表现回传模型头顶锚点。该值只用于 UI，不参与任何战斗判定。
func set_visual_head_top_offset(top_offset_y: float) -> void:
	set_visual_head_world_position(get_visual_screen_position() + Vector2(0.0, top_offset_y))


func set_visual_head_world_position(world_position: Vector2) -> void:
	# 模型投影坐标属于战场画布，先转换到最终视口，再把血条放到屏幕上方。
	# 这样 Camera2D 翻转（红蓝双方视角）时，血条仍然贴在画面中的头顶。
	var local_to_view := get_global_transform_with_canvas()
	var world_to_view := local_to_view * global_transform.affine_inverse()
	var head_screen := world_to_view * world_position
	var bar_screen := head_screen - Vector2(0.0, HEALTH_BAR_HEAD_GAP + HEALTH_BAR_HEIGHT * 0.5)
	var local_center := local_to_view.affine_inverse() * bar_screen
	_health_bar_center = local_center - _vis_offset
	_health_bar_head_screen = head_screen
	_health_bar_screen_center = bar_screen
	queue_redraw()


func get_health_bar_screen_center() -> Vector2:
	return _health_bar_screen_center


func get_visual_head_screen_position() -> Vector2:
	return _health_bar_head_screen


func get_health_bar_fill_color() -> Color:
	return Color(0.95, 0.25, 0.25) if team == 1 else Color(0.2, 0.9, 0.2)


func _update_fallback_health_bar_anchor() -> void:
	if is_inside_tree():
		set_visual_head_world_position(get_visual_screen_position() + Vector2(0.0, -visual_radius).rotated(-get_canvas_transform().get_rotation()))

func _draw() -> void:
	draw_set_transform(_vis_offset, 0.0, Vector2.ONE)

	if continuous_beam_visible and has_continuous_visual_target():
		_draw_continuous_beam()
	if is_building and not has_model_art:
		draw_rect(Rect2(-body_radius, -body_radius, body_radius * 2.0, body_radius * 2.0), color)
		draw_rect(Rect2(-body_radius, -body_radius, body_radius * 2.0, body_radius * 2.0), Color(0.2, 0.18, 0.12), false, 2.0)
	elif not is_building and not has_model_art:
		var outline := Color(0.30, 0.60, 1.00) if team == 0 else Color(1.00, 0.35, 0.30)
		draw_circle(Vector2.ZERO, visual_radius + 2.0, outline)
		draw_circle(Vector2.ZERO, visual_radius, color)
	if _deploy_timer > 0.0:
		# 部署读条仍使用代码绘制，便于观察一秒落地窗口。
		var deploy_ratio := 1.0 - _deploy_timer / maxf(deploy_time, 0.001)
		draw_arc(Vector2.ZERO, visual_radius + 6.0, -PI / 2.0, -PI / 2.0 + TAU * deploy_ratio, 24, Color.WHITE, 3.0)
	if _sweep_fx_timer > 0.0 and deploy_sweep_radius > 0.0:
		_draw_sweep_fx()
	_draw_active_sweep_fx()
	# 血条和资源条绕其屏幕锚点反向旋转，填充方向与上下关系不随场地倒转。
	var ui_rotation := -get_global_transform_with_canvas().get_rotation()
	draw_set_transform(_vis_offset + _health_bar_center - _health_bar_center.rotated(ui_rotation), ui_rotation, Vector2.ONE)
	var raw_hp_ratio := presentation_state().health_ratio
	var hp_ratio := minf(raw_hp_ratio, 1.0)
	var overheal_ratio := maxf(raw_hp_ratio - 1.0, 0.0)
	var shield_health_ratio := get_shield_health_ratio()
	var shield_capacity_ratio := get_shield_capacity_ratio()
	if death_form.waiting() or not is_equal_approx(raw_hp_ratio, 1.0) or shield_health_ratio > 0.0:
		var bar_w := visual_radius * 2.0
		var bar_rect := Rect2(
			_health_bar_center.x - bar_w * 0.5,
			_health_bar_center.y - HEALTH_BAR_HEIGHT * 0.5,
			bar_w,
			HEALTH_BAR_HEIGHT
		)
		draw_rect(bar_rect, Color(0.15, 0.15, 0.15))
		# 生命与护盾共用一条固定宽度的容量条；护盾始终接在当前生命段之后。
		var combined_capacity := 1.0 + shield_capacity_ratio
		var hp_width := bar_w * hp_ratio / combined_capacity
		var shield_width := bar_w * shield_health_ratio / combined_capacity
		if hp_width > 0.0:
			draw_rect(Rect2(bar_rect.position, Vector2(hp_width, HEALTH_BAR_HEIGHT)), get_health_bar_fill_color())
		if shield_width > 0.0:
			draw_rect(Rect2(Vector2(bar_rect.position.x + hp_width, bar_rect.position.y), Vector2(shield_width, HEALTH_BAR_HEIGHT)), Color.WHITE)
		# 溢出生命画在基础血条右侧，长度直接表示超过基础上限的比例；皮克斯最多延伸 50%。
		if overheal_ratio > 0.0:
			draw_rect(
				Rect2(Vector2(bar_rect.end.x, bar_rect.position.y), Vector2(bar_w * overheal_ratio, HEALTH_BAR_HEIGHT)),
				Color(0.82, 0.35, 1.0),
			)
	if is_skill_resource_visible():
		var resource_w := visual_radius * 2.0
		var resource_y := _health_bar_center.y + HEALTH_BAR_HEIGHT * 0.5 + SKILL_RESOURCE_BAR_GAP
		var segment_count := get_skill_resource_segment_count()
		if segment_count > 0:
			var segment_gap := maxf(1.0, SKILL_RESOURCE_BAR_GAP * 0.75)
			var segment_w := maxf((resource_w - segment_gap * float(segment_count - 1)) / float(segment_count), 0.0)
			var filled_segments := mini(get_skill_resource_stacks(), segment_count)
			var resource_fill_color := get_skill_resource_fill_color()
			for segment_index in range(segment_count):
				var segment_x := -resource_w * 0.5 + float(segment_index) * (segment_w + segment_gap)
				var segment_rect := Rect2(Vector2(segment_x, resource_y), Vector2(segment_w, SKILL_RESOURCE_BAR_HEIGHT))
				draw_rect(segment_rect, Color(0.10, 0.10, 0.12, 0.9))
				if segment_index < filled_segments:
					draw_rect(segment_rect, resource_fill_color)
		else:
			var resource_rect := Rect2(Vector2(-resource_w * 0.5, resource_y), Vector2(resource_w, SKILL_RESOURCE_BAR_HEIGHT))
			draw_rect(resource_rect, Color(0.10, 0.10, 0.12, 0.9))
			draw_rect(Rect2(resource_rect.position, Vector2(resource_w * get_skill_resource_ratio(), SKILL_RESOURCE_BAR_HEIGHT)), get_skill_resource_fill_color())
	for stack in bleeding.total_stacks():
		draw_circle(_health_bar_center + Vector2((stack - (bleeding.total_stacks() - 1) * 0.5) * 7.0, 11.0), 2.5, Color(0.95, 0.12, 0.18))
	draw_set_transform(_vis_offset, 0.0, Vector2.ONE)
	if restoration_fx_timer > 0.0 and hp > 0.0:
		preload("res://scripts/presentation/restoration_heal_effect.gd").draw_effect(self, 1.0 - restoration_fx_timer / preload("res://scripts/presentation/restoration_heal_effect.gd").DURATION)
	if control.frozen_timer > 0.0:
		draw_circle(Vector2.ZERO, visual_radius + 4.0, Color(0.4, 0.8, 1.0, 0.3))
	if stun_visual():
		preload("res://scripts/presentation/stun_effect.gd").draw_effect(self, stun_effect_origin(), _status_effect_phase)
	if hp > 0.0 and (movement_slow_effect_visible() or attack_speed_slow_visual()):
		preload("res://scripts/presentation/soft_control_effect.gd").draw_effect(self, _status_effect_phase, movement_slow_effect_visible(), attack_speed_slow_visual())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func get_shield_ratio() -> float:
	if _in_client_mode():
		return clampf(net_shield_ratio, 0.0, 1.0)
	if shield_hp <= 0.0 or shield_max_hp <= 0.0 or shield_timer <= 0.0:
		return 0.0
	return clampf(shield_hp / shield_max_hp, 0.0, 1.0)

func get_shield_capacity_ratio() -> float:
	if _in_client_mode():
		return maxf(net_shield_capacity_ratio, 0.0)
	return maxf(shield_max_hp / maxf(max_hp, 0.001), 0.0) if shield_hp > 0.0 and shield_timer > 0.0 else 0.0

func get_shield_health_ratio() -> float:
	if _in_client_mode():
		return get_shield_ratio() * get_shield_capacity_ratio()
	if shield_hp <= 0.0 or shield_timer <= 0.0:
		return 0.0
	return maxf(shield_hp / maxf(max_hp, 0.001), 0.0)

## 临时吐息表现：嘴部端窄、目标端宽的半透明梯形光柱。
## 光柱只读取已经确定的攻击目标，宽度与高度均不参与权威命中判定。
func _draw_continuous_beam() -> void:
	var source_screen := get_visual_screen_position()
	var target_local := get_continuous_beam_endpoint_position() - source_screen
	var mouth_local := continuous_beam_origin_world_position - source_screen if continuous_beam_origin_tracks_model else Vector2(0.0, -continuous_beam_origin_height)
	var to_target := target_local - mouth_local
	if to_target.length_squared() < 0.001:
		return
	var direction := to_target.normalized()
	if not continuous_beam_origin_tracks_model:
		mouth_local += direction * continuous_beam_forward_offset
	to_target = target_local - mouth_local
	if to_target.length_squared() < 0.001:
		return
	direction = to_target.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var start_half := continuous_beam_start_width * 0.5
	var end_half := continuous_beam_end_width * 0.5
	draw_colored_polygon(PackedVector2Array([
		mouth_local - perpendicular * start_half,
		mouth_local + perpendicular * start_half,
		target_local + perpendicular * end_half,
		target_local - perpendicular * end_half,
	]), continuous_beam_color)

## 部署与主动共用环身枪芒；客户端从动作快照读取进度，不重放伤害。
func _draw_sweep_fx() -> void:
	SWEEP_EFFECT.draw_effect(self, deploy_sweep_radius, get_visual_facing_direction(), 1.0 - _sweep_fx_timer / SWEEP_FX_DURATION)

func _draw_active_sweep_fx() -> void:
	if get_visual_action_time_left() <= 0.0:
		return
	var elapsed := get_visual_action_duration() - get_visual_action_time_left()
	if elapsed >= SWEEP_FX_DURATION:
		return
	var stats := transformed_stats if get_form_index() == 1 else _base_form_stats
	for skill in stats.get("active_skills", []):
		if String(skill.get("kind", "")) == "nova" and StringName(skill.get("visual_action", "")) == get_visual_action_name():
			SWEEP_EFFECT.draw_effect(self, float(skill.get("radius", 0.0)), get_visual_facing_direction(), elapsed / SWEEP_FX_DURATION)
			return
