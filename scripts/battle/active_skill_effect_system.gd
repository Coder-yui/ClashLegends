class_name ActiveSkillEffectSystem
extends RefCounted
## 主动技能 Gameplay Impact 执行器。
## 技能资格、Command Buffer 与 Cast 时间线仍由 Main 编排；具体效果集中在这里扩展。

var pending_frontal_stuns: Array[Dictionary] = []
var frontal_effects: Array[Dictionary] = []
var expanding_shockwaves: Array[Dictionary] = []

var _controller: Node2D


func _init(controller: Node2D) -> void:
	_controller = controller

## Cast Start 固化资源倍率和强/弱动作选择。返回值只进入本次权威时间线，
## 不回写 CardDB，也不会让动画决定伤害。
func prepare_cast(source: Unit, skill: Dictionary) -> Dictionary:
	var prepared := skill.duplicate(true)
	if bool(prepared.get("uses_skill_resource", false)) and source.skill_resource_enabled and source.skill_resource_max > 0.0:
		var resource_stacks := source.get_skill_resource_stacks()
		var resource_ratio := source.consume_skill_resource_ratio()
		prepared["resource_ratio"] = resource_ratio
		prepared["resource_stacks"] = resource_stacks
		var damage_by_stacks = prepared.get("resource_damage_by_stacks", [])
		if damage_by_stacks is Array and not (damage_by_stacks as Array).is_empty():
			var damage_index := clampi(resource_stacks, 0, (damage_by_stacks as Array).size() - 1)
			prepared["damage"] = float((damage_by_stacks as Array)[damage_index])
		var max_scale := maxf(float(prepared.get("resource_damage_scale_max", 1.0)), 1.0)
		if max_scale > 1.0:
			prepared["damage"] = float(prepared.get("damage", 0.0)) * lerpf(1.0, max_scale, resource_ratio)
		var strong_action := String(prepared.get("full_resource_visual_action", ""))
		if resource_ratio >= 0.999 and not strong_action.is_empty():
			prepared["visual_action"] = strong_action
			prepared["damage"] = float(prepared.get("damage", 0.0)) * maxf(float(prepared.get("resource_full_damage_multiplier", 1.0)), 1.0)
			prepared["stun_duration"] = float(prepared.get("stun_duration", 0.0)) * maxf(float(prepared.get("resource_full_stun_multiplier", 1.0)), 1.0)
			prepared["cast_duration"] = float(prepared.get("full_resource_cast_duration", prepared.get("cast_duration", 0.0)))
			prepared["impact_delay"] = float(prepared.get("full_resource_impact_delay", prepared.get("impact_delay", 0.0)))
			prepared["full_resource"] = true
	return prepared


func apply(source: Unit, skill: Dictionary) -> bool:
	match StringName(skill.get("kind", "")):
		&"buff":
			source.apply_active_buff(
				float(skill.get("duration", 0.0)),
				float(skill.get("speed_multiplier", 1.0)),
				float(skill.get("damage_multiplier", 1.0)),
				float(skill.get("attack_speed_multiplier", 1.0))
			)
			source.add_shield(float(skill.get("shield", 0.0)), float(skill.get("shield_duration", skill.get("duration", 0.0))))
		&"nova":
			activate_nova(source, skill)
		&"summon":
			activate_summon(source, skill)
		&"dual_form":
			activate_dual_form(source, skill)
		&"frontal":
			apply_frontal(source, skill, source.active_skill_cast_facing)
		&"forward_area":
			apply_forward_area(source, skill, source.active_skill_cast_facing)
		&"empowered_attack":
			source.prepare_empowered_attack(
				float(skill.get("empowered_damage_multiplier", 1.0)),
				float(skill.get("empowered_speed_multiplier", 1.0)),
				int(skill.get("blind_charges", 0))
			)
		_:
			push_error("未实现的主动技能 kind：%s" % String(skill.get("kind", "")))
			return false
	return true


func activate_nova(source: Unit, skill: Dictionary) -> void:
	var radius := float(skill.get("radius", 0.0))
	var amount := float(skill.get("damage", 0.0))
	var knockback := float(skill.get("knockback", 0.0))
	var knockback_duration := float(skill.get("knockback_duration", 0.2))
	var knockback_mass_factor_max := float(skill.get("knockback_mass_factor_max", 1.4))
	var ground_only := bool(skill.get("ground_only", false))
	var slow_duration := float(skill.get("slow_duration", 0.0))
	var slow_multiplier := float(skill.get("slow_multiplier", 1.0))
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		if combatant.global_position.distance_to(source.global_position) > radius + combatant.body_radius:
			continue
		if amount > 0.0:
			_damage_combatant(source, combatant, amount, source.global_position)
		if combatant is Unit and is_instance_valid(combatant) and combatant.hp > 0.0:
			if knockback > 0.0:
				(combatant as Unit).apply_knockback(source.global_position, knockback, knockback_duration, knockback_mass_factor_max)
			if slow_duration > 0.0:
				(combatant as Unit).apply_slow(slow_duration, slow_multiplier)
	source.add_shield(float(skill.get("shield", 0.0)), float(skill.get("shield_duration", 0.0)))


func activate_summon(source: Unit, skill: Dictionary) -> void:
	var spawn_id := String(skill.get("spawn_id", ""))
	var count := maxi(int(skill.get("spawn_count", 1)), 1)
	var summon_stats := CardDB.get_unit_stats(spawn_id)
	if summon_stats.is_empty():
		push_error("主动技能引用了不存在的召唤单位：%s" % spawn_id)
		return
	var summon_radius := float(summon_stats.get("radius", 14.0))
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		var offset := Vector2.RIGHT.rotated(angle) * (source.body_radius + summon_radius + Unit.SUMMON_SEPARATION)
		_controller.spawn_summoned(source.team, spawn_id, source.global_position + offset)


## 扇形/梯形主动统一按施法开始时锁定的朝向结算。目标碰撞圆会扩张边界，
## 但动画、箭矢线条和预警多边形都不参与权威命中。
func apply_frontal(source: Unit, skill: Dictionary, forward: Vector2 = Vector2.ZERO) -> void:
	forward = frontal_forward(source) if forward.length_squared() < 0.001 else forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var length := maxf(float(skill.get("length", 0.0)), 0.0)
	var shape := StringName(skill.get("shape", "trapezoid"))
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	var ground_only := bool(skill.get("ground_only", false))
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		var local_offset: Vector2 = combatant.global_position - source.global_position
		var forward_distance := local_offset.dot(forward) - source.body_radius
		var lateral_distance := absf(local_offset.dot(side))
		var hit := false
		var damage_multiplier := 1.0
		if shape == &"fan":
			var center_distance := maxf(local_offset.dot(forward), 0.0)
			var half_angle := deg_to_rad(clampf(float(skill.get("arc_degrees", 0.0)), 0.0, 179.0) * 0.5)
			var fan_half_width := tan(half_angle) * center_distance
			hit = forward_distance >= -combatant.body_radius and forward_distance <= length + combatant.body_radius and lateral_distance <= fan_half_width + combatant.body_radius
			var center_ratio := clampf(float(skill.get("center_ratio", 0.0)), 0.0, 1.0)
			if hit and center_ratio > 0.0 and lateral_distance <= fan_half_width * center_ratio + combatant.body_radius:
				damage_multiplier = maxf(float(skill.get("center_damage_multiplier", 1.0)), 1.0)
		else:
			var near_half := maxf(float(skill.get("near_width", skill.get("width", 0.0))) * 0.5, 0.0)
			var far_half := maxf(float(skill.get("far_width", skill.get("width", 0.0))) * 0.5, 0.0)
			var width_ratio := clampf(forward_distance / maxf(length, 0.001), 0.0, 1.0)
			var half_width := lerpf(near_half, far_half, width_ratio)
			hit = forward_distance >= -combatant.body_radius and forward_distance <= length + combatant.body_radius and lateral_distance <= half_width + combatant.body_radius
			var center_ratio := clampf(float(skill.get("center_ratio", 0.0)), 0.0, 1.0)
			if hit and center_ratio > 0.0 and lateral_distance <= half_width * center_ratio + combatant.body_radius:
				damage_multiplier = maxf(float(skill.get("center_damage_multiplier", 1.0)), 1.0)
		if not hit:
			continue
		if amount > 0.0:
			_damage_combatant(source, combatant, amount * damage_multiplier)
		if combatant is Unit and is_instance_valid(combatant) and combatant.hp > 0.0 and float(skill.get("slow_duration", 0.0)) > 0.0:
			(combatant as Unit).apply_slow(float(skill.slow_duration), float(skill.get("slow_multiplier", 1.0)))


## 向施法开始时锁定方向的前方圆形区域落下一颗星；冲击波由固定 tick 独立扩散。
func apply_forward_area(source: Unit, skill: Dictionary, forward: Vector2 = Vector2.ZERO) -> void:
	forward = frontal_forward(source) if forward.length_squared() < 0.001 else forward.normalized()
	var center := source.global_position + forward * maxf(float(skill.get("forward_distance", 0.0)), 0.0)
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	var stun_duration := maxf(float(skill.get("stun_duration", 0.0)), 0.0)
	var already_hit := {}
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if combatant.global_position.distance_to(center) > radius + combatant.body_radius:
			continue
		already_hit[int(combatant.get_instance_id())] = true
		if amount > 0.0:
			_damage_combatant(source, combatant, amount, center)
		if is_instance_valid(combatant) and combatant.hp > 0.0 and stun_duration > 0.0 and combatant.has_method("stun"):
			combatant.stun(stun_duration)
	var shockwave_duration := maxf(float(skill.get("shockwave_duration", 0.0)), 0.0)
	if bool(skill.get("shockwave_full_only", false)) and not bool(skill.get("full_resource", false)):
		shockwave_duration = 0.0
	if shockwave_duration <= 0.0:
		return
	var end_radius := maxf(float(skill.get("shockwave_end_radius", radius)), radius)
	expanding_shockwaves.append({
		"source_ref": weakref(source), "team": source.team, "center": center,
		"start_radius": radius, "end_radius": end_radius,
		"previous_radius": radius, "timer": shockwave_duration, "duration": shockwave_duration,
		"damage": maxf(float(skill.get("shockwave_damage", 0.0)), 0.0),
		"slow_duration": maxf(float(skill.get("shockwave_slow_duration", 0.0)), 0.0),
		"slow_multiplier": clampf(float(skill.get("shockwave_slow_multiplier", 1.0)), 0.1, 1.0),
		"hit_ids": already_hit,
	})
	add_fixed_area_effect(center, radius, end_radius, shockwave_duration, source.team, &"shockwave")
	if _controller.mode == "host":
		_controller._rpc_frontal_skill_fx.rpc(
			-1, center, Vector2.UP, 0.0, end_radius, radius, shockwave_duration, source.team, "shockwave"
		)


func begin_forward_area_visual(source: Unit, skill: Dictionary, cast_forward: Vector2) -> void:
	var duration := maxf(float(skill.get("impact_delay", 0.0)), 0.0)
	if duration <= 0.0:
		return
	var center := source.global_position + cast_forward.normalized() * maxf(float(skill.get("forward_distance", 0.0)), 0.0)
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	add_fixed_area_effect(center, radius, radius, duration, source.team, &"target_circle")
	if _controller.mode == "host":
		_controller._rpc_frontal_skill_fx.rpc(
			-1, center, Vector2.UP, 0.0, radius, 0.0, duration, source.team, "target_circle"
		)


func add_fixed_area_effect(center: Vector2, start_radius: float, end_radius: float, duration: float, p_team: int, shape: StringName) -> void:
	frontal_effects.append({
		"source_ref": null, "net_id": -1, "fixed_position": true,
		"pos": center, "forward": Vector2.UP, "source_radius": 0.0,
		"length": end_radius, "width": start_radius, "shape": String(shape),
		"timer": duration, "duration": duration, "team": p_team,
	})


func _damage_combatant(source: Unit, combatant: Node2D, amount: float, origin: Vector2 = Vector2(INF, INF)) -> bool:
	if combatant == null or not is_instance_valid(combatant) or combatant.hp <= 0.0 or amount <= 0.0:
		return false
	var was_alive: bool = combatant.hp > 0.0
	var source_position := source.global_position if origin.x == INF else origin
	var landed: bool = combatant.take_damage(amount, source, source.team, source_position)
	if landed and was_alive and combatant.hp <= 0.0 and is_instance_valid(source):
		source.on_enemy_killed(combatant)
	return landed


func begin_frontal_visual(source: Unit, skill: Dictionary, cast_forward: Vector2) -> void:
	var duration := maxf(float(skill.get("impact_delay", 0.0)), 0.0)
	if duration <= 0.0:
		return
	add_frontal_effect(source, skill, duration, cast_forward)
	if _controller.mode == "host":
		_controller._rpc_frontal_skill_fx.rpc(
			source.net_id, source.global_position, cast_forward, source.body_radius,
			float(skill.get("length", 0.0)), float(skill.get("width", skill.get("far_width", 0.0))),
			duration, source.team, String(skill.get("shape", "rectangle")),
			float(skill.get("near_width", skill.get("width", 0.0))), float(skill.get("far_width", skill.get("width", 0.0))),
			float(skill.get("arc_degrees", 0.0)), int(skill.get("projectile_count", 0)),
			float(skill.get("center_ratio", 0.0))
		)


func activate_dual_form(source: Unit, skill: Dictionary) -> void:
	var cast_forward := frontal_forward(source)
	if source.form_index == 0:
		source.transform_to_mega(true)
		activate_frontal_stun(
			source, skill, false,
			float(skill.get("transform_impact_delay", 0.9)),
			float(skill.get("transform_cast_duration", 1.3)),
			cast_forward
		)
		return
	activate_frontal_stun(
		source, skill, true,
		float(skill.get("impact_delay", 0.8)),
		float(skill.get("cast_duration", 1.2)),
		cast_forward
	)


func activate_frontal_stun(source: Unit, skill: Dictionary, play_action: bool = true, impact_delay: float = -1.0, cast_duration: float = -1.0, cast_forward: Vector2 = Vector2.ZERO) -> void:
	impact_delay = maxf(float(skill.get("impact_delay", 0.8)), 0.0) if impact_delay < 0.0 else maxf(impact_delay, 0.0)
	cast_duration = maxf(float(skill.get("cast_duration", 1.2)), 0.0) if cast_duration < 0.0 else maxf(cast_duration, 0.0)
	cast_forward = frontal_forward(source) if cast_forward.length_squared() < 0.001 else cast_forward.normalized()
	var cast_locks: Array = skill.get("cast_locks", Unit.DEFAULT_CAST_LOCKS)
	source.begin_active_skill_cast(cast_duration, cast_forward, cast_locks)
	if play_action:
		source.play_visual_action(StringName(skill.get("visual_action", "active")), cast_duration)
	pending_frontal_stuns.append({
		"source_ref": weakref(source),
		"skill": skill.duplicate(true),
		"forward": cast_forward,
		"time_left": impact_delay,
	})
	add_frontal_effect(source, skill, impact_delay, cast_forward)
	if _controller.mode == "host":
		_controller._rpc_frontal_skill_fx.rpc(
			source.net_id,
			source.global_position,
			cast_forward,
			source.body_radius,
			float(skill.get("length", 0.0)),
			float(skill.get("width", 0.0)),
			impact_delay,
			source.team,
		)


func tick_pending(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	for pending in pending_frontal_stuns:
		var source = (pending.source_ref as WeakRef).get_ref()
		if not source is Unit or not is_instance_valid(source) or source.hp <= 0.0:
			continue
		if source.frozen_timer > 0.0 or source.stun_timer > 0.0:
			waiting.append(pending)
			continue
		pending.time_left = maxf(0.0, float(pending.time_left) - dt)
		if float(pending.time_left) > 0.001:
			waiting.append(pending)
			continue
		apply_frontal_stun(source as Unit, pending.skill, pending.forward)
	pending_frontal_stuns.assign(waiting)
	_tick_expanding_shockwaves(dt)


func _tick_expanding_shockwaves(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for shockwave in expanding_shockwaves:
		shockwave.timer = maxf(float(shockwave.timer) - dt, 0.0)
		var progress := 1.0 - float(shockwave.timer) / maxf(float(shockwave.duration), 0.001)
		var current_radius := lerpf(float(shockwave.start_radius), float(shockwave.end_radius), progress)
		var source = (shockwave.source_ref as WeakRef).get_ref()
		for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(combatant) or combatant.team == int(shockwave.team) or combatant.hp <= 0.0:
				continue
			var instance_id := int(combatant.get_instance_id())
			if (shockwave.hit_ids as Dictionary).has(instance_id):
				continue
			if combatant.global_position.distance_to(shockwave.center) > current_radius + combatant.body_radius:
				continue
			shockwave.hit_ids[instance_id] = true
			if source is Unit and is_instance_valid(source):
				_damage_combatant(source as Unit, combatant, float(shockwave.damage), shockwave.center)
			else:
				combatant.take_damage(float(shockwave.damage), null, int(shockwave.team), shockwave.center)
			if combatant is Unit and is_instance_valid(combatant) and combatant.hp > 0.0 and float(shockwave.slow_duration) > 0.0:
				(combatant as Unit).apply_slow(float(shockwave.slow_duration), float(shockwave.slow_multiplier))
		shockwave.previous_radius = current_radius
		if float(shockwave.timer) > 0.001:
			alive.append(shockwave)
	expanding_shockwaves.assign(alive)


func apply_frontal_stun(source: Unit, skill: Dictionary, forward: Vector2) -> void:
	forward = forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var length := maxf(float(skill.get("length", 0.0)), 0.0)
	var half_width := maxf(float(skill.get("width", 0.0)) * 0.5, 0.0)
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	var stun_duration := maxf(float(skill.get("stun_duration", 0.0)), 0.0)
	var ground_only := bool(skill.get("ground_only", true))
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		var local_offset: Vector2 = combatant.global_position - source.global_position
		var forward_distance := local_offset.dot(forward) - source.body_radius
		var lateral_distance := absf(local_offset.dot(side))
		if forward_distance < -combatant.body_radius or forward_distance > length + combatant.body_radius:
			continue
		if lateral_distance > half_width + combatant.body_radius:
			continue
		if amount > 0.0:
			combatant.take_damage(amount, source, source.team, source.global_position)
		if is_instance_valid(combatant) and combatant.hp > 0.0 and stun_duration > 0.0 and combatant.has_method("stun"):
			combatant.stun(stun_duration)


func frontal_forward(source: Unit) -> Vector2:
	var forward := source.get_visual_facing_direction()
	if forward.length_squared() < 0.001:
		forward = Vector2.UP if source.team == 0 else Vector2.DOWN
	return forward.normalized()


func add_frontal_effect(source: Unit, skill: Dictionary, duration: float, cast_forward: Vector2) -> void:
	frontal_effects.append({
		"source_ref": weakref(source),
		"net_id": source.net_id,
		"pos": source.global_position,
		"forward": cast_forward,
		"source_radius": source.body_radius,
		"length": maxf(float(skill.get("length", 0.0)), 0.0),
		"width": maxf(float(skill.get("width", 0.0)), 0.0),
		"shape": String(skill.get("shape", "rectangle")),
		"near_width": maxf(float(skill.get("near_width", skill.get("width", 0.0))), 0.0),
		"far_width": maxf(float(skill.get("far_width", skill.get("width", 0.0))), 0.0),
		"arc_degrees": maxf(float(skill.get("arc_degrees", 0.0)), 0.0),
		"projectile_count": maxi(int(skill.get("projectile_count", 0)), 0),
		"center_ratio": clampf(float(skill.get("center_ratio", 0.0)), 0.0, 1.0),
		"timer": duration,
		"duration": duration,
		"team": source.team,
	})


func tick_visuals(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for effect in frontal_effects:
		var source = effect_source(effect)
		if source is Unit and (source.frozen_timer > 0.0 or source.stun_timer > 0.0):
			alive.append(effect)
			continue
		effect.timer = maxf(0.0, float(effect.timer) - delta)
		if float(effect.timer) > 0.001:
			alive.append(effect)
	frontal_effects.assign(alive)


func effect_source(effect: Dictionary):
	var source_ref = effect.get("source_ref")
	if source_ref is WeakRef:
		var source = (source_ref as WeakRef).get_ref()
		if source is Unit and is_instance_valid(source):
			return source
	var net_id := int(effect.get("net_id", -1))
	if net_id >= 0:
		var client_source = _controller._client_units.get(net_id)
		if client_source is Unit and is_instance_valid(client_source):
			return client_source
	return null


func clear() -> void:
	pending_frontal_stuns.clear()
	frontal_effects.clear()
	expanding_shockwaves.clear()
