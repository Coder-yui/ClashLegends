class_name MovementStrikeState
extends RefCounted
## 移动蓄势或技能准备后的单目标突进。途中穿障，落点与中断恢复使用通用位移查询。
var target_ref: WeakRef
var remaining := 0.0
var approach := Vector2.ZERO
var prepared: Dictionary = {}
var executing: Dictionary = {}

func arm(skill: Dictionary) -> void:
	prepared = skill.duplicate(true)

func is_armed() -> bool:
	return not prepared.is_empty() or not executing.is_empty()

func in_transit() -> bool:
	return target_ref != null

func cancel(unit: Unit) -> void:
	if target_ref != null:
		# 新外力已接管时不修正旧路径，否则会改变新外力起点。
		if not unit.knockback.in_transit: unit.recover_displacement_position()
		unit._move_intent = Vector2.ZERO
		unit.play_visual_action(&"", 0.0)
	target_ref = null
	executing.clear()
	remaining = 0.0

func tick(unit: Unit, dt: float) -> bool:
	if unit.control.hard.remaining(&"root") > 0.0:
		if in_transit(): unit.cancel_charge()
		return false
	var config := executing if not executing.is_empty() else prepared
	if config.is_empty(): config = unit._base_form_stats
	if float(config.get("charge_attack_range", 0.0)) <= 0.0: return false
	if target_ref == null:
		if (prepared.is_empty() and not unit._charged) or unit.attack_timeline.recovery > 0.0 or unit.attack_timeline.cooldown > 0.0: return false
		unit._update_target(false)
		var candidate := unit._target
		if not is_instance_valid(candidate) or unit._target_gap(candidate) > float(config.charge_attack_range): return false
		approach = unit.global_position.direction_to(candidate.global_position)
		if approach.is_zero_approx(): approach = Vector2.UP if unit.team == 0 else Vector2.DOWN
		if not _landing(unit, candidate, config).is_finite(): return false
		executing = config.duplicate(true)
		prepared.clear()
		config = executing
		target_ref = weakref(candidate)
		remaining = 1.0
		unit.attack_timeline.cancel(true)
		unit._attacking = false
		unit.play_visual_action(&"charge_strike", float(config.get("charge_visual_duration", 1.0)))
		unit.battle_context.notify_unit_audio_event(unit, &"charge:start", unit.global_position)
	var target = target_ref.get_ref()
	remaining -= dt
	if not is_instance_valid(target) or not unit._target_is_attackable(target) or remaining <= 0.0:
		unit.cancel_charge()
		return true
	var landing := _landing(unit, target, config)
	if not landing.is_finite():
		unit.cancel_charge()
		return true
	if unit.global_position.distance_to(landing) <= 0.01:
		unit.basic_attack_sequence += 1
		unit._attack_swing_count += 1
		unit._perform_attack_strike(target, unit.damage * unit.active_damage_multiplier, {
			"attack_id": unit.basic_attack_sequence, "cycle_id": unit.get_visual_action_serial(),
			"movement_strike": true, "movement_strike_radius": float(config.get("charge_impact_radius", 0.0)), "stun_duration": float(config.get("charge_stun_duration", 0.0)), "ground_only": true,
			"ignore_blind": bool(config.get("ignore_blind", false)),
			"movement_strike_haste": float(config.get("attack_speed_multiplier", 1.0)),
			"movement_strike_haste_duration": float(config.get("duration", 0.0))})
		if not is_instance_valid(unit) or unit.hp <= 0.0 or unit.is_queued_for_deletion(): return true
		# 命中后保留动作尾段；中断路径仍由 cancel 清除动作。
		target_ref = null
		unit.cancel_charge()
		var interval := unit.attack_interval / unit._effective_attack_speed_multiplier()
		unit._attack_visual_pending = true
		unit.attack_timeline.commit_hit(interval)
		unit.attack_timeline.begin_recovery(interval, unit.first_hit_time, unit._effective_attack_speed_multiplier())
		return true
	var direction := unit.global_position.direction_to(landing)
	var travel := minf(float(config.charge_dash_speed) * dt, unit.global_position.distance_to(landing))
	unit._move_direction = direction
	unit._body_facing_direction = unit.global_position.direction_to(target.global_position)
	unit._move_intent = direction * travel / dt
	return true

func _landing(unit: Unit, target: Node2D, config: Dictionary) -> Vector2:
	return UnitLandingQuery.find_strike_position(unit, target, approach, String(config.get("charge_landing_side", "front")))
