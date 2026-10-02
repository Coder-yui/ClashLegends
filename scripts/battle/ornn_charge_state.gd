class_name OrnnChargeState
extends RefCounted
## Fixed-speed charge. Collision is tested against authoritative ground geometry, never the model.

var source_ref: WeakRef
var skill: Dictionary
var serial := -1
var forward := Vector2.UP
var travelled := 0.0
var elapsed := 0.0
var recovery_elapsed := 0.0
var stopped := false
var hit_obstacle := false
var collided := false
var finished := false
var cancelled := false
var trail_hit_ids: Dictionary = {}
var blast_hit_ids: Dictionary = {}
var stop_structure: Node2D
var impact_center := Vector2.ZERO
var next_step := 0

func _init(source: Unit, definition: Dictionary) -> void:
	source_ref = weakref(source)
	skill = definition.duplicate(true)
	serial = source.active_skill_cast_serial
	forward = source.active_skill_cast_facing.normalized()
	if forward.is_zero_approx():
		forward = Vector2.UP if source.team == 0 else Vector2.DOWN

func tick(dt: float) -> bool:
	if finished:
		return false
	var source = source_ref.get_ref()
	if not is_instance_valid(source):
		return false
	if source.hp <= 0.0 or source.is_frozen() or serial <= source.cancelled_skill_cast_serial or serial != source.active_skill_cast_serial:
		cancelled = true
		_finish(source)
		return false
	var prepare := float(skill.charge_prepare_time)
	var dash_duration := float(skill.length) / float(skill.fixed_speed)
	var recovery := float(skill.charge_recovery_time) if hit_obstacle else float(skill.charge_miss_recovery_time)
	var duration := prepare + dash_duration
	if elapsed < prepare - 0.000001:
		elapsed = minf(elapsed + dt, prepare)
		source.sync_dash_cast(serial, false, duration, elapsed, 1.0, duration - elapsed)
		return true
	if not stopped:
		if source.is_stunned() or source._knockback_timer > 0.0:
			# 准备结束仍受控也不能开始位移；取消不伪造撞墙/抵达。
			source.skill_dash_active = true
			source.cancel_controlled_action(&"stun" if source.is_stunned() else &"knockback")
			cancelled = true
			_finish(source)
			return false
		_play_steps(source, travelled / float(skill.length))
		_advance_charge(source, float(skill.length), float(skill.fixed_speed) * dt)
		if stopped:
			hit_obstacle = collided
			recovery = float(skill.charge_recovery_time) if hit_obstacle else float(skill.charge_miss_recovery_time)
			source.play_visual_action(&"ornn_charge_hit" if hit_obstacle else &"ornn_charge_miss", recovery)
		if stopped and collided:
			_resolve_blast(source)
			collided = false
			if source.battle_context != null:
				source.battle_context.present_ornn_charge_impact(source, float(skill.radius), impact_center)
				source.battle_context.notify_unit_audio_event(source, &"charge:impact", impact_center)
		elapsed = prepare + travelled / float(skill.fixed_speed)
		if stopped: elapsed = prepare + dash_duration
	else:
		recovery_elapsed += dt
		elapsed = prepare + dash_duration + recovery_elapsed
	if recovery_elapsed + 0.000001 >= recovery:
		_finish(source)
		return false
	if stopped:
		source.sync_dash_cast(serial, false, recovery, recovery_elapsed, 1.0, maxf(recovery - recovery_elapsed, 0.000001))
	else:
		source.sync_dash_cast(serial, true, duration, elapsed, 1.0, maxf(duration - elapsed, 0.000001))
	return true

func _advance_charge(source: Unit, max_distance: float, requested_distance: float) -> void:
	var remaining := minf(requested_distance, maxf(max_distance - travelled, 0.0))
	if remaining > 0.000001:
		source.begin_dash_motion()
	while remaining > 0.000001 and not stopped:
		var step := minf(4.0, remaining)
		var start := source.global_position
		var end := start + forward * step
		if source.battle_context.is_ground_segment_walkable(start, end, source.body_radius, source):
			source.apply_dash_motion(end)
			travelled += step
			remaining -= step
			_hit_trail(source, start, end, null)
			continue
		var low := 0.0
		var high := step
		for iteration in 10:
			var mid := (low + high) * 0.5
			if source.battle_context.is_ground_segment_walkable(start, start + forward * mid, source.body_radius, source):
				low = mid
			else:
				high = mid
		var contact_end := start + forward * low
		if low > 0.001:
			source.apply_dash_motion(contact_end)
			travelled += low
		stop_structure = _structure_contact(source, start, start + forward * step)
		if low > 0.001:
			_hit_trail(source, start, contact_end, stop_structure)
		impact_center = _contact_point(source)
		stopped = true
		collided = true
		source.skill_dash_active = false
		remaining = 0.0
	if not stopped and travelled + 0.000001 >= max_distance:
		stopped = true
		source.skill_dash_active = false

func _structure_contact(source: Unit, start: Vector2, end: Vector2) -> Node2D:
	var nearest := INF
	var result: Node2D
	var segment_length := start.distance_to(end)
	for structure in source.get_tree().get_nodes_in_group("combat_structures"):
		if structure == source or not is_instance_valid(structure) or structure.hp <= 0.0:
			continue
		var samples := maxi(1, ceili(segment_length))
		for index in range(samples + 1):
			var ratio := float(index) / float(samples)
			var point := start.lerp(end, ratio)
			var gap: float = structure.surface_gap_to_circle(point, source.body_radius) if structure.has_method("surface_gap_to_circle") else point.distance_to(structure.global_position) - structure.body_radius - source.body_radius
			if gap > ArenaRules.STRUCTURE_SEPARATION + 0.1:
				continue
			var distance := segment_length * ratio
			if distance < nearest:
				nearest = distance
				result = structure
			break
	return result

func _hit_trail(source: Unit, start: Vector2, end: Vector2, excluded: Node2D) -> void:
	if float(skill.get("trail_damage", 0.0)) <= 0.0:
		return
	for target in source.get_tree().get_nodes_in_group("combatants"):
		if target == source or target == excluded or not is_instance_valid(target) or target.hp <= 0.0 or target.team == source.team:
			continue
		var identity := int(target.combat_source_id)
		if trail_hit_ids.has(identity):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(target.global_position, start, end)
		if closest.distance_to(target.global_position) > float(skill.width) * 0.5 + target.body_radius:
			continue
		trail_hit_ids[identity] = true
		if _active_damage(source, target, float(skill.trail_damage), source.global_position):
			source.battle_context.notify_unit_audio_event(source, &"charge:trail_hit", target.global_position)

func _resolve_blast(source: Unit) -> void:
	# 碰撞爆发同时覆盖空地目标，独立于奥恩仅攻击建筑的普攻索敌能力。
	var center: Vector2 = impact_center
	for target in source.get_tree().get_nodes_in_group("combatants"):
		if target == source or not is_instance_valid(target) or target.hp <= 0.0 or target.team == source.team:
			continue
		if not CombatInteraction.allows(target, source, source.team, center):
			continue
		if center.distance_to(target.global_position) > float(skill.radius) + target.body_radius:
			continue
		var identity := int(target.combat_source_id)
		if blast_hit_ids.has(identity):
			continue
		blast_hit_ids[identity] = true
		if _active_damage(source, target, float(skill.damage), center) and target is Unit and not target.is_building:
			source.battle_context.notify_unit_audio_event(source, &"charge:knockup", target.global_position)
		if target.has_method("stun") and target.hp > 0.0:
			if target is Unit:
				target.stun(float(skill.stun_duration), source.status_source("ornn_charge"), CombatInteraction.effect_context(source))
			else:
				target.stun(float(skill.stun_duration), source.status_source("ornn_charge"), CombatInteraction.effect_context(source))

func _active_damage(source: Unit, target: Node2D, amount: float, origin: Vector2) -> bool:
	if source.battle_context != null:
		return source.battle_context.apply_damage_pulse(source, target, amount, 0.0, origin, false)
	else:
		target.take_damage(BattleNumbers.quantity(amount), source, source.team, origin)
		return true

func _finish(source: Unit) -> void:
	finished = true
	source.finish_dash_cast(serial)

func _contact_point(source: Unit) -> Vector2:
	var center := source.global_position
	if is_instance_valid(stop_structure):
		return stop_structure.global_position + stop_structure.global_position.direction_to(center) * stop_structure.body_radius
	# Closest point on the actual field or river boundary (not the expanded mover boundary).
	var candidates: Array[Vector2] = [Vector2(0, center.y), Vector2(ArenaRules.FIELD_W, center.y), Vector2(center.x, 0), Vector2(center.x, ArenaRules.FIELD_H)]
	var edges := [Vector2(0, ArenaRules.BRIDGE_X_LEFT - ArenaRules.BRIDGE_HALF), Vector2(ArenaRules.BRIDGE_X_LEFT + ArenaRules.BRIDGE_HALF, ArenaRules.BRIDGE_X_RIGHT - ArenaRules.BRIDGE_HALF), Vector2(ArenaRules.BRIDGE_X_RIGHT + ArenaRules.BRIDGE_HALF, ArenaRules.FIELD_W)]
	for edge in edges:
		candidates.append(Vector2(clampf(center.x, edge.x, edge.y), clampf(center.y, ArenaRules.RIVER_Y - ArenaRules.RIVER_HALF, ArenaRules.RIVER_Y + ArenaRules.RIVER_HALF)))
	var closest := center + forward * source.body_radius
	var distance := INF
	for point in candidates:
		if (point - center).dot(forward) < -0.001: continue
		var gap := center.distance_squared_to(point)
		if gap < distance:
			distance = gap
			closest = point
	return closest

func _play_steps(source: Unit, progress: float) -> void:
	# Native Spell3_Dash footstep frames 0, 4, 8, 13 at 30fps; final endpoint is not an extra step after stopping.
	var nodes := [0.0, 4.0 / 13.0, 8.0 / 13.0]
	while next_step < nodes.size() and progress + 0.000001 >= nodes[next_step]:
		source.battle_context.notify_unit_audio_event(source, &"charge:step", source.global_position)
		next_step += 1
