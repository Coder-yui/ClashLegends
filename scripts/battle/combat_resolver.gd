class_name CombatResolver
extends Node2D
## 真实命中、溅射、附带效果与存活来源收益；表现事件只传值。
signal attack_hit(source: Dictionary, position: Vector2, first_strike: bool)

func _settle_bleeding_attack(target: Node2D, source: Unit, effects: Dictionary, result: Dictionary) -> void:
	if not effects.has("bleed_definition"): return
	var definition: Dictionary = effects.bleed_definition
	var stacks: int = target.bleeding.apply(target, source, definition, bool(effects.get("bleed_full", false)))
	if source.hp <= 0.0: return
	if source.buffs.remaining(&"blood_rage") > 0.0 or stacks >= int(definition.bleed_max_stacks):
		source.refresh_blood_rage()
	if bool(effects.get("execute_reset", false)) and target.hp <= 0.0 and (not target is Unit or target.is_true_death()) and float(result.health_lost) > 0.0:
		source.refresh_blood_rage()
		if source.battle_context != null:
			source.battle_context.grant_skill_recast(source)
			source.battle_context.notify_unit_audio_event(source, &"execute:kill", target.global_position)

func _apply_attack_hit_effects(target: Node2D, effects: Dictionary, source: Node2D = null) -> void:
	if is_instance_valid(target) and target is Unit and target.hp > 0.0:
		if float(effects.get("on_hit_slow_duration", 0.0)) > 0.0:
			target.apply_slow(float(effects.on_hit_slow_duration), float(effects.on_hit_slow_multiplier), effects.on_hit_status_source, effects.on_hit_context)
		var blind_charges := maxi(int(effects.get("blind_charges", 0)), 0)
		if blind_charges > 0:
			(target as Unit).apply_blind(blind_charges, CombatInteraction.effect_context(source if is_instance_valid(source) else null))


func _hit(target: Node2D, hit_amount: float, raw_amount: float, source: Node2D, team: int, position: Vector2, effects: Dictionary) -> Dictionary:
	if bool(effects.get("continuous_damage", false)) and is_instance_valid(source) and source is Unit:
		return source._continuous_damage_stream.hit(target, raw_amount, source, team, position, hit_amount - BattleNumbers.quantity(raw_amount))
	return BattleNumbers.hit(target, hit_amount, source, team, position)

## 一个明确模拟阶段的事务；不跨 Tick，也不跨技能/单位/弹体阶段。
var collecting := false
var committing := false
var _hits: Array[Dictionary] = []
var _attack_receipts: Array[Dictionary] = []
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

func submit_damage(target: Node2D, amount: float, source: Node2D, team: int, position: Vector2, attached: bool = false) -> Dictionary:
	var accepted: bool = is_instance_valid(target) and not target.is_queued_for_deletion() and target.hp > 0.0 and CombatInteraction.allows(target, source, team, position, attached)
	var result := BattleNumbers.pending_hit(accepted, amount)
	result["assist_conversion"] = AssistConversionState.source_definition(source)
	var blocked := accepted and BattleNumbers.quantity(amount) > 0 and CombatInteraction.blocks_effect(target, CombatInteraction.effect_context(source, team, position, attached))
	result["blocked"] = blocked
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
		var will_land: bool = is_instance_valid(target) and not target.is_queued_for_deletion() and bool(hit.result.accepted) and not bool(hit.result.blocked)
		if not will_land:
			BattleNumbers.settle_hit(hit.result, false)
			continue
		if not groups.has(target): groups[target] = []
		groups[target].append(hit)
	# 独立盾层仍由 ShieldState 消耗。每刀保留记录与回调；同批盾量和实际掉血
	# 按各刀有效伤害比例归属（不取整），无尾刀优先或重复掉血归属。
	for target in groups:
		var total := 0.0
		for hit in groups[target]: total += float(hit.result.damage)
		# 本批所有有效参与者先登记，再扣血，避免同刻最后一刀或遍历顺序漏记。
		for hit in groups[target]:
			if float(hit.result.damage) > 0.0:
				target.assist_conversion.record(target, hit.result.assist_conversion)
		var before_hp := float(target.hp)
		var before_shield := float(target.shield_hp)
		for hit in groups[target]:
			# 逐刀消耗独立盾层与伤害入口；已致死后仍保留本批其余命中记录。
			target.take_damage(float(hit.result.damage))
		var lost := maxf(before_hp - float(target.hp), 0.0)
		var absorbed := maxf(before_shield - float(target.shield_hp), 0.0)
		for hit in groups[target]:
			var share := float(hit.result.damage) / total if total > 0.0 else 0.0
			BattleNumbers.settle_hit(hit.result, true, lost * share, absorbed * share)
			if (lost + absorbed) * share > 0.0:
				CombatInteraction.record_combat_effect(target, CombatInteraction.effect_context(hit.source if is_instance_valid(hit.source) else null))
	for receipt in _attack_receipts:
		var lost := 0.0
		var absorbed := 0.0
		var any_landed := false
		for hit in receipt.hits:
			assert(hit.settled, "攻击子命中必须先提交")
			any_landed = any_landed or hit.landed
			lost += float(hit.health_lost)
			absorbed += float(hit.shield_absorbed)
		BattleNumbers.settle_hit(receipt, any_landed, lost, absorbed)
	# take_damage 已固定全批存活状态与死亡结果，再施加控制和发放存活收益。
	for callback in _effects:
		if callback.is_valid(): callback.call()
	_commit_knockbacks()
	# 回调本身可调用资源入口；退出 committing 后才执行，避免二次排队。
	committing = false
	for callback in _benefits:
		if callback.is_valid(): callback.call()
	for unit in _deaths:
		if not is_instance_valid(unit): continue
		_record("death_commit", null, unit)
		unit._die(bool(_deaths[unit]))
	_hits.clear()
	_attack_receipts.clear()
	_effects.clear()
	_benefits.clear()
	_deaths.clear()
	_kill_awards.clear()

func resolve_attack_hit(p_team: int, origin: Vector2, primary: Node2D, amount: float, radius: float, knockback: float, from: Node2D = null, source_position: Vector2 = Vector2(INF, INF), source_form_index: int = -1, effects: Dictionary = {}, counts_as_attack: bool = true) -> Dictionary:
	var receipt := BattleNumbers.pending_hit(false, 0.0)
	receipt["hits"] = []
	var own_batch := not collecting
	if own_batch: begin_batch(0, "immediate_attack")
	if not is_instance_valid(primary) or primary.hp <= 0.0:
		if own_batch: commit_batch()
		return receipt
	effects = effects.duplicate(true)
	if not effects.has("presentation_source") and is_instance_valid(from):
		effects.presentation_source = PresentationConfig.attack_source(from)
	var displacement_order: Array = effects.get("displacement_order", [])
	if knockback > 0.0 and displacement_order.is_empty():
		displacement_order = next_displacement_order(from)
	var cleave_radius := float(effects.get("cleave_radius", 0.0))
	var targets: Array = [primary] if radius <= 0.0 and cleave_radius <= 0.0 else get_tree().get_nodes_in_group("combatants")
	var landed := false
	var hit_results: Array = receipt.hits
	var impact := primary.global_position
	var swing: int = from._attack_swing_count if from is Unit else 0
	var source_ref: WeakRef = weakref(from) if is_instance_valid(from) else null
	for target in targets:
		if not is_instance_valid(target) or target.hp <= 0.0: continue
		if radius > 0.0 and (target.team == p_team or target.global_position.distance_to(impact) > radius + target.body_radius): continue
		if bool(effects.get("ground_only", false)) and target is Unit and target.is_air: continue
		if bool(effects.get("splash_match_primary_air", false)) and (target is Unit and target.is_air) != (primary is Unit and primary.is_air): continue
		if cleave_radius > 0.0 and (target.team == p_team or (target != primary and target.global_position.distance_to(effects.cleave_center) > cleave_radius + target.body_radius)): continue
		var hit_amount := float(BattleNumbers.quantity(amount)) if cleave_radius <= 0.0 or target == primary else 0.0
		if cleave_radius > 0.0: hit_amount += float(effects.cleave_damage)
		if counts_as_attack and from is Unit: hit_amount += from.on_hit_passive_damage(target)
		var result := _hit(target, hit_amount, amount, from, p_team, source_position, effects)
		if not result.accepted: continue
		hit_results.append(result)
		landed = true
		var target_ref: WeakRef = weakref(target)
		var primary_hit: bool = target == primary
		defer_effect(func():
			var landed_target = _node_from(target_ref)
			var landed_source = _node_from(source_ref)
			if not result.landed or not is_instance_valid(landed_target): return
			_apply_attack_hit_effects(landed_target, effects, landed_source)
			if counts_as_attack and radius <= 0.0 and (cleave_radius <= 0.0 or primary_hit) and landed_source is Unit:
				_settle_bleeding_attack(landed_target, landed_source, effects, result)
				if landed_source.battle_context != null: landed_source.battle_context.record_growth_hit(landed_source, landed_target))
		if knockback > 0.0 and target is Unit:
			submit_knockback(target, origin, knockback, 0.2, 1.4, displacement_order, result, CombatInteraction.effect_context(from, p_team, source_position))
		defer_benefit(func():
			var landed_source = _node_from(source_ref)
			var landed_target = _node_from(target_ref)
			if not result.landed or not landed_source is Unit or landed_source.hp <= 0.0: return
			if counts_as_attack and is_instance_valid(landed_target): landed_source.record_structure_attack(landed_target)
			if counts_as_attack and radius <= 0.0 and (cleave_radius <= 0.0 or primary_hit):
				landed_source.on_attack_landed(source_form_index, float(result.health_lost), swing, int(effects.get("source_generation", -1)))
			if is_instance_valid(landed_target): _award_hit_kill(landed_source, landed_target, result))
	if landed:
		if cleave_radius > 0.0:
			defer_effect(func():
				var landed_source = _node_from(source_ref)
				if hit_results.any(func(result): return result.landed) and is_instance_valid(landed_source) and landed_source.battle_context != null:
					landed_source.battle_context.notify_unit_audio_event(landed_source, &"cleave:hit", landed_source.global_position))
		if float(effects.get("hit_heal", 0.0)) > 0.0:
			defer_benefit(func():
				var landed_source = _node_from(source_ref)
				if hit_results.any(func(result): return result.landed) and is_instance_valid(landed_source) and landed_source is Unit and landed_source.hp > 0.0:
					landed_source.heal(float(effects.hit_heal)))
		if float(effects.get("cleave_heal_ratio", 0.0)) > 0.0:
			defer_benefit(func():
				var landed_source = _node_from(source_ref)
				if not is_instance_valid(landed_source) or not landed_source is Unit or landed_source.hp <= 0.0: return
				var damage_total := 0.0
				for result in hit_results:
					if result.landed: damage_total += float(result.health_lost)
				landed_source.heal(damage_total * float(effects.cleave_heal_ratio)))
		var completion: Callable = effects.get("delivery_callback", Callable())
		if completion.is_valid():
			defer_effect(func():
				if completion.is_valid(): completion.call(hit_results.any(func(result): return result.landed or bool(result.blocked))))
		if counts_as_attack and radius > 0.0:
			defer_benefit(func():
				var landed_source = _node_from(source_ref)
				if hit_results.any(func(result): return result.landed) and is_instance_valid(landed_source) and landed_source is Unit and landed_source.hp > 0.0:
					landed_source.on_attack_landed(source_form_index, 0.0, swing, int(effects.get("source_generation", -1))))
		if counts_as_attack:
			defer_effect(func():
				if hit_results.any(func(result): return result.landed):
					attack_hit.emit(effects.get("presentation_source", {}), impact, bool(effects.get("first_strike", false))))
	if landed:
		receipt.accepted = true
		receipt.settled = false
		for result in hit_results:
			receipt.damage += result.damage
			receipt.blocked = receipt.blocked or result.blocked
		_attack_receipts.append(receipt)
	if own_batch: commit_batch()
	return receipt

## 技能普通伤害也返回同一可提交回执；不伪装普攻，不增加普攻资源/成长。
func resolve_damage_hit(target: Node2D, amount: float, source: Node2D, team: int, position: Vector2, award_kill: bool = false) -> Dictionary:
	var own_batch := not collecting
	if own_batch: begin_batch(0, "immediate_damage")
	var result := submit_damage(target, amount, source, team, position)
	if award_kill:
		var source_ref: WeakRef = weakref(source) if is_instance_valid(source) else null
		var target_ref: WeakRef = weakref(target) if is_instance_valid(target) else null
		defer_benefit(func():
			var landed_source = _node_from(source_ref)
			var landed_target = _node_from(target_ref)
			if is_instance_valid(landed_source) and is_instance_valid(landed_target): _award_hit_kill(landed_source, landed_target, result))
	if own_batch: commit_batch()
	return result

func _node_from(reference: WeakRef) -> Node2D:
	return reference.get_ref() if reference != null else null

## 同批存活参与者每目标只领一次击杀；即时/正式技能和普攻共用。
func _award_hit_kill(source: Node2D, target: Node2D, result: Dictionary) -> void:
	if not result.settled or not result.landed or float(result.health_lost) <= 0.0: return
	if not is_instance_valid(source) or not source is Unit or source.hp <= 0.0 or not is_instance_valid(target) or target.hp > 0.0: return
	var key := "%s:%s" % [source.get_instance_id(), target.get_instance_id()]
	if _kill_awards.has(key): return
	_kill_awards[key] = true
	source.on_enemy_killed(target)

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

func submit_knockback(target: Unit, origin: Vector2, distance: float, duration: float, mass_factor_max: float, order: Array, hit_result: Dictionary = {}, interaction: Dictionary = {}) -> void:
	if not target.can_receive_knockback(origin, distance, duration, mass_factor_max): return
	assert(order.size() == 3 and int(order[0]) > 0 and int(order[1]) > 0 and int(order[2]) >= 0)
	_knockbacks.append({"target": target, "origin": origin, "distance": distance,
		"duration": duration, "mass_factor_max": mass_factor_max, "order": order.duplicate(), "hit_result": hit_result, "interaction": interaction})

func submit_forced_displacement(target: Unit, direction: Vector2, distance: float, duration: float, extension: float, order: Array, interaction: Dictionary = {}) -> void:
	assert(order.size() == 3 and int(order[0]) > 0 and int(order[1]) > 0 and int(order[2]) >= 0)
	_knockbacks.append({"target": target, "origin": target.global_position, "direction": direction,
		"distance": distance, "duration": duration, "extension": extension, "mass_factor_max": 1.0,
		"order": order.duplicate(), "hit_result": {}, "interaction": interaction, "forced": true})

func _commit_knockbacks() -> void:
	_knockbacks.sort_custom(func(a, b):
		for index in 3:
			if a.order[index] != b.order[index]: return a.order[index] < b.order[index]
		return false)
	for event in _knockbacks:
		if not event.hit_result.is_empty() and not event.hit_result.landed: continue
		if is_instance_valid(event.target) and CombatInteraction.allows(event.target) and event.target.can_receive_knockback(event.origin, event.distance, event.duration, event.mass_factor_max):
			# 来源上下文只补战斗归属，不重新用已移动的来源改变本批既有空间准入。
			if bool(event.get("forced", false)):
				if not event.target.apply_forced_displacement(event.direction, event.distance, event.duration, event.extension): continue
			else:
				event.target.apply_knockback(event.origin, event.distance, event.duration, event.mass_factor_max)
			CombatInteraction.record_combat_effect(event.target, event.interaction)
	_knockbacks.clear()
