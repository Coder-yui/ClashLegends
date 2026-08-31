class_name XinSuite
extends RefCounted
## 赵信卡牌领域：部署/主动新月护卫、三段普攻转跑与回血循环。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_xin_deploy_sweep()
	_check_xin_art_integration()
	_check_xin_animation_routes_and_active()

func _check_xin_deploy_sweep() -> void:
	# 部署新月护卫：赵信生成当帧挥击并击退，部署阶段只播放 1 秒 Spell4。
	var xin_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var light_stats := SuiteUtils.sweep_dummy_stats(CardDB.imp_stats())            # 质量 1
	var heavy_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))         # 质量 8
	var far_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("ashe"))            # 圈外
	var air_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("aurelionsol"))     # 空中
	var building_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("tombstone"))
	var xin := Unit.new()
	var light := Unit.new()
	var heavy := Unit.new()
	var far := Unit.new()
	var air := Unit.new()
	var building := Unit.new()
	var tower := Tower.new()
	xin.position = Vector2(360.0, 900.0)
	# 分散目标，避免最终位移混入彼此碰撞分离；所有受击目标仍与 90px 圆相交。
	light.position = Vector2(360.0, 805.0)
	heavy.position = Vector2(465.0, 900.0)
	far.position = Vector2(600.0, 720.0)
	air.position = Vector2(320.0, 940.0)
	building.position = Vector2(360.0, 1010.0)
	tower.position = Vector2(255.0, 900.0)
	xin.setup(0, xin_stats, xin_stats.name)
	light.setup(1, light_stats, light_stats.name)
	heavy.setup(1, heavy_stats, heavy_stats.name)
	far.setup(1, far_stats, far_stats.name)
	air.setup(1, air_stats, air_stats.name)
	building.setup(1, building_stats, building_stats.name)
	tower.setup(1, {
		"hp": 99999.0, "damage": 0.0, "range": 0.0, "interval": 1.0,
		"radius": 30.0, "visual_radius": 30.0, "deployment_radius": 30.0,
		"first_hit": 0.2, "projectile_speed": 0.0,
	}, false)
	# 敌人先进入战场；赵信加入 combatants 的同一帧就应命中它们。
	for u in [light, heavy, far, air, building, tower]:
		_main.add_child(u)
	var light_start := light.global_position
	var heavy_start := heavy.global_position
	var far_start := far.global_position
	var air_start := air.global_position
	var building_start := building.global_position
	var tower_start := tower.global_position
	_main.add_child(xin)
	_expect(not xin.is_deployed() and is_equal_approx(xin._deploy_timer, 1.0), "赵信生成后进入 1 秒部署阶段")
	var deploy_damage := float(xin_stats.deploy_sweep_damage)
	var deployment_targets_ok := (
		is_equal_approx(light.hp, 99999.0 - deploy_damage)
		and is_equal_approx(heavy.hp, 99999.0 - deploy_damage)
		and is_equal_approx(building.hp, 99999.0 - deploy_damage)
		and is_equal_approx(tower.hp, 99999.0 - deploy_damage)
		and is_equal_approx(far.hp, 99999.0)
		and is_equal_approx(air.hp, 99999.0)
	)
	_expect(
		deployment_targets_ok
		and light._knockback_timer > 0.0 and heavy._knockback_timer > 0.0
		and is_zero_approx(building._knockback_timer),
		"赵信生成当帧的新月护卫伤害地面单位、建筑和防御塔，只击退非建筑地面 Unit",
	)
	var light_requested_push := light._knockback_velocity.length() * light._knockback_timer
	var heavy_requested_push := heavy._knockback_velocity.length() * heavy._knockback_timer
	_expect(is_equal_approx(light_requested_push, 90.0), "轻单位的质量倍率封顶 1.0，权威击退距离保持 90px")
	_expect(is_equal_approx(heavy_requested_push, 45.0), "质量 8 的单位按 0.5 质量倍率击退 45px")
	_expect(xin._sweep_fx_timer > 0.0, "部署版新月护卫触发短暂扇形冲击特效")
	var xin_start := xin.global_position
	# 跑完整段部署；赵信自身不行动，受击单位的权威击退照常推进。
	for _i in 20:
		for u in [xin, light, heavy, far, air, building]:
			u.sim_tick(_main.SIM_DT)
		_main._apply_unit_movement(_main.SIM_DT)
	_expect(xin.is_deployed(), "Spell4 的 1 秒部署演出结束后赵信解锁行动")
	_expect(xin.global_position.distance_to(xin_start) < 0.01, "赵信在出场演出期间没有自主移动")
	var light_push := light.global_position.distance_to(light_start)
	var heavy_push := heavy.global_position.distance_to(heavy_start)
	var far_push := far.global_position.distance_to(far_start)
	var air_push := air.global_position.distance_to(air_start)
	var building_push := building.global_position.distance_to(building_start)
	var tower_push := tower.global_position.distance_to(tower_start)
	_expect(light_push > 85.0 and light_push <= 95.0, "圈内轻单位最终被击退约 90px（推移 %.1fpx）" % light_push)
	_expect(heavy_push > 10.0 and heavy_push < light_push, "圈内重单位（质量8）被顶开但幅度小于轻单位（推移 %.1fpx < %.1fpx）" % [heavy_push, light_push])
	_expect(far_push < 0.5, "圈外地面单位不受部署版新月护卫影响（位移 %.2fpx）" % far_push)
	_expect(air_push < 0.5, "空中单位扫不到（位移 %.2fpx）" % air_push)
	_expect(building_push < 0.5 and tower_push < 0.5, "建筑和防御塔会受伤但不会被新月护卫击退")
	for u in [xin, light, heavy, far, air, building, tower]:
		u.free()

func _check_xin_art_integration() -> void:
	# 赵信素材接入：三段普攻循环、单段出场动作与第三击回血。
	var stats: Dictionary = CardDB.get_card("xin").duplicate(true)
	var anim_names: Dictionary = stats.visual_animations
	_expect(anim_names.deploy == "Spell4" and is_equal_approx(float(stats.deploy_time), 1.0), "赵信部署只使用 1 秒 Spell4，不再追加 Spell4 ToIdle")
	_expect(
		anim_names.attack.size() == 3
		and anim_names.attack_hit.size() == 3
		and anim_names.attack[2] == "Passive_AA_01_XinZhaoRework_anm"
		and anim_names.attack_hit[2] == "",
		"赵信第三段普攻只使用 Passive AA 01，不再播放前置 hit 动画",
	)
	# 第三击回血：站桩木桩不还手，赵信只应在第 3/6/9…次命中时回复 heal_amount。
	var combat_stats: Dictionary = stats.duplicate()
	combat_stats["deploy_time"] = 0.0
	var xin := Unit.new()
	var dummy := Unit.new()
	xin.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 870.0)
	xin.setup(0, combat_stats, combat_stats.name)
	dummy.setup(1, SuiteUtils.sweep_dummy_stats(stats), stats.name)
	_main.add_child(xin)
	_main.add_child(dummy)
	xin.take_damage(xin.max_hp - 300.0)
	var hits := 0
	var heals := 0
	var heal_at_third := false
	var heal_at_sixth := false
	var third_checked := false
	var sixth_checked := false
	var last_self_hp := xin.hp
	var last_dummy_hp := dummy.hp
	# 部署锁定已由上一项独立验证；这里关闭部署时间，只验证三段攻击与回血循环。
	for _i in 280:
		xin.sim_tick(_main.SIM_DT)
		if not is_equal_approx(dummy.hp, last_dummy_hp):
			hits += 1
			last_dummy_hp = dummy.hp
		if xin.hp > last_self_hp + 0.01:
			heals += 1
			last_self_hp = xin.hp
		# 里程碑在 tick 末检查：命中与回血在同一 tick 同步结算。
		if hits >= 3 and not third_checked:
			third_checked = true
			heal_at_third = heals == 1
		if hits >= 6 and not sixth_checked:
			sixth_checked = true
			heal_at_sixth = heals == 2
	_expect(hits >= 7, "赵信在模拟窗口内完成多轮普攻循环（命中 %d 次）" % hits)
	_expect(heal_at_third, "三段循环第三击命中时回复生命")
	_expect(heal_at_sixth, "第六击命中时再次回复，循环持续生效")
	_expect(is_equal_approx(xin.hp, 300.0 + heals * stats.heal_amount), "回血总量与 heal_amount × 触发次数一致（300→%.0f，回复 %d 次）" % [xin.hp, heals])
	xin.free()
	dummy.free()

func _check_xin_animation_routes_and_active() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate(true)
	var skill: Dictionary = stats.active_skill
	var xin := Unit.new()
	var dummy := Unit.new()
	var air := Unit.new()
	var building := Unit.new()
	var tower := Tower.new()
	xin.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 850.0)
	air.position = Vector2(410.0, 900.0)
	building.position = Vector2(360.0, 950.0)
	tower.position = Vector2(310.0, 900.0)
	xin.setup(0, stats, stats.name)
	dummy.setup(1, SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen")), "赵信技能木桩")
	air.setup(1, SuiteUtils.sweep_dummy_stats(CardDB.get_card("aurelionsol")), "空中新月木桩")
	building.setup(1, SuiteUtils.sweep_dummy_stats(CardDB.get_card("tombstone")), "建筑新月木桩")
	tower.setup(1, {
		"hp": 99999.0, "damage": 0.0, "range": 0.0, "interval": 1.0,
		"radius": 30.0, "visual_radius": 30.0, "deployment_radius": 30.0,
		"first_hit": 0.2, "projectile_speed": 0.0,
	}, false)
	_main.add_child(xin)
	for target in [dummy, air, building, tower]:
		_main.add_child(target)
	var attached: bool = _main._battle_presentation.attach_unit(xin, stats)
	var view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == xin:
			view = child as UnitModel3D
			break

	var deployment_routes_ok := false
	var attack_routes_ok := false
	var active_move_route_ok := false
	var active_attack_route_ok := false
	var active_locks_ok := false
	if view != null:
		var deploy_started_with_spell4 := view._animation_player.current_animation == "Spell4"
		xin._deploy_timer = 0.0
		xin._move_intent = Vector2.UP * xin.move_speed
		view._sync_visual(false, 0.05)
		var deploy_to_run := view._animation_player.current_animation == "Spell4_To_Run"
		view._on_animation_finished(&"Spell4_To_Run")
		var deploy_reached_run := view._animation_player.current_animation == "RunBase"

		# 重新置于部署动作末尾；直接进入攻击时只使用统一 Pose blend，不插专用转场。
		xin._move_intent = Vector2.ZERO
		xin._attacking = false
		view._current_state = 0
		view._play_state(0, 0.0)
		xin._target = dummy
		xin._attacking = true
		xin._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		var deploy_to_attack := view._animation_player.current_animation == "Attack1_Hit"
		deployment_routes_ok = deploy_started_with_spell4 and deploy_to_run and deploy_reached_run and deploy_to_attack

		view._play_attack(1)
		view._transition_to_basic_state(2, 0.0, &"attack")
		var first_to_run_in := view._animation_player.current_animation == "RunIn"
		view._on_animation_finished(&"RunIn")
		var first_reached_run := view._animation_player.current_animation == "RunBase"
		view._play_attack(2)
		view._transition_to_basic_state(2, 0.0, &"attack")
		var second_to_run_in := view._animation_player.current_animation == "RunIn"
		view._play_attack(3)
		var passive_uses_single_clip := (
			view._animation_player.current_animation == "Passive_AA_01_XinZhaoRework_anm"
			and not view._attack_hit_pending
		)
		view._transition_to_basic_state(2, 0.0, &"attack")
		var passive_to_run := view._animation_player.current_animation == "PassiveAA_to_Run_XinZhaoRework_anm"
		view._on_animation_finished(&"PassiveAA_to_Run_XinZhaoRework_anm")
		var passive_reached_run := view._animation_player.current_animation == "RunBase"
		attack_routes_ok = first_to_run_in and first_reached_run and second_to_run_in and passive_uses_single_clip and passive_to_run and passive_reached_run

		xin._attacking = false
		xin._target = null
		xin._move_intent = Vector2.ZERO
		var prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(xin, skill)
		_main._begin_configured_active_skill_cast(xin, prepared)
		view._sync_visual(false, 0.05)
		var active_started_with_spell4 := view._animation_player.current_animation == "Spell4"
		active_locks_ok = (
			xin.is_active_skill_movement_locked()
			and xin.is_active_skill_attack_locked()
			and xin.is_active_skill_facing_locked()
		)
		xin.active_skill_cast_timer = 0.0
		xin.active_skill_cast_locks.clear()
		xin._move_intent = Vector2.UP * xin.move_speed
		view._on_animation_finished(&"Spell4")
		active_move_route_ok = active_started_with_spell4 and view._animation_player.current_animation == "Spell4_To_Run"

		view._on_animation_finished(&"Spell4_To_Run")
		xin._move_intent = Vector2.ZERO
		_main._begin_configured_active_skill_cast(xin, prepared)
		view._sync_visual(false, 0.05)
		xin._target = dummy
		xin._attacking = true
		xin._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		var attack_waited_for_spell4 := view._animation_player.current_animation == "Spell4" and view._pending_attack_serial > 0
		view._on_animation_finished(&"Spell4")
		active_attack_route_ok = (
			attack_waited_for_spell4
			and view._animation_player.current_animation in ["Attack1_Hit", "Attack3_Hit", "Passive_AA_01_XinZhaoRework_anm"]
		)

	var hp_before := dummy.hp
	var air_hp_before := air.hp
	var building_hp_before := building.hp
	var tower_hp_before := tower.hp
	_main._active_skill_effect_system.apply(xin, skill)
	var unified_parameters: bool = (
		is_equal_approx(float(stats.deploy_sweep_radius), float(skill.radius))
		and is_equal_approx(float(stats.deploy_sweep_damage), float(skill.damage))
		and is_equal_approx(float(stats.deploy_sweep_knockback), float(skill.knockback))
		and is_equal_approx(float(stats.deploy_sweep_duration), float(skill.knockback_duration))
		and is_equal_approx(float(stats.deploy_sweep_mass_factor_max), float(skill.knockback_mass_factor_max))
		and bool(skill.ground_only)
	)
	var active_mechanics_ok: bool = (
		unified_parameters
		and is_equal_approx(hp_before - dummy.hp, float(skill.damage))
		and is_equal_approx(building_hp_before - building.hp, float(skill.damage))
		and is_equal_approx(tower_hp_before - tower.hp, float(skill.damage))
		and is_equal_approx(air.hp, air_hp_before)
		and dummy._knockback_timer > 0.0
		and is_equal_approx(dummy._knockback_timer, float(skill.knockback_duration))
		and is_zero_approx(building._knockback_timer)
		and is_equal_approx(float(skill.cast_duration), 1.0)
		and skill.cast_locks == ["movement", "attack", "facing"]
	)
	_expect(attached and deployment_routes_ok, "赵信部署只播 Spell4；部署后移动接 Spell4 ToRun，部署后攻击使用统一 Pose 衔接")
	_expect(attack_routes_ok, "赵信前两段普攻后移动接 RunIn，第三段被动普攻后移动接 PassiveAA ToRun")
	_expect(active_locks_ok and active_mechanics_ok and active_move_route_ok, "主动与部署新月护卫统一为 90 半径、90 伤害、90 基础击退和 0.25 秒位移；仅命中地面且建筑只受伤，移动接 Spell4 ToRun")
	_expect(active_attack_route_ok, "主动新月护卫期间到来的普攻排队，并在 Spell4 完成后用统一 Pose 衔接进入攻击")
	if view != null:
		view.free()
	for unit in [xin, dummy, air, building, tower]:
		if is_instance_valid(unit):
			unit.free()
