class_name TeamAttackBoostSystem
extends RefCounted
## Fixed-tick, permanent single-recipient boost. It is authority-only in network games.

var _controller: Node2D
var flights: Array[Dictionary] = []
const FORGE_LEAD_TIME := 3.6
var forging: Dictionary = {}

func _init(controller: Node2D) -> void:
	_controller = controller

func tick(dt: float) -> void:
	if _controller.is_net_client():
		return
	_tick_flights(dt)
	var combatants := _controller.get_tree().get_nodes_in_group("combatants")
	for source in combatants:
		if not source is Unit or not is_instance_valid(source) or source.hp <= 0.0:
			continue
		if source.team_attack_boost_interval <= 0.0 or source.team_attack_boost_first_delay <= 0.0:
			continue
		if source._deploy_timer > 0.0:
			continue
		if not source.team_attack_boost_started:
			source.team_attack_boost_started = true
			source.team_attack_boost_clock = source.team_attack_boost_first_delay
			continue
		var identity := source.get_instance_id()
		var state: Dictionary = forging.get(identity, {"active": false, "restart": false, "controlled": false})
		var controlled: bool = source.is_frozen() or source.control.stun_timer > 0.0 or CombatInteraction.in_stasis(source)
		if controlled:
			if not state.controlled:
				_controller.notify_unit_audio_event(source, &"forge:cancel", source.global_position)
			if state.active or source.team_attack_boost_clock <= FORGE_LEAD_TIME:
				state.active = false
				state.restart = true
				source.team_attack_boost_clock = FORGE_LEAD_TIME
			else:
				source.team_attack_boost_clock = maxf(FORGE_LEAD_TIME, source.team_attack_boost_clock - dt)
			state.controlled = true
			forging[identity] = state
			continue
		state.controlled = false
		if state.restart:
			state.restart = false
			source.team_attack_boost_clock = FORGE_LEAD_TIME
		else:
			source.team_attack_boost_clock -= dt
		if not state.active and source.team_attack_boost_clock <= FORGE_LEAD_TIME + 0.000001:
			state.active = true
			source.team_attack_boost_clock = FORGE_LEAD_TIME
			_controller.notify_unit_audio_event(source, &"forge:pulse", source.global_position)
		elif state.active and source.team_attack_boost_clock <= 0.000001:
			_grant_one(source, combatants)
			source.team_attack_boost_clock = source.team_attack_boost_interval
			state.active = false
		forging[identity] = state
	for identity in forging.keys():
		var unit = instance_from_id(identity)
		if not is_instance_valid(unit) or unit.hp <= 0.0: forging.erase(identity)

func _grant_one(source: Unit, combatants: Array) -> void:
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
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.cost) != int(b.cost): return int(a.cost) > int(b.cost)
		if not is_equal_approx(float(a.distance), float(b.distance)): return float(a.distance) < float(b.distance)
		return int(a.identity) < int(b.identity)
	)
	var target: Unit = candidates[0].unit
	var card := CardDB.get_card(source.card_id)
	var duration := clampf(0.35 + source.global_position.distance_to(target.global_position) / 500.0, 0.35, 2.5)
	flights.append({"target": weakref(target), "remaining": duration, "source": PresentationConfig.attack_source(source), "multiplier": maxf(float(card.get("team_attack_boost_multiplier", 1.2)), 1.0)})
	_controller.present_team_attack_boost(source, target, duration)

func _reserved(target: Unit) -> bool:
	for flight in flights:
		if flight.target.get_ref() == target: return true
	return false

func _tick_flights(dt: float) -> void:
	for index in range(flights.size() - 1, -1, -1):
		var flight := flights[index]
		var target = flight.target.get_ref()
		if not is_instance_valid(target) or target.hp <= 0.0:
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
	for identity in forging:
		var unit = instance_from_id(identity)
		if is_instance_valid(unit): _controller.notify_unit_audio_event(unit, &"forge:cancel", unit.global_position)
	forging.clear()
	flights.clear()

func _eligible(target: Unit, team: int) -> bool:
	return CombatInteraction.allows_allied_target(target, team) and not target.is_building and target.card_id != "anivia_egg"

func interrupt(source: Unit) -> void:
	if source.team_attack_boost_interval <= 0.0: return
	var identity := source.get_instance_id()
	var state: Dictionary = forging.get(identity, {})
	if bool(state.get("active", false)):
		state.active = false
		state.restart = true
		source.team_attack_boost_clock = FORGE_LEAD_TIME
		forging[identity] = state
	_controller.notify_unit_audio_event(source, &"forge:cancel", source.global_position)
