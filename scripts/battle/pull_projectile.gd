class_name PullProjectile
extends RefCounted
## 独立释放结果：固定出手中心；只跟踪目标资格，不再读取来源动作/生命/射程。
static func create(source: Unit, target: Unit) -> Dictionary:
	var origin := source.global_position
	return {"pull": true, "attacker": source, "target": target, "team": source.team,
		"source_pos": origin, "pos": origin, "direction": origin.direction_to(target.global_position),
		"color": Color.WHITE, "radius": 4.0, "visual": &"blitzcrank_hook", "speed": 800.0,
		"age": 0.0, "returning": false, "flight": float(source._base_form_stats.auto_pull_flight),
		"duration": float(source._base_form_stats.auto_pull_duration), "spacing": source.body_radius + source.attack_range * 0.5,
		"order": source.battle_context.damage_batch().next_displacement_order(source),
		"presentation_source": PresentationConfig.attack_source(source),
		"visual_path": {"start": origin, "end": target.global_position, "origin_offset": Vector2.ZERO,
			"progress": 0.0, "contact_radius": 0.0, "wave": false,
			"source": ProjectileSystem._visual_entity(source), "target": ProjectileSystem._visual_entity(target)}}

static func cancel_return(p: Dictionary) -> void:
	var target = p.get("target")
	if is_instance_valid(target) and bool(p.get("returning", false)) and target.knockback.in_transit and target.knockback.endpoint == p.get("endpoint"):
		target.knockback.cancel(&"pull_target_invalid")
		target.recover_displacement_position()

static func tick(p: Dictionary, dt: float, system: ProjectileSystem) -> bool:
	var target = p.target
	if not is_instance_valid(target) or target.hp <= 0.0 or target.is_queued_for_deletion(): return true
	var context := CombatInteraction.effect_context(null, int(p.team), p.source_pos)
	if not CombatInteraction.can_acquire(target, int(p.team)) or not CombatInteraction.allows_effect(target, context) or target.structure_rush.control_immune():
		cancel_return(p)
		return true
	p.age = float(p.age) + dt
	if not bool(p.returning):
		var progress := clampf(float(p.age) / float(p.flight), 0.0, 1.0)
		p.pos = (p.source_pos as Vector2).lerp(target.global_position, progress)
		p.visual_path.progress = progress
		p.visual_path.end = target.global_position
		if progress < 1.0: return false
		var toward_source: Vector2 = target.global_position.direction_to(p.source_pos)
		var spacing: float = float(p.spacing) + target.body_radius
		var nominal_distance := maxf(0.0, target.global_position.distance_to(p.source_pos) - spacing)
		if nominal_distance <= 0.0: return true
		var preferred: Vector2 = p.source_pos - toward_source * spacing
		# 搜索限于身前间距外再一格，不能因河岸/塔挡住直线而退回远端桥面。
		var endpoint := UnitLandingQuery.pull_destination(target, p.source_pos, preferred, spacing + ArenaRules.TILE_SIZE)
		if not endpoint.is_finite(): return true
		var distance: float = target.global_position.distance_to(endpoint)
		if distance <= 0.000001: return true
		var direction: Vector2 = target.global_position.direction_to(endpoint)
		p.return_duration = maxf(float(p.duration), distance / (nominal_distance / float(p.duration)))
		# 已选合法目的地：以该方向/距离调用原有直线执行器，不再请求前延。
		if not target.apply_forced_displacement(direction, distance, float(p.return_duration), 0.0, context, p.order): return true
		endpoint = target.global_position + direction * distance

		p.returning = true
		p.age = 0.0
		p.endpoint = endpoint
		p.visual_path.wave = true # 同一公开轨迹字段标记回程表现。
		p.hit_pending = true
	else:
		if bool(p.get("hit_pending", false)):
			if not target.knockback.in_transit or target.knockback.endpoint != p.endpoint: return true
			p.hit_pending = false
			system.wave_audio.emit(p.presentation_source, "pull", target.global_position, "hit")
		p.pos = target.global_position
		p.visual_path.end = target.global_position
		p.visual_path.progress = clampf(float(p.age) / float(p.return_duration), 0.0, 1.0)
		if float(p.age) + 0.000001 >= float(p.return_duration) + FixedStepClock.STEP: return true
	return false
