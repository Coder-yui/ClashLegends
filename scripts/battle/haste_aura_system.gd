extends RefCounted
## 行动批次前统一采样，避免按单位遍历顺序产生不同的攻速。
static func update(combatants: Array) -> void:
	var sources: Array[Dictionary] = []
	for actor in combatants:
		if not is_instance_valid(actor) or not actor is Unit or actor.hp <= 0.0 or actor._deploy_timer > 0.0 or CombatInteraction.in_stasis(actor): continue
		var stats := PresentationConfig.for_form(actor._base_form_stats, actor.form_index)
		if stats.has("haste_aura_radius"):
			sources.append({"unit": actor, "radius": float(stats.haste_aura_radius), "multiplier": float(stats.haste_aura_multiplier)})
	for target in combatants:
		if not is_instance_valid(target) or not target is Unit: continue
		var multiplier := 1.0
		if target.hp > 0.0 and not CombatInteraction.in_stasis(target):
			for source in sources:
				if source.unit.team == target.team and source.unit.global_position.distance_to(target.global_position) <= source.radius + target.body_radius:
					multiplier = maxf(multiplier, source.multiplier)
		target.set_haste_aura_multiplier(multiplier)
