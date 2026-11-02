extends RefCounted
var started := false
var target_spawned := false
var target_removed := false
var repaired := false
var source: Unit
var target: Unit
var dormant_seen := false
var active_seen := false
var dormant_again := false
var attack_seen := false
var repair_seen := false
var previous_hp := INF
func poll(main: Node2D) -> void:
	if main.runtime.mode == "server" and main.runtime._match_started:
		var tick: int = main.runtime._sim_tick_id
		if tick >= 12 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0, "evolution_turret", Vector2(680, 1210), {"deploy_time_override": 0.0, "position_resolved": true}))
		if tick >= 40 and not target_spawned:
			target_spawned = true
			target = main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(680, 1100), {"deploy_time_override": 0.0, "position_resolved": true}))
			target.can_attack = false
			target.hp = 5000
			target.max_hp = 5000
		if tick >= 85 and not target_removed:
			target_removed = true
			if is_instance_valid(target): target._die()
		if tick >= 105 and not repaired:
			repaired = true
			if is_instance_valid(source): main.preview_active_skill(source, CardDB.active_skills_for("evolution_turret")[0])
	if main.runtime.mode == "client":
		for unit in main.world.replica_units_snapshot().values(): _observe(unit)
	elif is_instance_valid(source): _observe(source)
func _observe(unit: Unit) -> void:
	if unit.card_id != "evolution_turret": return
	dormant_seen = dormant_seen or unit.dormant
	active_seen = active_seen or (dormant_seen and not unit.dormant)
	dormant_again = dormant_again or (active_seen and unit.dormant)
	attack_seen = attack_seen or unit.get_attack_visual_serial() > 0
	repair_seen = repair_seen or unit.hp > previous_hp + 100.0
	previous_hp = unit.hp
func result() -> Dictionary:
	return {"passed": dormant_seen and active_seen and dormant_again and attack_seen and repair_seen, "dormant": dormant_seen, "active": active_seen, "dormant_again": dormant_again, "attack": attack_seen, "repair": repair_seen}
