extends Node2D
class_name Unit
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
## 横扫击退的短暂表现时长，不参与命中或位移判定。
const SWEEP_FX_DURATION := 0.35
const HEALTH_BAR_HEAD_GAP := 3.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const HEALTH_BAR_HEIGHT := 4.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const SUMMON_SEPARATION := 2.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
# 建筑卡召唤小鬼的确定性方向偏移（按序轮转，不引入随机数）
const SPAWN_DIRECTIONS := [
	Vector2.RIGHT, Vector2(0.70710678, 0.70710678), Vector2.DOWN, Vector2(-0.70710678, 0.70710678),
	Vector2.LEFT, Vector2(-0.70710678, -0.70710678), Vector2.UP, Vector2(0.70710678, -0.70710678),
]

var net_id := -1
## 每次由主动位卡牌部署时分配一次；-1 表示该实例没有携带主动技能。
var active_ability_id := -1
## 0/1 分别对应备战卡组的第 1/2 主动槽；同槽新实例会覆盖旧实例资格。
var active_ability_slot := -1
var card_id := ""
var team := 0
var hp := 100.0
var max_hp := 100.0
var damage := 10.0
var attack_range := 20.0
var attack_interval := 1.0
var move_speed := 60.0
var body_radius := 14.0
var visual_radius := 14.0
var mass := 4.0
var sight_range := DEFAULT_SIGHT_RANGE
var is_air := false
var is_building := false
var building_only := false
var can_attack_air := true
var continuous_attack := false
var color := Color.DIM_GRAY
var visual_frames: SpriteFrames = null
var has_model_art := false
var show_team_ring := true
var deploy_time := 1.0
var first_hit_time := 0.2
var projectile_speed := 0.0
var projectile_visual := &"orb"
var projectile_visual_height := 0.0
## 纯表现用的武器前向发射偏移；权威弹体仍从单位地面原点推进和判定。
var projectile_visual_forward_offset := 0.0
var projectile_color := Color.DIM_GRAY
var splash_radius := 0.0
var attack_knockback := 0.0
# 持续攻击光柱是纯表现数据；权威伤害仍由 continuous_attack 的固定 tick 结算。
var continuous_beam_color := Color(0.95, 0.6, 0.2, 0.8)
var continuous_beam_start_width := 3.0
var continuous_beam_end_width := 3.0
var continuous_beam_origin_height := 0.0
var continuous_beam_forward_offset := 0.0
# 横扫千军：赵信生成瞬间击退半径内敌方地面单位；radius<=0 表示未启用。
# 只击退不造成伤害，击退距离由 apply_knockback 的质量因子衰减。
var deploy_sweep_radius := 0.0
var deploy_sweep_knockback := 0.0
var deploy_sweep_duration := 0.25
# 命中回血：每 heal_every_hits 次普攻命中回复 heal_amount 生命（赵信三段循环的第三击）。
var heal_every_hits := 0
var heal_amount := 0.0
var charge_time := 0.0
var charge_speed_multiplier := 1.0
var charge_damage_multiplier := 1.0
# 丝缕缠流：开启后，离开自身 shroud_radius（px）的敌方看不到她、不会把她当目标，攻击对其无效；0 表示未启用。
var shroud_radius := 0.0
## 连招攻击节奏：每次命中后到下一次命中的间隔（秒），按数组循环；空数组表示每个周期间隔固定为 attack_interval。
## 例如 [0.28, 1.05, 0.28, 1.05] 表示快速两拳后停顿、再快速两拳后停顿。
var attack_pattern: Array = []
## 连招伤害倍率：按每次命中的顺序循环；空数组表示每拳使用 damage 原值。
var attack_damage_multipliers: Array = []
## 双形态单位配置。0 为初始形态，1 为 transformed_stats；命中次数可让两形态循环切换。
var transform_after_hits := 0
var revert_after_hits := 0
var transform_hit_count := 0
var form_index := 0
var transformed_stats: Dictionary = {}
var _base_form_stats: Dictionary = {}
## 形态数值在命中瞬间切换；这段固定计时只锁自主攻击，仍允许按新形态寻路移动。
var form_transition_timer := 0.0
var transform_duration := 0.0
var active_transform_duration := 0.0
var revert_duration := 0.0
var form_change_serial := 0
## 主动技能施放锁：方向在发动帧固定，计时期间禁止自主移动与普攻。
var active_skill_cast_timer := 0.0
var active_skill_cast_facing := Vector2.ZERO

var frozen_timer := 0.0
var stun_timer := 0.0
var slow_timer := 0.0
var slow_multiplier := 1.0
var shield_hp := 0.0
var shield_timer := 0.0
var active_buff_timer := 0.0
var active_speed_multiplier := 1.0
var active_damage_multiplier := 1.0
var active_attack_speed_multiplier := 1.0

# 联机客户端插值字段（main 快照写入）
var net_target_pos: Vector2

# 建筑卡专用
var lifespan := 0.0
var spawn_interval := 0.0
var spawn_count := 1
var spawn_side := ""
var death_spawn_id := ""
var death_spawn_count := 0
var nav_cells: Array = []

var _target: Node2D = null
var _attack_cd := 0.0
var _attacking := false
var _attack_windup := 0.0
## 本次攻击已经命中后的收招锁定。期间保持 Attack 表现且不能开始追击；
## 时长由权威攻击节奏推导，不读取 3D 动画长度。
var _attack_recovery_timer := 0.0
var _attack_load := 0.0
var _attack_visual_serial := 0
## 持续攻击的目标表现标识；原地换目标时推进序号，让两端播放换目标衔接。
var _continuous_visual_target_id := 0
var _attack_visual_pending := false
var _attack_hit_index := 0
## 挥击总数：与表现层攻击动画序号同步推进，用于命中回血按三段循环取模。
var _attack_swing_count := 0
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
var _steering_velocity := Vector2.ZERO
var _forced_movement := false
var _knockback_velocity := Vector2.ZERO
var _knockback_timer := 0.0
var _charge_timer := 0.0
var _charged := false
var _just_deployed := false
var _facing_x := 1.0
var net_visual_state := 1
var net_facing_x := 1.0
var net_attack_visual_serial := 0
var net_shroud_active := false
var net_shield_active := false
var net_slow_active := false
var net_stun_active := false
var net_form_index := 0
var net_form_change_serial := 0
var net_visual_action_serial := 0
var net_visual_action_name := &""
var net_facing_direction := Vector2.ZERO
## 主机快照同步当前普攻目标是否为建筑，供客户端选择对应动作；不参与伤害判定。
var net_attacking_structure := false
var net_has_continuous_target := false
var net_continuous_target_pos := Vector2.ZERO
## 仅由表现代理切换：进入吐息循环后显示，进入动画和退出攻击时隐藏。
var continuous_beam_visible := false
var _presentation: UnitPresentation = null
var _shroud_active := false
var _visual_action_serial := 0
var _visual_action_name := &""
## 血条绘制中心（兼容旧调试字段）；实际位置由屏幕空间头顶锚点计算。
var _health_bar_y := -24.0
var _health_bar_center := Vector2.ZERO
var _health_bar_screen_center := Vector2.ZERO
var _health_bar_head_screen := Vector2.ZERO

# 渲染插值：sim 为 20Hz，渲染在上一模拟位置与当前位置间过渡
var _prev_pos := Vector2.ZERO
var _vis_offset := Vector2.ZERO

func setup(p_team: int, stats: Dictionary, _p_name: String) -> void:
	_base_form_stats = stats.duplicate(true)
	team = p_team
	hp = stats.hp
	max_hp = stats.hp
	damage = stats.damage
	attack_range = stats.range
	attack_interval = stats.interval
	move_speed = stats.speed
	body_radius = stats.radius
	visual_radius = stats.get("visual_radius", body_radius)
	_health_bar_y = -visual_radius - HEALTH_BAR_HEAD_GAP
	_health_bar_center = Vector2(0.0, _health_bar_y - HEALTH_BAR_HEIGHT * 0.5)
	mass = stats.get("mass", maxf(1.0, body_radius / 3.0))
	sight_range = stats.get("sight", DEFAULT_SIGHT_RANGE)
	color = stats.get("color", Color.DIM_GRAY)
	show_team_ring = stats.get("show_team_ring", true)
	projectile_color = color
	var projectile_colors: Array = stats.get("projectile_colors", [])
	if team >= 0 and team < projectile_colors.size():
		projectile_color = projectile_colors[team]
	var frames_path: String = stats.get("visual_frames_path", "")
	if not frames_path.is_empty() and ResourceLoader.exists(frames_path):
		visual_frames = load(frames_path) as SpriteFrames
	is_air = stats.get("is_air", false)
	# 单位 2D 层（血条/状态圈）必须盖在防御塔 2D 层之上：塔层 z_index=10，
	# 地面单位取 11、空中单位取 12；否则贴塔/水晶作战的单位血条会被建筑血条挡住。
	z_index = 12 if is_air else 11
	is_building = stats.get("is_building", false)
	building_only = stats.get("building_only", false)
	can_attack_air = stats.get("can_attack_air", true)
	continuous_attack = stats.get("is_continuous_attack", false)
	deploy_time = stats.get("deploy_time", 1.0)
	first_hit_time = stats.get("first_hit", minf(attack_interval * 0.5, 0.4))
	projectile_speed = stats.get("projectile_speed", 0.0)
	projectile_visual = StringName(stats.get("projectile_visual", "orb"))
	projectile_visual_height = stats.get("projectile_visual_height", 0.0)
	projectile_visual_forward_offset = stats.get("projectile_visual_forward_offset", 0.0)
	splash_radius = stats.get("splash_radius", 0.0)
	attack_knockback = stats.get("knockback", 0.0)
	continuous_beam_color = stats.get("continuous_beam_color", continuous_beam_color)
	continuous_beam_start_width = stats.get("continuous_beam_start_width", continuous_beam_start_width)
	continuous_beam_end_width = stats.get("continuous_beam_end_width", continuous_beam_end_width)
	continuous_beam_origin_height = stats.get("continuous_beam_origin_height", continuous_beam_origin_height)
	continuous_beam_forward_offset = stats.get("continuous_beam_forward_offset", continuous_beam_forward_offset)
	deploy_sweep_radius = stats.get("deploy_sweep_radius", 0.0)
	deploy_sweep_knockback = stats.get("deploy_sweep_knockback", 0.0)
	deploy_sweep_duration = stats.get("deploy_sweep_duration", 0.25)
	heal_every_hits = stats.get("heal_every_hits", 0)
	heal_amount = stats.get("heal_amount", 0.0)
	charge_time = stats.get("charge_time", 0.0)
	charge_speed_multiplier = stats.get("charge_speed_multiplier", 1.0)
	charge_damage_multiplier = stats.get("charge_damage_multiplier", 1.0)
	shroud_radius = stats.get("shroud_radius", 0.0)
	attack_pattern = stats.get("attack_pattern", [])
	attack_damage_multipliers = stats.get("attack_damage_multipliers", [])
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
	lifespan = stats.get("lifespan", 0.0)
	spawn_interval = stats.get("spawn_interval", 0.0)
	spawn_count = maxi(int(stats.get("spawn_count", 1)), 1)
	spawn_side = String(stats.get("spawn_side", ""))
	death_spawn_id = String(stats.get("death_spawn_id", ""))
	death_spawn_count = maxi(int(stats.get("death_spawn_count", 0)), 0)
	_lifespan_left = lifespan
	_spawn_timer = spawn_interval
	_deploy_timer = deploy_time
	net_target_pos = global_position
	_prev_pos = global_position
	_update_fallback_health_bar_anchor()

func _ready() -> void:
	add_to_group("combatants")
	_presentation = UnitPresentation.new()
	add_child(_presentation)
	_presentation.setup(visual_frames, visual_radius)
	_update_fallback_health_bar_anchor()
	# 赵信的横扫就是部署动作本身：生成当帧结算一次，不等待部署锁定结束，
	# 也不让动画帧反向驱动权威效果。客户端仅显示同帧特效。
	if deploy_time > 0.0 and deploy_sweep_radius > 0.0 and deploy_sweep_knockback > 0.0:
		if _in_client_mode():
			_sweep_fx_timer = SWEEP_FX_DURATION
		else:
			_perform_deploy_sweep()

func _process(delta: float) -> void:
	_sweep_fx_timer = maxf(0.0, _sweep_fx_timer - delta)
	if _in_client_mode():
		# 客户端：朝快照目标位置平滑插值，血量/冰冻由 main 快照直接写入
		position = position.lerp(net_target_pos, minf(delta * 10.0, 1.0))
		# 客户端不跑权威横扫，只倒计时部署状态；击退与受伤结果由快照驱动。
		_deploy_timer = maxf(0.0, _deploy_timer - delta)
		_sync_presentation(net_visual_state, net_facing_x)
		if not has_model_art and (_presentation == null or not _presentation.has_art()):
			_update_fallback_health_bar_anchor()
		queue_redraw()
		return
	if is_building or hp <= 0.0:
		return
	# 主机/单机：使用 main 的统一模拟余量插值，不能让每个节点独立累计进度。
	_vis_offset = get_visual_screen_position() - position
	_sync_presentation(get_visual_state_code(), _facing_x)
	if not has_model_art and (_presentation == null or not _presentation.has_art()):
		_update_fallback_health_bar_anchor()
	queue_redraw()

func _sync_presentation(state: int, facing_x: float) -> void:
	if _presentation == null:
		return
	_presentation.position = _vis_offset
	_presentation.play_state(state, facing_x, frozen_timer > 0.0)

## 网络快照只同步这个粗粒度表现状态；动画无权决定攻击是否命中。
func get_visual_state_code() -> int:
	if _deploy_timer > 0.0:
		return 0
	if _attacking:
		return 3
	if _move_intent.length_squared() > 0.01:
		return 2
	return 1

func get_facing_x() -> float:
	return _facing_x

## 3D 与 2D 表现都直接读取同一个最终渲染位置，不依赖彼此的 _process 执行顺序。
func get_visual_screen_position() -> Vector2:
	if _in_client_mode():
		return global_position
	var scene := get_tree().current_scene
	var alpha := 1.0
	if scene != null and scene.has_method("get_sim_interpolation_alpha"):
		alpha = scene.get_sim_interpolation_alpha()
	return _prev_pos.lerp(global_position, alpha)

func get_attack_visual_serial() -> int:
	return _attack_visual_serial

## 仅供表现层选择普通普攻或建筑普攻动作。目标类型由权威端判定并随快照同步。
func is_attacking_structure_visual() -> bool:
	if _in_client_mode():
		return net_attacking_structure
	return _attacking and _target != null and is_instance_valid(_target) and _is_struct(_target)

func get_form_index() -> int:
	return net_form_index if _in_client_mode() else form_index

func get_visual_action_serial() -> int:
	return _visual_action_serial

func get_visual_action_name() -> StringName:
	return _visual_action_name

## 主机记录一次纯表现动作；序号和名称会随快照同步，动画无权决定效果时刻。
func play_visual_action(action_name: StringName) -> void:
	_visual_action_name = action_name
	_visual_action_serial += 1

func begin_active_skill_cast(duration: float, facing: Vector2) -> void:
	active_skill_cast_timer = maxf(duration, 0.0)
	if facing.length_squared() < 0.001:
		facing = Vector2.UP if team == 0 else Vector2.DOWN
	active_skill_cast_facing = facing.normalized()
	_target = null
	_attacking = false
	_attack_cd = 0.0
	_attack_windup = 0.0
	_attack_recovery_timer = 0.0
	_attack_load = 0.0
	_attack_visual_pending = false
	_move_intent = Vector2.ZERO
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
	if form_index != 0 or transformed_stats.is_empty():
		return false
	_apply_form(1, true)
	form_transition_timer = active_transform_duration if active_cast else transform_duration
	play_visual_action(&"transform_active" if active_cast else &"transform")
	return true

func transform_to_small() -> bool:
	if form_index != 1:
		return false
	_apply_form(0, false)
	form_transition_timer = revert_duration
	play_visual_action(&"revert")
	return true

func _apply_form(next_form_index: int, grant_max_hp_increase: bool, advance_form_serial: bool = true) -> void:
	var next_stats: Dictionary = transformed_stats if next_form_index == 1 else _base_form_stats
	if next_stats.is_empty():
		return
	var old_max_hp := max_hp
	var old_body_radius := body_radius
	max_hp = float(next_stats.get("hp", max_hp))
	if grant_max_hp_increase:
		hp = minf(hp + maxf(max_hp - old_max_hp, 0.0), max_hp)
	else:
		hp = minf(hp, max_hp)
	damage = float(next_stats.get("damage", damage))
	attack_range = float(next_stats.get("range", attack_range))
	attack_interval = float(next_stats.get("interval", attack_interval))
	first_hit_time = float(next_stats.get("first_hit", first_hit_time))
	move_speed = float(next_stats.get("speed", move_speed))
	body_radius = float(next_stats.get("radius", body_radius))
	visual_radius = float(next_stats.get("visual_radius", body_radius))
	mass = float(next_stats.get("mass", mass))
	sight_range = float(next_stats.get("sight", sight_range))
	is_air = bool(next_stats.get("is_air", is_air))
	building_only = bool(next_stats.get("building_only", building_only))
	can_attack_air = bool(next_stats.get("can_attack_air", can_attack_air))
	projectile_speed = float(next_stats.get("projectile_speed", projectile_speed))
	projectile_visual = StringName(next_stats.get("projectile_visual", projectile_visual))
	projectile_visual_height = float(next_stats.get("projectile_visual_height", projectile_visual_height))
	projectile_visual_forward_offset = float(next_stats.get("projectile_visual_forward_offset", projectile_visual_forward_offset))
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
	_attack_cd = 0.0
	_attack_windup = 0.0
	_attack_recovery_timer = 0.0
	_attack_load = 0.0
	_attack_visual_pending = false
	_path = PackedVector2Array()
	_path_index = 0
	cancel_charge()
	_health_bar_y = -visual_radius - HEALTH_BAR_HEAD_GAP
	_health_bar_center = Vector2(0.0, _health_bar_y - HEALTH_BAR_HEIGHT * 0.5)
	form_changed.emit(form_index)
	# 放大碰撞半径后立即做一次地形/建筑安全修正；单位间重叠仍交给本 tick 的统一推挤。
	var scene := get_tree().current_scene
	if body_radius > old_body_radius and not _in_client_mode() and scene != null and scene.has_method("ensure_unit_form_resize_safe"):
		scene.ensure_unit_form_resize_safe(self)
	queue_redraw()

func is_form_transitioning() -> bool:
	return form_transition_timer > 0.0

func is_active_skill_casting() -> bool:
	return active_skill_cast_timer > 0.0

## 3D 表现使用完整方向；客户端读取主机快照，保证前方技能动作朝向与权威判定一致。
func get_visual_facing_direction() -> Vector2:
	if _in_client_mode():
		if continuous_attack and net_visual_state == 3 and net_has_continuous_target:
			var continuous_direction := global_position.direction_to(net_continuous_target_pos)
			if continuous_direction.length_squared() > 0.001:
				return continuous_direction
		if net_facing_direction.length_squared() > 0.001:
			return net_facing_direction.normalized()
		return Vector2.UP if team == 0 else Vector2.DOWN
	if active_skill_cast_timer > 0.0 and active_skill_cast_facing.length_squared() > 0.001:
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

func set_continuous_beam_visible(visible: bool) -> void:
	if continuous_beam_visible == visible:
		return
	continuous_beam_visible = visible
	queue_redraw()

## 固定 tick 模拟入口，由 main._sim_step 以 SIM_DT 驱动
func sim_tick(dt: float) -> void:
	if hp <= 0.0:
		return
	_tick_active_statuses(dt)
	_hit_flash_event_cooldown = maxf(0.0, _hit_flash_event_cooldown - dt)
	_prev_pos = position
	_move_intent = Vector2.ZERO
	_forced_movement = false
	var active_skill_cast_ticked := false
	# 技能动作被冰冻/眩晕时表现层也会暂停，因此施放锁和变形锁必须一起暂停。
	if active_skill_cast_timer > 0.0:
		_target = null
		_attacking = false
		_move_intent = Vector2.ZERO
		if frozen_timer <= 0.0 and stun_timer <= 0.0:
			active_skill_cast_ticked = true
			active_skill_cast_timer = maxf(0.0, active_skill_cast_timer - dt)
			if form_transition_timer > 0.0:
				form_transition_timer = maxf(0.0, form_transition_timer - dt)
			if active_skill_cast_timer <= 0.0:
				active_skill_cast_facing = Vector2.ZERO
	# 卡牌生成后进入部署时间：自身不索敌、不移动、不攻击，但实体已经存在，
	# 会参与碰撞，也能被敌方索敌、命中、受伤和施加状态。
	if _deploy_timer > 0.0:
		_deploy_timer = maxf(0.0, _deploy_timer - dt)
		# 冰冻时长从命中当帧开始消耗；不会在部署结束后再额外补一整段冻结。
		frozen_timer = maxf(0.0, frozen_timer - dt)
		stun_timer = maxf(0.0, stun_timer - dt)
		# “不能移动”只锁自主行军；碰撞与击退等外力仍可改变位置，保证部署实体
		# 被命中后的附带效果不会延迟到部署结束才突然补播。
		if _knockback_timer > 0.0:
			_knockback_timer = maxf(0.0, _knockback_timer - dt)
			_move_intent = _knockback_velocity
			_forced_movement = true
		if _deploy_timer <= 0.0:
			_just_deployed = true
			if is_building and frozen_timer <= 0.0:
				_spawn_initial_summons()
		queue_redraw()
		return
	if frozen_timer > 0.0 or stun_timer > 0.0:
		frozen_timer = maxf(0.0, frozen_timer - dt)
		stun_timer = maxf(0.0, stun_timer - dt)
		if frozen_timer <= 0.0 and stun_timer <= 0.0:
			queue_redraw()
		_charge_timer = 0.0
		_charged = false
		return
	if is_building:
		_building_tick(dt)
		return
	if _knockback_timer > 0.0:
		_knockback_timer = maxf(0.0, _knockback_timer - dt)
		_move_intent = _knockback_velocity
		_forced_movement = true
		_charge_timer = 0.0
		_charged = false
		return
	if active_skill_cast_timer > 0.0:
		_target = null
		_attacking = false
		_move_intent = Vector2.ZERO
		return
	if form_transition_timer > 0.0:
		if not active_skill_cast_ticked:
			form_transition_timer = maxf(0.0, form_transition_timer - dt)
		if form_transition_timer > 0.0:
			_tick_form_transition_movement(dt)
			return
	_attack_cd = maxf(0.0, _attack_cd - dt)
	# 命中后必须完整收招。目标此时即使死亡、失效或离开射程，也要等后摇结束
	# 才重新索敌/追击；冻结会在上方提前 return，因此同样会暂停后摇计时。
	if _attack_recovery_timer > 0.0:
		_attack_recovery_timer = maxf(0.0, _attack_recovery_timer - dt)
		_attacking = true
		if _attack_recovery_timer > 0.0:
			return
	# 正好到达权威命中节点的这个 tick 不再做距离取消。这样目标在最后一刻跨出
	# 攻击圈时，本次挥击仍会命中；更早脱离则仍会取消前摇并继续追击。
	var reaches_hit_this_tick := _reaches_attack_hit_this_tick(dt)
	_update_target(reaches_hit_this_tick)
	if _target != null:
		if _target_gap(_target) <= attack_range or reaches_hit_this_tick:
			if continuous_attack:
				var continuous_target_id := int(_target.get_instance_id())
				if continuous_target_id != _continuous_visual_target_id:
					_continuous_visual_target_id = continuous_target_id
					_attack_visual_serial += 1
			if not _attacking:
				# 移动期间会预装填一部分攻击周期；被推出射程会丢失这次预装填。
				_attack_windup = maxf(first_hit_time, attack_interval - _attack_load)
				_attack_visual_pending = true
			_attacking = true
			_path = PackedVector2Array()
			_path_index = 0
			_attack(dt)
			return
	if _attacking and _attack_windup > 0.0:
		_attack_load = 0.0
	# 退出攻击状态（目标丢失/脱离攻击圈，回到行军）→ 关闭丝缕缠流。
	_attacking = false
	_continuous_visual_target_id = 0
	_attack_windup = 0.0
	_attack_recovery_timer = 0.0
	_shroud_active = false
	_chase(dt)

## 变形期间用新形态的视野/射程立即决策：圈外继续移动，圈内预装填但不开始攻击。
func _tick_form_transition_movement(dt: float) -> void:
	_attacking = false
	_attack_windup = 0.0
	_attack_recovery_timer = 0.0
	_attack_visual_pending = false
	_update_target(false)
	if _target != null and is_instance_valid(_target) and _target_gap(_target) <= attack_range:
		_attack_load = maxf(attack_interval - first_hit_time, 0.0)
		var face_delta: float = _target.global_position.x - global_position.x
		if absf(face_delta) > 0.05:
			_facing_x = signf(face_delta)
		return
	_chase(dt)

func is_deployed() -> bool:
	return _deploy_timer <= 0.0

func is_charged() -> bool:
	return _charged

func cancel_charge() -> void:
	_charge_timer = 0.0
	_charged = false

func on_movement_applied(distance: float, dt: float) -> void:
	if _forced_movement:
		cancel_charge()
		return
	if distance > 0.01:
		if attack_interval > 0.0:
			var max_load := maxf(attack_interval - first_hit_time, 0.0)
			_attack_load = minf(_attack_load + dt, max_load)
		if charge_time > 0.0:
			_charge_timer = minf(_charge_timer + dt, charge_time)
			_charged = _charge_timer >= charge_time
	elif _move_intent.length_squared() > 0.001:
		# 有行进意图但被堵停，不能站在原地继续积攒冲锋。
		cancel_charge()

## 横扫千军：赵信生成的瞬间以自身为中心击退四周敌人。
## 只击退，不造成伤害；空中单位扫不到，建筑/塔不可被击退。
## 击退距离经 apply_knockback 的质量因子衰减——轻单位被推出圈外，重单位只被顶开一小步。
## 由主机/单机的 _ready 在生成当帧触发，客户端击退位移由快照插值驱动。
func _perform_deploy_sweep() -> void:
	if deploy_sweep_radius <= 0.0 or deploy_sweep_knockback <= 0.0:
		return
	_sweep_fx_timer = SWEEP_FX_DURATION
	for c in get_tree().get_nodes_in_group("combatants"):
		if not c is Unit or c == self or c.team == team or c.hp <= 0.0:
			continue
		var u := c as Unit
		if u.is_air or u.is_building:
			continue
		# 命中判定与法术/溅射一致：横扫圆与目标碰撞圆相交即命中。
		if global_position.distance_to(u.global_position) <= deploy_sweep_radius + u.body_radius:
			u.apply_knockback(global_position, deploy_sweep_knockback, deploy_sweep_duration)

func apply_knockback(origin: Vector2, distance: float, duration: float = 0.2) -> void:
	if is_building or distance <= 0.0:
		return
	var direction := origin.direction_to(global_position)
	if direction.length_squared() < 0.001:
		direction = Vector2.DOWN if team == 0 else Vector2.UP
	var mass_factor := clampf(4.0 / maxf(mass, 1.0), 0.35, 1.4)
	_knockback_timer = maxf(duration, SIM_DT)
	_knockback_velocity = direction * distance * mass_factor / _knockback_timer
	_attack_windup = 0.0
	_attack_recovery_timer = 0.0
	_attack_load = 0.0
	_attacking = false
	_shroud_active = false
	cancel_charge()

func _target_gap(target: Node2D) -> float:
	if target.has_method("surface_gap_to_circle"):
		return target.surface_gap_to_circle(global_position, body_radius)
	return maxf(0.0, global_position.distance_to(target.global_position) - body_radius - target.body_radius)

## 人物圆柱使用圆形底面；建筑卡按绘制出来的方形占地计算。
func surface_gap_to_circle(center: Vector2, radius: float) -> float:
	if not is_building:
		return maxf(0.0, center.distance_to(global_position) - body_radius - radius)
	# 墓碑的 2x2 格占地仍由 nav/部署格子保留为正方形，但真实静态碰撞使用其内切圆。
	return maxf(0.0, center.distance_to(global_position) - body_radius - radius)

func _building_tick(dt: float) -> void:
	if lifespan > 0.0:
		_lifespan_left -= dt
		if _lifespan_left <= 0.0:
			_die()
			return
	if not _initial_summons_spawned:
		_spawn_initial_summons()
	if spawn_interval > 0.0:
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			_spawn_timer += spawn_interval
			_spawn_imp_batch()

func _spawn_initial_summons() -> void:
	if _initial_summons_spawned or spawn_interval <= 0.0:
		return
	_initial_summons_spawned = true
	_spawn_imp_batch()

func _spawn_imp_batch() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("spawn_summoned"):
		return
	var count := maxi(spawn_count, 1)
	if spawn_side == "map_side":
		# 以地图中线决定墓碑的产出侧：左半区始终在左侧，右半区始终在右侧。
		var side := Vector2.LEFT if global_position.x < float(scene.FIELD_W) * 0.5 else Vector2.RIGHT
		var lateral_step := CardDB.RADIUS_EXTREMELY_SMALL * 2.0 + SUMMON_SEPARATION
		var first_lateral := -float(count - 1) * lateral_step * 0.5
		var spawn_distance := body_radius + CardDB.RADIUS_EXTREMELY_SMALL + SUMMON_SEPARATION
		for index in count:
			var lateral := first_lateral + float(index) * lateral_step
			var spawn_pos := global_position + side * spawn_distance + Vector2.UP * lateral
			scene.spawn_summoned(team, "imp", spawn_pos)
		_spawn_counter += count
		return
	for index in count:
		var direction: Vector2 = SPAWN_DIRECTIONS[_spawn_counter % SPAWN_DIRECTIONS.size()]
		var spawn_distance := body_radius + CardDB.RADIUS_EXTREMELY_SMALL + SUMMON_SEPARATION
		var spawn_pos: Vector2 = global_position + direction * spawn_distance
		_spawn_counter += 1
		scene.spawn_summoned(team, "imp", spawn_pos)

## 目标管理：当前目标失效/超距则丢弃，重新索敌；目标切换时强制重寻路
func _update_target(allow_out_of_range_hit: bool = false) -> void:
	# 一旦挥出攻击/进入攻击前摇，就锁定当前目标。只有目标死亡、失效或真正离开
	# 攻击范围才解除锁定；不会因为旁边出现更近单位而中途转火。
	if _attacking:
		if _target_is_attackable(_target) and (_target_gap(_target) <= attack_range or allow_out_of_range_hit):
			return
		_target = null
		_attacking = false
		_attack_windup = 0.0
		_attack_recovery_timer = 0.0
		_attack_load = 0.0
		_shroud_active = false
		_path = PackedVector2Array()
		_path_index = 0
	# Godot 的已释放对象引用不等同于普通 null，任何 `is Type` 判断前都必须先清理。
	if not is_instance_valid(_target):
		_target = null
		_attacking = false
		_attack_windup = 0.0
		_attack_recovery_timer = 0.0
		_shroud_active = false
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
		elif _target is Unit and (_target as Unit).is_hidden_from(self):
			drop = true
		elif not _target is Tower and _target_gap(_target) > sight_range:
			drop = true
		if drop:
			_target = null
			_attacking = false
			_attack_windup = 0.0
			_attack_recovery_timer = 0.0
			_shroud_active = false
			_path = PackedVector2Array()
			_path_index = 0
	# 塔只是没有仇恨目标时的行军目标；途中进入视野的合法单位/建筑应能拉走部队。
	if is_instance_valid(_target) and _target is Tower:
		# 水晶不是“公主塔全灭后才存在”的特殊目标：只要进入任意敌方塔的攻击范围，
		# 就按实际表面距离重新比较，包括仍未激活的敌方水晶。
		var nearer_tower := _find_nearest_tower()
		if nearer_tower != null and nearer_tower != _target and _target_gap(nearer_tower) + 0.01 < _target_gap(_target):
			_target = nearer_tower
			_attacking = false
			_attack_windup = 0.0
			_attack_recovery_timer = 0.0
			_attack_load = 0.0
			_shroud_active = false
			_path = PackedVector2Array()
			_path_index = 0
			_repath_cd = 0.0
		var distraction := _find_nearest_distraction()
		if distraction != null:
			_target = distraction
			_attacking = false
			_attack_windup = 0.0
			_attack_recovery_timer = 0.0
			_shroud_active = false
			_path = PackedVector2Array()
			_path_index = 0
			_repath_cd = 0.0
	# 还在追击、尚未进入攻击状态时，视野内出现更近的合法兵种/建筑可以转移仇恨。
	# 一旦进入攻击前摇，函数会在上方提前 return，仍保持攻击锁定规则。
	elif is_instance_valid(_target):
		var nearer := _find_nearest_distraction()
		if nearer != null and nearer != _target and _target_gap(nearer) + 0.01 < _target_gap(_target):
			_target = nearer
			_path = PackedVector2Array()
			_path_index = 0
			_repath_cd = 0.0
	if _target == null:
		_target = _find_nearest_distraction()
		if _target == null:
			_target = _find_nearest_tower()
		if _target != null:
			_repath_cd = 0.0

func _target_is_attackable(target) -> bool:
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return false
	if building_only and not _is_struct(target):
		return false
	if not can_attack_air and target is Unit and (target as Unit).is_air:
		return false
	# 丝缕缠流：目标开启且我方在圈外 → 视为无法看到，不锁定。
	if target is Unit and (target as Unit).is_hidden_from(self):
		return false
	return true

func _is_struct(c: Node) -> bool:
	return c is Tower or (c is Unit and (c as Unit).is_building)

func _find_nearest_distraction() -> Node2D:
	var best: Node2D = null
	var best_dist := sight_range
	for c in get_tree().get_nodes_in_group("combatants"):
		if not c is Unit or c == self or c.team == team or c.hp <= 0.0:
			continue
		var u := c as Unit
		if u.is_air and not can_attack_air:
			continue
		# 丝缕缠流：目标开启但我方在圈外 → 看不到它，照常做自己的事。
		if u.is_hidden_from(self):
			continue
		if building_only and not u.is_building:
			continue
		var dist := _target_gap(c)
		# 普通单位对敌方兵种和建筑一视同仁，统一按碰撞表面距离选最近目标。
		# building_only 单位在上方已经过滤掉普通兵种。
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
	if _target == null or not is_instance_valid(_target):
		return
	if is_air:
		_prepare_movement((_target.global_position - global_position).normalized(), dt)
		return
	# 没有视野仇恨时，塔只是推进方向。地面单位在宽松的低成本路线场上
	# 计算一次推进路径，并不持续跑 A*；只有目标或动态障碍改变才重算。
	if _target is Tower:
		_chase_march(dt)
		return
	_chase_target(dt)

func _chase_march(dt: float) -> void:
	_repath_cd -= dt
	var needs_path := _path_target != _target or _path_goal.x == INF or _path_index >= _path.size()
	var scene := get_tree().current_scene
	if not needs_path and _path_index < _path.size() and scene != null:
		needs_path = not scene.is_ground_segment_walkable(global_position, _path[_path_index], body_radius, self)
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
	if absf(direction.x) > 0.05:
		_facing_x = signf(direction.x)
	# 路径拐点和路线汇入采用短暂方向插值，形成弧线感，避免突然水平切线。
	if _move_direction.length_squared() < 0.001:
		_move_direction = direction.normalized()
	else:
		var turn_weight := minf(_dt * 8.0, 1.0)
		_move_direction = _move_direction.lerp(direction.normalized(), turn_weight).normalized()
	var speed_multiplier := charge_speed_multiplier if _charged else 1.0
	speed_multiplier *= active_speed_multiplier
	if slow_timer > 0.0:
		speed_multiplier *= slow_multiplier
	_move_intent = _move_direction * move_speed * speed_multiplier

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
	var scene := get_tree().current_scene
	var full: PackedVector2Array
	if scene != null and scene.has_method("find_ground_path"):
		full = scene.find_ground_path(global_position, goal, _target, body_radius)
	else:
		full = nav_grid.find_path(global_position, goal)
	if full.size() >= 2:
		_path = full
		_path_index = 1

func _attack(dt: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_attacking = false
		_shroud_active = false
		return
	var face_delta: float = _target.global_position.x - global_position.x
	if absf(face_delta) > 0.05:
		_facing_x = signf(face_delta)
	if _attack_windup > 0.0:
		_try_start_attack_visual(_attack_windup)
		_attack_windup = maxf(0.0, _attack_windup - dt)
		if _attack_windup > 0.0:
			return
	if continuous_attack:
		_deal_attack_damage(damage * active_damage_multiplier * active_attack_speed_multiplier * dt)
		return
	_try_start_attack_visual(_attack_cd)
	if _attack_cd <= 0.0:
		# 连招节奏：若配置了 attack_pattern，则按本次命中后的间隔取值；否则固定为 attack_interval。
		var hit_index := _attack_hit_index
		var next_attack_gap := _next_attack_gap()
		_attack_cd = next_attack_gap
		var hit_damage := damage * _attack_damage_multiplier(hit_index) * active_damage_multiplier * (charge_damage_multiplier if _charged else 1.0)
		# 挥击序号与表现层攻击动画序号同步推进，供命中回血按三段循环取模。
		_attack_swing_count += 1
		var attack_form_index := form_index
		_deal_attack_damage(hit_damage)
		# 这一击若触发形态变化，新形态已清空旧攻击状态；不能再写回旧形态的后摇。
		if form_index != attack_form_index:
			return
		# 从命中点锁定到下一次攻击动作应当开始的时刻，即当前动作的后摇段。
		# 若目标仍在射程内，计时结束后无缝开始下一次前摇；若已离开，则此时才追击。
		_attack_recovery_timer = maxf(next_attack_gap - first_hit_time, 0.0)
		_attack_load = 0.0
		_attack_visual_pending = true
		cancel_charge()

## 当前固定 tick 是否正好跨过一次攻击命中节点。
## 命中节点之外仍严格检查射程，避免把整个前摇都变成不可取消的攻击锁定。
func _reaches_attack_hit_this_tick(dt: float) -> bool:
	if not _attacking or continuous_attack or not _target_is_attackable(_target):
		return false
	if _attack_windup > 0.0:
		return _attack_windup <= dt + 0.0001
	return not _attack_visual_pending and _attack_cd <= dt + 0.0001

## 连招间距：attack_pattern 为每次命中后到下一次命中的间隔，按数组顺序循环。
func _next_attack_gap() -> float:
	if attack_pattern.is_empty():
		return attack_interval / active_attack_speed_multiplier
	var gap: float = float(attack_pattern[_attack_hit_index % attack_pattern.size()])
	_attack_hit_index += 1
	return maxf(gap / active_attack_speed_multiplier, 0.01)

func _attack_damage_multiplier(hit_index: int) -> float:
	if attack_damage_multipliers.is_empty():
		return 1.0
	return maxf(float(attack_damage_multipliers[hit_index % attack_damage_multipliers.size()]), 0.0)

## 每次攻击在命中前 first_hit_time 发出一次表现序号。表现层可以据此播放完整动作，
## 但伤害仍只由上面的固定 tick 逻辑结算。
func _try_start_attack_visual(time_until_hit: float) -> void:
	if continuous_attack or not _attack_visual_pending or time_until_hit > first_hit_time + 0.001:
		return
	_attack_visual_pending = false
	_attack_visual_serial += 1

func _deal_attack_damage(amount: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("launch_attack"):
		scene.launch_attack(self, _target, amount, projectile_speed, splash_radius, attack_knockback, projectile_color)
	else:
		var landed: bool = _target.take_damage(amount, self)
		if landed:
			on_attack_landed()

## 主机在伤害真正落到目标后调用。格温由此精确地在首次普攻命中而非出手时开启缠流；
## 赵信等配置了命中回血的单位也在这里结算，未真正造成伤害的挥击不触发回复。
func on_attack_landed(attack_form_index: int = -1) -> void:
	var landed_form := form_index if attack_form_index < 0 else attack_form_index
	# 在途小纳尔回旋镖不会在大形态下误算成大纳尔的 4 次近战命中。
	if landed_form != form_index:
		return
	if transform_after_hits > 0 and form_index == 0:
		transform_hit_count += 1
		if transform_hit_count >= transform_after_hits:
			transform_to_mega()
	elif revert_after_hits > 0 and form_index == 1:
		transform_hit_count += 1
		if transform_hit_count >= revert_after_hits:
			transform_to_small()
	if shroud_radius > 0.0 and not _shroud_active:
		_shroud_active = true
		queue_redraw()
	_try_heal_on_hit()

## 命中回血：每 heal_every_hits 次挥击中的命中回复 heal_amount 生命。
## 挥击序号与三段普攻动画循环对齐——第三击（Passive_AA_01）命中时回复。
func _try_heal_on_hit() -> void:
	if heal_every_hits <= 0 or heal_amount <= 0.0:
		return
	if _attack_swing_count % heal_every_hits != 0:
		return
	hp = minf(hp + heal_amount, max_hp)
	queue_redraw()

func freeze(duration: float) -> void:
	frozen_timer = maxf(frozen_timer, duration)
	queue_redraw()

func stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, duration)
	queue_redraw()

func apply_slow(duration: float, multiplier: float) -> void:
	slow_timer = maxf(slow_timer, duration)
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.1, 1.0))
	queue_redraw()

func apply_active_buff(duration: float, speed_multiplier: float, damage_multiplier: float, attack_speed_multiplier: float) -> void:
	active_buff_timer = maxf(active_buff_timer, duration)
	active_speed_multiplier = maxf(active_speed_multiplier, speed_multiplier)
	active_damage_multiplier = maxf(active_damage_multiplier, damage_multiplier)
	active_attack_speed_multiplier = maxf(active_attack_speed_multiplier, attack_speed_multiplier)
	# 已经进入普攻冷却时也立即获得攻速收益，避免按钮按下后要等完整旧周期。
	_attack_cd /= maxf(attack_speed_multiplier, 1.0)
	queue_redraw()

func add_shield(amount: float, duration: float) -> void:
	shield_hp += maxf(amount, 0.0)
	shield_timer = maxf(shield_timer, duration)
	queue_redraw()

func _tick_active_statuses(dt: float) -> void:
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - dt)
		if slow_timer <= 0.0:
			slow_multiplier = 1.0
	if shield_timer > 0.0:
		shield_timer = maxf(0.0, shield_timer - dt)
		if shield_timer <= 0.0:
			shield_hp = 0.0
	if active_buff_timer > 0.0:
		active_buff_timer = maxf(0.0, active_buff_timer - dt)
		if active_buff_timer <= 0.0:
			active_speed_multiplier = 1.0
			active_damage_multiplier = 1.0
			active_attack_speed_multiplier = 1.0

func is_frozen() -> bool:
	return frozen_timer > 0.0

func is_stunned() -> bool:
	return stun_timer > 0.0

func take_damage(amount: float, from: Node2D = null, source_team: int = -1, source_position: Vector2 = Vector2(INF, INF)) -> bool:
	if hp <= 0.0:
		return false
	if _is_shroud_blocked(from, source_team, source_position):
		return false
	var remaining_damage := amount
	if shield_hp > 0.0 and shield_timer > 0.0:
		var absorbed := minf(shield_hp, remaining_damage)
		shield_hp -= absorbed
		remaining_damage -= absorbed
		if shield_hp <= 0.0:
			shield_timer = 0.0
	hp -= remaining_damage
	if hp <= 0.0:
		_die(death_spawn_count > 0)
	else:
		# 持续伤害可能每个 20Hz tick 都结算；限制纯表现事件频率，避免模型常亮和可靠 RPC 洪泛。
		if _hit_flash_event_cooldown <= 0.0:
			_hit_flash_event_cooldown = HIT_FLASH_EVENT_COOLDOWN
			notify_visual_hit()
			var scene := get_tree().current_scene
			if net_id >= 0 and scene != null and scene.has_method("on_unit_hit"):
				scene.on_unit_hit(net_id)
		queue_redraw()
	return true

## 只触发表现，不参与血量或硬直；主机通过可靠 RPC 在客户端重放同一次闪白。
func notify_visual_hit() -> void:
	visual_hit.emit()

## 丝缕缠流：开启后，距离 viewer 超过 shroud_radius 的敌方看到她但无法锁定/命中，
## 视她为不存在。用于敌方索敌时跳过格温，让其照常做自己的事。
## viewer 为试图攻击/索敌的敌方（单位或塔），距离按两中心点计算。
func is_hidden_from(viewer: Node2D) -> bool:
	if viewer == null or not is_instance_valid(viewer):
		return false
	return is_hidden_from_position(viewer.team, viewer.global_position)

## 弹体保留攻击者最后的有效位置；即使攻击者在飞行途中死亡，也能正确判断圈外攻击。
func is_hidden_from_position(viewer_team: int, viewer_position: Vector2) -> bool:
	if not _shroud_active or shroud_radius <= 0.0 or viewer_team == team:
		return false
	return global_position.distance_to(viewer_position) > shroud_radius

## 丝缕缠流：开启后，伤害来源离开自身 shroud_radius 时整次伤害失效。
## from 由 main 在近战/弹道命中时透传攻击者（单位或塔），仅主机结算。
## main 会优先让在途弹体消散；这里继续兜底同一 tick 的竞态或其他直接伤害入口，
## 确保圈外伤害和击退都不能穿透，而敌方能看见的圈内攻击仍正常生效。
func _is_shroud_blocked(from: Node2D, source_team: int = -1, source_position: Vector2 = Vector2(INF, INF)) -> bool:
	if not _shroud_active or shroud_radius <= 0.0:
		return false
	var resolved_team := source_team
	var resolved_position := source_position
	if from != null and is_instance_valid(from):
		resolved_team = from.team
		resolved_position = from.global_position
	if resolved_team < 0 or resolved_position.x == INF or resolved_position.y == INF:
		return false
	if resolved_team == team:
		return false
	return global_position.distance_to(resolved_position) > shroud_radius

## 供 main 的推挤逻辑调用：该位置对当前单位是否可行走
func is_walkable_at(pos: Vector2) -> bool:
	if is_air:
		return true
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("is_ground_position_walkable"):
		return scene.is_ground_position_walkable(pos, body_radius, self)
	var nav_grid := _get_nav()
	if nav_grid == null:
		return true
	return nav_grid.is_walkable(pos)

func _get_nav() -> NavGrid:
	var scene := get_tree().current_scene
	if scene == null or not ("nav" in scene):
		return null
	return scene.nav

func _in_client_mode() -> bool:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("is_net_client"):
		return false
	return scene.is_net_client()

func _die(trigger_death_effect: bool = false) -> void:
	remove_from_group("combatants")
	var scene := get_tree().current_scene
	# 建筑卡死亡 → 解除导航网格占地
	if is_building and not nav_cells.is_empty():
		if scene != null and scene.has_method("unblock_nav_cells"):
			scene.unblock_nav_cells(nav_cells)
		nav_cells = []
	if trigger_death_effect:
		_spawn_death_summons()
	# 表现层只保留一个无碰撞代理播放死亡动作；战斗节点仍在本帧释放。
	notify_visual_death()
	# 联机单位死亡 → 主机可靠通知客户端播放死亡动作，并立即清理 net_id 映射。
	if net_id >= 0 and scene != null and scene.has_method("on_unit_died"):
		scene.on_unit_died(net_id)
	queue_free()

func _spawn_death_summons() -> void:
	if death_spawn_count <= 0 or death_spawn_id.is_empty() or _in_client_mode():
		return
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("spawn_summoned"):
		return
	var summon_stats: Dictionary = CardDB.imp_stats() if death_spawn_id == "imp" else CardDB.all().get(death_spawn_id, {})
	if summon_stats.is_empty():
		return
	var summon_radius := float(summon_stats.get("radius", 14.0))
	var spawn_distance := body_radius + summon_radius + SUMMON_SEPARATION
	for index in range(death_spawn_count):
		var direction: Vector2 = SPAWN_DIRECTIONS[index % SPAWN_DIRECTIONS.size()]
		var spawn_pos := global_position + direction * spawn_distance
		scene.spawn_summoned(team, death_spawn_id, spawn_pos)

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
	_health_bar_y = _health_bar_center.y
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
		set_visual_head_world_position(get_visual_screen_position() + Vector2(0.0, -visual_radius))

func _draw() -> void:
	draw_set_transform(_vis_offset, 0.0, Vector2.ONE)
	var shroud_visible := net_shroud_active if _in_client_mode() else _shroud_active
	if shroud_visible and shroud_radius > 0.0:
		draw_circle(Vector2.ZERO, shroud_radius, Color(0.34, 0.76, 0.92, 0.08))
		draw_arc(Vector2.ZERO, shroud_radius, 0.0, TAU, 72, Color(0.55, 0.88, 1.0, 0.58), 2.0, true)
	if continuous_beam_visible and has_continuous_visual_target():
		_draw_continuous_beam()
	var has_art := has_model_art or (_presentation != null and _presentation.has_art())
	if is_building and not has_art:
		draw_rect(Rect2(-body_radius, -body_radius, body_radius * 2.0, body_radius * 2.0), color)
		draw_rect(Rect2(-body_radius, -body_radius, body_radius * 2.0, body_radius * 2.0), Color(0.2, 0.18, 0.12), false, 2.0)
	elif not is_building and not has_art:
		var outline := Color(0.30, 0.60, 1.00) if team == 0 else Color(1.00, 0.35, 0.30)
		draw_circle(Vector2.ZERO, visual_radius + 2.0, outline)
		draw_circle(Vector2.ZERO, visual_radius, color)
	if _deploy_timer > 0.0:
		# 部署读条仍使用代码绘制，便于观察一秒落地窗口。
		var deploy_ratio := 1.0 - _deploy_timer / maxf(deploy_time, 0.001)
		draw_arc(Vector2.ZERO, visual_radius + 6.0, -PI / 2.0, -PI / 2.0 + TAU * deploy_ratio, 24, Color.WHITE, 3.0)
	if _sweep_fx_timer > 0.0 and deploy_sweep_radius > 0.0:
		_draw_sweep_fx()
	var ratio := maxf(hp / max_hp, 0.0)
	if ratio < 1.0:
		var bar_w := visual_radius * 2.0
		var bar_rect := Rect2(
			_health_bar_center.x - bar_w * 0.5,
			_health_bar_center.y - HEALTH_BAR_HEIGHT * 0.5,
			bar_w,
			HEALTH_BAR_HEIGHT
		)
		draw_rect(bar_rect, Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(bar_rect.position, Vector2(bar_w * ratio, HEALTH_BAR_HEIGHT)), get_health_bar_fill_color())
	if frozen_timer > 0.0:
		draw_circle(Vector2.ZERO, visual_radius + 4.0, Color(0.4, 0.8, 1.0, 0.3))
	var stunned_visible := net_stun_active if _in_client_mode() else stun_timer > 0.0
	if stunned_visible:
		draw_arc(Vector2.ZERO, visual_radius + 5.0, 0.0, TAU, 24, Color(1.0, 0.78, 0.18, 0.95), 3.0, true)
	var shield_visible := net_shield_active if _in_client_mode() else shield_hp > 0.0
	if shield_visible:
		draw_arc(Vector2.ZERO, visual_radius + 7.0, 0.0, TAU, 36, Color(0.35, 0.85, 1.0, 0.9), 3.0, true)
	var slow_visible := net_slow_active if _in_client_mode() else slow_timer > 0.0
	if slow_visible:
		draw_arc(Vector2.ZERO, visual_radius + 10.0, 0.0, TAU, 24, Color(0.45, 0.65, 1.0, 0.75), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 临时吐息表现：嘴部端窄、目标端宽的半透明梯形光柱。
## 光柱只读取已经确定的攻击目标，宽度与高度均不参与权威命中判定。
func _draw_continuous_beam() -> void:
	var source_screen := get_visual_screen_position()
	var target_local := get_continuous_visual_target_position() - source_screen
	var mouth_local := Vector2(0.0, -continuous_beam_origin_height)
	var to_target := target_local - mouth_local
	if to_target.length_squared() < 0.001:
		return
	var direction := to_target.normalized()
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

## 横扫表现：面向单位正面的扇形斩击与外扩冲击弧，不绘制完整圆环。
func _draw_sweep_fx() -> void:
	var progress := 1.0 - _sweep_fx_timer / SWEEP_FX_DURATION
	var fade := 1.0 - progress
	var eased := 1.0 - pow(1.0 - progress, 0.65)
	var facing := get_visual_facing_direction()
	var center_angle := facing.angle()
	var radius := lerpf(visual_radius + 8.0, deploy_sweep_radius * 0.88, eased)
	var span := lerpf(1.25, 2.15, progress)
	var start_angle := center_angle - span * 0.5
	var end_angle := center_angle + span * 0.5
	var gold := Color(1.0, 0.78, 0.28, fade * 0.9)
	var highlight := Color(1.0, 0.96, 0.72, fade)
	draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 28, gold, 7.0, true)
	draw_arc(Vector2.ZERO, radius - 5.0, start_angle + 0.08, end_angle - 0.08, 24, highlight, 2.5, true)
	var tip := Vector2.from_angle(center_angle) * radius
	var tail := Vector2.from_angle(center_angle) * (radius * 0.42)
	draw_line(tail, tip, highlight, 3.0, true)
