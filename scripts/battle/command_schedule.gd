class_name CommandSchedule
extends RefCounted
## 命令与施法排程的唯一状态所有者。入队资格/费用由 Main 校验，排程不读取 Main。
var _card_commands: Array[Dictionary] = []
var _skill_commands: Array[Dictionary] = []
var _pre_deployments: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _next_pre_deploy_id := 1
var impact: Callable
var cast_end: Callable

func take_card_commands(tick: int) -> Array[Dictionary]:
	return _take_due(_card_commands, tick)

func take_skill_commands(tick: int) -> Array[Dictionary]:
	return _take_due(_skill_commands, tick)

func _take_due(queue: Array[Dictionary], tick: int) -> Array[Dictionary]:
	var ready: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for entry in queue:
		if int(entry.execute_tick) <= tick:
			ready.append(entry)
		else:
			waiting.append(entry)
	queue.assign(waiting)
	return ready

func take_pre_deployments(dt: float) -> Array[Dictionary]:
	var ready: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for entry in _pre_deployments:
		entry.time_left = maxf(float(entry.get("time_left", 0.0)) - dt, 0.0)
		if float(entry.time_left) <= 0.001:
			ready.append(entry)
		else:
			waiting.append(entry)
	_pre_deployments.assign(waiting)
	return ready

func tick_impacts(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	for pending in _impacts:
		var reference: WeakRef = pending.get("source_ref")
		var source = reference.get_ref() if reference != null else null
		var independent := (pending.skill as Dictionary).has("independent_result")
		var unit := source as Unit
		if not independent:
			if not is_instance_valid(unit) or unit.hp <= 0.0:
				continue
			if unit.is_frozen() or int(pending.get("cast_serial", unit.active_skill_cast_serial)) <= unit.cancelled_skill_cast_serial:
				continue
		pending.time_left = maxf(0.0, float(pending.time_left) - dt)
		if float(pending.time_left) > 0.001:
			waiting.append(pending)
			continue
		if StringName(pending.get("phase", &"impact")) == &"cast_end":
			cast_end.call(unit, pending.skill)
		else:
			impact.call(unit, pending.skill)
	_impacts = waiting

func cancel_skill(ability_id: int, refund: bool) -> void:
	var waiting: Array[Dictionary] = []
	for pending in _skill_commands:
		if int(pending.ability_id) == ability_id:
			settle_skill(pending, refund)
		else:
			waiting.append(pending)
	_skill_commands = waiting

func settle_skill(pending: Dictionary, refund: bool) -> void:
	var payment = pending.get("payment")
	if payment is CommandPayment:
		payment.settle(refund)

## 终局/清场经济关闭，未执行收据作废；不再向已结束对局退费。

func clear() -> void:
	for pending in _skill_commands:
		settle_skill(pending, false)
	_card_commands.clear()
	_skill_commands.clear()
	_pre_deployments.clear()
	_impacts.clear()

## 低频检查导出隔离副本；绘制逐项读取，不在每 Tick 复制整个队列。
func inspect_cards() -> Array[Dictionary]:
	return _card_commands.duplicate(true)

func inspect_skills() -> Array[Dictionary]:
	return _skill_commands.duplicate(true)

func inspect_deployments() -> Array[Dictionary]:
	return _pre_deployments.duplicate(true)

func inspect_impacts() -> Array[Dictionary]:
	return _impacts.duplicate(true)

func enqueue_card(team: int, card_id: String, pos: Vector2, execute_tick: int) -> void:
	_card_commands.append({"team": team, "card_id": card_id, "pos": pos, "execute_tick": execute_tick})

func enqueue_skill(ability_id: int, team: int, execute_tick: int, payment: CommandPayment = null, requester_peer_id: int = 0) -> bool:
	if has_pending_skill(ability_id): return false
	_skill_commands.append({"ability_id": ability_id, "team": team, "execute_tick": execute_tick, "payment": payment, "requester_peer_id": requester_peer_id})
	return true

func has_pending_skill(ability_id: int) -> bool:
	for command in _skill_commands:
		if int(command.ability_id) == ability_id: return true
	return false

func enqueue_deployment(team: int, card_id: String, pos: Vector2, time_left: float, active_slot: int = -1, id: int = -1, duration: float = -1.0) -> void:
	_pre_deployments.append({"team": team, "card_id": card_id, "pos": pos, "time_left": time_left,
		"active_slot": active_slot, "id": id, "duration": time_left if duration < 0.0 else duration})

func allocate_deployment_id() -> int:
	var id := _next_pre_deploy_id
	_next_pre_deploy_id += 1
	return id

func enqueue_impact(source: Unit, skill: Dictionary, time_left: float, phase: StringName = &"impact", cast_serial: int = -1) -> void:
	_impacts.append({"source_ref": weakref(source) if is_instance_valid(source) else null, "skill": skill.duplicate(true), "time_left": time_left,
		"phase": phase, "cast_serial": source.active_skill_cast_serial if cast_serial < 0 and is_instance_valid(source) else cast_serial})

func clear_impacts() -> void:
	_impacts.clear()

func clear_cards() -> void:
	_card_commands.clear()

func clear_deployments() -> void:
	_pre_deployments.clear()

func cancel_last_card() -> void:
	_card_commands.pop_back()

func remove_deployment(id: int) -> void:
	if id < 0: return
	_pre_deployments = _pre_deployments.filter(func(entry): return int(entry.get("id", -1)) != id)

func tick_deployment_visuals(dt: float) -> void:
	take_pre_deployments(dt)

func draw_deployments(draw: Callable) -> void:
	for entry in _pre_deployments:
		var view := entry.duplicate()
		view.make_read_only()
		draw.call(view)

func schedule_cast(source: Unit, skill: Dictionary, impact_delay: float, displacement_order: Array) -> void:
	skill = skill.duplicate(true)
	skill["cast_forward"] = source.active_skill_cast_facing if not source.active_skill_cast_facing.is_zero_approx() else source.get_visual_facing_direction()
	skill["displacement_order"] = displacement_order
	skill["cast_hit_state"] = ActiveSkillEffectSystem.CastHitState.new()
	var hit_damages = skill.get("prepared_hit_damages", [])
	var hit_delays = skill.get("prepared_hit_delays", [])
	if hit_damages is Array and hit_delays is Array and not (hit_damages as Array).is_empty():
		var hit_count := mini((hit_damages as Array).size(), (hit_delays as Array).size())
		for hit_index in hit_count:
			var hit_skill := skill.duplicate(true)
			hit_skill.displacement_order[2] = hit_index
			hit_skill.erase("prepared_hit_damages")
			hit_skill.erase("prepared_hit_delays")
			hit_skill["hit_audio_phase"] = "first" if hit_index == 0 else ("last" if hit_index == hit_count - 1 else "middle")
			hit_skill["damage"] = maxf(float((hit_damages as Array)[hit_index]), 0.0)
			_queue_single_active_skill_impact(source, hit_skill, maxf(float((hit_delays as Array)[hit_index]), 0.0))
	else:
		_queue_single_active_skill_impact(source, skill, impact_delay)
	var cast_end_heal := maxf(float(skill.get("cast_end_heal", 0.0)), 0.0)
	if cast_end_heal > 0.0:
		enqueue_impact(source, {"cast_end_heal": cast_end_heal, "cast_end_heal_requires_hit": bool(skill.get("cast_end_heal_requires_hit", false)), "cast_hit_state": skill.cast_hit_state}, maxf(float(skill.get("cast_duration", 0.0)), 0.0), &"cast_end", source.active_skill_cast_serial)

func _queue_single_active_skill_impact(source: Unit, skill: Dictionary, impact_delay: float) -> void:
	if impact_delay <= 0.0:
		impact.call(source, skill)
		return
	enqueue_impact(source, skill, impact_delay, &"impact", source.active_skill_cast_serial)
