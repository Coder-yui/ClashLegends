class_name AutoPullState
extends RefCounted
## 瞄准属于单位动作；出钩后由 ProjectileSystem 独立持有，不随来源取消。
var target_ref: WeakRef
var elapsed := 0.0
var launched := false
var cast_serial := -1
var projectile_id := -1

func active() -> bool:
	return target_ref != null

func cancel() -> void:
	target_ref = null
	elapsed = 0.0
	launched = false
	projectile_id = -1

func _finish(unit: Unit) -> void:
	if unit.active_skill_cast_serial == cast_serial:
		unit.active_skill_cast_timer = 0.0
		unit.active_skill_cast_locks.clear()
		unit._visual_action_time_left = 0.0
	unit._attack_visual_pending = true
	cancel()

static func valid_target(unit: Unit, target) -> bool:
	return is_instance_valid(target) and target is Unit and not target.is_building and not target.structure_rush.control_immune() and unit._target_is_attackable(target) and CombatInteraction.allows(target, unit)

func tick(unit: Unit, dt: float) -> bool:
	if not active(): return false
	if unit.active_skill_cast_serial != cast_serial:
		cancel()
		return false
	var target = target_ref.get_ref()
	if launched:
		if not unit.battle_context.pull_projectile_active(projectile_id):
			_finish(unit)
			return false
	else:
		if not valid_target(unit, target) or unit._target_gap(target) > minf(unit.sight_range, float(unit._base_form_stats.auto_pull_break_range)) or unit._target_gap(target) <= unit.attack_range:
			_finish(unit)
			return false
		unit.active_skill_cast_facing = unit.global_position.direction_to(target.global_position)
		unit._body_facing_direction = unit.active_skill_cast_facing
		elapsed += dt
		if elapsed + 0.000001 >= float(unit._base_form_stats.auto_pull_windup):
			launched = true
			projectile_id = unit.battle_context.launch_pull(unit, target)
			unit.play_visual_action(&"auto_pull", float(unit._base_form_stats.auto_pull_flight) + float(unit._base_form_stats.auto_pull_duration) + FixedStepClock.STEP)
			unit.battle_context.notify_unit_audio_event(unit, &"pull:start", unit.global_position)
	return true

func try_start(unit: Unit) -> bool:
	var reach := float(unit._base_form_stats.get("auto_pull_range", 0.0))
	if reach <= 0.0 or unit.battle_context == null: return false
	var minimum := float(unit._base_form_stats.auto_pull_min_range)
	var target: Unit
	var best := INF
	for candidate in unit.get_tree().get_nodes_in_group("combatants"):
		if not candidate is Node2D or not unit._target_is_attackable(candidate): continue
		var gap := unit._target_gap(candidate)
		if gap < minimum: return false # 含建筑：近身攻击/追击优先。
		if gap <= minf(reach, unit.sight_range) and gap < best and valid_target(unit, candidate):
			target = candidate
			best = gap
	if target == null: return false
	target_ref = weakref(target)
	elapsed = 0.0
	launched = false
	var duration := float(unit._base_form_stats.auto_pull_windup) + float(unit._base_form_stats.auto_pull_flight) + float(unit._base_form_stats.auto_pull_duration) + 2.0 * FixedStepClock.STEP
	unit.begin_active_skill_cast(duration, target.global_position - unit.global_position)
	cast_serial = unit.active_skill_cast_serial
	unit._target = target
	return true
