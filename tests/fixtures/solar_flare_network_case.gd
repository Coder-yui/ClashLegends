extends RefCounted
var started := false
var target: Unit
var marked := false
var consumed := false
var replica_only := true
var dealt := false
var cues: Array[String] = []
var connected := false
var structure_marked := false
var structure_consumed := false
func poll(main: Node2D) -> void:
	if not connected and main._audio_manager != null:
		connected = true
		main._audio_manager.cue_played.connect(func(card, cue, _pos):
			if card == "solar_flare": cues.append(String(cue)))
	if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 12 and not started:
		started = true
		target = main._spawn_unit(UnitSpawnRequest.new(1, "anivia", Vector2(660, 700), {"deploy_time_override": 0.0}))
		target.can_attack = false
		target.root(12.0)
		main.runtime._cast_spell(0, "solar_flare", target.position, true, 0)
		var tower: Tower = main.world.towers_snapshot()[2]
		main.runtime._cast_spell(1-tower.team, "solar_flare", tower.position, true, 0)
	if main.runtime._match_started:
		var tower: Tower = main.world.towers_snapshot()[2]
		structure_marked = structure_marked or tower.sunlight_visual() > 0
		structure_consumed = structure_consumed or (structure_marked and tower.sunlight_visual() == 0 and tower.hp == tower.max_hp - 40)
		if main.runtime.mode == "client": replica_only = replica_only and tower.sunlight_marks.remaining(&"sunlight") == 0
	var spells: SpellSystem = main.get("_spell_system")
	if main.runtime.mode == "client":
		replica_only = replica_only and spells.solar_casts.is_empty()
		for unit in main.world.replica_units_snapshot().values():
			if unit.card_id == "anivia":
				marked = marked or unit.sunlight_visual() > 0
				consumed = consumed or (marked and unit.sunlight_visual() == 0 and unit.hp == float(CardDB.get_unit_stats("anivia").hp) - 110.0)
	elif is_instance_valid(target):
		marked = marked or target.sunlight_visual() > 0
		if marked and not dealt and main.runtime._sim_tick_id >= 60:
			dealt = true
			target.take_damage(10)
			main.world.towers_snapshot()[2].take_damage(10)
		consumed = consumed or (dealt and target.hp == target.max_hp - 110 and target.sunlight_visual() == 0)
func result() -> Dictionary:
	return {"passed": marked and consumed and replica_only and structure_marked and structure_consumed, "structure_marked": structure_marked, "structure_consumed": structure_consumed, "marked": marked, "consumed": consumed, "replica_only": replica_only, "cues": cues}
