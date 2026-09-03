class_name TwistedFateSuite
extends RefCounted
## 卡牌大师卡牌领域：全图地面部署、两段式落地、万能牌表现和第五击被动配置。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_card_config()
	_check_global_ground_deployment()
	_check_two_stage_deployment()
	_check_wild_cards_visual()
	_check_attack_release_and_skill_lock()

func _check_card_config() -> void:
	var stats: Dictionary = CardDB.get_card("twisted_fate").duplicate(true)
	var animations: Dictionary = stats.get("visual_animations", {})
	var attack_animations: Array = animations.get("attack", [])
	var skill: Dictionary = stats.get("active_skills", [])[0]
	var visual_actions: Dictionary = animations.get("visual_actions", {})
	var wild_cards_action: Dictionary = visual_actions.get("wild_cards", {})
	_expect(
		stats.get("name", "") == "卡牌大师"
		and stats.get("type", "") == "unit"
		and not bool(stats.get("is_air", true))
		and bool(stats.get("can_attack_air", false))
		and String(stats.get("deploy_zone", "")) == "global"
		and not bool(stats.get("deploy_ignore_structures", false))
		and is_equal_approx(float(stats.get("interval", 0.0)), 1.2)
		and is_equal_approx(float(stats.get("first_hit", -1.0)), 0.25)
		and is_equal_approx(float(stats.get("pre_deploy_time", 0.0)), 1.0)
		and is_equal_approx(float(stats.get("deploy_time", 0.0)), 1.0),
		"卡牌大师是远程对陆对空单位，deploy_zone=global 且受占位（含河道）限制，启用 1 秒预部署 + 1 秒单位部署",
	)
	_expect(
		attack_animations == ["Attack1", "Attack2", "Attack3", "Attack4", "Spell3"]
		and stats.get("attack_extra_hit_damage_multipliers", []) == [[], [], [], [], [0.5]]
		and stats.get("attack_extra_hit_delays", []) == [[], [], [], [], [0.12]],
		"卡牌大师普攻按 Attack1/2/3/4/Spell3 循环，第五击追加额外伤害",
	)
	_expect(
		String(skill.get("name", "")) == "万能牌"
		and String(skill.get("kind", "")) == "frontal"
		and String(skill.get("shape", "")) == "fan"
		and int(skill.get("projectile_count", 0)) == 3
		and String(skill.get("projectile_visual", "")) == "card"
		and is_equal_approx(float(skill.get("projectile_launch_delay", -1.0)), 0.25)
		and is_equal_approx(float(skill.get("projectile_flight_duration", -1.0)), 0.7177415)
		and is_equal_approx(float(skill.get("impact_delay", -1.0)), 0.25)
		and is_equal_approx(float(skill.get("cast_duration", -1.0)), 0.9677415)
		and String(skill.get("visual_action", "")) == "wild_cards"
		and String(wild_cards_action.get("animation", "")) == "Spell1",
		"万能牌配置为扇形甩出 3 张牌，并使用 Spell1 动画",
	)

func _check_global_ground_deployment() -> void:
	var enemy_side := Vector2(60.0, 100.0)
	var own_side := Vector2(60.0, 1160.0)
	var center_ground := Vector2(360.0, 800.0)
	var river_top := Vector2(360.0, 620.0)
	var river_bottom := Vector2(360.0, 660.0)
	var left_bridge_top := Vector2(_main.BRIDGE_X_LEFT, river_top.y)
	var right_bridge_bottom := Vector2(_main.BRIDGE_X_RIGHT, river_bottom.y)
	var enemy_king: Vector2 = _main._king_enemy.global_position
	var player_king: Vector2 = _main._king_player.global_position
	_expect(
		_main.is_card_deploy_position_valid(0, "twisted_fate", enemy_side)
		and _main.is_card_deploy_position_valid(0, "twisted_fate", own_side)
		and _main.is_card_deploy_position_valid(1, "twisted_fate", enemy_side)
		and _main.is_card_deploy_position_valid(1, "twisted_fate", own_side)
		and _main.is_card_deploy_position_valid(0, "twisted_fate", center_ground)
		and _main.is_card_deploy_position_valid(0, "twisted_fate", left_bridge_top)
		and _main.is_card_deploy_position_valid(0, "twisted_fate", right_bridge_bottom)
		and _main.is_card_deploy_position_valid(1, "twisted_fate", left_bridge_top),
		"卡牌大师可在敌我双方、中场河道外、左右桥面的地面落点部署",
	)
	_expect(
		not _main.is_card_deploy_position_valid(0, "twisted_fate", river_top)
		and not _main.is_card_deploy_position_valid(0, "twisted_fate", river_bottom)
		and not _main.is_card_deploy_position_valid(0, "twisted_fate", enemy_king)
		and not _main.is_card_deploy_position_valid(0, "twisted_fate", player_king),
		"卡牌大师不能落在非桥面河道、或防御塔/水晶占地格",
	)

func _check_two_stage_deployment() -> void:
	_main._pending_card_pre_deployments.clear()
	var desired := Vector2(60.0, 100.0)
	var before_count := 0
	for combatant in _main.get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and (combatant as Unit).card_id == "twisted_fate":
			before_count += 1
	_main._execute_card_deployment(0, "twisted_fate", desired)
	var scheduled: bool = _main._pending_card_pre_deployments.size() == 1
	var no_unit_during_pre_stage := true
	for combatant in _main.get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and (combatant as Unit).card_id == "twisted_fate":
			no_unit_during_pre_stage = false
	_expect(scheduled and no_unit_during_pre_stage and before_count == 0, "第一段 1 秒只显示卡牌落点提示，不生成卡牌大师")
	for _tick in range(19):
		_main._sim_step(_main.SIM_DT)
	var still_waiting: bool = _main._pending_card_pre_deployments.size() == 1
	var unit_before_second_stage: bool = _latest_twisted_fate() == null
	_main._sim_step(_main.SIM_DT)
	var unit := _latest_twisted_fate()
	var spawned_after_one_second: bool = unit != null and _main._pending_card_pre_deployments.is_empty()
	var unit_deployment_lock_started: bool = unit != null and not unit.is_deployed() and unit._deploy_timer > 0.9 and unit._deploy_timer <= 1.0
	_expect(still_waiting and unit_before_second_stage and spawned_after_one_second and unit_deployment_lock_started, "第二段开始时卡牌大师出现，并进入 1 秒单位部署锁定")
	if unit != null and is_instance_valid(unit):
		unit.free()
	_main._pending_card_pre_deployments.clear()

func _latest_twisted_fate() -> Unit:
	var latest: Unit = null
	for combatant in _main.get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and (combatant as Unit).card_id == "twisted_fate":
			latest = combatant as Unit
	return latest

func _check_wild_cards_visual() -> void:
	_main._active_skill_effect_system.clear()
	var stats: Dictionary = CardDB.get_card("twisted_fate").duplicate(true)
	stats["deploy_time"] = 0.0
	var skill: Dictionary = stats.active_skills[0]
	var caster := Unit.new()
	caster.position = Vector2(360.0, 900.0)
	caster.setup(0, stats, stats.name)
	_main.add_child(caster)
	_main._active_skill_effect_system.begin_frontal_visual(caster, skill, Vector2.UP)
	var effect: Dictionary = _main._active_skill_effect_system.frontal_effects.back()
	_expect(
		String(effect.get("shape", "")) == "fan"
		and int(effect.get("projectile_count", 0)) == 3
		and String(effect.get("projectile_visual", "")) == "card",
		"万能牌的范围表现保留 3 张卡牌弹道标记，且不参与权威伤害判定",
	)
	_main._active_skill_effect_system.clear()
	caster.free()

func _check_attack_release_and_skill_lock() -> void:
	var stats: Dictionary = CardDB.get_card("twisted_fate").duplicate(true)
	stats["deploy_time"] = 0.0
	var target_stats: Dictionary = CardDB.get_card("garen").duplicate(true)
	target_stats["deploy_time"] = 0.0
	_main._projectile_system.clear_all()
	var attacker := Unit.new()
	var target := Unit.new()
	attacker.position = Vector2(360.0, 900.0)
	target.position = Vector2(360.0, 700.0)
	attacker.setup(0, stats, stats.name)
	target.setup(1, target_stats, target_stats.name)
	_main.add_child(attacker)
	_main.add_child(target)
	attacker._target = target
	attacker._attacking = true
	attacker._attack_visual_pending = true
	attacker._attack_windup = _main.SIM_DT
	var target_hp_before := target.hp
	attacker.sim_tick(_main.SIM_DT)
	_expect(
		not _main._projectiles.is_empty()
		and is_equal_approx(target.hp, target_hp_before)
		and attacker.get_attack_visual_serial() > 0,
		"卡牌大师普攻在 first_hit 出手 tick 生成远程弹体，飞行期间不提前扣血",
	)

	var skill: Dictionary = stats.active_skills[0]
	var cast_facing := Vector2.RIGHT
	attacker.begin_active_skill_cast(float(skill.cast_duration), cast_facing, skill.cast_locks)
	attacker._target = target
	attacker._attacking = true
	var position_before := attacker.position
	_main._active_skill_effect_system.begin_frontal_visual(attacker, skill, cast_facing)
	var effect: Dictionary = _main._active_skill_effect_system.frontal_effects.back()
	var visual_timing_ok := (
		is_equal_approx(float(effect.get("projectile_launch_delay", -1.0)), 0.25)
		and is_equal_approx(float(effect.get("projectile_flight_duration", -1.0)), 0.7177415)
	)
	attacker.sim_tick(_main.SIM_DT)
	_expect(
		visual_timing_ok
		and attacker.is_active_skill_movement_locked()
		and attacker.is_active_skill_attack_locked()
		and attacker.is_active_skill_facing_locked()
		and attacker.get_visual_facing_direction().is_equal_approx(cast_facing)
		and attacker.position.is_equal_approx(position_before)
		and not attacker._attacking,
		"万能牌施法期间锁定移动、攻击、朝向，卡牌表现弹体按出手延迟单独计时",
	)
	_main._active_skill_effect_system.clear()
	_main._projectile_system.clear_all()
	attacker.free()
	target.free()
