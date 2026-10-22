class_name MovementStrikeState
extends RefCounted
## 移动蓄势或技能准备后的单目标突进。途中穿障，落点与中断恢复使用通用位移查询。
var target_ref: WeakRef
var remaining := 0.0
var approach := Vector2.ZERO
var prepared: Dictionary = {}
var executing: Dictionary = {}
# 接触踢击是独立的固定时序攻击；其他技能保留原有抵达结算路径。
var contact_active := false
var following := false
var contact_elapsed := 0.0
var contact_origin := Vector2.ZERO
var contact_endpoint := Vector2.ZERO
var follow_origin := Vector2.ZERO
var follow_endpoint := Vector2.ZERO
var follow_elapsed := 0.0
var travel_limit := 0.0

func stun_protected() -> bool:
	return contact_active

func arm(skill: Dictionary) -> void:
	prepared = skill.duplicate(true)

func is_armed() -> bool:
	return not prepared.is_empty() or not executing.is_empty()

func in_transit() -> bool:
	return target_ref != null or contact_active

func cancel(unit: Unit) -> void:
	if in_transit():
		# 新外力已接管时不修正旧路径，否则会改变新外力起点。
		if not unit.knockback.in_transit: unit.recover_displacement_position()
		unit._move_intent = Vector2.ZERO
		unit.play_visual_action(&"", 0.0)
	target_ref = null
	contact_active = false
	following = false
	executing.clear()
	remaining = 0.0

func tick(unit: Unit, dt: float) -> bool:
	if unit.control.hard.remaining(&"root") > 0.0:
		if in_transit(): unit.cancel_charge()
		return false
	var config := executing if not executing.is_empty() else prepared
	if config.is_empty(): config = unit._base_form_stats
	if float(config.get("charge_contact_duration", 0.0)) > 0.0: return _tick_contact(unit, dt, config)
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

## 起跳只负责锁定目标与本次配置；追踪、命中和落地各自推进。
func _begin_contact(unit: Unit, config: Dictionary) -> bool:
	if not unit._charged or unit.attack_timeline.recovery > 0.0 or unit.attack_timeline.cooldown > 0.0: return false
	unit._update_target(false)
	var candidate := unit._target
	if not is_instance_valid(candidate) or unit._target_gap(candidate) > float(config.charge_attack_range): return false
	approach = unit.global_position.direction_to(candidate.global_position)
	if approach.is_zero_approx(): approach = Vector2.UP if unit.team == 0 else Vector2.DOWN
	contact_endpoint = _landing(unit, candidate, config)
	if not contact_endpoint.is_finite(): return false
	contact_origin = unit.global_position
	travel_limit = maxf(contact_origin.distance_to(contact_endpoint), float(config.charge_attack_range)) + ArenaRules.TILE_SIZE
	executing = config.duplicate(true)
	config = executing
	target_ref = weakref(candidate)
	contact_active = true
	following = false
	contact_elapsed = 0.0
	unit._charged = false
	unit._charge_distance_travelled = 0.0
	unit._attacking = false
	unit.attack_timeline.cancel(true)
	unit.play_visual_action(&"charge_strike", float(config.charge_contact_duration))
	unit.battle_context.notify_unit_audio_event(unit, &"charge:start", unit.global_position)
	return true

## 固定起跳时序：近距离也完整播放前段，接触和节点必须同时满足才命中。
func _tick_contact(unit: Unit, dt: float, config: Dictionary) -> bool:
	if not contact_active and not _begin_contact(unit, config): return false
	config = executing
	if following: return _tick_contact_landing(unit, dt)
	var target = target_ref.get_ref() if target_ref != null else null
	if is_instance_valid(target) and unit._target_is_attackable(target):
		var desired := _landing(unit, target, config)
		if desired.is_finite() and contact_origin.distance_to(desired) <= travel_limit:
			contact_endpoint = desired
		else:
			target_ref = null
	else:
		target_ref = null
	# 一旦失效，不换目标也不恢复追踪；沿最后有效轨迹踢空落地。
	var duration := float(config.charge_contact_duration)
	if contact_elapsed >= duration - 0.000001:
		return _finish_contact(unit, target if target_ref != null else null, dt, config)
	# 在固定节点前到达接触位置；目标变位可修正接近速度，但有总距离上限。
	var left := maxf(duration - contact_elapsed, dt)
	var delta := contact_endpoint - unit.global_position
	unit._move_intent = delta.normalized() * minf(delta.length() / left, float(config.charge_dash_speed))
	unit._move_direction = unit._move_intent.normalized()
	unit._body_facing_direction = approach
	contact_elapsed = minf(contact_elapsed + dt, duration)
	return true

## 命中或踢空均只结算一次，然后进入续冲；回调可能销毁或中断施法者。
func _finish_contact(unit: Unit, target: Node2D, dt: float, config: Dictionary) -> bool:
	unit.basic_attack_sequence += 1
	unit._attack_swing_count += 1
	if target_ref != null and unit._target_gap(target) <= 4.0:
		unit._perform_attack_strike(target, unit.damage * unit.active_damage_multiplier, {
			"attack_id": unit.basic_attack_sequence, "cycle_id": unit.get_visual_action_serial(),
			"movement_strike": true, "ground_only": true,
			"movement_strike_knockback": float(config.get("charge_knockback", 0.0)),
			"movement_strike_knockback_origin": target.global_position - approach,
			"knockback_duration": float(config.get("charge_knockback_duration", 0.5)),
			"stun_duration": float(config.get("charge_stun_duration", 0.0)) if target is Unit and not target.is_building else 0.0})
	else:
		# 踢空仍是一次正式出手，只消费一次致盲，不发放命中收益。
		unit._consume_blind_for_strike({})
	if not is_instance_valid(unit) or unit.hp <= 0.0 or unit.is_queued_for_deletion() or not contact_active: return true
	target_ref = null
	following = true
	follow_origin = unit.global_position
	follow_endpoint = UnitLandingQuery.displacement_endpoint(unit, follow_origin, approach, float(config.charge_follow_distance), 0.0)
	if not follow_endpoint.is_finite(): follow_endpoint = follow_origin
	follow_elapsed = 0.0
	unit.play_visual_action(&"charge_followthrough", float(config.charge_follow_duration))
	return _tick_contact_landing(unit, dt)

func _tick_contact_landing(unit: Unit, dt: float) -> bool:
	var duration := float(executing.charge_follow_duration)
	if follow_elapsed >= duration - 0.000001:
		unit._move_intent = Vector2.ZERO
		var landed := unit.recover_displacement_position()
		contact_active = false
		following = false
		unit.cancel_charge()
		unit.attack_timeline.cancel(true)
		unit._attack_visual_pending = true
		# 不保留旧普攻冷却；无合法落点时仍由恢复锁阻止攻击。
		return not landed
	follow_elapsed = minf(follow_elapsed + dt, duration)
	var progress := follow_elapsed / duration
	var point := follow_origin.lerp(follow_endpoint, 1.0 - pow(1.0 - progress, 2.0))
	unit._move_intent = (point - unit.global_position) / dt
	unit._move_direction = approach
	unit._body_facing_direction = approach
	return true
