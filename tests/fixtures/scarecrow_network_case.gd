extends RefCounted
var started := false
var transformed := false
var targets_moved := false
var source: Unit
var targets: Array[Unit] = []
var multiple_seen := false
var heal_seen := false
var form_seen := false
var movement_seen := false
var damaged_seen := false
var preserved := true
var form_origin := Vector2.INF
var initial_position := Vector2(90, 850)
func poll(main: Node2D) -> void:
	if main.runtime.mode == "server" and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0, "scarecrow", initial_position, {"deploy_time_override": 0.0}))
			source.hp = 600
			for card in ["target_dummy", "aurelionsol"]:
				var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1, card, Vector2(180, 850 - targets.size() * 100), {"deploy_time_override": 0.0}))
				target.can_attack = false
				target.root(20.0)
				targets.append(target)
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 65 and not transformed:
			transformed = true
			var old_hp := source.hp
			main.preview_active_skill(source, CardDB.active_skills_for("scarecrow")[0])
			preserved = source.hp == old_hp
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 80 and not targets_moved:
			targets_moved = true
			# 强制追击窗口，避免集成场景其他敌人停在180射程内掩盖移动。
			source.attack_range = 1.0
			source.sight_range = 2000.0
			for target in targets:
				if is_instance_valid(target): target.global_position = Vector2(300, 750)
	var units: Array = main.world.replica_units_snapshot().values() if main.runtime.mode == "client" else main.world.authoritative_units_snapshot().values()
	for unit in units:
		if not is_instance_valid(unit): continue
		if unit.card_id == "scarecrow":
			multiple_seen = multiple_seen or unit.continuous_targets_snapshot().size() >= 2
			heal_seen = heal_seen or (unit.form_index == 0 and unit.hp > 620 and unit.hp < 1200)
			form_seen = form_seen or (unit.form_index == 1 and not unit.is_building and unit.lifespan == 0)
			if unit.form_index == 1:
				if not form_origin.is_finite(): form_origin = unit.global_position
				movement_seen = movement_seen or unit.global_position.distance_to(form_origin) > 5.0
		if unit.card_id == "target_dummy" and unit.team == 1: damaged_seen = damaged_seen or unit.hp < unit.max_hp
func result() -> Dictionary:
	return {"passed": multiple_seen and heal_seen and form_seen and movement_seen and damaged_seen and preserved,
		"multiple_seen": multiple_seen, "heal_seen": heal_seen, "form_seen": form_seen, "movement_seen": movement_seen, "damaged_seen": damaged_seen, "preserved": preserved}
