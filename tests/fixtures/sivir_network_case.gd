extends RefCounted
var source: Unit
var target: Unit
var started := false
var shield_cast := false
var hit_sent := false
var outbound_seen := false
var inbound_seen := false
var shield_seen := false
var heal_seen := false
var damage_seen := false
var single_projectile := true
var last_trace := -1
func poll(main: Node2D) -> void:
	if main.runtime.mode == "server" and main.runtime._match_started:
		var tick: int = main.runtime._sim_tick_id
		if tick >= 12 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0,"sivir",Vector2(70,1080),{"deploy_time_override":0.0}))
			source.hp = 100
			source.root(20)
			target = main._spawn_unit(UnitSpawnRequest.new(1,"target_dummy",Vector2(200,1080),{"deploy_time_override":0.0}))
			target.max_hp = 10000
			target.hp = 10000
			target.can_attack = false
			target.root(20)
		if tick >= 45 and not shield_cast and is_instance_valid(source):
			shield_cast = true
			main.preview_active_skill(source,CardDB.active_skills_for("sivir")[0])
		if tick >= 55 and not hit_sent and is_instance_valid(source) and is_instance_valid(target):
			hit_sent = true
			main.launch_attack(target,source,30,0,0,0,Color.WHITE)
	if main.runtime.mode == "server" and is_instance_valid(source) and main.runtime._sim_tick_id != last_trace and main.runtime._sim_tick_id >= 43 and main.runtime._sim_tick_id <= 57:
		last_trace = main.runtime._sim_tick_id
		print("[SIVIR_SHIELD_TRACE] ", last_trace, " ", source.buffs.remaining(&"effect_shield"), " hp=",source.hp)
	var units: Array = main.world.replica_units_snapshot().values() if main.runtime.mode == "client" else main.world.authoritative_units_snapshot().values()
	for unit in units:
		if not is_instance_valid(unit): continue
		if unit.card_id == "sivir":
			shield_seen = shield_seen or unit.get_active_buff_active_visual()
			heal_seen = heal_seen or unit.hp >= 220
		if unit.card_id == "target_dummy" and unit.position.y > 1000: damage_seen = damage_seen or unit.hp < 9930
	var count := 0
	for projectile in main.projectile_service().visible_view().values():
		if String(projectile.visual) != "sivir_blade": continue
		count += 1
		outbound_seen = outbound_seen or projectile.direction.x > 0.5
		inbound_seen = inbound_seen or projectile.direction.x < -0.5
	single_projectile = single_projectile and count <= 1
func result() -> Dictionary:
	return {"passed":outbound_seen and inbound_seen and shield_seen and heal_seen and damage_seen and single_projectile,
		"outbound":outbound_seen,"inbound":inbound_seen,"shield":shield_seen,"heal":heal_seen,"damage":damage_seen,"single_projectile":single_projectile}
