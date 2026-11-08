extends RefCounted
var started := false
var triggered := false
var nests: Array[Unit] = []
var nest_seen := false
var empty_seen := false
var normal_seen := false
var angry_seen := false
var normal_deploy_seen := false
var angry_immediate_seen := false
func poll(main: Node2D) -> void:
	var server: bool = main.runtime.mode == "server"
	if server and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			for team in 2:
				nests.append(main._spawn_unit(UnitSpawnRequest.new(team, "queen_nest", Vector2(650, 1050 if team == 0 else 230), {"deploy_time_override": 0.0})))
		if main.runtime._sim_tick_id >= 30 and not triggered:
			triggered = true
			main.preview_active_skill(nests[0], CardDB.active_skills_for("queen_nest")[0])
			nests[1].take_damage(10000)
	var units: Array = main.world.authoritative_units_snapshot().values() if server else main.world.replica_units_snapshot().values()
	for unit in units:
		if not is_instance_valid(unit): continue
		if unit.card_id == "queen_nest":
			nest_seen = true
			empty_seen = empty_seen or unit.get_form_index() == 1
		if unit.card_id == "nest_reksai":
			normal_seen = true
			normal_deploy_seen = normal_deploy_seen or unit.get_visual_state_code() == 0
		if unit.card_id == "enraged_reksai":
			angry_seen = true
			angry_immediate_seen = angry_immediate_seen or unit.get_visual_state_code() != 0
func result() -> Dictionary:
	return {"passed": empty_seen and nest_seen and normal_seen and angry_seen and normal_deploy_seen and angry_immediate_seen,
		"empty_seen": empty_seen, "nest_seen": nest_seen, "normal_seen": normal_seen, "angry_seen": angry_seen,
		"normal_deploy_seen": normal_deploy_seen, "angry_immediate_seen": angry_immediate_seen}
