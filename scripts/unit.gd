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

const SIM_DT := 1.0 / 20.0
const PATH_REACH := 8.0
const REPATH_INTERVAL := 0.25
const MARCH_REPATH_INTERVAL := 0.8
const DEFAULT_SIGHT_RANGE := 220.0
# 建筑卡召唤小鬼的确定性方向偏移（按序轮转，不引入随机数）
const SPAWN_OFFSETS := [
	Vector2(24, 0), Vector2(17, 17), Vector2(0, 24), Vector2(-17, 17),
	Vector2(-24, 0), Vector2(-17, -17), Vector2(0, -24), Vector2(17, -17),
]

var net_id := -1
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
var deploy_time := 1.0
var first_hit_time := 0.2
var projectile_speed := 0.0
var splash_radius := 0.0
var attack_knockback := 0.0
var charge_time := 0.0
var charge_speed_multiplier := 1.0
var charge_damage_multiplier := 1.0

var frozen_timer := 0.0

# 联机客户端插值字段（main 快照写入）
var net_target_pos: Vector2

# 建筑卡专用
var lifespan := 0.0
var spawn_interval := 0.0
var nav_cells: Array = []

var _target: Node2D = null
var _attack_cd := 0.0
var _attacking := false
var _attack_windup := 0.0
var _attack_load := 0.0
var _deploy_timer := 0.0
var _lifespan_left := 0.0
var _spawn_timer := 0.0
var _spawn_counter := 0

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
var _presentation: UnitPresentation = null

# 渲染插值：sim 为 20Hz，渲染在上一模拟位置与当前位置间过渡
var _prev_pos := Vector2.ZERO
var _interp := 1.0
var _vis_offset := Vector2.ZERO

func setup(p_team: int, stats: Dictionary, _p_name: String) -> void:
	team = p_team
	hp = stats.hp
	max_hp = stats.hp
	damage = stats.damage
	attack_range = stats.range
	attack_interval = stats.interval
	move_speed = stats.speed
	body_radius = stats.radius
	visual_radius = stats.get("visual_radius", body_radius)
	mass = stats.get("mass", maxf(1.0, body_radius / 3.0))
	sight_range = stats.get("sight", DEFAULT_SIGHT_RANGE)
	color = stats.get("color", Color.DIM_GRAY)
	var frames_path: String = stats.get("visual_frames_path", "")
	if not frames_path.is_empty() and ResourceLoader.exists(frames_path):
		visual_frames = load(frames_path) as SpriteFrames
	is_air = stats.get("is_air", false)
	is_building = stats.get("is_building", false)
	building_only = stats.get("building_only", false)
	can_attack_air = stats.get("can_attack_air", true)
	continuous_attack = stats.get("is_continuous_attack", false)
	deploy_time = stats.get("deploy_time", 1.0)
	first_hit_time = stats.get("first_hit", minf(attack_interval * 0.5, 0.4))
	projectile_speed = stats.get("projectile_speed", 0.0)
	splash_radius = stats.get("splash_radius", 0.0)
	attack_knockback = stats.get("knockback", 0.0)
	charge_time = stats.get("charge_time", 0.0)
	charge_speed_multiplier = stats.get("charge_speed_multiplier", 1.0)
	charge_damage_multiplier = stats.get("charge_damage_multiplier", 1.0)
	lifespan = stats.get("lifespan", 0.0)
	spawn_interval = stats.get("spawn_interval", 0.0)
	_lifespan_left = lifespan
	_spawn_timer = spawn_interval
	_deploy_timer = deploy_time
	net_target_pos = global_position
	_prev_pos = global_position

func _ready() -> void:
	add_to_group("combatants")
	_presentation = UnitPresentation.new()
	add_child(_presentation)
	_presentation.setup(visual_frames, visual_radius)

func _process(delta: float) -> void:
	if _in_client_mode():
		# 客户端：朝快照目标位置平滑插值，血量/冰冻由 main 快照直接写入
		position = position.lerp(net_target_pos, minf(delta * 10.0, 1.0))
		_deploy_timer = maxf(0.0, _deploy_timer - delta)
		_sync_presentation(net_visual_state, net_facing_x)
		queue_redraw()
		return
	if is_building or hp <= 0.0:
		return
	# 主机/单机：渲染层在两次模拟之间插值
	_interp = minf(_interp + delta / SIM_DT, 1.0)
	_vis_offset = (_prev_pos - position) * (1.0 - _interp)
	_sync_presentation(get_visual_state_code(), _facing_x)
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

## 固定 tick 模拟入口，由 main._sim_step 以 SIM_DT 驱动
func sim_tick(dt: float) -> void:
	if hp <= 0.0:
		return
	_prev_pos = position
	_interp = 0.0
	_move_intent = Vector2.ZERO
	_forced_movement = false
	# CR 卡牌落地后有部署时间；期间不索敌、不移动、不可被锁定。
	if _deploy_timer > 0.0:
		_deploy_timer = maxf(0.0, _deploy_timer - dt)
		if _deploy_timer <= 0.0:
			_just_deployed = true
		queue_redraw()
		return
	if frozen_timer > 0.0:
		frozen_timer = maxf(0.0, frozen_timer - dt)
		if frozen_timer <= 0.0:
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
	_attack_cd = maxf(0.0, _attack_cd - dt)
	_update_target()
	if _target != null:
		if _target_gap(_target) <= attack_range:
			if not _attacking:
				# 移动期间会预装填一部分攻击周期；被推出射程会丢失这次预装填。
				_attack_windup = maxf(first_hit_time, attack_interval - _attack_load)
			_attacking = true
			_path = PackedVector2Array()
			_path_index = 0
			_attack(dt)
			return
	if _attacking and _attack_windup > 0.0:
		_attack_load = 0.0
	_attacking = false
	_attack_windup = 0.0
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
	_attack_load = 0.0
	_attacking = false
	cancel_charge()

func _target_gap(target: Node2D) -> float:
	if target.has_method("surface_gap_to_circle"):
		return target.surface_gap_to_circle(global_position, body_radius)
	return maxf(0.0, global_position.distance_to(target.global_position) - body_radius - target.body_radius)

## 普通单位是圆；建筑卡按绘制出来的方形占地计算。
func surface_gap_to_circle(center: Vector2, radius: float) -> float:
	if not is_building:
		return maxf(0.0, center.distance_to(global_position) - body_radius - radius)
	var rect := Rect2(global_position - Vector2.ONE * body_radius, Vector2.ONE * body_radius * 2.0)
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	return maxf(0.0, center.distance_to(closest) - radius)

func _building_tick(dt: float) -> void:
	if lifespan > 0.0:
		_lifespan_left -= dt
		if _lifespan_left <= 0.0:
			_die()
			return
	if spawn_interval > 0.0:
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			_spawn_timer += spawn_interval
			_spawn_imp()

func _spawn_imp() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("spawn_summoned"):
		return
	var spawn_pos: Vector2 = global_position + SPAWN_OFFSETS[_spawn_counter % SPAWN_OFFSETS.size()]
	_spawn_counter += 1
	scene.spawn_summoned(team, "imp", spawn_pos)

## 目标管理：当前目标失效/超距则丢弃，重新索敌；目标切换时强制重寻路
func _update_target() -> void:
	# 一旦挥出攻击/进入攻击前摇，就锁定当前目标。只有目标死亡、失效或真正离开
	# 攻击范围才解除锁定；不会因为旁边出现更近单位而中途转火。
	if _attacking:
		if _target_is_attackable(_target) and _target_gap(_target) <= attack_range:
			return
		_target = null
		_attacking = false
		_attack_windup = 0.0
		_attack_load = 0.0
		_path = PackedVector2Array()
		_path_index = 0
	# Godot 的已释放对象引用不等同于普通 null，任何 `is Type` 判断前都必须先清理。
	if not is_instance_valid(_target):
		_target = null
		_attacking = false
		_attack_windup = 0.0
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
		elif _target is Unit and not (_target as Unit).is_deployed():
			drop = true
		elif not _target is Tower and _target_gap(_target) > sight_range:
			drop = true
		if drop:
			_target = null
			_attacking = false
			_attack_windup = 0.0
			_path = PackedVector2Array()
			_path_index = 0
	# 塔只是没有仇恨目标时的行军目标；途中进入视野的合法单位/建筑应能拉走部队。
	if is_instance_valid(_target) and _target is Tower:
		var distraction := _find_nearest_distraction()
		if distraction != null:
			_target = distraction
			_attacking = false
			_attack_windup = 0.0
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
	if target is Unit and not (target as Unit).is_deployed():
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
		if not u.is_deployed() or (u.is_air and not can_attack_air):
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
	# 塔永远可作为行军目标；动态建筑由视野内仇恨选择处理。
	var best: Node2D = null
	var best_dist := INF
	for c in get_tree().get_nodes_in_group("combatants"):
		if not c is Tower or c.team == team or c.hp <= 0.0:
			continue
		var dist := _target_gap(c)
		if dist < best_dist:
			best = c
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
	elif _target != null and not (_target is Tower):
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
		return
	var face_delta: float = _target.global_position.x - global_position.x
	if absf(face_delta) > 0.05:
		_facing_x = signf(face_delta)
	if _attack_windup > 0.0:
		_attack_windup = maxf(0.0, _attack_windup - dt)
		if _attack_windup > 0.0:
			return
	if continuous_attack:
		_deal_attack_damage(damage * dt)
		return
	if _attack_cd <= 0.0:
		_attack_cd = attack_interval
		var hit_damage := damage * (charge_damage_multiplier if _charged else 1.0)
		_deal_attack_damage(hit_damage)
		_attack_load = 0.0
		cancel_charge()

func _deal_attack_damage(amount: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("launch_attack"):
		scene.launch_attack(self, _target, amount, projectile_speed, splash_radius, attack_knockback, color)
	else:
		_target.take_damage(amount)

func freeze(duration: float) -> void:
	frozen_timer = maxf(frozen_timer, duration)
	queue_redraw()

func is_frozen() -> bool:
	return frozen_timer > 0.0

func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		_die()
	else:
		queue_redraw()

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

func _die() -> void:
	remove_from_group("combatants")
	var scene := get_tree().current_scene
	# 建筑卡死亡 → 解除导航网格占地
	if is_building and not nav_cells.is_empty():
		if scene != null and scene.has_method("unblock_nav_cells"):
			scene.unblock_nav_cells(nav_cells)
		nav_cells = []
	# 联机单位死亡 → 通知主机立即清理 net_id 映射（快照靠缺席判定给客户端移除）
	if net_id >= 0 and scene != null and scene.has_method("on_unit_died"):
		scene.on_unit_died(net_id)
	queue_free()

func _draw() -> void:
	draw_set_transform(_vis_offset, 0.0, Vector2.ONE)
	if continuous_attack and _attacking and _target != null and is_instance_valid(_target):
		var target_pos: Vector2 = _target.global_position
		if _target is Unit:
			target_pos += (_target as Unit)._vis_offset
		var dir := (target_pos - global_position).normalized()
		draw_line(dir * body_radius, target_pos - global_position, Color(0.95, 0.6, 0.2, 0.8), 3.0)
	var has_art := _presentation != null and _presentation.has_art()
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
	var ratio := maxf(hp / max_hp, 0.0)
	if ratio < 1.0:
		var bar_w := visual_radius * 2.0
		var bar_y := -visual_radius - 10.0
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w, 4.0), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w * ratio, 4.0), Color(0.2, 0.9, 0.2))
	if frozen_timer > 0.0:
		draw_circle(Vector2.ZERO, visual_radius + 4.0, Color(0.4, 0.8, 1.0, 0.3))
	if _charged:
		draw_arc(Vector2.ZERO, visual_radius + 6.0, 0.0, TAU, 28, Color(1.0, 0.82, 0.25, 0.9), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
