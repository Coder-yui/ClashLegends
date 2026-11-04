extends RefCounted
var started := false
var dashed := false
var source: Unit
var target: Unit
var empty_seen := false
var partial_seen := false
var full_after_reload := false
var dash_seen := false
var damage_seen := false
var pellet_seen := false
var reload_seen := false
var previous_target_hp := -1.0
func poll(main: Node2D) -> void:
	if main.runtime.mode == "server" and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0, "graves", Vector2(90, 1000), {"deploy_time_override": 0.0}))
			target = main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(90, 890), {"deploy_time_override": 0.0}))
			target.hp = 10000
			target.max_hp = 10000
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 96 and not dashed:
			dashed = true
			main.preview_active_skill(source, CardDB.active_skills_for("graves")[0])
	var units: Array = main.world.replica_units_snapshot().values() if main.runtime.mode == "client" else main.world.authoritative_units_snapshot().values()
	for unit in units:
		if not is_instance_valid(unit): continue
		if unit.card_id == "graves":
			var state: Vector3 = unit.magazine_visual_state()
			empty_seen = empty_seen or state.x == 0
			partial_seen = partial_seen or state.x == 1
			reload_seen = reload_seen or state.y > 0.0
			full_after_reload = full_after_reload or (reload_seen and state.x == 2)
			dash_seen = dash_seen or (unit.get_visual_action_name() == &"active" and unit.get_visual_action_time_left() > 0.0)
		if unit.card_id == "target_dummy" and unit.team == 1:
			damage_seen = damage_seen or (previous_target_hp >= 0.0 and unit.hp < previous_target_hp)
			previous_target_hp = unit.hp
	for shot in main._projectile_system.visible_view().values():
		if String(shot.get("visual", "")) == "graves_bullet": pellet_seen = true
func result() -> Dictionary:
	return {"passed": empty_seen and partial_seen and reload_seen and full_after_reload and dash_seen and damage_seen and pellet_seen,
		"empty_seen": empty_seen, "partial_seen": partial_seen, "reload_seen": reload_seen, "full_after_reload": full_after_reload, "dash_seen": dash_seen, "damage_seen": damage_seen, "pellet_seen": pellet_seen}
