extends RefCounted
var started := false
var damaged := false
var pulled := false
var expired := false
var replica_only := true
var seen_effect := false
var target: Unit
var listening := false
var hit_audio := false
var execute_audio := false
var forced_execute := false
const START := Vector2(620, 700)
const CENTER := Vector2(540, 700)

func poll(main: Node2D) -> void:
	var spells: SpellSystem = main._spell_system
	if not listening:
		listening = true
		if main.runtime.mode == "server":
			main.runtime.event.connect(func(kind, payload):
				if kind == "card_event": _audio(payload.get("card_id", ""), payload.get("cue", "")))
		else:
			main._audio_manager.cue_played.connect(func(card, cue, _pos): _audio(card, cue))
	if main.runtime.mode == "server" and is_instance_valid(target) and main.runtime._sim_tick_id >= 75 and not forced_execute:
		forced_execute = true
		target.hp = 1

	if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 12 and not started:
		started = true
		target = main._spawn_unit(UnitSpawnRequest.new(1, "anivia", START, {"deploy_time_override": 0.0}))
		target.can_attack = false
		target.root(12.0)
		main.runtime._cast_spell(0, "stellar_convergence", CENTER, true, 0)
	if main.runtime.mode == "client":
		replica_only = replica_only and spells.stellar_zones.is_empty()
		seen_effect = seen_effect or not spells.stellar_effects.is_empty()
		for unit in main.world.replica_units_snapshot().values():
			if unit.card_id == "anivia": _observe(unit)
	elif is_instance_valid(target):
		_observe(target)
		seen_effect = true
		expired = expired or (main.runtime._sim_tick_id > 115 and spells.stellar_zones.is_empty())

func _observe(unit: Unit) -> void:
	damaged = damaged or unit.hp <= float(CardDB.get_unit_stats("anivia").hp) - 6.0
	pulled = pulled or unit.position.x < START.x - 20.0

func result() -> Dictionary:
	return {"passed": damaged and pulled and replica_only and seen_effect and hit_audio and execute_audio, "hit_audio": hit_audio, "execute_audio": execute_audio, "damaged": damaged, "pulled": pulled, "replica_only": replica_only, "seen_effect": seen_effect, "server_expired": expired}

func _audio(card: String, cue: String) -> void:
	if card != "stellar_convergence": return
	hit_audio = hit_audio or cue == "spell:hit"
	execute_audio = execute_audio or cue == "spell:execute"
