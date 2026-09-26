class_name DashStrikeState
extends RefCounted
## 依附施法的两段伤害；20Hz效果阶段推进，突进后恢复通用碰撞，旋转按命中时当前位置结算。
var source_ref: WeakRef
var skill: Dictionary
var serial := -1
var elapsed := 0.0
var forward := Vector2.UP
var hit_ids: Dictionary = {}
var dash_healed := false
var stopped := false
var cancelled := false

func _init(source: Unit, definition: Dictionary) -> void:
	source_ref = weakref(source)
	skill = definition
	serial = source.active_skill_cast_serial
	forward = source.active_skill_cast_facing.normalized()
	if forward.is_zero_approx(): forward = Vector2.UP if source.team == 0 else Vector2.DOWN
	source.skill_dash_active = true

func tick(dt: float) -> bool:
	var source = source_ref.get_ref()
	if not is_instance_valid(source): return false
	if source.hp <= 0.0:
		source.skill_dash_active = false
		return false
	cancelled = cancelled or source.is_frozen() or serial <= source.cancelled_skill_cast_serial
	if cancelled or source._knockback_timer > 0.0: stopped = true
	var dash_duration := float(skill.dash_duration)
	if not stopped and elapsed < dash_duration:
		var step := minf(dt, dash_duration - elapsed)
		source._prev_pos = source.position
		source.skill_dash_moved_tick = source.battle_context.simulation_tick()
		var start: Vector2 = source.global_position
		var end: Vector2 = start + forward * float(skill.length) * step / dash_duration
		end = Vector2(clampf(end.x, source.body_radius, ArenaRules.FIELD_W-source.body_radius), clampf(end.y, source.body_radius, ArenaRules.FIELD_H-source.body_radius))
		# 逐段记录地形边沿，避免单Tick跨过窄地形漏回一次血。
		var samples := maxi(1, ceili(start.distance_to(end)/4.0))
		for index in range(1, samples+1):
			source.global_position = start.lerp(end, float(index)/samples)
			source.terrain_traversal.update(source)
		_hit(source, start, end, false)
	elapsed += dt
	if stopped or elapsed + 0.000001 >= dash_duration:
		stopped = true
		# Stop/Circle 与普通单位一样参与接触分离；不瞬移找空位，
		# 也不因为人堆拥堵延迟旋转伤害或保留穿单位权限。
		source.skill_dash_active = false
		if cancelled: return false
	if elapsed + 0.000001 >= float(skill.spin_delay):
		_hit(source, source.global_position, source.global_position, true)
		source.battle_context.notify_unit_audio_event(source, &"active:spin", source.global_position)
		return false
	return true

func _hit(source: Unit, start: Vector2, end: Vector2, spin: bool) -> void:
	var receipts: Array[Dictionary] = []
	for target in source.get_tree().get_nodes_in_group("combatants"):
		if target == source or not is_instance_valid(target) or target.hp <= 0.0 or target.team == source.team: continue
		if target is Unit and target.is_air: continue
		var id: int = target.combat_source_id
		if not spin and hit_ids.has(id): continue
		var closest := Geometry2D.get_closest_point_to_segment(target.global_position, start, end) if not spin else end
		var radius := float(skill.radius) if spin else float(skill.width)*0.5
		if closest.distance_to(target.global_position) > radius + target.body_radius: continue
		var extra := float(skill.get("on_hit_tower_damage", 0.0)) if target is Tower else float(target.max_hp)*float(skill.get("on_hit_max_health_ratio", 0.0))
		var result := BattleNumbers.hit(target, BattleNumbers.quantity(float(skill.damage)+extra), source, source.team, source.global_position)
		if not result.accepted: continue
		if not spin: hit_ids[id] = true
		receipts.append(result)
	var resolver := source.battle_context.damage_batch()
	var reward := func():
		if not is_instance_valid(source) or source.hp <= 0.0 or not receipts.any(func(result): return result.landed): return
		if spin or not dash_healed:
			source.heal(float(skill.get("hit_heal", 0.0)))
			if not spin: dash_healed = true
	var impact := func():
		if is_instance_valid(source) and receipts.any(func(result): return result.landed): source.battle_context.notify_unit_audio_event(source, &"active:hit", source.global_position)
	if resolver.collecting:
		resolver.defer_benefit(reward)
		resolver.defer_effect(impact)
	else:
		reward.call()
		impact.call()
