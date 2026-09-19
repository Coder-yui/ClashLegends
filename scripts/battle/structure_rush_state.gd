class_name StructureRushState
extends RefCounted
## 一生一次的建筑冲撞。只由权威单位 Tick 推进；模型动作仅镜像这些窗口。
enum Phase { READY, PREPARING, DASHING, RECOVERY, SPENT }
var phase := Phase.READY
var remaining := 0.0
## 准备被硬控/击退打断后，直到下一次冲撞决策明确失败前仍属于本轮尝试。
## 仅影响先锋主动技能资格，不改变 READY 的寻路与索敌语义。
var awaiting_reprepare := false
var target: Node2D
var direction := Vector2.ZERO
var endpoint := Vector2.ZERO
var hit_ids := {}
var config: Dictionary = {}
var _launch_target_id := 0
var _launch_nav_revision := -1
var _launch_target_position := Vector2.INF
var _launch_retry := 0.0
# 累积计数供测试/性能采样读取；不逐 Tick 输出。
var search_count := 0
var candidate_count := 0
var path_count := 0
var search_usec := 0

func configure(stats: Dictionary) -> void:
	config = stats
	_launch_target_id = 0
	_launch_retry = 0.0
	awaiting_reprepare = false
	phase = Phase.READY if float(stats.get("rush_distance", 0.0)) > 0.0 else Phase.SPENT

func locked() -> bool:
	return phase in [Phase.PREPARING, Phase.DASHING, Phase.RECOVERY]

func skill_locked() -> bool:
	return locked() or awaiting_reprepare

func displacement_immune() -> bool:
	return phase in [Phase.PREPARING, Phase.DASHING]

func control_immune() -> bool:
	return phase == Phase.DASHING

func interrupt_preparation(unit: Unit) -> void:
	if phase != Phase.PREPARING: return
	remaining = float(config.rush_prepare_time)
	awaiting_reprepare = true
	phase = Phase.READY
	unit.play_visual_action(&"", 0.0)

func tick(unit: Unit, dt: float) -> bool:
	if phase == Phase.SPENT: return false
	if phase == Phase.RECOVERY:
		remaining = maxf(0.0, remaining - dt)
		if remaining <= 0.000001: phase = Phase.SPENT
		return true
	if phase == Phase.READY:
		unit._update_target(false)
		target = unit._target
		if not _valid_target(unit):
			awaiting_reprepare = false
			return false
		if unit._target_gap(target) > float(config.rush_distance):
			awaiting_reprepare = false
			unit._chase(dt)
			return true
		direction = unit.global_position.direction_to(target.global_position)
		endpoint = target.global_position - direction * (unit.body_radius + target.body_radius + ArenaRules.STRUCTURE_SEPARATION + 0.1)
		# 整段圆柱必须能行走：不会跨水、切桥角或穿越其他建筑。
		if not unit.battle_context.is_ground_segment_walkable(unit.global_position, endpoint, unit.body_radius, unit):
			awaiting_reprepare = false
			_approach_launch_point(unit, dt)
			return true
		phase = Phase.PREPARING
		awaiting_reprepare = false
		remaining = float(config.rush_prepare_time)
		unit._knockback_timer = 0.0
		unit.attack_timeline.cancel()
		unit._attacking = false
		unit._move_direction = direction
		unit.play_visual_action(&"rush_prepare", remaining)
		return true
	if phase == Phase.PREPARING:
		if not _valid_target(unit):
			phase = Phase.READY
			awaiting_reprepare = false
			unit.play_visual_action(&"", 0.0)
			return true
		remaining = maxf(0.0, remaining - dt)
		if remaining > 0.000001: return true
		# 准备期间出现建筑也必须重新验证，不能沿过时路线冲过去。
		if not unit.battle_context.is_ground_segment_walkable(unit.global_position, endpoint, unit.body_radius, unit):
			phase = Phase.READY
			awaiting_reprepare = false
			unit.play_visual_action(&"", 0.0)
			return true
		phase = Phase.DASHING
		hit_ids.clear()
		unit.play_visual_action(&"rush_dash", maxf(Unit.SIM_DT, unit.global_position.distance_to(endpoint) / float(config.rush_speed)))
		_audio(unit, &"rush:start")
	if phase == Phase.DASHING:
		if not _valid_target(unit):
			_finish(unit, false)
			return true
		var distance := unit.global_position.distance_to(endpoint)
		if distance <= 0.01:
			_impact(unit)
			return true
		var step := minf(distance, float(config.rush_speed) * dt)
		var blocker := _first_structure_contact(unit, step)
		if not blocker.is_empty():
			if blocker.structure.team == unit.team:
				_finish(unit, false)
				return true
			target = blocker.structure
			step = float(blocker.distance)
			endpoint = unit.global_position + direction * step
			if step <= 0.01:
				_impact(unit)
				return true
		var next := unit.global_position + direction * step
		if not unit.battle_context.is_ground_segment_walkable(unit.global_position, next, unit.body_radius, unit):
			_finish(unit, false)
			return true
		unit._move_intent = direction * step / dt
		unit._move_direction = direction
		unit._forced_movement = true
		_sweep(unit, next)
		return true
	return false

## 找本 Tick 最先接触的建筑表面；复用建筑权威表面距离，不穿透后排。
func _first_structure_contact(unit: Unit, distance: float) -> Dictionary:
	var result := {}
	var nearest := INF
	var samples := maxi(1, ceili(distance))
	for structure in unit.get_tree().get_nodes_in_group("combat_structures"):
		if structure == unit or not is_instance_valid(structure) or structure.hp <= 0.0 or structure.is_queued_for_deletion(): continue
		for index in range(samples + 1):
			var travel := distance * float(index) / float(samples)
			if travel > nearest + 1.0: break
			if _structure_gap(structure, unit.global_position + direction * travel, unit.body_radius) > ArenaRules.STRUCTURE_SEPARATION + 0.1: continue
			var low := maxf(0.0, travel - distance / float(samples))
			var high := travel
			for iteration in 16:
				var mid := (low + high) * 0.5
				if _structure_gap(structure, unit.global_position + direction * mid, unit.body_radius) > ArenaRules.STRUCTURE_SEPARATION + 0.1: low = mid
				else: high = mid
			if low < nearest:
				nearest = low
				result = {"structure": structure, "distance": low}
			break
	return result

func _structure_gap(structure: Node2D, point: Vector2, radius: float) -> float:
	if structure.has_method("surface_gap_to_circle"):
		return structure.surface_gap_to_circle(point, radius)
	return maxf(0.0, point.distance_to(structure.global_position) - structure.body_radius - radius)

func _valid_target(unit: Unit) -> bool:
	return is_instance_valid(target) and target.hp > 0.0 and not target.is_queued_for_deletion() and target.team != unit.team and unit._is_struct(target)

func _sweep(unit: Unit, next: Vector2) -> void:
	var side := Vector2(-direction.y, direction.x)
	var order := unit.battle_context.damage_batch().next_displacement_order(unit)
	for c in unit.get_tree().get_nodes_in_group("combatants"):
		if not c is Unit or c == unit or c.hp <= 0.0 or c.team == unit.team or c.is_air or c.is_building: continue
		var id: int = c.get_instance_id()
		if hit_ids.has(id): continue
		var closest := Geometry2D.get_closest_point_to_segment(c.global_position, unit.global_position, next)
		if closest.distance_to(c.global_position) > unit.body_radius + c.body_radius: continue
		hit_ids[id] = true
		var result := BattleNumbers.hit(c, float(config.rush_path_damage), unit, unit.team, unit.global_position)
		var signed_side: float = (c.global_position - unit.global_position).dot(side)
		var push_side := side * (signf(signed_side) if absf(signed_side) > 0.001 else (-1.0 if c.combat_source_id % 2 == 0 else 1.0))
		# 挤出路径的侧向位移走现有击退接管、质量与地形规则。
		var origin: Vector2 = c.global_position - push_side
		if unit.battle_context.damage_batch().collecting:
			unit.battle_context.damage_batch().submit_knockback(c, origin, float(config.rush_push_distance), 0.2, 1.0, order, result)
		elif result.landed:
			c.apply_knockback(origin, float(config.rush_push_distance), 0.2, 1.0, order)
		var apply_hit := func():
			if not result.landed: return
			_audio(unit, &"rush:path_hit")
		if unit.battle_context.damage_batch().collecting:
			unit.battle_context.damage_batch().defer_effect(apply_hit)
		else: apply_hit.call()

func _impact(unit: Unit) -> void:
	if not is_instance_valid(unit): return
	if unit.hp <= 0.0 or not _valid_target(unit):
		_finish(unit, false)
		return
	var result := BattleNumbers.hit(target, float(config.rush_building_damage), unit, unit.team, unit.global_position)
	var point := unit.global_position + direction * unit.body_radius
	var impact_direction := direction
	_finish(unit, true)
	var on_hit := func():
		# 同批次死亡也属于空撞；不能由延迟提交回调留下死后孵化。
		if not result.landed or not is_instance_valid(unit) or unit.hp <= 0.0: return
		_audio(unit, &"rush:hit")
		# 代价明确扣当前生命，不由护盾抵消，也不发放吸血/普攻收益。
		if is_instance_valid(unit) and unit.hp > 0.0:
			unit.hp = maxf(1.0, unit.hp - BattleNumbers.quantity(unit.hp * float(config.rush_self_health_ratio)))
		var count := int(config.rush_spawn_count)
		var radius := float(CardDB.get_unit_stats(String(config.rush_spawn_id)).radius)
		var side := Vector2(-impact_direction.y, impact_direction.x)
		# 紧凑的撞击源向建筑外侧扇形爆出，而非围着目标摆成整圈。
		for index in count:
			var ratio := float(index) / float(maxi(1, count - 1))
			var outward := (-impact_direction).rotated(lerpf(-1.22, 1.22, ratio))
			var seed := point - impact_direction * (radius + ArenaRules.STRUCTURE_SEPARATION + 2.0) + side * lerpf(-8.0, 8.0, ratio)
			var spawn := unit.battle_context.spawn_summoned(unit.team, String(config.rush_spawn_id), seed)
			if spawn != null:
				spawn.apply_knockback(spawn.global_position - outward, float(config.rush_spawn_spread) * ([0.8, 2.3, 1.5, 2.0, 1.0, 2.6][index % 6]), 0.45, 1.0)
	if unit.battle_context.damage_batch().collecting:
		unit.battle_context.damage_batch().defer_effect(on_hit)
	else: on_hit.call()

func _finish(unit: Unit, landed: bool) -> void:
	phase = Phase.RECOVERY
	remaining = float(config.rush_recovery_time)
	unit._move_intent = Vector2.ZERO
	unit._forced_movement = false
	unit.play_visual_action(&"rush_hit" if landed else &"", remaining if landed else 0.0)

func _audio(unit: Unit, cue: StringName) -> void:
	if is_instance_valid(unit) and unit.battle_context != null:
		unit.battle_context.notify_unit_audio_event(unit, cue, unit.global_position)

## 找最近可达的发起点：桥面可用，水域与建筑仍按整段圆柱检查。
func _approach_launch_point(unit: Unit, dt: float) -> void:
	_launch_retry -= dt
	var nav := unit.battle_context.navigation()
	var revision := nav.revision if nav != null else -1
	var invalid_path := unit._path_index < unit._path.size() and not unit.battle_context.is_ground_segment_walkable(unit.global_position, unit._path[unit._path_index], unit.body_radius, unit)
	if _launch_retry <= 0.000001 or _launch_target_id != target.get_instance_id() or _launch_nav_revision != revision or _launch_target_position != target.global_position or invalid_path:
		var started := Time.get_ticks_usec()
		search_count += 1
		_launch_target_id = target.get_instance_id()
		_launch_nav_revision = revision
		_launch_target_position = target.global_position
		# 失败也覆盖旧路线，不能向旧目标继续移动。
		unit._path = PackedVector2Array()
		unit._path_index = 0
		unit._path_target = target
		unit._path_goal = Vector2.INF
		var goal := Vector2.INF
		var best := INF
		var best_path := PackedVector2Array()
		# 以导航格心与目标周围候选点搜索，按实际步行路线长度选最近点。
		var clearance: float = unit.body_radius + target.body_radius + ArenaRules.STRUCTURE_SEPARATION + 0.1
		var reach: float = float(config.rush_distance) + unit.body_radius + target.body_radius
		var center := target.global_position
		var tile := float(ArenaRules.TILE_SIZE)
		# 保留原行列顺序和全部圆内候选，仅跳过必然不合法的外接矩形外格心。
		for row in range(maxi(0, ceili((center.y - reach) / tile - 0.5)), mini(ArenaRules.ARENA_ROWS, floori((center.y + reach) / tile - 0.5) + 1)):
			for column in range(maxi(0, ceili((center.x - reach) / tile - 0.5)), mini(ArenaRules.ARENA_COLUMNS, floori((center.x + reach) / tile - 0.5) + 1)):
				candidate_count += 1
				var candidate := Vector2((column + 0.5) * ArenaRules.TILE_SIZE, (row + 0.5) * ArenaRules.TILE_SIZE)
				var distance: float = candidate.distance_to(target.global_position)
				if distance <= clearance or distance - unit.body_radius - target.body_radius > float(config.rush_distance): continue
				if unit.global_position.distance_to(candidate) >= best: continue
				if not unit.battle_context.is_ground_position_walkable(candidate, unit.body_radius, unit): continue
				var landing: Vector2 = target.global_position + target.global_position.direction_to(candidate) * clearance
				if not unit.battle_context.is_ground_segment_walkable(candidate, landing, unit.body_radius, unit): continue
				path_count += 1
				var path := unit.battle_context.find_ground_path(unit.global_position, candidate, target, unit.body_radius)
				if path.is_empty(): continue
				if not unit.battle_context.is_ground_segment_walkable(path[-1], candidate, unit.body_radius, unit): continue
				var path_length := 0.0
				var previous := unit.global_position
				for point in path:
					path_length += previous.distance_to(point)
					previous = point
				path_length += previous.distance_to(candidate)
				if path_length < best:
					best = path_length
					goal = candidate
					best_path = path
		if goal.is_finite():
			unit._path = best_path
			unit._path.append(goal)
			unit._path_index = 0
			unit._path_target = target
			unit._path_goal = goal
		_launch_retry = 0.4
		search_usec += Time.get_ticks_usec() - started
	if not unit._path.is_empty(): unit._follow_current_path(dt)
