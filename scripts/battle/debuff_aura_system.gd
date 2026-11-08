extends RefCounted
## 与加速光环同一行动边界采样；来源死亡、离场与凝滞不会留下定时减益。
static func update(combatants: Array) -> void:
	var sources: Array[Dictionary] = []
	for actor in combatants:
		if not is_instance_valid(actor) or not actor is Unit:
			continue
		if actor.hp <= 0.0 or actor._deploy_timer > 0.0 or CombatInteraction.in_stasis(actor):
			continue
		var stats := PresentationConfig.for_form(actor._base_form_stats, actor.form_index)
		if stats.has("debuff_aura_radius"):
			sources.append({
				"unit": actor,
				"radius": float(stats.debuff_aura_active_radius if actor.active_buff_timer > 0.0 else stats.debuff_aura_radius),
				"move": float(stats.debuff_aura_move_multiplier),
				"attack": float(stats.debuff_aura_attack_multiplier),
			})
	for target in combatants:
		if not is_instance_valid(target) or not target is Unit: continue
		var move := 1.0
		var attack := 1.0
		if target.hp > 0.0 and not target.rejects_control():
			for source in sources:
				if source.unit.team == target.team or source.unit.global_position.distance_to(target.global_position) > source.radius + target.body_radius: continue
				var context := CombatInteraction.effect_context(source.unit)
				if not CombatInteraction.allows_effect(target, context): continue
				# 持续区域每次采样是一次交互，两种减益共用同一护盾判定。
				if CombatInteraction.blocks_effect(target, context): continue
				move = minf(move, source.move)
				attack = minf(attack, source.attack)
				CombatInteraction.record_combat_effect(target, context)
		target.set_debuff_aura_multipliers(move, attack)
