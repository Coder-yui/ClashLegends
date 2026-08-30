class_name ActiveSkillEffectSystem
extends RefCounted
## 主动技能 Gameplay Impact 执行器。
## 技能资格、Command Buffer 与 Cast 时间线仍由 Main 编排；具体效果集中在这里扩展。

var pending_frontal_stuns: Array[Dictionary] = []
var frontal_effects: Array[Dictionary] = []

var _controller: Node2D


func _init(controller: Node2D) -> void:
	_controller = controller


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
		_:
			push_error("未实现的主动技能 kind：%s" % String(skill.get("kind", "")))
			return false
	return true


func activate_nova(source: Unit, skill: Dictionary) -> void:
	var radius := float(skill.get("radius", 0.0))
	var amount := float(skill.get("damage", 0.0))
	var knockback := float(skill.get("knockback", 0.0))
	var slow_duration := float(skill.get("slow_duration", 0.0))
	var slow_multiplier := float(skill.get("slow_multiplier", 1.0))
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if combatant.global_position.distance_to(source.global_position) > radius + combatant.body_radius:
			continue
		if amount > 0.0:
			combatant.take_damage(amount, source, source.team, source.global_position)
		if combatant is Unit and is_instance_valid(combatant) and combatant.hp > 0.0:
			if knockback > 0.0:
				(combatant as Unit).apply_knockback(source.global_position, knockback)
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
