extends RefCounted
var started := false
var buff_started := false
var damaged := false
var buff_seen := false
var attack_seen := false
var buff_ended := false
var growth_seen := false
var growth_restored := false
var source: Unit
var target: Unit
func poll(main: Node2D) -> void:
	if main.runtime.mode == "server" and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 12 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0, "thorn_spitter", Vector2(90,1000), {"deploy_time_override":0.0}))
			target = main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(90,880), {"deploy_time_override":0.0}))
			target.can_attack = false
			target.root(12.0)
		if is_instance_valid(source) and main.runtime._sim_tick_id >= 40 and not buff_started:
			buff_started = true
			main.preview_active_skill(source, CardDB.active_skills_for("thorn_spitter")[0])
	if main.runtime.mode == "client":
		for unit in main.world.replica_units_snapshot().values(): _observe(unit)
	else:
		if is_instance_valid(source): _observe(source)
		if is_instance_valid(target): _observe(target)
func _observe(unit: Unit) -> void:
	if unit.card_id == "thorn_spitter":
		attack_seen = attack_seen or unit.get_attack_visual_serial() > 0
		growth_seen = growth_seen or (unit.max_hp == 1200.0 and is_equal_approx(unit.body_radius, 26.25) and is_equal_approx(unit.timed_growth_stats.y, 1.25))
		growth_restored = growth_restored or (growth_seen and unit.max_hp == 800.0 and is_equal_approx(unit.body_radius, 21.0) and unit.timed_growth_stats == Vector2(0,1))
		buff_seen = buff_seen or unit.get_active_buff_active_visual()
		buff_ended = buff_ended or (buff_seen and not unit.get_active_buff_active_visual())
	if unit.card_id == "target_dummy" and unit.team == 1:
		damaged = damaged or unit.hp <= unit.max_hp - 100.0
func result() -> Dictionary:
	return {"passed": damaged and buff_seen and attack_seen and buff_ended and growth_seen and growth_restored, "growth_seen": growth_seen, "growth_restored": growth_restored, "damaged": damaged, "buff_seen": buff_seen, "attack_seen": attack_seen, "buff_ended": buff_ended}
