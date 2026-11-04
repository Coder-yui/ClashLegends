extends RefCounted
var started := false
var seen := false
var haste := false
var expired := false
var replica_only := true
var cues: Array[String] = []
var connected := false
var cast_tick := -1
var birth_delay := -1
var immediate_action := true
var client := false
func poll(main: Node2D) -> void:
	client = main.runtime.mode == "client"
	if not connected and main._audio_manager != null:
		connected = true
		main._audio_manager.cue_played.connect(func(card, cue, _pos):
			if card in ["airdrop_bear", "tibbers"]: cues.append(String(cue)))
	if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 12 and not started:
		started = true
		cast_tick = main.get_authoritative_server_tick()
		main.runtime._cast_spell(0, "airdrop_bear", Vector2(660, 920), true, 0)
	var units: Dictionary = main.world.replica_units_snapshot() if main.runtime.mode == "client" else main.world.authoritative_units_snapshot()
	for unit in units.values():
		if not is_instance_valid(unit) or unit.card_id != "tibbers": continue
		if main.runtime.mode == "server" and birth_delay < 0:
			birth_delay = main.get_authoritative_server_tick() - cast_tick
			immediate_action = unit._deploy_timer == 0.0
		seen = seen or unit.burning_aura
		haste = haste or unit.get_active_attack_speed_multiplier_visual() > 1.49
		expired = expired or (haste and unit.burning_aura and unit.get_active_attack_speed_multiplier_visual() < 1.01)
		if main.runtime.mode == "server":
			unit.can_attack = false
			unit.root(10.0)
	if main.runtime.mode == "client":
		replica_only = replica_only and main._spell_system.bear_casts.is_empty() and main._spell_system.bear_auras.is_empty()
func result() -> Dictionary:
	return {"passed": seen and haste and expired and replica_only and (not client or cues.count("spell:enraged") == 1) and immediate_action and (cast_tick < 0 or birth_delay == 30), "birth_delay_ticks": birth_delay, "immediate_action": immediate_action, "aura_seen": seen, "haste_seen": haste, "haste_expired_aura_remains": expired, "replica_only": replica_only, "cues": cues}
