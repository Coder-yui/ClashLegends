class_name CombatResolver
extends Node2D
## 真实命中、溅射、附带效果与存活来源收益；表现事件只传值。
signal attack_hit(source: Dictionary, position: Vector2, first_strike: bool)

func _resolve_immediate_attack_hit(p_team: int, origin: Vector2, primary: Node2D, amount: float, radius: float, knockback: float, from: Node2D = null, source_position: Vector2 = Vector2(INF, INF), source_form_index: int = -1, effects: Dictionary = {}, counts_as_attack: bool = true) -> bool:
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
			(from as Unit).on_attack_landed(source_form_index, float(result.health_lost), -1, int(effects.get("source_generation", -1)))
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
		(from as Unit).on_attack_landed(source_form_index, 0.0, -1, int(effects.get("source_generation", -1))) # 范围吸血尚未设计，不把名义伤害作为掉血。
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

## 一个明确模拟阶段的事务；不跨 Tick，也不跨技能/单位/弹体阶段。
var collecting := false
var committing := false
var _hits: Array[Dictionary] = []
var _effects: Array[Callable] = []
var _benefits: Array[Callable] = []
var _deaths: Dictionary = {}
var _kill_awards: Dictionary = {}
var trace_enabled := false
var trace: Array[Dictionary] = []
var _tick := 0
var _phase := ""

func begin_batch(tick: int, phase: String) -> void:
	assert(not collecting and not committing)
	_tick = tick
	_phase = phase
	collecting = true

func defer_effect(callback: Callable) -> void:
	_effects.append(callback)

func defer_benefit(callback: Callable) -> void:
	_benefits.append(callback)

func defer_death(unit: Unit, trigger: bool) -> void:
	_deaths[unit] = trigger

func submit_damage(target: Node2D, amount: float, source: Node2D, team: int, position: Vector2) -> Dictionary:
	var accepted: bool = is_instance_valid(target) and not target.is_queued_for_deletion() and target.hp > 0.0
	var result := {"accepted": accepted, "landed": false, "damage": BattleNumbers.quantity(amount), "health_lost": 0.0, "shield_absorbed": 0.0, "overkill": 0.0}
	if accepted:
		_hits.append({"target": target, "source": source, "result": result})
		_record("hit_submit", source, target, result.damage)
	return result

func _record(event: String, source: Node2D, target: Node2D, amount: float = 0.0) -> void:
	if not trace_enabled: return
	trace.append({"tick": _tick, "phase": _phase, "event": event,
		"source": source.get_instance_id() if is_instance_valid(source) else -1,
		"target": target.get_instance_id() if is_instance_valid(target) else -1,
		"segment": source._attack_hit_index - 1 if source is Unit else -1, "amount": amount})

func commit_batch() -> void:
	assert(collecting)
	collecting = false
	committing = true
	var groups := {}
	for hit in _hits:
		var target = hit.target
		# 在任何本批扣血之前冻结最终资格，不能逐刀用实时 hp 撤回同刻命中。
		hit.result.landed = is_instance_valid(target) and not target.is_queued_for_deletion() and bool(hit.result.accepted)
		if not hit.result.landed: continue
		if not groups.has(target): groups[target] = []
		groups[target].append(hit)
	# 独立盾层仍由 ShieldState 消耗。每刀保留记录与回调；同批盾量和实际掉血
	# 按各刀有效伤害比例归属（不取整），无尾刀优先或重复掉血归属。
	for target in groups:
		var total := 0.0
		for hit in groups[target]: total += float(hit.result.damage)
		var before_hp := float(target.hp)
		var before_shield := float(target.shield_hp)
		for hit in groups[target]:
			# 逐刀消耗独立盾层与伤害入口；已致死后仍保留本批其余命中记录。
			target.take_damage(float(hit.result.damage))
		var lost := maxf(before_hp - float(target.hp), 0.0)
		var absorbed := maxf(before_shield - float(target.shield_hp), 0.0)
		for hit in groups[target]:
			var share := float(hit.result.damage) / total if total > 0.0 else 0.0
			hit.result.health_lost = lost * share
			hit.result.shield_absorbed = absorbed * share
			hit.result.overkill = maxf(float(hit.result.damage) - (lost + absorbed) * share, 0.0)
	# 先固定全批存活状态，再施加控制和发放存活收益。
	for callback in _effects: callback.call()
	_commit_knockbacks()
	# 回调本身可调用资源入口；退出 committing 后才执行，避免二次排队。
	committing = false
	for callback in _benefits: callback.call()
	for unit in _deaths:
		_record("death_commit", null, unit)
		unit._die(bool(_deaths[unit]))
	_hits.clear()
	_effects.clear()
	_benefits.clear()
	_deaths.clear()
	_kill_awards.clear()

func resolve_attack_hit(p_team: int, origin: Vector2, primary: Node2D, amount: float, radius: float, knockback: float, from: Node2D = null, source_position: Vector2 = Vector2(INF, INF), source_form_index: int = -1, effects: Dictionary = {}, counts_as_attack: bool = true) -> bool:
	if not collecting:
		return _resolve_immediate_attack_hit(p_team, origin, primary, amount, radius, knockback, from, source_position, source_form_index, effects, counts_as_attack)
	if not is_instance_valid(primary) or primary.hp <= 0.0: return false
	effects = effects.duplicate(true)
	if not effects.has("presentation_source") and is_instance_valid(from):
		effects.presentation_source = PresentationConfig.attack_source(from)
	var displacement_order: Array = effects.get("displacement_order", [])
	if knockback > 0.0 and displacement_order.is_empty():
		displacement_order = next_displacement_order(from)
	var targets: Array = [primary] if radius <= 0.0 else get_tree().get_nodes_in_group("combatants")
	var landed := false
	var hit_results: Array[Dictionary] = []
	var impact := primary.global_position
	var swing: int = from._attack_swing_count if from is Unit else 0
	for target in targets:
		if not is_instance_valid(target) or target.hp <= 0.0: continue
		if radius > 0.0 and (target.team == p_team or target.global_position.distance_to(impact) > radius + target.body_radius): continue
		if bool(effects.get("ground_only", false)) and target is Unit and target.is_air: continue
		var hit_amount := float(BattleNumbers.quantity(amount))
		if counts_as_attack and from is Unit: hit_amount += from.on_hit_passive_damage(target)
		var result := _hit(target, hit_amount, amount, from, p_team, source_position, effects)
		if not result.accepted: continue
		hit_results.append(result)
		landed = true
		var fixed_target: Node2D = target
		defer_effect(func():
			if not result.landed: return
			_apply_attack_hit_effects(fixed_target, effects))
		if knockback > 0.0 and fixed_target is Unit:
			submit_knockback(fixed_target, origin, knockback, 0.2, 1.4, displacement_order, result)
		defer_benefit(func():
			if not result.landed: return
			if not is_instance_valid(from) or not from is Unit or from.hp <= 0.0: return
			if counts_as_attack and radius <= 0.0:
				from.on_attack_landed(source_form_index, float(result.health_lost), swing, int(effects.get("source_generation", -1)))
			# 同批多人共同致死只给存活参与者一次自己的击杀收益，不按遍历挑尾刀。
			if fixed_target.hp <= 0.0 and float(result.health_lost) > 0.0:
				var key := "%s:%s" % [from.get_instance_id(), fixed_target.get_instance_id()]
				if not _kill_awards.has(key):
					_kill_awards[key] = true
					from.on_enemy_killed(fixed_target))
	if landed:
		var completion: Callable = effects.get("delivery_callback", Callable())
		if completion.is_valid():
			defer_effect(func(): completion.call(hit_results.any(func(result): return result.landed)))
		if counts_as_attack and radius > 0.0:
			defer_benefit(func():
				if hit_results.any(func(result): return result.landed) and is_instance_valid(from) and from is Unit and from.hp > 0.0:
					from.on_attack_landed(source_form_index, 0.0, swing, int(effects.get("source_generation", -1))))
		if counts_as_attack:
			defer_effect(func():
				if hit_results.any(func(result): return result.landed):
					attack_hit.emit(effects.get("presentation_source", {}), impact, bool(effects.get("first_strike", false))))
	return landed


# 来源身份在出生注册时确定；来源内事件序号在出手/技能排队时分配并随弹体保存。
var _next_source_id := 1
var _source_event_sequences: Dictionary = {}
var _knockbacks: Array[Dictionary] = []

func register_source(source: Node2D) -> void:
	if source.combat_source_id > 0: return
	source.combat_source_id = _next_source_id
	_next_source_id += 1

func next_displacement_order(source: Node2D) -> Array:
	assert(is_instance_valid(source) and source.combat_source_id > 0)
	var id := int(source.combat_source_id)
	var sequence := int(_source_event_sequences.get(id, 0)) + 1
	_source_event_sequences[id] = sequence
	return [id, sequence, 0]

func submit_knockback(target: Unit, origin: Vector2, distance: float, duration: float, mass_factor_max: float, order: Array, hit_result: Dictionary = {}) -> void:
	if not target.can_receive_knockback(origin, distance, duration, mass_factor_max): return
	assert(order.size() == 3 and int(order[0]) > 0 and int(order[1]) > 0 and int(order[2]) >= 0)
	_knockbacks.append({"target": target, "origin": origin, "distance": distance,
		"duration": duration, "mass_factor_max": mass_factor_max, "order": order.duplicate(), "hit_result": hit_result})

func _commit_knockbacks() -> void:
	_knockbacks.sort_custom(func(a, b):
		for index in 3:
			if a.order[index] != b.order[index]: return a.order[index] < b.order[index]
		return false)
	for event in _knockbacks:
		if not event.hit_result.is_empty() and not event.hit_result.landed: continue
		if is_instance_valid(event.target):
			event.target.apply_knockback(event.origin, event.distance, event.duration, event.mass_factor_max)
	_knockbacks.clear()
