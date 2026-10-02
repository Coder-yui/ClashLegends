class_name TeamAttackBoostSystem
extends RefCounted
## Fixed-tick, permanent single-recipient boost. It is authority-only in network games.

var _controller: Node2D
var flights: Array[Dictionary] = []
var forging: Dictionary = {}

func _init(controller: Node2D) -> void:
	_controller = controller

func tick(dt: float) -> void:
	if _controller.is_net_client(): return
	_tick_flights(dt)
	var combatants := _controller.get_tree().get_nodes_in_group("combatants")
	for source in combatants:
		if not source is Unit or source.hp <= 0.0 or source.team_attack_boost_interval <= 0.0: continue
		if source._deploy_timer > 0.0: continue
		if not source.team_attack_boost_started:
			source.team_attack_boost_started = true
			source.team_attack_boost_clock = source.team_attack_boost_first_delay
			continue
		source.team_attack_boost_clock = maxf(0.0, source.team_attack_boost_clock - dt)
		var identity := source.get_instance_id()
		if forging.has(identity):
			if _blocked(source) or source.active_skill_cast_timer > 0.0:
				interrupt(source)
				continue
			var state: Dictionary = forging[identity]
			state.elapsed += dt
			source._visual_action_time_left = maxf(0.0, float(state.duration) - float(state.elapsed))
			if not state.released and float(state.elapsed) + 0.000001 >= float(state.release):
				state.released = true
				var target = state.target.get_ref()
				if not is_instance_valid(target) or not _eligible(target, source.team) or target.team_attack_boost_multiplier > 1.0:
					interrupt(source)
					continue
				_launch(source, target)
				_controller.present_skill_projectile_hit(PresentationConfig.attack_source(source), "forge", source.global_position, "strike")
			if float(state.elapsed) + 0.000001 >= float(state.duration): _finish(source)
			continue
		if source.team_attack_boost_clock > 0.000001 or _blocked(source): continue
		if source._attacking or source.attack_timeline.windup > 0.0 or source.attack_timeline.recovery > 0.0 or source.active_skill_cast_timer > 0.0 or source.is_form_transitioning(): continue
		var target := _choose_target(source, combatants)
		if target == null: continue
		var card := CardDB.get_card(source.card_id)
		var duration := float(card.get("team_attack_boost_forge_duration", 1.0))
		forging[identity] = {"active": true, "elapsed": 0.0, "released": false, "target": weakref(target), "duration": duration, "release": float(card.get("team_attack_boost_release_time", 0.65))}
		source.team_attack_boost_clock = source.team_attack_boost_interval
		source.team_attack_boost_forging = true
		source._move_intent = Vector2.ZERO
		source.play_visual_action(&"ornn_forge", duration)
		source.visual_action_clock_managed = true
	for identity in forging.keys():
		var source = instance_from_id(identity)
		if not is_instance_valid(source): forging.erase(identity)
		elif source.hp <= 0.0: interrupt(source)

func _blocked(source: Unit) -> bool:
	return source.is_frozen() or source.is_stunned() or CombatInteraction.in_stasis(source) or source._knockback_timer > 0.0 or source.knockback.recovery_pending

func _choose_target(source: Unit, combatants: Array) -> Unit:
	var candidates: Array[Dictionary] = []
	for target in combatants:
		if not target is Unit or not is_instance_valid(target) or target.hp <= 0.0:
			continue
		if not _eligible(target, source.team) or target.team_attack_boost_multiplier > 1.0 or _reserved(target):
			continue
		var definition := CardDB.get_card(target.card_id)
		candidates.append({
			"unit": target,
			"cost": int(definition.get("cost", 0)),
			"distance": source.global_position.distance_squared_to(target.global_position),
			"identity": target.combat_source_id,
		})
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.cost) != int(b.cost): return int(a.cost) > int(b.cost)
		if not is_equal_approx(float(a.distance), float(b.distance)): return float(a.distance) < float(b.distance)
		return int(a.identity) < int(b.identity)
	)
	return candidates[0].unit

func _grant_one(source: Unit, combatants: Array) -> void:
	var target := _choose_target(source, combatants)
	if target != null: _launch(source, target)

func _launch(source: Unit, target: Unit) -> void:
	var card := CardDB.get_card(source.card_id)
	var duration := clampf(0.35 + source.global_position.distance_to(target.global_position) / 500.0, 0.35, 2.5)
	flights.append({"target": weakref(target), "remaining": duration, "source": PresentationConfig.attack_source(source), "multiplier": maxf(float(card.get("team_attack_boost_multiplier", 1.2)), 1.0)})
	_controller.present_team_attack_boost(source, target, duration)

func _reserved(target: Unit) -> bool:
	for state in forging.values():
		if not state.released and state.target.get_ref() == target: return true
	for flight in flights:
		if flight.target.get_ref() == target: return true
	return false

func _tick_flights(dt: float) -> void:
	for index in range(flights.size() - 1, -1, -1):
		var flight := flights[index]
		var target = flight.target.get_ref()
		if not is_instance_valid(target) or not _eligible(target, int(flight.source.team)):
			flights.remove_at(index)
			continue
		flight.remaining -= dt
		if float(flight.remaining) > 0.000001: continue
		if _eligible(target, int(flight.source.team)) and target.team_attack_boost_multiplier <= 1.0:
			target.team_attack_boost_multiplier = float(flight.multiplier)
			target.queue_redraw()
			_controller.present_skill_projectile_hit(flight.source, "forge", target.global_position, "arrive")
		flights.remove_at(index)

func clear() -> void:
	for identity in forging.keys():
		var unit = instance_from_id(identity)
		if is_instance_valid(unit): interrupt(unit)
	forging.clear()
	flights.clear()

func _eligible(target: Unit, team: int) -> bool:
	return CombatInteraction.allows_allied_target(target, team) and not target.is_building and target.card_id != "anivia_egg"

func _finish(source: Unit) -> void:
	forging.erase(source.get_instance_id())
	source.team_attack_boost_forging = false
	if source.get_visual_action_name() == &"ornn_forge":
		source.visual_action_clock_managed = false
		source._visual_action_time_left = 0.0
		source._visual_action_name = &""

func interrupt(source: Unit) -> void:
	if not forging.has(source.get_instance_id()): return
	_finish(source)
	_controller.notify_unit_audio_event(source, &"forge:cancel", source.global_position)

func invalidate_target_locks(target: Node2D) -> void:
	for index in range(flights.size()-1, -1, -1):
		var flight := flights[index]
		if flight.target.get_ref() == target and not _eligible(target, int(flight.source.team)):
			flights.remove_at(index)
