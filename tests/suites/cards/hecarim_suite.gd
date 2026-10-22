extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_w_upperbody()
	_check_w_release()
	var source := _unit(0, Vector2(300, 1000))
	source._charged = true
	var snapshots := NetworkSnapshotSystem.new(main, main._projectile_system)
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload: Array = fixture.snapshot_payload(snapshots, 77, source)
	var packet: Array = fixture.packet(snapshots, [payload], [], fixture.tower_payloads(snapshots), 0.0, main.runtime._match_rules.time_left, false)
	var decoded = snapshots.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
	_expect(decoded != null and decoded.packet[NetworkSnapshotSystem.S_UNITS][0][NetworkSnapshotSystem.U_CHARGED] == 1, "冲刺状态通过压缩快照显式同步，不依赖减速后的移速猜测")
	payload[NetworkSnapshotSystem.U_CHARGED] = 2
	_expect(snapshots.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) == null, "快照拒绝非法冲刺标志")
	source.cancel_charge()
	var edge_target := _unit(1, Vector2(439, 1000))
	var beyond_target := _unit(1, Vector2(443, 1000))
	var area_skill: Dictionary = CardDB.active_skills_for("hecarim")[0].duplicate(true)
	main._active_skill_effect_system.activate_continuous_area(source, area_skill)
	main._active_skill_effect_system.tick_effects(0.5)
	_expect(edge_target.hp == 830.0 and beyond_target.hp == 850.0, "120像素领域按身体边缘命中139像素中心目标，排除143像素中心目标")
	main._active_skill_effect_system.continuous_area_effects.clear()
	source.buffs.clear_family(&"timed_lifesteal")
	edge_target.free()
	beyond_target.free()
	var front := _unit(1, Vector2(370, 1000))
	var rear := _unit(1, Vector2(230, 1000))
	var outside := _unit(1, Vector2(420, 1000))
	var resolver: CombatResolver = main.combat_service()
	var result := resolver.resolve_attack_hit(0, source.position, front, 80.0, 0.0, 0.0, source, source.position, -1, {"self_radius": 85.0, "ground_only": true})
	_expect(result.landed and front.hp == 770.0 and rear.hp == 770.0 and outside.hp == 850.0, "旋斩以自身为中心同时命中前后，排除圈外")
	source.hp = 400.0
	var skill: Dictionary = CardDB.active_skills_for("hecarim")[0].duplicate(true)
	main._active_skill_effect_system.activate_continuous_area(source, skill)
	for tick in 9: main._active_skill_effect_system.tick_effects(0.05)
	_expect(source.hp == 400.0 and front.hp == 770.0, "领域半秒前不提前伤害或回血")
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(front.hp == 750.0 and rear.hp == 750.0 and outside.hp == 830.0, "领域第10Tick命中全部范围目标")
	_expect(source.hp == 418.0, "领域按三目标真实掉血30%治疗")
	resolver.resolve_attack_hit(0, source.position, front, 80.0, 0.0, 0.0, source, source.position, -1, {"self_radius": 85.0, "ground_only": true})
	_expect(source.hp == 466.0, "领域中旋斩对两个目标的真实掉血均吸血")
	main._active_skill_effect_system.continuous_area_effects.clear()
	source.buffs.clear_family(&"timed_lifesteal")
	source._move_intent = Vector2.UP * 76.0
	for tick in 46: source.on_movement_applied(3.0, 0.05)
	_expect(not source._charged, "138像素尚未蓄满")
	source.on_movement_applied(2.0, 0.05)
	_expect(source._charged, "累计140像素即3.5格进入冲刺")
	source.cancel_charge()
	for tick in 140: source.on_movement_applied(1.0, 0.05)
	_expect(source._charged, "慢速移动用更长时间走满3.5格同样蓄满")
	source.cancel_charge()
	source.on_movement_applied(139.0, 10.0)
	_expect(not source._charged, "时间再长但不足3.5格仍不蓄满")
	source.on_movement_applied(0.0, 0.05)
	_expect(source._charge_distance_travelled == 0.0, "受阻停止清空连续移动距离")
	for unit in [front, rear, outside]: unit.free()
	var target := _unit(1, Vector2(410, 1000))
	source._charged = true
	_expect(source.movement_strike.tick(source, 0.05), "2格范围内启动突进")
	for tick in 40:
		if source.movement_strike.target_ref == null: break
		source.global_position += source._move_intent * 0.05
		source._move_intent = Vector2.ZERO
		source.movement_strike.tick(source, 0.05)
	_expect(target.hp == 770.0 and target.control.stun_timer == 1.5, "接触时单次伤害与1.5秒眩晕")
	_expect(not source._charged and source.movement_strike.target_ref == null, "命中消费蓄势")
	_expect(source.position.x < target.position.x and is_equal_approx(source._target_gap(target), 2.0), "在目标前侧接触位置命中，不等穿到身后")
	_expect(source.movement_strike.following and source.get_visual_action_name() == &"charge_followthrough", "命中立即转入Spell3后半段续冲")
	var follow_payload: Array = fixture.snapshot_payload(snapshots, 78, source)
	var follow_packet: Array = fixture.packet(snapshots, [follow_payload], [], fixture.tower_payloads(snapshots), 0.0, main.runtime._match_rules.time_left, false)
	var follow_decoded = snapshots.decode_validated(var_to_bytes(follow_packet).compress(FileAccess.COMPRESSION_DEFLATE))
	_expect(follow_decoded != null and follow_payload[NetworkSnapshotSystem.U_ACTION_NAME] == &"charge_followthrough", "续冲动作及进度使用已有压缩快照同步")
	var contact_position := source.position
	var fixed_endpoint := source.movement_strike.follow_endpoint
	target.position += Vector2(80,80)
	for tick in 15:
		if not source.movement_strike.in_transit(): break
		source.position += source._move_intent * 0.05
		source._move_intent = Vector2.ZERO
		source.movement_strike.tick(source, 0.05)
	_expect(source.position.is_equal_approx(contact_position + Vector2(24,0)) and source.position.is_equal_approx(fixed_endpoint), "目标横移和继续击退不改变24像素固定续冲终点")
	_expect(target.hp == 770.0 and source.basic_attack_sequence == 1, "续冲不重复命中")
	target.position = Vector2(410,1000)
	_expect(is_equal_approx(target.knockback.remaining, 0.5), "击退持续0.5秒")
	_expect(is_equal_approx(target.knockback.velocity.length() * 0.5, 40.0 * 4.0 / 6.0) and target.knockback.velocity.x > 0.0, "质量6目标按质量缩放击退距离并沿起手冲刺方向被踢退")
	var light := _unit(1, Vector2(600,1000))
	light.mass = 2.0
	resolver.resolve_attack_hit(0, Vector2(650,1000), light, 80.0, 0.0, 0.0, source, source.position, -1, {"movement_strike_knockback": 40.0, "knockback_duration": 0.5})
	_expect(is_equal_approx(light.knockback.velocity.length() * 0.5, 56.0), "轻质量目标使用通用1.4倍上限")
	light.free()
	target.knockback.cancel(&"test_reset")

	var q_view = load("res://assets/units/hecarim/hecarim_view.tscn").instantiate()
	main.add_child(q_view)
	q_view.configure_unit_visual(source)
	source._attacking = true
	source._attack_visual_serial = 1
	source.attack_timeline.visual_elapsed = 0.2
	q_view.advance_ambient_visual(0.0)
	_expect(not q_view._cas.visible, "冲刺动作仍在播放时不叠加Q刀光")
	source._visual_action_time_left = 0.0
	q_view.advance_ambient_visual(0.0)
	_expect(source.get_visual_action_name() == &"charge_followthrough" and q_view._cas.visible and q_view._buf.visible, "冲刺名称保留但窗口结束后恢复Q施放与附着层")
	source._attack_visual_serial += 1
	source.attack_timeline.visual_elapsed = 0.25
	q_view.advance_ambient_visual(0.0)
	_expect(q_view._cas.visible, "冲刺后的后续连续普攻继续播放Q")
	_expect(q_view._buf._pools[7].is_empty() and q_view._buf._ribbon.mesh.get_surface_count() == 1, "Q武器拖尾使用连续带状网格而非固定火焰面片")
	var geometry = preload("res://assets/effects/hecarim/geometry.gd")
	_expect(is_equal_approx(517.7974672797 * geometry.W_SCALE * geometry.PIXELS_PER_WORLD, 120.0), "W原版绿色指示线的中心半径为120像素")
	var early_anchor: Array = q_view._buf._weapon_points[0]
	var swing_anchor: Array = q_view._buf._weapon_points[48]
	_expect(Vector3(early_anchor[0],early_anchor[1],early_anchor[2]).distance_to(Vector3(swing_anchor[0],swing_anchor[1],swing_anchor[2])) > 1.0, "Q拖尾挂点来自旋斩动画中的实际武器轨迹")
	q_view.reset_pool_visual()
	_expect(not q_view._cas.visible and not q_view._buf.visible, "模型回收清理Q特效")
	q_view.free()
	source._attacking = false
	source.attack_timeline.cancel(true)
	source.position = Vector2(300,1000)
	source._charged = true
	source.movement_strike.tick(source, 0.05)
	source.stun(1.0)
	source.sim_tick(0.05)
	_expect(source.movement_strike.in_transit() and source.control.stun_timer > 0.0, "眩晕保留当前踢击与剩余时长")
	source.freeze(0.5)
	_expect(not source.movement_strike.in_transit(), "冰冻取消起跳且不补打")
	source.control.hard.clear_family(&"freeze")
	source.control.hard.clear_family(&"stun")
	source.cancel_charge()
	source.attack_timeline.cancel(true)
	source.position = Vector2(300,1000)
	target.position = Vector2(423,1000)
	source._charged = true
	_expect(not source.movement_strike.tick(source,0.05), "两格之外不触发冲刺")
	target.position = Vector2(420,1000)
	_expect(source.movement_strike.tick(source,0.05), "两格内触发冲刺")
	for tick in 40:
		if source.movement_strike.target_ref == null: break
		main._movement.tick(0.05)
		source._move_intent = Vector2.ZERO
		source.movement_strike.tick(source,0.05)
	_expect(source._target_gap(target) >= -0.05 and target.hp == 690.0, "真实移动系统保持身体分离并结算一次冲击")
	source.cancel_charge()
	source.attack_timeline.cancel(true)
	source.position = Vector2(350,700)
	target.position = Vector2(350,580)
	source._charged = true
	_expect(not source.movement_strike.tick(source,0.05), "前侧无合法接触点时不启动跨河踢击")
	source.cancel_charge()
	source.position = Vector2(300,1000)
	target.position = Vector2(370,1000)
	source.attack_timeline.cancel(true)
	source._charged = true
	source.blind_attack_charges = 1
	target.control.hard.clear_family(&"stun")
	target.knockback.cancel(&"test_reset")
	var hp_before := target.hp
	source.movement_strike.tick(source, 0.05)
	for tick in 40:
		if not source.movement_strike.in_transit(): break
		source.global_position += source._move_intent * 0.05
		source._move_intent = Vector2.ZERO
		source.movement_strike.tick(source, 0.05)
	_expect(is_equal_approx(source.position.x, 350.0) and source.blind_attack_charges == 0, "致盲仍完成接触加24像素续冲并消费一次致盲")
	_expect(target.hp == hp_before and target.control.stun_timer == 0.0 and target.knockback.remaining == 0.0, "致盲强化普攻不造成伤害击退眩晕")
	source.position = Vector2(300,1000)
	source.hp = 400.0
	target.hp = 5.0
	source.active_skill_cast_serial += 1 # 冰冻取消后的新施法身份
	main._active_skill_effect_system.activate_continuous_area(source, skill)
	main._active_skill_effect_system.tick_effects(0.5)
	_expect(source.hp == 402.0, "领域过量伤害只按5点实际掉血治疗并遵守统一整数规则")
	source.freeze(1.0)
	main._active_skill_effect_system.tick_effects(0.05)
	_expect(main._active_skill_effect_system.continuous_area_effects.is_empty() and source.buffs.remaining(&"timed_lifesteal") == 0.0, "冰冻同时取消领域和限时吸血")
	var runner := _unit(0, Vector2(150,1000))
	var victim := _unit(1, Vector2(230,1000))
	runner._charged = true
	runner.movement_strike.tick(runner, 0.05)
	for tick in 40:
		if runner.movement_strike.following: break
		runner.position += runner._move_intent * 0.05
		runner._move_intent = Vector2.ZERO
		runner.movement_strike.tick(runner, 0.05)
	var death_endpoint := runner.movement_strike.follow_endpoint
	victim.free()
	for tick in 15:
		if not runner.movement_strike.in_transit(): break
		runner.position += runner._move_intent * 0.05
		runner._move_intent = Vector2.ZERO
		runner.movement_strike.tick(runner, 0.05)
	_expect(runner.position.is_equal_approx(death_endpoint), "命中后目标释放仍完成独立续冲")
	runner.position = Vector2(150,1000)
	runner.attack_timeline.cancel(true)
	var blocker := _unit(1, Vector2(230,1000))
	runner._charged = true
	runner.movement_strike.tick(runner,0.05)
	for tick in 40:
		if runner.movement_strike.following: break
		runner.position += runner._move_intent * 0.05
		runner._move_intent = Vector2.ZERO
		runner.movement_strike.tick(runner,0.05)
	runner.stun(1.0)
	_expect(runner.movement_strike.in_transit() and runner.control.stun_timer > 0.0, "命中后眩晕也不取消落地")
	runner.freeze(0.5)
	_expect(not runner.movement_strike.in_transit() and runner._move_intent.is_zero_approx(), "命中后冰冻取消续冲且不补打")
	blocker.free()
	runner.free()
	source.free()
	if is_instance_valid(target): target.free()
	_check_contact_contract()

func _unit(team: int, point: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, "hecarim", point, {"deploy_time_override": 0.0}))

func _check_w_release() -> void:
	for charged in [false, true]:
		var unit := _unit(0, Vector2(300, 1000))
		var target := _unit(1, Vector2(440 if charged else 340, 1000))
		target.can_attack = false
		unit._charged = charged
		unit._charge_distance_travelled = unit.charge_distance if charged else 0.0
		var skill: Dictionary = CardDB.active_skills_for("hecarim")[0].duplicate(true)
		_expect(_main.runtime._skill_lifecycle.start(unit, skill), "W可启动")
		_expect(unit.is_active_skill_attack_locked() and not unit.is_active_skill_movement_locked(), "W起手只锁攻击不锁移动")
		for tick in 8:
			_main.runtime._commands.tick_impacts(0.05)
			_step_pair(unit)
		_expect(not unit.get_active_buff_active_visual() and unit.get_attack_visual_serial() == 0 and not unit.movement_strike.in_transit(), "W前0.4秒不生效不攻击")
		_main.runtime._commands.tick_impacts(0.05)
		_step_pair(unit)
		_expect(unit.get_active_buff_active_visual() and not unit.is_active_skill_attack_locked(), "W在0.44秒后的第9Tick生效解锁")
		_step_pair(unit)
		_expect(unit.movement_strike.in_transit() if charged else unit.get_attack_visual_serial() > 0, "W生效后直接接续冲刺或普通攻击")
		_main.runtime._commands.clear_impacts()
		_main._active_skill_effect_system.continuous_area_effects.clear()
		unit.free()
		target.free()

func _check_w_upperbody() -> void:
	var model = load("res://assets/units/hecarim/hecarim_view.tscn").instantiate()
	_main.add_child(model)
	var unit := Unit.new()
	unit.hp = 850.0
	unit.buffs.apply(&"timed_lifesteal", &"w_test", 4.0, {})
	unit._buff_visual_start_tick = 0
	unit._buff_visual_duration = 4.0
	model.configure_unit_visual(unit)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	_expect(model._w_upper.tracks.size() > 0, "W原版遮罩解析出上身轨道")
	for clip_name in ["Run", "Spell3run"]:
		player.play(clip_name)
		player.pause()
		var unchanged := true
		var upper_changed := false
		for frame in range(1, 30):
			unit.buffs.tick_index = frame
			player.seek(frame / 20.0, true)
			var before: Array[Transform3D] = []
			for bone in skeleton.get_bone_count(): before.append(skeleton.get_bone_pose(bone))
			model._w_upper._process_modification()
			for name in ["root_b", "waist", "spine", "chest", "r_f_leg", "l_f_leg", "r_b_leg", "l_b_leg"]:
				var bone := skeleton.find_bone(name)
				unchanged = unchanged and before[bone].is_equal_approx(skeleton.get_bone_pose(bone))
			for track in model._w_upper.tracks:
				upper_changed = upper_changed or not before[track.y].is_equal_approx(skeleton.get_bone_pose(track.y))
		_expect(unchanged and upper_changed, "W叠加上身且保留%s马身腿部相位" % clip_name)
	model.free()
	unit.free()

func _step_pair(source: Unit, target: Unit = null) -> void:
	source.sim_tick(0.05)
	if is_instance_valid(target): target.sim_tick(0.05)
	_main._movement.tick(0.05)

func _check_contact_contract() -> void:
	var bad_errors: PackedStringArray = []
	preload("res://scripts/data/card_validator.gd")._validate_combat_stats("bad_contact", {"charge_contact_duration": 0.4}, false, bad_errors)
	_expect(bad_errors.has("bad_contact.charge_follow_duration: 接触续冲需要成组正数"), "仅声明接触时长的残缺配置被拒绝")
	var source := _unit(0, Vector2(300,1000))
	var target := _unit(1, Vector2(350,1000))
	target.can_attack = false
	source._charged = true
	for tick in 8:
		_step_pair(source,target)
		_expect(target.hp == 850.0, "近距离也必须等到0.4秒踢击节点，不提前命中")
	_step_pair(source,target)
	_expect(target.hp == 770.0 and source.movement_strike.following, "第8帧步后节点结算一次踢击")
	for tick in 17: _step_pair(source,target)
	_expect(not source.movement_strike.in_transit() and source._attacking, "落地后立即进入下一次普攻前摇，不等旧冷却")
	source.free()
	target.free()
	# 眩晕不取消起跳，不延长动作，但落地后剩余眩晕继续禁止普攻。
	source = _unit(0,Vector2(300,1000))
	target = _unit(1,Vector2(410,1000))
	target.can_attack = false
	source._charged = true
	_step_pair(source,target)
	source.stun(2.0)
	for tick in 23: _step_pair(source,target)
	_expect(target.hp == 770.0 and not source.movement_strike.in_transit() and source.control.stun_timer > 0.0 and not source._attacking, "眩晕中完成踢击落地，剩余眩晕继续禁止下一击")
	source.control.hard.clear_family(&"stun")
	_step_pair(source,target)
	_expect(source._attacking, "解除剩余眩晕后可立即普攻")
	source.free()
	target.free()
	for invalidation in ["death", "stasis", "untargetable", "teleport"]:
		source = _unit(0,Vector2(300,1000))
		target = _unit(1,Vector2(410,1000))
		target.can_attack = false
		source._charged = true
		_step_pair(source,target)
		match invalidation:
			"death":
				target.free()
				target = null
			"stasis": target.apply_stasis(2.0)
			"untargetable": target.target_protection.begin(target.position, 25.0, 2.0)
			"teleport": target.teleport_to(Vector2(600,800))
		for tick in 23: _step_pair(source,target)
		_expect(not source.movement_strike.in_transit() and not source._charged and UnitLandingQuery.displacement_legal(source,source.position), "起跳后%s仍踢空并完成合法落地且消费资格" % invalidation)
		if is_instance_valid(target):
			_expect(target.hp == 850.0 and target.control.stun_timer == 0.0 and target.knockback.remaining == 0.0, "%s失效目标无伤害和命中控制" % invalidation)
			target.free()
		source.free()
	source = _unit(0,Vector2(300,1000))
	target = _main._spawn_unit(UnitSpawnRequest.new(1,"apex_turret",Vector2(410,1000),{"deploy_time_override":0.0}))
	target.can_attack = false
	source._charged = true
	var building_start := target.position
	var building_hp := target.hp
	for tick in 23: _step_pair(source,target)
	_expect(target.hp < building_hp and target.position.is_equal_approx(building_start) and target.control.stun_timer == 0.0 and target.knockback.remaining == 0.0, "建筑踢击只伤害，不击退或眩晕")
	_expect(UnitLandingQuery.displacement_legal(source,source.position), "建筑阻挡续冲时仍落在合法外沿")
	source.free()
	target.free()
	for control in ["freeze", "stasis", "root", "knockback"]:
		source = _unit(0,Vector2(300,1000))
		target = _unit(1,Vector2(410,1000))
		target.can_attack = false
		source._charged = true
		_step_pair(source,target)
		match control:
			"freeze": source.freeze(1.0)
			"stasis": source.apply_stasis(1.0)
			"root": source.root(1.0)
			"knockback": source.apply_knockback(Vector2(250,1000),40.0,0.5)
		_expect(not source.movement_strike.in_transit() and not source._charged and target.hp == 850.0, "%s中断起跳不补打且清除冲刺" % control)
		source.free()
		target.free()
	source = _unit(0,Vector2(300,1000))
	source._charged = true
	source._move_intent = Vector2.ZERO
	source.on_movement_applied(0.0,0.05)
	_expect(not source._charged, "就绪状态停止移动也清零，起跳消费例外由阶段保护")
	source.free()
