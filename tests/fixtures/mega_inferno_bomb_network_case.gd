extends RefCounted
var started := false
var target: Unit
var marked := false
var persisted := false
var replica_only := true
var cues: Array[String] = []
var connected := false
func poll(main: Node2D) -> void:
	if not connected and main._audio_manager != null:
		connected = true
		main._audio_manager.cue_played.connect(func(card, cue, _pos):
			if card == "mega_inferno_bomb": cues.append(String(cue)))
	if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 12 and not started:
		started = true
		target = main._spawn_unit(UnitSpawnRequest.new(1, "garen", Vector2(660, 700), {"deploy_time_override": 0.0}))
		target.can_attack = false
		target.root(20.0)
		target.add_shield(1000, 20)
		main.runtime._cast_spell(0, "mega_inferno_bomb", target.position, true, 0)
	if main.runtime.mode == "client":
		replica_only = replica_only and main._spell_system.spell_flights.is_empty()
		for unit in main.world.replica_units_snapshot().values():
			if unit.card_id == "garen" and unit.position.x > 600:
				marked = marked or (unit.grievous_wounds_visual() and unit.shield_hp == 0)
				persisted = persisted or (marked and main.get_authoritative_server_tick() >= 150 and unit.grievous_wounds_visual())
				replica_only = replica_only and unit.buffs.remaining(&"grievous_wounds") == 0
	elif is_instance_valid(target):
		marked = marked or (target.grievous_wounds_visual() and target.shield_hp == 0 and target.hp == target.max_hp - 600)
		persisted = persisted or (marked and main.get_authoritative_server_tick() >= 150 and target.grievous_wounds_visual())
func result() -> Dictionary:
	return {"passed": marked and persisted and replica_only, "marked":marked, "persisted":persisted, "replica_only":replica_only, "cues":cues}
