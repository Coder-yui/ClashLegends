extends RefCounted
var started := false
var target: Unit
var area_seen := false
var shield_seen := false
var ended := false
var replica_only := true
func poll(main: Node2D) -> void:
	if main.runtime.mode == "server" and main.runtime._match_started and main.runtime._sim_tick_id >= 12 and not started:
		started = true
		target = main._spawn_unit(UnitSpawnRequest.new(0, "anivia", Vector2(660, 850), {"deploy_time_override": 0.0}))
		target.can_attack = false
		target.root(12.0)
		main.runtime._cast_spell(0, "pool_of_reflection", Vector2(660, 850), true, 0)
	var spells: SpellSystem = main.get("_spell_system")
	if main.runtime.mode == "client":
		replica_only = replica_only and spells.pool_zones.is_empty()
		area_seen = area_seen or not spells.pool_effects.is_empty()
		for unit in main.world.replica_units_snapshot().values():
			if unit.card_id != "anivia" or unit.team != 0: continue
			shield_seen = shield_seen or (unit.pool_shield_visual() and unit.get_shield_health_ratio() > 0.0)
			ended = ended or (shield_seen and not unit.pool_shield_visual())
	elif is_instance_valid(target):
		area_seen = area_seen or not spells.pool_zones.is_empty()
		shield_seen = shield_seen or target.pool_shield_visual()
		ended = ended or (shield_seen and not target.pool_shield_visual())
func result() -> Dictionary:
	return {"passed": area_seen and shield_seen and ended and replica_only, "area": area_seen, "shield": shield_seen, "ended": ended, "replica_only": replica_only}
