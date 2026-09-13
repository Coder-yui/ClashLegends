class_name CombatResolver
extends Node2D
## 真实命中、溅射、附带效果与存活来源收益；表现事件只传值。
signal attack_hit(source: Dictionary, position: Vector2, first_strike: bool)

func resolve_attack_hit(p_team: int, origin: Vector2, primary: Node2D, amount: float, radius: float, knockback: float, from: Node2D = null, source_position: Vector2 = Vector2(INF, INF), source_form_index: int = -1, effects: Dictionary = {}, counts_as_attack: bool = true) -> bool:
	if not effects.has("presentation_source") and is_instance_valid(from) and (from is Unit or from is Tower):
		effects = effects.duplicate(true)
		effects["presentation_source"] = PresentationConfig.attack_source(from)
	if primary == null or not is_instance_valid(primary) or primary.hp <= 0.0:
		return false
	var ground_only := bool(effects.get("ground_only", false))
	if ground_only and primary is Unit and (primary as Unit).is_air:
		return false
	if radius <= 0.0:
		var was_alive: bool = primary.hp > 0.0
		var hit_amount := BattleNumbers.quantity(amount)
		if counts_as_attack and is_instance_valid(from) and from is Unit:
			hit_amount += (from as Unit).on_hit_passive_damage(primary)
		var result := _hit(primary, hit_amount, amount, from, p_team, source_position, effects)
		var landed: bool = result.landed
		if landed:
			_apply_attack_hit_effects(primary, effects)
		if landed and counts_as_attack and from is Unit and is_instance_valid(from) and from.hp > 0.0:
			(from as Unit).on_attack_landed(source_form_index, float(result.health_lost))
		if landed and counts_as_attack:
			attack_hit.emit(effects.get("presentation_source", {}), primary.global_position, bool(effects.get("first_strike", false)))
		if landed and was_alive and primary.hp <= 0.0 and from is Unit and is_instance_valid(from) and from.hp > 0.0:
			(from as Unit).on_enemy_killed(primary)
		if landed and knockback > 0.0 and primary is Unit and is_instance_valid(primary) and primary.hp > 0.0:
			(primary as Unit).apply_knockback(origin, knockback)
		return landed
	var impact_pos := primary.global_position
	var any_landed := false
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.team == p_team or c.hp <= 0.0:
			continue
		if ground_only and c is Unit and (c as Unit).is_air:
			continue
		if c.global_position.distance_to(impact_pos) <= radius + c.body_radius:
			var was_alive: bool = c.hp > 0.0
			var hit_amount := BattleNumbers.quantity(amount)
			if counts_as_attack and is_instance_valid(from) and from is Unit:
				hit_amount += (from as Unit).on_hit_passive_damage(c)
			var result := _hit(c, hit_amount, amount, from, p_team, source_position, effects)
			var landed: bool = result.landed
			if landed:
				_apply_attack_hit_effects(c, effects)
			any_landed = landed or any_landed
			if landed and was_alive and c.hp <= 0.0 and from is Unit and is_instance_valid(from) and from.hp > 0.0:
				(from as Unit).on_enemy_killed(c)
			if landed and knockback > 0.0 and c is Unit and is_instance_valid(c) and c.hp > 0.0:
				(c as Unit).apply_knockback(origin, knockback)
	if any_landed and counts_as_attack and from is Unit and is_instance_valid(from) and from.hp > 0.0:
		(from as Unit).on_attack_landed(source_form_index, 0.0) # 范围吸血尚未设计，不把名义伤害作为掉血。
	if any_landed and counts_as_attack:
		attack_hit.emit(effects.get("presentation_source", {}), impact_pos, bool(effects.get("first_strike", false)))
	return any_landed

func _apply_attack_hit_effects(target: Node2D, effects: Dictionary) -> void:
	if target is Unit and is_instance_valid(target) and target.hp > 0.0:
		var blind_charges := maxi(int(effects.get("blind_charges", 0)), 0)
		if blind_charges > 0:
			(target as Unit).apply_blind(blind_charges)


func _hit(target: Node2D, hit_amount: float, raw_amount: float, source: Node2D, team: int, position: Vector2, effects: Dictionary) -> Dictionary:
	if bool(effects.get("continuous_damage", false)) and is_instance_valid(source) and source is Unit:
		return source._continuous_damage_stream.hit(target, raw_amount, source, team, position, hit_amount - BattleNumbers.quantity(raw_amount))
	return BattleNumbers.hit(target, hit_amount, source, team, position)
