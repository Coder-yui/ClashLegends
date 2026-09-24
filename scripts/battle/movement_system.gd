class_name MovementSystem
extends Node2D
## 固定 Tick 的移动/同层碰撞；拥有本 Tick 候选与速度计算，不访问 Main 私有状态。
var terrain_walkable: Callable
var structure_gap: Callable
var last_movement_usec := 0
var last_collision_usec := 0
var last_unit_count := 0

func tick(dt: float) -> void:
	var units := _active_mobile_units()
	last_unit_count = units.size()
	var started := Time.get_ticks_usec()
	_apply_unit_movement(dt, units)
	last_movement_usec = maxi(Time.get_ticks_usec() - started - last_collision_usec, 0)

## 所有单位先计算移动意图，再统一做局部避让并应用，避免节点遍历顺序影响结果。
func _apply_unit_movement(dt: float, units: Array[Unit]) -> void:
	var velocities := {}
	for unit in units:
		velocities[_unit_order_key(unit)] = _adjust_unit_velocity(unit, units, dt)
	var contact_started := Time.get_ticks_usec()
	var contacts := _collect_unit_contacts(units)
	last_collision_usec = Time.get_ticks_usec() - contact_started
	# 击退也是真实碰撞体。先基于同一位置快照裁剪相对扫掠，避免高速一步穿过单位。
	var combined_velocities := {}
	for unit in units:
		var key := _unit_order_key(unit)
		combined_velocities[key] = velocities[key] + contacts[key] / maxf(dt, 0.0001)
	_clip_knockback_contacts(units, combined_velocities, dt)
	for unit in units:
		var key := _unit_order_key(unit)
		if unit.skill_dash_active: continue
		var autonomous: Vector2 = velocities[key]
		if unit.structure_rush.displacement_immune():
			# 冲撞只能沿已验证直线推进，准备期也不接受接触推挤。
			if unit.structure_rush.control_immune() and unit.battle_context.is_ground_segment_walkable(unit.global_position, unit.global_position + autonomous * dt, unit.body_radius, unit):
				unit.global_position += autonomous * dt
			continue
		var velocity: Vector2 = combined_velocities[key]
		if unit._forced_movement:
			_apply_knockback_step(unit, velocity * dt)
			unit.on_movement_applied(0.0, dt)
			continue
		if velocity.length_squared() < 0.001:
			unit.on_movement_applied(0.0, dt)
			continue
		var old_pos := unit.global_position
		var applied := _try_apply_velocity(unit, velocity, dt)
		if not applied and not velocity.is_equal_approx(unit._move_intent):
			# 先去掉局部避让分量，尝试原始路径速度。
			applied = _try_apply_velocity(unit, unit._move_intent, dt)
		if not applied:
			# 桥角/塔角的斜向步进可能同时跨入障碍。沿障碍切线尝试单轴分量，
			# 让单位先滑到桥口再向前，而不是在角点原地踏步。
			applied = _try_slide_velocity(unit, velocity, dt)
		if applied:
			# 接触不写回自主速度，也不能让站定/冻结单位凭被推行积攒冲锋。
			var self_distance := minf(autonomous.length() * dt, unit.global_position.distance_to(old_pos))
			unit.on_movement_applied(self_distance, dt)
		else:
			unit.cancel_charge()
			unit.on_movement_applied(0.0, dt)

	for unit in units:
		unit.terrain_traversal.update(unit)
		unit._just_deployed = false

func _clip_knockback_contacts(units: Array[Unit], velocities: Dictionary, dt: float) -> void:
	for i in units.size():
		var a := units[i]
		if not a._forced_movement or a.structure_rush.displacement_immune(): continue
		for j in units.size():
			var b := units[j]
			if a == b or a.skill_dash_active or b.skill_dash_active or a.is_air != b.is_air or b.structure_rush.displacement_immune(): continue
			if b._forced_movement and j < i: continue
			var ka := _unit_order_key(a)
			var kb := _unit_order_key(b)
			var delta := a.global_position - b.global_position
			var step: Vector2 = (velocities[ka] - velocities[kb]) * dt
			var radius := maxf(a.body_radius + b.body_radius - ArenaRules.COLLISION_SLOP, 0.001)
			var closing := delta.dot(step)
			if closing >= 0.0 or step.length_squared() < 0.000001: continue
			var c := delta.length_squared() - radius * radius
			var fraction := 0.0
			if c > 0.0:
				var discriminant := closing * closing - step.length_squared() * c
				if discriminant < 0.0: continue
				fraction = (-closing - sqrt(discriminant)) / step.length_squared()
				if fraction >= 1.0: continue
			fraction = maxf(fraction, 0.0)
			if b._forced_movement:
				velocities[ka] *= fraction
				velocities[kb] *= fraction
			else:
				# 保留被撞者本步的正常接触推挤，只裁剪击退者相对它的运动。
				# 不能把双方一起归零，否则已有重叠会永远卡住。
				velocities[ka] = velocities[kb] + (velocities[ka] - velocities[kb]) * fraction

## 普通击退只沿原步进前进，不能调用桥角切线/单轴滑动，也不能只检查终点。
func _apply_knockback_step(unit: Unit, displacement: Vector2) -> void:
	if displacement.length_squared() < 0.000001: return
	var start := unit.global_position
	var samples := maxi(1, ceili(displacement.length() / 4.0))
	var last := start
	for i in range(1, samples + 1):
		var candidate := start + displacement * (float(i) / samples)
		if _knockback_position_legal(unit, candidate):
			last = candidate
			continue
		# 定位第一段非法步进内的最后合法位置，撞停后仍保留行动锁。
		var blocked := candidate
		for iteration in 12:
			var middle := (last + blocked) * 0.5
			if _knockback_position_legal(unit, middle): last = middle
			else: blocked = middle
		unit.global_position = last
		unit.knockback.stop_at_obstacle()
		return
	unit.global_position = last

func _knockback_position_legal(unit: Unit, pos: Vector2) -> bool:
	if pos.x < unit.body_radius or pos.x > ArenaRules.FIELD_W - unit.body_radius or pos.y < unit.body_radius or pos.y > ArenaRules.FIELD_H - unit.body_radius:
		return false
	return unit.is_walkable_at(pos) or _try_leave_deployment_river_overlap(unit, pos)

func _try_apply_velocity(unit: Unit, velocity: Vector2, dt: float) -> bool:
	if velocity.length_squared() < 0.001:
		return false
	# 部署允许单位从边缘格心出生；先把候选位置收回完整圆柱可活动的场内，
	# 再做塔/河岸碰撞检查，避免边缘格心因为半径超出几像素而永远无法向内移动。
	var raw_next_pos := unit.global_position + velocity * dt
	var next_pos := Vector2(
			clampf(raw_next_pos.x, unit.body_radius, ArenaRules.FIELD_W - unit.body_radius),
			clampf(raw_next_pos.y, unit.body_radius, ArenaRules.FIELD_H - unit.body_radius)
		)
	if not unit.is_walkable_at(next_pos):
		if _try_leave_deployment_river_overlap(unit, next_pos):
			unit.global_position = next_pos
			return true
		return _try_bridge_corner_tangent(unit, velocity, dt)
	unit.global_position = Vector2(
		clampf(next_pos.x, unit.body_radius, ArenaRules.FIELD_W - unit.body_radius),
		clampf(next_pos.y, unit.body_radius, ArenaRules.FIELD_H - unit.body_radius)
	)
	return true

## 大体型单位允许在靠河第一部署排的格心出生，落点可能暂时压过河岸几像素。
## 若这一步正沿远离河道的方向移动，允许它先退出这段部署重叠，再恢复标准地形碰撞。
func _try_leave_deployment_river_overlap(unit: Unit, candidate: Vector2) -> bool:
	if unit.is_air:
		return false
	# 只允许退出已有的地形重叠；桥上合法位置不能借此被斜向推入水中。
	if terrain_walkable.call(unit.global_position, unit.body_radius):
		return false
	var clearance := ArenaRules.RIVER_HALF + unit.body_radius
	var current_gap := absf(unit.global_position.y - ArenaRules.RIVER_Y)
	var candidate_gap := absf(candidate.y - ArenaRules.RIVER_Y)
	if current_gap >= clearance or candidate_gap <= current_gap + 0.001:
		return false
	if terrain_walkable.call(candidate, unit.body_radius):
		return false
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == unit or not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var is_structure: bool = c is Tower or (c is Unit and (c as Unit).is_building)
		if is_structure and structure_gap.call(c, candidate, unit.body_radius) < ArenaRules.STRUCTURE_SEPARATION:
			return false
	return true

## 圆柱碰到桥面与河岸的直角交界时，把剩余速度投影到河岸切线。
## 这样单位会以原速度横向对准桥口，再连续进入桥面，不会先原地停一帧才缓慢挪动。
func _try_bridge_corner_tangent(unit: Unit, velocity: Vector2, dt: float) -> bool:
	if unit.is_air or velocity.length_squared() < 0.001:
		return false
	var shore_clearance := ArenaRules.RIVER_HALF + unit.body_radius
	var distance_to_river := absf(unit.global_position.y - ArenaRules.RIVER_Y)
	var movement_step := velocity.length() * dt
	if distance_to_river > shore_clearance + movement_step + ArenaRules.BRIDGE_EDGE_MARGIN:
		return false
	var moving_toward_river := (
		(unit.global_position.y > ArenaRules.RIVER_Y and velocity.y < 0.0)
		or (unit.global_position.y < ArenaRules.RIVER_Y and velocity.y > 0.0)
	)
	if not moving_toward_river and distance_to_river >= shore_clearance:
		return false
	var bridge_x := ArenaRules.BRIDGE_X_LEFT
	if absf(unit.global_position.x - ArenaRules.BRIDGE_X_RIGHT) < absf(unit.global_position.x - ArenaRules.BRIDGE_X_LEFT):
		bridge_x = ArenaRules.BRIDGE_X_RIGHT
	var safe_half := maxf(ArenaRules.BRIDGE_HALF - unit.body_radius - ArenaRules.BRIDGE_EDGE_MARGIN, 0.0)
	var safe_min_x := bridge_x - safe_half
	var safe_max_x := bridge_x + safe_half
	var candidate := unit.global_position + velocity * dt
	if unit.global_position.x < safe_min_x:
		candidate = Vector2(minf(unit.global_position.x + movement_step, safe_min_x), unit.global_position.y)
	elif unit.global_position.x > safe_max_x:
		candidate = Vector2(maxf(unit.global_position.x - movement_step, safe_max_x), unit.global_position.y)
	else:
		candidate.x = clampf(candidate.x, safe_min_x, safe_max_x)
	if not unit.is_walkable_at(candidate):
		return false
	unit.global_position = Vector2(
		clampf(candidate.x, unit.body_radius, ArenaRules.FIELD_W - unit.body_radius),
		clampf(candidate.y, unit.body_radius, ArenaRules.FIELD_H - unit.body_radius)
	)
	return true

func _try_slide_velocity(unit: Unit, velocity: Vector2, dt: float) -> bool:
	var primary := Vector2(velocity.x, 0.0)
	var secondary := Vector2(0.0, velocity.y)
	if absf(velocity.y) > absf(velocity.x):
		primary = Vector2(0.0, velocity.y)
		secondary = Vector2(velocity.x, 0.0)
	return _try_apply_velocity(unit, primary, dt) or _try_apply_velocity(unit, secondary, dt)

func _active_mobile_units() -> Array[Unit]:
	var units: Array[Unit] = []
	for c in get_tree().get_nodes_in_group("combatants"):
		if c is Unit:
			var unit := c as Unit
			if unit.hp > 0.0 and not unit.is_building:
				units.append(unit)
	units.sort_custom(func(a: Unit, b: Unit): return _unit_order_key(a) < _unit_order_key(b))
	return units

func _adjust_unit_velocity(unit: Unit, units: Array[Unit], dt: float) -> Vector2:
	var desired: Vector2 = unit._move_intent
	if unit._forced_movement:
		unit._avoidance_turn = 0.0
		return desired
	if desired.length_squared() > 0.001:
		var direction := desired.normalized()
		var side := Vector2(-direction.y, direction.x)
		for other in units:
			if other == unit or other.skill_dash_active or unit.skill_dash_active or other.is_air != unit.is_air:
				continue
			# 敌军仅为互不索敌、迎面接触的建筑目标单位解除僵持。
			# 防守者（包括已停步攻击者）不触发推进单位主动避让。
			if other.team != unit.team and not (unit.building_only and other.building_only
					and not other._forced_movement and desired.dot(other._move_intent) < 0.0):
				continue
			# ContactA 对同向行军不请求侧移；冲锋且质量更大的单位也能继续推行。
			if not other._forced_movement and desired.dot(other._move_intent) > 0.0:
				continue
			if unit._charged and unit.mass > other.mass:
				continue
			# 只在身体受阻后侧挤，不提前选择空位或改变寻路目标。
			if unit.global_position.distance_squared_to(other.global_position) > pow(unit.body_radius + other.body_radius, 2.0):
				continue
			var relative := other.global_position - unit.global_position
			if relative.dot(direction) <= 0.0:
				continue
			if is_zero_approx(unit._avoidance_turn):
				var signed_side := relative.dot(side)
				var side_sign := signf(-signed_side)
				if absf(signed_side) < 0.001:
					side_sign = 1.0 if other.team != unit.team else (-1.0 if _unit_order_key(unit) < _unit_order_key(other) else 1.0)
				unit._avoidance_turn = side_sign * ArenaRules.AVOID_TURN
	# 原生转向量每 Tick 向零衰减 10/256；它只控制方向，不保存接触速度。
	unit._avoidance_turn = move_toward(unit._avoidance_turn, 0.0, ArenaRules.AVOID_TURN_DECAY * dt)
	if desired.length_squared() < 0.001:
		return Vector2.ZERO
	var perpendicular := Vector2(-desired.y, desired.x)
	var steered := desired * (1.0 - absf(unit._avoidance_turn)) + perpendicular * unit._avoidance_turn
	return steered.normalized() * desired.length()

## 原生 0xf67834 / 0xf67e7c：接触贡献按 other_mass/self_mass 加权，
## 每个单位求平均、限幅，再叠加自主位移；没有接触速度或跨 Tick 动量状态。
## 采用本项目同 Tick 位置快照，避免边收集边移动产生遍历顺序偏差。
func _collect_unit_contacts(units: Array[Unit]) -> Dictionary:
	var sums := {}
	var counts := {}
	for unit in units:
		var key := _unit_order_key(unit)
		sums[key] = Vector2.ZERO
		counts[key] = 0
	for i in range(units.size()):
		var a := units[i]
		for j in range(i + 1, units.size()):
			var b := units[j]
			if a.skill_dash_active or b.skill_dash_active or a.structure_rush.control_immune() or b.structure_rush.control_immune(): continue
			if a.is_air != b.is_air:
				continue
			var delta := a.global_position - b.global_position
			var distance := delta.length()
			var radius_sum := a.body_radius + b.body_radius
			if distance > radius_sum:
				continue
			var direction: Vector2
			if distance > 0.0001:
				direction = delta / distance
			elif a._just_deployed or b._just_deployed:
				# 保留项目部署挤位的结构朝向约定，不冒充原生对象 id 奇偶规则。
				direction = _landing_overlap_direction(a, b)
			else:
				direction = Vector2.UP if _unit_order_key(a) < _unit_order_key(b) else Vector2.DOWN
			var penetration := minf(radius_sum - distance, ArenaRules.CONTACT_PAIR_LIMIT)
			var key_a := _unit_order_key(a)
			var key_b := _unit_order_key(b)
			sums[key_a] += direction * _contact_magnitude(penetration, a.mass, b.mass)
			sums[key_b] -= direction * _contact_magnitude(penetration, b.mass, a.mass)
			counts[key_a] += 1
			counts[key_b] += 1
	for unit in units:
		var key := _unit_order_key(unit)
		if counts[key] > 0:
			var average: Vector2 = sums[key] / float(counts[key])
			sums[key] = average.limit_length(ArenaRules.CONTACT_STEP_LIMIT)
	return sums

func _contact_magnitude(penetration: float, self_mass: float, other_mass: float) -> float:
	return minf(penetration * other_mass / maxf(self_mass, 0.001),
		ArenaRules.CONTACT_PAIR_LIMIT - ArenaRules.CONTACT_MIN_STEP) + ArenaRules.CONTACT_MIN_STEP

## 供部署/变形几何回归使用的纯接触步；正常 Tick 已在 _apply_unit_movement
## 内把同一批接触叠加到自主移动，不能再调用本入口进行第二次修正。
func _resolve_unit_collisions(dt: float, units: Array[Unit]) -> void:
	var contacts := _collect_unit_contacts(units)
	for unit in units:
		var correction: Vector2 = contacts[_unit_order_key(unit)]
		_apply_contact_displacement(unit, correction, dt)
		unit.terrain_traversal.update(unit)
		unit._just_deployed = false

func _apply_contact_displacement(unit: Unit, correction: Vector2, dt: float) -> void:
	if unit.structure_rush.displacement_immune(): return
	if correction.length_squared() < 0.000001:
		return
	var velocity := correction / maxf(dt, 0.0001)
	if not _try_apply_velocity(unit, velocity, dt):
		_try_slide_velocity(unit, velocity, dt)

func _unit_order_key(unit: Unit) -> int:
	return unit.net_id if unit.net_id >= 0 else unit.get_instance_id()

## 两个单位完全重合落地时没有几何法线。如果附近有塔/建筑，优先把原有单位
## 沿远离该结构的方向挤开，支持“在塔和近战单位之间下兵”的细节交互。
func _landing_overlap_direction(a: Unit, b: Unit) -> Vector2:
	var landing := a if a._just_deployed else b
	if a._just_deployed and b._just_deployed:
		landing = a if _unit_order_key(a) > _unit_order_key(b) else b
	var existing := b if landing == a else a
	var nearest_structure: Node2D = null
	var nearest_distance := INF
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == a or c == b or not is_instance_valid(c) or c.hp <= 0.0:
			continue
		if not (c is Tower or (c is Unit and (c as Unit).is_building)):
			continue
		var dist: float = c.global_position.distance_squared_to(landing.global_position)
		if dist < nearest_distance:
			nearest_distance = dist
			nearest_structure = c
	var existing_direction := Vector2.ZERO
	if nearest_structure != null:
		existing_direction = nearest_structure.global_position.direction_to(landing.global_position)
	if existing_direction.length_squared() < 0.001:
		existing_direction = Vector2.UP if existing.team == 1 else Vector2.DOWN
	# direction 是 b -> a：若 a 是原有单位则直接返回其应移动方向。
	return existing_direction if existing == a else -existing_direction
