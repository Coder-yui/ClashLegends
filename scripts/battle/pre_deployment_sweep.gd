extends RefCounted
## 预部署冲击波的权威几何。排程持有命中集合；表现只读同一轨迹函数。
static func start_position(destination: Vector2, team: int, stats: Dictionary) -> Vector2:
	return destination + Vector2(0, 1 if team == 0 else -1) * float(stats.get("pre_deploy_sweep_distance", 0.0))

static func position_at(destination: Vector2, team: int, stats: Dictionary, elapsed: float) -> Vector2:
	var start := float(stats.get("pre_deploy_sweep_start", 0.0))
	var duration := maxf(float(stats.get("pre_deploy_time", 0.0)) - start, 0.001)
	var progress := clampf((elapsed - start) / duration, 0.0, 1.0)
	return start_position(destination, team, stats).lerp(destination, 1.0 - pow(1.0 - progress, 2.0))

static func advance(entry: Dictionary, before: float, after: float, combatants: Array) -> void:
	var stats := CardDB.get_card(String(entry.card_id))
	var damage := float(stats.get("pre_deploy_sweep_damage", 0.0))
	if damage <= 0.0 or after + 0.00001 < float(stats.pre_deploy_sweep_start): return
	var team := int(entry.team)
	var previous := position_at(entry.pos, team, stats, before)
	var current := position_at(entry.pos, team, stats, after)
	var radius := float(stats.pre_deploy_sweep_radius)
	var hit_ids: Dictionary = entry.get("sweep_hit_ids", {})
	entry["sweep_hit_ids"] = hit_ids
	for target in combatants:
		if not is_instance_valid(target) or target.hp <= 0.0 or target.team == team: continue
		if target is Unit and target.is_air: continue
		var id: int = target.get_instance_id()
		if hit_ids.has(id): continue
		var closest := Geometry2D.get_closest_point_to_segment(target.global_position, previous, current)
		if target.global_position.distance_to(closest) > radius + target.body_radius: continue
		if not CombatInteraction.allows(target, null, team, closest): continue
		hit_ids[id] = true
		target.take_damage(damage, null, team, closest)
