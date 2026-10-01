class_name DashStrikeState
extends RefCounted
## 权威距离进度驱动突进；实际结束后才启动固定时长收势，可选旋转命中。
var source_ref: WeakRef
var skill: Dictionary
var serial := -1
var elapsed := 0.0
var forward := Vector2.UP
var hit_ids: Dictionary = {}
var dash_healed := false
var stopped := false
var cancelled := false
var distance := 0.0
var tail_elapsed := 0.0
var spin_hit := false
var finished := false

func _init(source: Unit, definition: Dictionary) -> void:
	source_ref = weakref(source)
	skill = definition
	serial = source.active_skill_cast_serial
	forward = source.active_skill_cast_facing.normalized()
	if forward.is_zero_approx():
		forward = Vector2.UP if source.team == 0 else Vector2.DOWN
	_sync_clock(source)

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
	var remaining := dt
	if source._knockback_timer > 0.0:
		stopped = true
	if not stopped:
		var tick_start: Vector2 = source.global_position
		source.begin_dash_motion()
		# 最多4px一小段，进入地形得到移速后，本Tick剩余时间即可使用新速度。
		while remaining > 0.000001 and not stopped:
			var wall := _boundary_distance(source)
			var left := maxf(0.0, float(skill.length) - distance)
			if wall <= 0.000001 or left <= 0.000001:
				stopped = true
				break
			var speed := _speed(source)
			if speed <= 0.000001:
				remaining = 0.0
				break
			var travel := minf(minf(4.0, left), minf(wall, speed * remaining))
			var start: Vector2 = source.global_position
			var end := start + forward * travel
			source.apply_dash_motion(end)
			distance += travel
			remaining = maxf(0.0, remaining - travel / speed)
			if travel + 0.000001 >= wall or distance + 0.000001 >= float(skill.length):
				stopped = true
		if tick_start.distance_squared_to(source.global_position) > 0.000001:
			_hit(source, tick_start, source.global_position, false)
	elapsed += dt
	if stopped:
		_sync_clock(source)
		tail_elapsed += remaining
		if bool(skill.get("dash_spin", true)) and not spin_hit and tail_elapsed + 0.000001 >= float(skill.spin_delay) - float(skill.dash_duration):
			spin_hit = true
			_hit(source, source.global_position, source.global_position, true)
			source.battle_context.notify_unit_audio_event(source, &"active:spin", source.global_position)
		if tail_elapsed + 0.000001 >= float(skill.cast_duration) - float(skill.dash_duration):
			_finish(source)
			return false
	_sync_clock(source)
	return true

func _speed(source: Unit) -> float:
	return float(skill.length) / float(skill.dash_duration) * source.move_speed * source._effective_movement_multiplier() / float(skill.dash_reference_speed)

func _boundary_distance(source: Unit) -> float:
	var point := source.global_position
	var radius := source.body_radius
	var result := INF
	if forward.x > 0.000001:
		result = minf(result, (ArenaRules.FIELD_W - radius - point.x) / forward.x)
	elif forward.x < -0.000001:
		result = minf(result, (radius - point.x) / forward.x)
	if forward.y > 0.000001:
		result = minf(result, (ArenaRules.FIELD_H - radius - point.y) / forward.y)
	elif forward.y < -0.000001:
		result = minf(result, (radius - point.y) / forward.y)
	return maxf(result, 0.0)

func _sync_clock(source: Unit) -> void:
	var duration := float(skill.cast_duration)
	var dash_duration := float(skill.dash_duration)
	var progress := dash_duration + tail_elapsed if stopped else dash_duration * distance / float(skill.length)
	var rate := 1.0 if stopped else _speed(source) * dash_duration / float(skill.length)
	var remaining := duration - progress if stopped else (float(skill.length) - distance) / maxf(_speed(source), 0.001) + duration - dash_duration
	source.sync_dash_cast(serial, not stopped, duration, progress, rate, remaining)

func _finish(source: Unit) -> void:
	finished = true
	source.finish_dash_cast(serial)

func _hit(source: Unit, start: Vector2, end: Vector2, spin: bool) -> void:
	var receipts: Array[Dictionary] = []
	for target in source.get_tree().get_nodes_in_group("combatants"):
		if target == source or not is_instance_valid(target) or target.hp <= 0.0 or target.team == source.team:
			continue
		if bool(skill.get("air_only", false)):
			if not target is Unit or not target.is_air:
				continue
		elif target is Unit and target.is_air:
			continue
		var id: int = target.combat_source_id
		if not spin and hit_ids.has(id):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(target.global_position, start, end) if not spin else end
		var radius := float(skill.radius) if spin else float(skill.width)*0.5
		if closest.distance_to(target.global_position) > radius + target.body_radius:
			continue
		var extra := float(skill.get("on_hit_tower_damage", 0.0)) if target is Tower else float(target.max_hp)*float(skill.get("on_hit_max_health_ratio", 0.0))
		var result := BattleNumbers.hit(target, BattleNumbers.quantity(float(skill.damage)+extra), source, source.team, source.global_position)
		if not result.accepted:
			continue
		if not spin:
			hit_ids[id] = true
		receipts.append(result)
	var resolver := source.battle_context.damage_batch()
	var reward := func():
		if not is_instance_valid(source) or source.hp <= 0.0 or not receipts.any(func(result): return result.landed):
			return
		if spin or not dash_healed:
			source.heal(float(skill.get("hit_heal", 0.0)))
			if not spin:
				dash_healed = true
	var impact := func():
		if is_instance_valid(source) and receipts.any(func(result): return result.landed):
			source.battle_context.notify_unit_audio_event(source, &"active:hit", source.global_position)
	if resolver.collecting:
		resolver.defer_benefit(reward)
		resolver.defer_effect(impact)
	else:
		reward.call()
		impact.call()
