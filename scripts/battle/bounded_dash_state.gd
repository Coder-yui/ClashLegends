class_name BoundedDashState
extends RefCounted
## 普通主动位移：剩余距离内能找到落点才跨地形，仅在名义终点受阻时使用配置的落点余量。
var source_ref: WeakRef
var serial: int
var direction: Vector2
var distance: float
var duration: float
var travelled := 0.0
var finished := false

func _init(source: Unit, skill: Dictionary) -> void:
	source_ref = weakref(source)
	serial = source.active_skill_cast_serial
	direction = source.active_skill_cast_facing.normalized()
	if bool(skill.get("dash_backward", false)): direction = -direction
	distance = float(skill.length)
	if skill.has("landing_extension"):
		var extra := float(skill.landing_extension) + source.body_radius + 2.0
		var landing := UnitLandingQuery.displacement_endpoint(source, source.global_position, direction, distance, extra)
		if landing.is_finite():
			# 起步时只分配一次额外路程，逐Tick检查不再次增加预算。
			distance = maxf(distance, source.global_position.distance_to(landing))
	duration = float(skill.cast_duration)
	source.magazine.restore(int(skill.get("ammo_restore", 0)))
	source.sync_dash_cast(serial, true, duration, 0.0, 1.0, duration)

func tick(dt: float) -> bool:
	var source = source_ref.get_ref()
	if finished or not is_instance_valid(source): return false
	if source.hp <= 0.0 or serial != source.active_skill_cast_serial or serial <= source.cancelled_skill_cast_serial:
		_finish(source)
		return false
	if source.is_frozen() or source.is_stunned() or source._knockback_timer > 0.0 or source.control.hard.remaining(&"root") > 0.0:
		source.cancel_skill_cast()
		_finish(source)
		return false
	var left := maxf(0.0, distance - travelled)
	var endpoint := UnitLandingQuery.displacement_endpoint(source, source.global_position, direction, left, 0.0)
	if not endpoint.is_finite():
		source.recover_displacement_position()
		_finish(source)
		return false
	var travel := minf(distance / duration * dt, source.global_position.distance_to(endpoint))
	source.begin_dash_motion()
	source.apply_dash_motion(source.global_position + direction * travel)
	travelled += travel
	if travel <= 0.000001 or source.global_position.distance_to(endpoint) < 0.01 or travelled >= distance - 0.001:
		_finish(source)
		return false
	var progress := duration * travelled / distance
	source.sync_dash_cast(serial, true, duration, progress, 1.0, duration - progress)
	return true

func _finish(source: Unit) -> void:
	finished = true
	source.finish_dash_cast(serial)
