extends RefCounted
var started := false
var damaged := false
var pulled := false
var crossed := false
var replica_only := true
var seen_effect := false
var target: Unit
const START := Vector2(620, 700)
const CENTER := Vector2(540, 700)

func poll(main: Node2D) -> void:
	var spells: SpellSystem = main.get("_spell_system")
	if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 12 and not started:
		started = true
		target = main._spawn_unit(UnitSpawnRequest.new(1, "anivia", START, {"deploy_time_override": 0.0}))
		target.can_attack = false
		target.root(12.0)
		main.runtime._cast_spell(0, "convergent_pulse", CENTER, true, 0)
	if main.runtime.mode == "client":
		replica_only = replica_only and spells.pulse_casts.is_empty()
		seen_effect = seen_effect or not spells.pulse_effects.is_empty()
		for unit in main.world.replica_units_snapshot().values():
			if unit.card_id == "anivia": _observe(unit)
	elif is_instance_valid(target):
		_observe(target)
		seen_effect = true # dedicated server deliberately has no presentation.

func _observe(unit: Unit) -> void:
	damaged = damaged or is_equal_approx(unit.hp, float(CardDB.get_unit_stats("anivia").hp) - 270.0)
	pulled = pulled or unit.position.x < START.x - 10.0
	crossed = crossed or unit.position.x < CENTER.x - 5.0

func result() -> Dictionary:
	return {"passed": damaged and pulled and crossed and replica_only and seen_effect, "damaged": damaged, "pulled": pulled, "crossed": crossed, "replica_only": replica_only, "seen_effect": seen_effect}
