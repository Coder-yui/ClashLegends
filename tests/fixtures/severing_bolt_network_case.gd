extends RefCounted
## 可选三进程落雷检查，生产逻辑不读取环境开关。
var started := false
var target: Unit
var warning_seen := false
var impact_seen := false
var damaged := false
var replica_only := true
var cues: Array[String] = []
var connected := false
func poll(main: Node2D) -> void:
	if not connected and main._audio_manager != null:
		connected = true
		main._audio_manager.cue_played.connect(func(card, cue, _pos):
			if card == "severing_bolt": cues.append(String(cue)))
	if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 12 and not started:
		started = true
		target = main._spawn_unit(UnitSpawnRequest.new(1, "anivia", Vector2(660, 700), {"deploy_time_override": 0.0}))
		target.can_attack = false
		target.root(12.0)
		main.runtime._cast_spell(0, "severing_bolt", Vector2(660, 700), true, 0)
	var spells: SpellSystem = main.get("_spell_system")
	if main.runtime.mode == "client":
		replica_only = replica_only and spells.bolt_casts.is_empty()
		for effect in spells.bolt_effects:
			if effect.kind == "severing_bolt": warning_seen = true
			if effect.kind == "severing_bolt_hit": impact_seen = true
		for unit in main.world.replica_units_snapshot().values():
			if unit.card_id == "anivia": damaged = damaged or unit.hp == float(CardDB.get_unit_stats("anivia").hp) - 420.0
	elif is_instance_valid(target):
		warning_seen = warning_seen or not spells.bolt_casts.is_empty()
		damaged = damaged or target.hp == target.max_hp - 420.0
		impact_seen = impact_seen or damaged
func result() -> Dictionary:
	return {"passed": warning_seen and impact_seen and damaged and replica_only, "warning": warning_seen, "impact": impact_seen, "damage": damaged, "replica_only": replica_only, "cues": cues}
