extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var system: ProjectileSystem = main.projectile_service()
	var source := _spawn_ready_unit("sivir", 0, Vector2(280, 900))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(380, 900))
	var beyond := _spawn_ready_unit("target_dummy", 1, Vector2(460, 900))
	var off_line := _spawn_ready_unit("target_dummy", 1, Vector2(380, 970))
	var air := _spawn_ready_unit("nocturne", 1, Vector2(420, 900))
	var friendly := _spawn_ready_unit("target_dummy", 0, Vector2(340, 900))
	for unit in [target, beyond, off_line, air, friendly]: unit.hp = 10000.0
	_expect(system.launch(source, target, 70, 400, 0, 0, Color.WHITE), "往返弹体正式创建")
	var id := source.returning_projectile_id
	_expect(id > 0 and system.projectiles[id].remaining == 200.0, "单枚往返弹体锁与五格行程")
	for tick in 10: system.tick(0.05)
	_expect(system.projectiles[id].returning and system.projectiles[id].pos.is_equal_approx(Vector2(480,900)), "第10Tick精确到五格后折返")
	_expect(target.hp == 9930 and beyond.hp == 9930 and air.hp == 9930, "去程穿透地面、超出锁定射程和空中单位各一次")
	_expect(off_line.hp == 10000 and friendly.hp == 10000, "旁路及友方不命中")
	for tick in 10: system.tick(0.05)
	_expect(target.hp == 9860 and beyond.hp == 9860 and air.hp == 9860, "回程单独去重再各伤害一次")
	_expect(system.projectiles.is_empty() and source.returning_projectile_id == -1, "抵达来源回收并解除攻击锁")
	# 离开路径的主目标不被跟踪；来源移位时回收位置跟随来源。
	system.launch(source, target, 70, 400, 0, 0, Color.WHITE)
	target.position.y += 90
	for tick in 10: system.tick(0.05)
	_expect(target.hp == 9860, "主目标移开不会引导去程转向")
	source.position.y += 40
	for tick in 15: system.tick(0.05)
	_expect(source.returning_projectile_id == -1, "来源移动后仍可接回")
	# 出手后来源受控不会取消在途弹体；清场必须解除实例锁。
	target.position = source.position + Vector2(100, 0)
	system.launch(source, target, 70, 400, 0, 0, Color.WHITE)
	source.stun(3.0)
	for tick in 20: system.tick(0.05)
	_expect(source.returning_projectile_id == -1 and target.hp == 9720, "硬控期间往返独立完成且命中两次")
	system.launch(source, target, 70, 400, 0, 0, Color.WHITE)
	system.clear_all()
	_expect(source.returning_projectile_id == -1, "清场解除待回收状态")
	# 来源死亡不取消已经创建的往返攻击。
	system.launch(source, target, 70, 400, 0, 0, Color.WHITE)
	source.hp = 0.0
	for tick in 20: system.tick(0.05)
	_expect(target.hp == 9580 and system.projectiles.is_empty(), "来源死亡后保留独立结果并回到原点结束")
	var shielded := _spawn_ready_unit("sivir", 0, Vector2(550,900))
	shielded.hp = 100.0
	var skill: Dictionary = CardDB.active_skills_for("sivir")[0]
	_expect(main.preview_active_skill(shielded, skill), "主动技能通过正式工作台入口")
	_expect(shielded.hp == 100.0, "开盾不提前治疗")
	var interaction := CombatInteraction.effect_context(target)
	interaction.delivery = CombatInteraction.Delivery.new()
	_expect(CombatInteraction.blocks_effect(shielded, interaction), "护盾抵挡敌方效果")
	_expect(shielded.hp == 220.0 and shielded.buffs.remaining(&"effect_shield") == 0.0, "成功抵挡治疗120并消费盾")
	_expect(CombatInteraction.blocks_effect(shielded, interaction) and shielded.hp == 220, "同一Delivery附带效果整体抵挡且治疗只一次")
	shielded.hp = 530
	shielded.apply_effect_shield(1.5, 0, 1, &"test", 120)
	shielded.consume_effect_shield()
	_expect(shielded.hp == 560, "治疗封顶且复用通用治疗")
	shielded.hp = 100
	shielded.apply_effect_shield(0.1, 0, 1, &"test", 120)
	for tick in 2: shielded._tick_active_statuses(0.05)
	_expect(shielded.hp == 100 and shielded.buffs.remaining(&"effect_shield") == 0.0, "自然到期不奖励治疗")
	var invalid: Dictionary = CardDB.get_card("sivir").duplicate(true)
	invalid.returning_attack_distance = -1.0
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"sivir":invalid}, false).is_empty(), "拒绝无效往返距离")
	invalid = CardDB.get_card("sivir").duplicate(true)
	invalid.active_skills[0].block_heal = -1.0
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"sivir":invalid}, false).is_empty(), "拒绝无效抵挡治疗")

	# Run complete authoritative attack cycles; a fast attack buff cannot create
	# a second blade before the previous one is caught.
	for unit in [source, target, beyond, off_line, air, friendly, shielded]: unit.can_attack = false
	var cadence := _spawn_ready_unit("sivir", 0, Vector2(220,1050))
	cadence.move_speed = 0
	cadence.apply_attack_speed_buff(&"sivir_test", &"sivir_test", 8.0, {"attack_speed":3.0})
	var stationary := _spawn_ready_unit("target_dummy", 1, Vector2(320,1050))
	stationary.can_attack = false
	stationary.move_speed = 0
	stationary.hp = 10000
	var exclusive := true
	var no_early_attack := true
	var waiting_serial := -1
	var captured := false
	for tick in 65:
		var had_blade := cadence.returning_projectile_id >= 0
		var serial := cadence.get_attack_visual_serial()
		_run_main_ticks(1)
		if had_blade and cadence.returning_projectile_id >= 0:
			no_early_attack = no_early_attack and cadence.get_attack_visual_serial() == serial
		var count := 0
		for projectile in system.projectiles.values():
			if projectile.get("attacker") == cadence: count += 1
		exclusive = exclusive and count <= 1
		captured = captured or (had_blade and cadence.returning_projectile_id < 0)
		waiting_serial = maxi(waiting_serial, cadence.get_attack_visual_serial())
	_expect(exclusive and no_early_attack and captured and waiting_serial >= 2, "正式攻击循环：攻速增加也须逐枚接回后重新前摇")
	_expect(cadence.battle_context.has_owned_projectile_visual(cadence, &"sivir_blade") == (cadence.returning_projectile_id >= 0), "武器隐藏读取正式弹体表现集合")
	# With no target in range, wait in place until catch; choose a newly arrived
	# target before deciding whether to walk.
	system.clear_all()
	cadence.can_attack = false
	for old_target in [target, beyond, off_line, air, stationary]: old_target.position = Vector2(630,300)
	var waiting := _spawn_ready_unit("sivir", 0, Vector2(300,1100))
	var departing := _spawn_ready_unit("target_dummy", 1, Vector2(400,1100))
	departing.can_attack = false
	departing.move_speed = 0
	system.launch(waiting, departing, 70, 400, 0, 0, Color.WHITE)
	departing.position = Vector2(600,700)
	var wait_origin := waiting.position
	_run_main_ticks(12)
	_expect(waiting.position.is_equal_approx(wait_origin), "等待回旋镖期间目标离开也不自主移动")
	var newcomer := _spawn_ready_unit("target_dummy", 1, wait_origin + Vector2(90,0))
	newcomer.can_attack = false
	newcomer.move_speed = 0
	_run_main_ticks(9)
	_expect(waiting.position.is_equal_approx(wait_origin) and waiting.get_attack_visual_serial() > 0 and waiting._target == newcomer, "接回后优先对新进入射程的目标重新起手")
	# Asset regression: source offsets must survive conversion and the shield
	# must stay above the floor even when the attack pose bends its center bone.
	var model := load("res://assets/units/sivir/sivir_view.tscn").instantiate() as Node3D
	main.add_child(model)
	var fx := load("res://assets/effects/sivir/shield.tscn").instantiate() as Node3D
	main.add_child(fx)
	fx.configure(20, 0)
	fx.bind_model(model)
	fx.advance(true, 0.2)
	var position_before: Vector3 = fx.global_position
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	skeleton.set_bone_pose_position(skeleton.find_bone("C_Buffbone_Glb_Center_Loc"), Vector3(0, -2, 0))
	fx.advance(true, 0.1)
	_expect(fx.global_position.is_equal_approx(position_before), "护盾锚点不随投掷弯腰下沉")
	var minimum := INF
	for particle in fx.shield._particles:
		if particle.c.name in ["Sphere", "spheredetail"]:
			var mesh := particle.node as MeshInstance3D
			minimum = minf(minimum, (mesh.global_transform * mesh.get_aabb()).position.y)
	_expect(minimum > 0.15 and minimum < 0.4, "护盾球壳离地且保持中体型包围尺寸")
	_expect(fx.definitions.shield[0].birthOffset.base[1] == 85.0 and fx.definitions.block[0].birthOffset.base[1] == 95.0, "护盾/抵挡源发射高度不被零默认值覆盖")
	var attached_positions: Dictionary = {}
	for particle in fx.shield._particles: attached_positions[particle.node.get_instance_id()] = particle.node.global_position
	model.position.x += 2.0
	fx.advance(true, 0.2)
	var follows := true
	for particle in fx.shield._particles:
		var particle_id: int = particle.node.get_instance_id()
		if attached_positions.has(particle_id): follows = follows and absf(particle.node.global_position.x - attached_positions[particle_id].x - 2.0) < 0.001
	_expect(follows, "护盾所有已发射层随角色平移，不留下衰减球壳")
	fx.on_cue(&"effect_shield:block")
	_expect(not is_instance_valid(fx.shield) and fx.bursts.size() == 1, "抵挡当帧销毁持续盾，仅创建独立proc")
	fx.advance(true, 0.05)
	_expect(not is_instance_valid(fx.shield), "迟到的启用状态不重建已消费护盾")
	fx.advance(false, 1.1)
	_expect(fx.bursts.is_empty() and not fx.visible, "抵挡反馈按原始粒子寿命结束，无额外保留计时")
	fx.on_cue(&"effect_shield:start")
	fx.advance(true, 0.1)
	fx.advance(false, 0.01)
	_expect(not is_instance_valid(fx.shield) and fx.bursts.is_empty() and not fx.visible, "自然到期立即清除护盾，不伪造抵挡反馈")
	model.free()
	fx.free()
