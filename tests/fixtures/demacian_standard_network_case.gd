extends RefCounted
var started := false
var cast := false
var removed := false
var source: Unit
var haste_seen := false
var shield_seen := false
var slow_seen := false
var haste_removed := false
func poll(main: Node2D) -> void:
	var server: bool = main.runtime.mode == "server"
	if server and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0, "demacian_standard", Vector2(680, 1100), {"deploy_time_override": 0.0}))
			main._spawn_unit(UnitSpawnRequest.new(0, "target_dummy", Vector2(620, 1100), {"deploy_time_override": 0.0}))
			var enemy: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "garen", Vector2(680, 1020), {"deploy_time_override": 0.0}))
			enemy.move_speed = 0.0
			enemy.can_attack = false
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 25 and not cast:
			cast = true
			main.preview_active_skill(source, CardDB.active_skills_for("demacian_standard")[0])
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 70 and not removed:
			removed = true
			source.take_damage(10000)
	var units: Array = main.world.authoritative_units_snapshot().values() if server else main.world.replica_units_snapshot().values()
	for unit in units:
		if not is_instance_valid(unit) or unit.card_id not in ["target_dummy", "garen"]: continue
		if unit.team == 0 and unit.position.distance_to(Vector2(620, 1100)) < 35:
			haste_seen = haste_seen or unit.get_active_attack_speed_multiplier_visual() > 1.2
			shield_seen = shield_seen or unit.get_shield_ratio() > 0
			haste_removed = haste_removed or (haste_seen and unit.get_active_attack_speed_multiplier_visual() < 1.01)
		if unit.team == 1 and unit.position.distance_to(Vector2(680, 1020)) < 35:
			slow_seen = slow_seen or unit.movement_slow_visual()
func result() -> Dictionary:
	return {"passed": haste_seen and shield_seen and slow_seen and haste_removed,
		"haste_seen": haste_seen, "shield_seen": shield_seen, "slow_seen": slow_seen, "haste_removed": haste_removed}
