extends RefCounted
var started := false
var cast := false
var removed := false
var source: Unit
var slow_seen := false
var attack_slow_seen := false
var expanded_seen := false
var removed_seen := false
func poll(main: Node2D) -> void:
	var server: bool = main.runtime.mode == "server"
	if server and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0, "pillar_of_ice", Vector2(60, 1100), {"deploy_time_override": 0.0}))
			for pos in [Vector2(120, 1100), Vector2(240, 1100)]:
				var enemy: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "garen", pos, {"deploy_time_override": 0.0}))
				enemy.move_speed = 0.0
				enemy.can_attack = false
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 25 and not cast:
			cast = true
			main.preview_active_skill(source, CardDB.active_skills_for("pillar_of_ice")[0])
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 70 and not removed:
			removed = true
			source.take_damage(10000)
	var units: Array = main.world.authoritative_units_snapshot().values() if server else main.world.replica_units_snapshot().values()
	for unit in units:
		if not is_instance_valid(unit) or unit.card_id != "garen" or unit.team != 1: continue
		if unit.position.distance_to(Vector2(120, 1100)) < 35:
			slow_seen = slow_seen or unit.movement_slow_visual()
			attack_slow_seen = attack_slow_seen or unit.attack_speed_slow_visual()
			removed_seen = removed_seen or (slow_seen and not unit.movement_slow_visual() and not unit.attack_speed_slow_visual())
		if unit.position.distance_to(Vector2(240, 1100)) < 35:
			expanded_seen = expanded_seen or unit.movement_slow_visual()
func result() -> Dictionary:
	return {"passed": slow_seen and attack_slow_seen and expanded_seen and removed_seen, "slow_seen": slow_seen, "attack_slow_seen": attack_slow_seen, "expanded_seen": expanded_seen, "removed_seen": removed_seen}
