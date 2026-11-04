extends RefCounted
var started := false
var normal_seen := false
var enhanced_seen := false
var second_seen := false
var third_seen := false
var ready_seen := false
var consumed_seen := false
var ground_damage_seen := false
var arc_seen := false
var source: Unit
func poll(main: Node2D) -> void:
	if main.runtime.mode == "server" and main.runtime._match_started:
		if main.runtime._sim_tick_id >= 40 and not started:
			started = true
			source = main._spawn_unit(UnitSpawnRequest.new(0, "ziggs", Vector2(100, 850), {"deploy_time_override":0.0}))
			source.root(30)
			for n in 3:
				var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(100, 700-n*60), {"deploy_time_override":0.0}))
				target.can_attack=false
				target.root(30)
		if main.runtime._sim_tick_id == 130 and is_instance_valid(source): main.preview_active_skill(source,CardDB.active_skills_for("ziggs")[0])
	var system: ProjectileSystem = main._projectile_system
	for p in system.visible_view().values():
		normal_seen = normal_seen or String(p.get("visual", "")) == "ziggs_bomb"
		enhanced_seen = enhanced_seen or String(p.get("visual", "")) == "ziggs_bounce"
		second_seen = second_seen or String(p.get("visual", "")) == "ziggs_bounce_2"
		third_seen = third_seen or String(p.get("visual", "")) == "ziggs_bounce_3"
		if String(p.get("visual", "")) in ["ziggs_bomb","ziggs_bounce"]: arc_seen = arc_seen or float(p.visual_height)>35.0
	for unit in main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit and unit.card_id == "ziggs":
			var ready: bool = unit.is_empowered_attack_ready_visual()
			consumed_seen = consumed_seen or (ready_seen and not ready)
			ready_seen = ready_seen or ready
		if unit is Unit and unit.card_id=="target_dummy" and unit.team==1: ground_damage_seen=ground_damage_seen or unit.hp<unit.max_hp
func result() -> Dictionary:
	return {"passed":normal_seen and enhanced_seen and ground_damage_seen and arc_seen and second_seen and third_seen and ready_seen and consumed_seen,"second":second_seen,"third":third_seen,"ready":ready_seen,"consumed":consumed_seen,"normal":normal_seen,"enhanced":enhanced_seen,"damage":ground_damage_seen,"arc":arc_seen}
