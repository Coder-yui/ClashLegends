class_name TwistedFateSuite
extends "res://tests/suites/battle_suite.gd"
## 卡牌大师卡牌领域：全图地面部署、两段式落地、万能牌表现和第五击被动配置。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_card_config()
	_check_global_ground_deployment()
	_check_two_stage_deployment()
	_check_wild_cards_visual()
	_check_attack_release_and_skill_lock()
	_check_passive_single_projectile()

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
		and is_equal_approx(float(stats.get("pre_deploy_time", 0.0)), 1.3)
		and is_equal_approx(float(stats.get("deploy_time", 0.0)), 0.45),
		"卡牌大师是远程对陆对空单位，deploy_zone=global 且受占位（含河道）限制，启用 1.3 秒预部署和 0.45 秒实际部署",
	)
	_expect(
		attack_animations == ["Attack1", "Attack2", "Attack3", "Attack4", "Spell3"]
		and stats.get("attack_damage_multipliers", []) == [1.0, 1.0, 1.0, 1.0, 1.5]
		and stats.get("attack_extra_hit_damage_multipliers", []).is_empty(),
		"卡牌大师普攻按 Attack1/2/3/4/Spell3 循环，第五击追加额外伤害",
	)
	_expect(
		String(skill.get("name", "")) == "万能牌"
		and String(skill.get("kind", "")) == "frontal"
		and String(skill.get("shape", "")) == "fan"
		and int(skill.get("projectile_count", 0)) == 3
		and String(skill.get("projectile_visual", "")) == "card"
		and is_equal_approx(float(skill.get("projectile_launch_delay", -1.0)), 0.25)
		and is_equal_approx(float(skill.get("projectile_flight_duration", -1.0)), 0.72)
		and is_equal_approx(float(skill.get("impact_delay", -1.0)), 0.25)
		and is_equal_approx(float(skill.get("cast_duration", -1.0)), 0.97)
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
	var left_bridge_top := Vector2(ArenaRules.BRIDGE_X_LEFT, river_top.y)
	var right_bridge_bottom := Vector2(ArenaRules.BRIDGE_X_RIGHT, river_bottom.y)
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
	_main._commands.pre_deployments.clear()
	var desired := Vector2(60.0, 100.0)
	var before_count := 0
	for combatant in _main.get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and (combatant as Unit).card_id == "twisted_fate":
			before_count += 1
	var cues: Array[String] = []
	var listener := func(card: String, cue: StringName, _pos: Vector2):
		if card == "twisted_fate" and cue == &"pre_deploy:start":
			cues.append(String(cue))
	_main._audio_manager.cue_played.connect(listener)
	_main.play_card(0, "twisted_fate", desired, {"immediate": true, "validate_position": false})
	_main._play_card_event(_main._presentation_event_id, "twisted_fate", "pre_deploy:start", desired)
	_expect(cues.size() == 1, "预部署开始播放一次 Gate_marker，重复可靠事件 ID 不重播")
	var scheduled: bool = _main._commands.pre_deployments.size() == 1
	var no_unit_during_pre_stage := true
	for combatant in _main.get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and (combatant as Unit).card_id == "twisted_fate":
			no_unit_during_pre_stage = false
	_expect(scheduled and no_unit_during_pre_stage and before_count == 0, "1.3 秒预部署只显示卡牌落点提示，不生成卡牌大师")
	for _tick in range(25):
		_main._sim_step(_main.SIM_DT)
	var still_waiting: bool = _main._commands.pre_deployments.size() == 1
	var unit_before_second_stage: bool = _latest_twisted_fate() == null
	_main._sim_step(_main.SIM_DT)
	var unit := _latest_twisted_fate()
	var spawned_after_pre_deploy: bool = unit != null and _main._commands.pre_deployments.is_empty()
	var unit_locked: bool = unit != null and not unit.is_deployed() and is_equal_approx(unit._deploy_timer, 0.45)
	for _tick in range(8):
		_main._sim_step(_main.SIM_DT)
	var locked_until_final_tick: bool = unit != null and not unit.is_deployed()
	_main._sim_step(_main.SIM_DT)
	var unit_ready: bool = unit != null and unit.is_deployed() and is_zero_approx(unit._deploy_timer) and unit.get_action_permissions_visual() == 3
	_expect(still_waiting and unit_before_second_stage and spawned_after_pre_deploy and unit_locked and locked_until_final_tick and unit_ready, "1.3 秒前不存在，出现后部署锁定 0.45 秒再允许移动攻击")
	_expect(cues.size() == 1, "落地进入部署不重复播放预部署声音")
	for path in CardDB.get_card("twisted_fate").audio.events["pre_deploy:start"].pool:
		var stream = load(path)
		_expect(is_equal_approx(stream.get_length(), 1.75) and "first_1_75s" in String(path), "落地原声前 1.75 秒，无加速，覆盖两阶段部署")

	_main._audio_manager.cue_played.disconnect(listener)
	if unit != null and is_instance_valid(unit):
		unit.free()
	_main._commands.pre_deployments.clear()

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
		String(effect.get("shape", "")) == "projectile_fan"
		and int(effect.get("projectile_count", 0)) == 3
		and String(effect.get("projectile_visual", "")) == "card",
		"万能牌范围提示保留三条真实弹道参数，不重复绘制视觉牌",
	)
	_main._projectile_system.clear_all()
	_main._projectile_system.launch_skill_fan(caster, skill, Vector2.UP)
	var paths_match := true
	var index := 0
	for projectile in _main._projectiles.values():
		var direction := ProjectileSystem.skill_fan_direction(Vector2.UP, float(effect.arc_degrees), int(effect.projectile_count), index)
		paths_match = paths_match and (projectile.pos as Vector2).is_equal_approx(caster.position + direction * float(effect.source_radius))
		paths_match = paths_match and (projectile.direction as Vector2).is_equal_approx(direction) and is_equal_approx(float(projectile.remaining), float(effect.length))
		index += 1
	_expect(paths_match and index == 3, "万能牌提示与三条真实弹体共用方向，逐条起点和长度一致")
	var old_mode: String = _main.mode
	_main.mode = "client"
	_main._rpc_frontal_skill_fx(-1, caster.position, Vector2.DOWN, caster.body_radius, float(effect.length), 0.0, float(effect.duration), 1, String(effect.shape), 0.0, 0.0, float(effect.arc_degrees), int(effect.projectile_count))
	var replay: Dictionary = _main._active_skill_effect_system.frontal_effects.back()
	_expect(replay.shape == "projectile_fan" and replay.projectile_count == 3 and replay.forward == Vector2.DOWN, "客户端范围 RPC 保留三条穿透路径参数和红方朝向")
	_main.mode = old_mode
	_main._projectile_system.clear_all()
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
	attacker.attack_timeline.windup = _main.SIM_DT
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
		and is_equal_approx(float(effect.get("projectile_flight_duration", -1.0)), 0.72)
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

func _check_passive_single_projectile() -> void:
	var stats := CardDB.get_card("twisted_fate").duplicate(true)
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	attacker.card_id = "twisted_fate"
	attacker.setup(0, stats, stats.name)
	attacker.position = Vector2(360, 900)
	var target := Unit.new()
	target.setup(1, CardDB.training_dummy_stats(), "被动木桩")
	target.position = Vector2(360, 740)
	_main.add_child(attacker)
	_main.add_child(target)
	_main._projectile_system.clear_all()
	var counts: Array[int] = []
	var amounts: Array[float] = []
	var flight_ok := true
	for attack in 10:
		var before := target.hp
		var released := false
		for tick in 40:
			attacker.sim_tick(0.05)
			if attacker._attack_swing_count == attack + 1:
				released = true
				break
		flight_ok = flight_ok and released and is_equal_approx(target.hp, before)
		# 不推进弹体，继续跨过原来的 0.12 秒追加攻击窗口。
		for tick in 4:
			attacker.sim_tick(0.05)
		counts.append(_main._projectiles.size())
		for tick in 20:
			_main._projectile_system.tick(0.05)
		amounts.append(before - target.hp)
	_expect(flight_ok and counts == [1,1,1,1,1,1,1,1,1,1], "卡牌连续十击各只生成一个弹体，跨过旧追加窗口也不补弹，飞行前不扣血")
	_expect(amounts == [62.0,62.0,62.0,62.0,93.0,62.0,62.0,62.0,62.0,93.0], "卡牌每第五击同一个弹体结算基础 62 + 被动 31，其余攻击不变")
	attacker.free()
	target.free()
	_main._projectile_system.clear_all()
