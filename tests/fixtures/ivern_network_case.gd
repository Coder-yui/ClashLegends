extends RefCounted
var started := false
var cast := false
var source: Unit
var daisy_seen := false
var stun_seen := false
var bolt_seen := false
var third_seen := false
var is_server := false
func poll(main: Node2D) -> void:
	is_server = main.runtime.mode == "server"
	if is_server and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			# 避开通用状态场景(80,900)的超级兵，确保第三击命中本场景木桩。
			source = main._spawn_unit(UnitSpawnRequest.new(0, "ivern", Vector2(680, 1100), {"deploy_time_override": 0.0}))
			source.move_speed = 0.0
			var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(680, 1010), {"deploy_time_override": 0.0}))
			target.hp = 10000
			target.max_hp = 10000
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 25 and not cast:
			cast = true
			main.preview_active_skill(source, CardDB.active_skills_for("ivern")[0])
	var units: Array = main.world.replica_units_snapshot().values() if not is_server else main.world.authoritative_units_snapshot().values()
	for unit in units:
		if not is_instance_valid(unit): continue
		if unit.card_id == "daisy":
			daisy_seen = daisy_seen or (unit.team == 0 and unit.max_hp == 1100.0)
			third_seen = third_seen or unit.get_attack_visual_serial() >= 3
		if unit.card_id == "target_dummy" and unit.team == 1:
			stun_seen = stun_seen or unit.stun_visual()
	for shot in main._projectile_system.visible_view().values():
		bolt_seen = bolt_seen or String(shot.get("visual", "")) == "ivern_bolt"
func result() -> Dictionary:
	return {"passed": daisy_seen and stun_seen and bolt_seen and third_seen,
		"daisy_seen": daisy_seen, "stun_seen": stun_seen, "bolt_seen": bolt_seen, "third_seen": third_seen}
