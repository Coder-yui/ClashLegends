class_name XinSuite
extends "res://tests/suites/battle_suite.gd"
## 赵信卡牌领域：部署/主动新月护卫、三段普攻转跑与回血循环。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_hit_ground_refresh()
	_check_dash_area_and_weapon()
	_check_collisionless_strike()
	_check_movement_strike()
	_check_xin_deploy_sweep()
	_check_xin_art_integration()
	_check_xin_animation_routes_and_active()

func _check_xin_deploy_sweep() -> void:
	# 部署新月护卫：赵信生成当帧挥击并击退，部署阶段只播放 1 秒 Spell4。
	var xin_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var light_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_unit_stats("imp")) # 质量 1
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
	# 部署未结束时赵信自身不行动；结束 Tick 允许立即行军。
	var stayed_during_deploy := true
	for _i in 20:
		for u in [xin, light, heavy, far, air, building]:
			u.sim_tick(_main.SIM_DT)
		_main._movement._apply_unit_movement(_main.SIM_DT, _main._movement._active_mobile_units())
		if not xin.is_deployed():
			stayed_during_deploy = stayed_during_deploy and xin.global_position.distance_to(xin_start) < 0.01
	_expect(xin.is_deployed(), "Spell4 的 1 秒部署演出结束后赵信解锁行动")
	_expect(stayed_during_deploy, "赵信在出场演出期间没有自主移动")
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
		and anim_names.attack_hit[2] == anim_names.attack[2]
		and anim_names.attack_clip_ranges[2] == [0.0, 0.3]
		and anim_names.attack_hit_clip_ranges[2] == [0.3, 3.0],
		"赵信第三击从同一个完整 Passive 连续取 0–0.3/0.3–3.0 秒，避免异源端点跳变",
	)
	var cancel_probe := Unit.new()
	cancel_probe.setup(0, stats, stats.name)
	for attempt in 3:
		cancel_probe._attack_visual_pending = true
		cancel_probe._try_start_attack_visual(0.3)
		_expect((cancel_probe._attack_visual_serial - 1) % 3 == 0, "取消前摇不占用赵信第三击被动动画段")
	cancel_probe._attack_swing_count = 2
	cancel_probe._attack_visual_pending = true
	cancel_probe._try_start_attack_visual(0.3)
	_expect((cancel_probe._attack_visual_serial - 1) % 3 == 2, "前两次已出手后下一次使用被动攻击段，声音序号同步")
	cancel_probe.free()
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
	var skill: Dictionary = stats.active_skills[0]
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
		var passive_uses_full_clip := (
			view._animation_player.current_animation == "Passive_AA_01_XinZhaoRework_anm"
			and view._attack_hit_pending
			and is_equal_approx(view._current_clip_speed, 1.0)
		)
		view._align_attack_progress(0.45)
		_expect(not view._attack_hit_pending and is_equal_approx(view._attack_clip_start, 0.3) and is_equal_approx(view._animation_player.current_animation_position, 0.975), "赵信被动先原速出枪，命中后连续衔接同源收势；晚到进度包含源片段起点")
		view._transition_to_basic_state(2, 0.0, &"attack")
		var passive_to_run := view._animation_player.current_animation == "PassiveAA_to_Run_XinZhaoRework_anm"
		view._on_animation_finished(&"PassiveAA_to_Run_XinZhaoRework_anm")
		var passive_reached_run := view._animation_player.current_animation == "RunBase"
		attack_routes_ok = first_to_run_in and first_reached_run and second_to_run_in and passive_uses_full_clip and passive_to_run and passive_reached_run

		xin._attacking = false
		xin._target = null
		xin._move_intent = Vector2.ZERO
		var prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(xin, skill)
		_main._skill_lifecycle._begin_cast(xin, prepared)
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
		_main._skill_lifecycle._begin_cast(xin, prepared)
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

func _check_movement_strike() -> void:
	var source: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "xin", Vector2(300, 1000), {"deploy_time_override": 0.0}))
	var target: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "hecarim", Vector2(502, 1000), {"deploy_time_override": 0.0}))
	var skill: Dictionary = CardDB.active_skills_for("xin")[1]
	source.movement_strike.arm(skill)
	_expect(not source.can_start_active_skill(skill), "已准备冲锋时不可重复付款覆盖")
	_expect(not source.movement_strike.tick(source, 0.05), "冲锋不触达四格之外")
	target.position.x = source.position.x + source.body_radius + target.body_radius + 160.0
	source.blind_attack_charges = 2
	var initial_hp := target.hp
	_expect(source.movement_strike.tick(source, 0.05), "四格身体边缘内开始真实突进")
	_expect(target.hp == initial_hp, "起手尚未抵达不提前伤害")
	for frame in 25:
		if source.movement_strike.target_ref == null: break
		_main._movement.tick(0.05)
		source._move_intent = Vector2.ZERO
		source.movement_strike.tick(source, 0.05)
	_expect(target.hp == initial_hp - 68.0 and source.blind_attack_charges == 2, "突进一次68伤害且不消费致盲")
	_expect(source._target_gap(target) >= -0.05, "抵达目标身前不重叠")
	_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.4), "真实命中获得40%攻速")
	_expect(not source.movement_strike.is_armed() and skill.charge_attack_range == 160.0, "技能消费且共享配置不变")
	_expect(source._attack_visual_pending, "突进恢复后重新准备普通攻击动作序号")
	var snapshots := NetworkSnapshotSystem.new(_main, _main._projectile_system)
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload: Array = fixture.snapshot_payload(snapshots, 77, source)
	var packet: Array = fixture.packet(snapshots, [payload], [], fixture.tower_payloads(snapshots), 0.0, _main.runtime._match_rules.time_left, false)
	var decoded = snapshots.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
	_expect(decoded != null and payload[NetworkSnapshotSystem.U_ACTION_NAME] == "charge_strike" and is_equal_approx(float(payload[NetworkSnapshotSystem.U_ACTIVE_ATTACK_SPEED_MULTIPLIER]), 1.4) and payload[NetworkSnapshotSystem.U_BUFF_VISUAL_CLOCK].y == 5.0, "压缩快照携带突进动作、40%攻速和五秒特效时钟")
	for frame in 99: source._tick_active_statuses(0.05)
	_expect(is_equal_approx(source.active_attack_speed_multiplier, 1.4), "攻速持续至4.95秒")
	source._tick_active_statuses(0.05)
	_expect(source.active_attack_speed_multiplier == 1.0, "五秒到期恢复基础攻速")
	source.attack_timeline.cancel(true)
	source.movement_strike.arm(skill)
	source.position = Vector2(350, 700)
	target.position = Vector2(350, 580)
	_expect(source.movement_strike.tick(source, 0.05), "技能冲锋允许跨河")
	source.cancel_charge()
	source.movement_strike.arm(skill)
	source.position = Vector2(300, 1000)
	target.position = Vector2(440, 1000)
	_expect(source.movement_strike.tick(source, 0.05), "再次起手")
	source.stun(0.5)
	_expect(source.movement_strike.target_ref == null, "眩晕中断正在进行的突进")
	source.control.hard.clear_family(&"stun")
	source.attack_timeline.cancel(true)
	source.movement_strike.arm(skill)
	source.movement_strike.tick(source, 0.05)
	target.free()
	_expect(source.movement_strike.tick(source, 0.05) and not source.movement_strike.is_armed() and source.active_attack_speed_multiplier == 1.0, "目标途中释放安全取消且不奖励攻速")
	source.free()

func _strike_pair(start: Vector2, end: Vector2) -> Array[Unit]:
	var source: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "xin", start, {"deploy_time_override": 0.0}))
	var target: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "hecarim", end, {"deploy_time_override": 0.0}))
	source.movement_strike.arm(CardDB.active_skills_for("xin")[1])
	return [source, target]

func _advance_strike(source: Unit, count: int) -> void:
	for frame in count:
		if not source.movement_strike.in_transit(): break
		_main._movement.tick(0.05)
		source._move_intent = Vector2.ZERO
		source.movement_strike.tick(source, 0.05)

func _check_collisionless_strike() -> void:
	var pair := _strike_pair(Vector2(350,720), Vector2(350,540))
	var source := pair[0]
	var target := pair[1]
	var hp := target.hp
	_expect(source.movement_strike.tick(source,0.05), "跨河突进找到对岸身前落点")
	_advance_strike(source, 1)
	_expect(source.movement_strike.in_transit() and not UnitLandingQuery.displacement_legal(source,source.position), "河中推进保留突进且暂不参与地形碰撞")
	_advance_strike(source, 12)
	_expect(target.hp == hp-68 and UnitLandingQuery.legal(source, source.position, false), "跨河抵达合法身前并只伤害一次")
	source.free()
	target.free()
	for kind in ["stun", "freeze", "root", "stasis", "knockback", "forced"]:
		pair = _strike_pair(Vector2(350,720), Vector2(350,540))
		source = pair[0]
		target = pair[1]
		hp = target.hp
		source.movement_strike.tick(source,0.05)
		_advance_strike(source,1)
		var interrupted_at := source.position
		match kind:
			"stun": source.stun(0.5)
			"freeze": source.freeze(0.5)
			"root": source.root(0.5)
			"stasis": source.apply_stasis(0.5)
			"knockback": source.apply_knockback(source.position + Vector2.UP*20,40,0.3)
			"forced": source.apply_forced_displacement(Vector2.DOWN,80,0.3)
		_expect(not source.movement_strike.in_transit() and not source.movement_strike.is_armed(), kind + "消耗并打断正在进行的突进")
		_expect(target.hp == hp and source.active_attack_speed_multiplier == 1.0, kind + "中断不补伤害或攻速")
		if kind == "forced":
			_expect(source.knockback.in_transit and source.position.is_equal_approx(interrupted_at), "新外力从真实中断位置接管，不被旧突进恢复覆盖")
		else:
			_expect(UnitLandingQuery.displacement_legal(source,source.position), kind + "中断后使用通用恢复落点")
		if kind == "root":
			_expect((source.action_permissions() & ControlState.MOVE)==0 and (source.action_permissions() & ControlState.BASIC_ATTACK)!=0, "禁锢保留普攻只限制自主移动")
			source._prepare_movement(Vector2.RIGHT,0.05)
			_expect(source._move_intent.is_zero_approx(), "禁锢阻止自主移动意图")
			for frame in 10: source.control.tick_hard_controls(0.05)
			_expect((source.action_permissions() & ControlState.MOVE)!=0, "禁锢按硬控时钟独立到期")
		source.free()
		target.free()
	pair = _strike_pair(Vector2(250,1000), Vector2(420,1000))
	source = pair[0]
	target = pair[1]
	var front := UnitLandingQuery.find_strike_position(source,target,Vector2.RIGHT)
	var blocker: Unit = _main._spawn_unit(UnitSpawnRequest.new(0,"hecarim",front,{"deploy_time_override":0.0}))
	var side := UnitLandingQuery.find_strike_position(source,target,Vector2.RIGHT)
	_expect(side.is_finite() and absf(side.y-target.position.y)>1 and side.x<=target.position.x+0.01, "正前被占用时选前半圆合法身侧")
	blocker.free()
	var back_skill: Dictionary = CardDB.active_skills_for("xin")[1].duplicate(true)
	back_skill.charge_landing_side = "back"
	source.movement_strike.arm(back_skill)
	source.movement_strike.tick(source,0.05)
	_advance_strike(source,15)
	_expect(source.position.x>target.position.x and target.hp==782.0 and UnitLandingQuery.legal(source,source.position,false), "配置身后时穿过目标到身后合法落点结算")
	source.free()
	target.free()

	# 同阵营建筑与单位只作为沿途障碍；不可因穿障而推走它们。
	for interrupted in [false, true]:
		pair = _strike_pair(Vector2(250,1000), Vector2(440,1000))
		source = pair[0]
		target = pair[1]
		var obstacle: Unit = _main._spawn_unit(UnitSpawnRequest.new(0,"target_dummy",Vector2(330,1000),{"deploy_time_override":0.0}))
		var obstacle_position := obstacle.position
		hp = target.hp
		source.movement_strike.tick(source,0.05)
		_advance_strike(source,2)
		_expect(source.movement_strike.in_transit() and not UnitLandingQuery.displacement_legal(source,source.position), "突进实际穿入建筑且仍可作为受击目标")
		var before_damage := source.hp
		source.take_damage(1.0)
		_expect(source.hp==before_damage-1.0, "无碰撞突进不提供无敌")
		if interrupted:
			source.freeze(0.5)
			_expect(UnitLandingQuery.displacement_legal(source,source.position) and target.hp==hp, "建筑内冰冻恢复到合法区域且不命中")
		else:
			_advance_strike(source,12)
			_expect(target.hp==hp-68.0 and UnitLandingQuery.legal(source,source.position,false), "穿建筑后合法落地并结算")
		_expect(obstacle.position==obstacle_position, "穿障不推挤沿途建筑")
		source.free()
		target.free()
		obstacle.free()

func _check_dash_area_and_weapon() -> void:
	var pair := _strike_pair(Vector2(200,1000),Vector2(390,1000))
	var source := pair[0]
	var target := pair[1]
	var units: Array[Unit] = [source,target]
	var inside: Unit = _main._spawn_unit(UnitSpawnRequest.new(1,"hecarim",Vector2(390,1127.9),{"deploy_time_override":0.0}))
	var outside: Unit = _main._spawn_unit(UnitSpawnRequest.new(1,"hecarim",Vector2(390,871.9),{"deploy_time_override":0.0}))
	inside.position = target.position + Vector2(0,70+inside.body_radius-0.1)
	outside.position = target.position - Vector2(0,70+outside.body_radius+0.1)
	var ally: Unit = _main._spawn_unit(UnitSpawnRequest.new(0,"hecarim",Vector2(440,1000),{"deploy_time_override":0.0}))
	var air: Unit = _main._spawn_unit(UnitSpawnRequest.new(1,"voidfish",Vector2(390,1050),{"deploy_time_override":0.0}))
	var building: Unit = _main._spawn_unit(UnitSpawnRequest.new(1,"target_dummy",Vector2(440,950),{"deploy_time_override":0.0}))
	units.append_array([inside,outside,ally,air,building])
	var health: Array = units.map(func(unit): return unit.hp)
	var impacts: Array[Vector2] = []
	var callback := func(id: String, cue: StringName, point: Vector2):
		if id == "xin" and cue == &"charge:hit": impacts.append(point)
	_main._audio_manager.cue_played.connect(callback)
	source.hp = 300
	source._attack_swing_count = 2
	source.blind_attack_charges = 2
	_expect(source.movement_strike.tick(source,0.05), "70像素范围冲锋正常起手")
	_advance_strike(source,12)
	_expect(target.hp==health[1]-68 and inside.hp==health[2]-68 and outside.hp==health[3], "主目标只伤害一次，70像素按身体边缘包含圈内并排除圈外")
	_expect(ally.hp==health[4] and air.hp==health[5] and building.hp==health[6]-68, "范围伤害排除友军和空军，包含建筑")
	_expect(impacts.size()==1 and impacts[0].is_equal_approx(target.position), "多人受伤只在主目标中心发布一次原版冲击")
	_expect(source.hp==360 and source.blind_attack_charges==2 and is_equal_approx(source.active_attack_speed_multiplier,1.4), "多人命中不重复第三击回血且保留致盲豁免与40%攻速")
	_main._audio_manager.cue_played.disconnect(callback)
	var view = load("res://assets/units/xin/xin_view.tscn").instantiate()
	_main.add_child(view)
	view.configure_unit_visual(source)
	view.scale = Vector3.ONE*1.3
	view.rotation.y = 0.7
	view.advance_ambient_visual(0.05)
	_expect(view._buff.visible and view._buff.global_transform.is_equal_approx(view._skeleton.global_transform*view._skeleton.get_bone_global_pose(view._weapon)), "枪上增益完整继承武器骨骼位置朝向和缩放，不重复缩放")
	for frame in 100: source._tick_active_statuses(0.05)
	view.advance_ambient_visual(0.05)
	_expect(not view._buff.visible, "五秒到期清理枪上攻速特效")
	source.apply_active_buff(2.0, 1.0, 1.2, 1.0, false, false, &"non_haste_probe")
	view.advance_ambient_visual(0.05)
	_expect(not view._buff.visible, "其他非攻速增益不能触发无畏冲锋枪光")
	view.free()
	for unit in units: unit.free()
	var invalid := CardDB.all().duplicate(true)
	invalid.xin.active_skills[1].charge_impact_radius = -1.0
	_expect(not CardDB.VALIDATOR.validate_all(invalid,false).is_empty(), "突进范围配置拒绝负数")

func _check_hit_ground_refresh() -> void:
	var world := Node3D.new()
	_main.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 20, 20)
	camera.look_at(Vector3.ZERO)
	var effects = load("res://scripts/presentation/attack_hit_visuals.gd").new()
	_main.add_child(effects)
	var point := Vector2(360, 900)
	effects.play_movement_hit("xin", point, world, camera)
	var hit: Node3D = effects._hits[0].player
	_expect(hit.scale.is_equal_approx(Vector3.ONE * 0.007), "命中层XYZ等比缩放至70像素范围，起手和枪光不随之缩小")
	var expected := preload("res://scripts/presentation/spell_effect_projection.gd").ground(camera, point) + Vector3.UP * 0.126
	effects.advance(0.05)
	effects._process(0.0)
	_expect(hit.global_position.is_equal_approx(expected), "逻辑推进后的逐帧挂点刷新保持赵信冲击贴地高度")
	camera.position.x += 2.0
	effects._process(0.0)
	expected = preload("res://scripts/presentation/spell_effect_projection.gd").ground(camera, point) + Vector3.UP * 0.126
	_expect(hit.global_position.is_equal_approx(expected), "相机变化重新定位冲击仍保留地面偏移")
	effects.advance(1.1)
	_expect(effects._hits.is_empty() and not is_instance_valid(hit), "冲击到期释放粒子与挂点记录")
	effects.free()
	world.free()
