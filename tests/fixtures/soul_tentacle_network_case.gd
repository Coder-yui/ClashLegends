extends RefCounted
var started := false
var buff_started := false
var damaged := false
var buff_seen := false
var attack_seen := false
var protection_seen := false
var protection_ended := false
var source: Unit
var target: Unit
func poll(main: Node2D) -> void:
	if main.runtime.mode == "server" and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0, "soul_tentacle", Vector2(90,1000), {"deploy_time_override":0.0}))
			target = main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(90,880), {"deploy_time_override":0.0}))
			target.can_attack = false
			target.root(12.0)
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 40 and not buff_started:
			buff_started = true
			main.preview_active_skill(source, CardDB.active_skills_for("soul_tentacle")[0])
	if main.runtime.mode == "client":
		for unit in main.world.replica_units_snapshot().values(): _observe(unit)
	else:
		if is_instance_valid(source): _observe(source)
		if is_instance_valid(target): _observe(target)
func _observe(unit: Unit) -> void:
	if unit.card_id == "soul_tentacle":
		attack_seen = attack_seen or unit.get_attack_visual_serial() > 0
		buff_seen = buff_seen or unit.get_active_buff_active_visual()
		protection_seen = protection_seen or unit.presentation_state().untargetable
		protection_ended = protection_ended or (protection_seen and not unit.presentation_state().untargetable)
	if unit.card_id == "target_dummy" and unit.team == 1:
		damaged = damaged or unit.hp <= unit.max_hp - 180.0
func result() -> Dictionary:
	return {"passed": damaged and buff_seen and attack_seen and protection_seen and protection_ended, "protection_seen":protection_seen,"protection_ended":protection_ended,"damaged":damaged,"buff_seen":buff_seen,"attack_seen":attack_seen}
