extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_pre_deployment()
	_check_directional_comet()
	_check_medium_scale()
	_check_payment()
	_check_visual_contract()
	_check_animation_routes()
	_check_resource_audio()
	var skill: Dictionary = CardDB.active_skills_for("pantheon")[0]
	for team in [0, 1]:
		_expect(_main.is_card_deploy_position_valid(team, "pantheon", Vector2(360, 400 if team == 0 else 880)), "敌方半场合法地面允许部署")
		_expect(not _main.is_card_deploy_position_valid(team, "pantheon", Vector2(360, 640)), "全图部署仍拒绝河道")
		var same_zone := true
		for x in range(20, 720, 40):
			for y in range(20, 1280, 40):
				var point := Vector2(x, y)
				same_zone = same_zone and _main.is_card_deploy_position_valid(team, "pantheon", point) == _main.is_card_deploy_position_valid(team, "twisted_fate", point)
		_expect(same_zone, "双方全场逐格部署范围与卡牌大师一致")
		var source: Unit = _main._spawn_unit(team, "pantheon", Vector2(360, 900), 0.0)
		source.add_skill_resource(4)
		_expect(source.skill_resource_value == 0, "未携带主动时不获得红怒")
		source.configure_carried_active_skill(skill)
		source.skill_resource_value = 3
		_expect(source.get_skill_resource_fill_color() == Unit.SKILL_RESOURCE_UNFILLED_COLOR, "未满四层保持白条")
		source.skill_resource_value = 4
		_expect(source.get_skill_resource_fill_color() == Color(0.65, 0.045, 0.07, 1.0), "四层改用暗深红色")
		for stacks in range(5):
			source.skill_resource_value = stacks
			var prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(source, skill)
			_expect(source.skill_resource_value == (0 if stacks == 4 else stacks + 1), "仅满四层消费，未满保留并加一层")
			_expect(prepared.damage == (240 if stacks == 4 else 120), "按释放前层数判定强化，三层释放仍为普通伤害")
			_expect(String(prepared.visual_action) == ("spear_tap_empowered" if stacks == 4 else "spear_tap"), "红怒强弱音画与本次伤害使用同一快照")
		source.add_skill_resource(9)
		_expect(source.skill_resource_value == 4, "红怒不能超过四层")
		source.clear_carried_active_skill_resource()
		_expect(not source.skill_resource_enabled and source.skill_resource_value == 0, "主动资格替换清理红怒")
		var enemy: Unit = _main._spawn_unit(1-team, "garen", source.position + Vector2(0, -60), 0.0)
		var ally: Unit = _main._spawn_unit(team, "garen", source.position + Vector2(0, -60), 0.0)
		var air: Unit = _main._spawn_unit(1-team, "anivia", source.position + Vector2(0, -60), 0.0)
		var behind: Unit = _main._spawn_unit(1-team, "garen", source.position + Vector2(0, 80), 0.0)
		var before: Array = [enemy.hp, ally.hp, air.hp, behind.hp]
		_main._active_skill_effect_system.apply_frontal(source, skill, Vector2.UP)
		_expect(enemy.hp == before[0] - 120 and ally.hp == before[1] and air.hp == before[2] and behind.hp == before[3], "短Q仅刺中前方地面敌人")
		var edge := source.body_radius + float(skill.length) + enemy.body_radius
		enemy.position = source.position + Vector2.UP * (edge - 0.5)
		var edge_hp := enemy.hp
		_main._active_skill_effect_system.apply_frontal(source, skill, Vector2.UP)
		_expect(enemy.hp == edge_hp - 120, "短Q新边界内命中")
		enemy.position = source.position + Vector2.UP * (edge + 0.5)
		edge_hp = enemy.hp
		_main._active_skill_effect_system.apply_frontal(source, skill, Vector2.UP)
		_expect(enemy.hp == edge_hp, "短Q新边界外不命中，旧长范围已移除")
		before = [enemy.hp, ally.hp, air.hp, behind.hp]
		source._perform_deploy_sweep()
		_expect(enemy.hp == before[0] and behind.hp == before[3] and ally.hp == before[1] and air.hp == before[2], "真正单位生成不再附加第二次登场伤害")
		for unit in [source, enemy, ally, air, behind]: unit.free()
	var invalid: Dictionary = CardDB.get_card("pantheon").duplicate(true)
	invalid.active_skills[0].resource_consume_only_full = "true"
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"pantheon": invalid}, false).is_empty(), "拒绝错误类型的满层消费开关")
	invalid = CardDB.get_card("pantheon").duplicate(true)
	invalid.active_skills[0].resource_nonfull_cast_gain = -1
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"pantheon": invalid}, false).is_empty(), "拒绝负数施法增怒")

func _check_payment() -> void:
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "pantheon"
	var source: Unit = _main._spawn_unit(0, "pantheon", Vector2(360, 1000), 0.0, 0)
	var ability := source.active_ability_id
	source.move_speed = 0.0
	_main._elixir.elixir = 10
	source.skill_resource_value = 3
	_expect(_main.use_active_skill(ability, 0) and _main._elixir.elixir == 9.0 and source.skill_resource_value == 3, "请求扣1金币，排队不提前改变红怒")
	_main._sim_tick_id += 10
	_main._tick_pending_active_skills(0.05)
	_expect(source.skill_resource_value == 4 and _main._active_skills.entry(ability).uses_remaining == 2 and _main._active_skills.entry(ability).cooldown_left == 4.0, "开始时增加红怒、扣次数并启动4秒冷却")
	_expect(not _main.use_active_skill(ability, 0), "冷却中不可重复请求")
	source.prepare_action_clocks(4.0)
	_main._tick_active_skill_cooldowns(4.0)
	_expect(_main.use_active_skill(ability, 0) and _main._elixir.elixir == 8.0, "4秒后允许第二次释放")
	_main._sim_tick_id += 10
	_main._tick_pending_active_skills(0.05)
	_expect(source.skill_resource_value == 0 and _main._active_skills.entry(ability).uses_remaining == 1, "第二次满怒释放清空红怒并保留最后一次")
	source.prepare_action_clocks(4.0)
	_main._tick_active_skill_cooldowns(4.0)
	_expect(_main.use_active_skill(ability, 0) and _main._elixir.elixir == 7.0, "第三次仍扣1金币")
	_main._sim_tick_id += 10
	_main._tick_pending_active_skills(0.05)
	_expect(source.skill_resource_value == 1 and _main._active_skills.entry(ability).uses_remaining == 0, "第三次普通Q增怒并耗尽次数")
	source.prepare_action_clocks(4.0)
	_main._tick_active_skill_cooldowns(4.0)
	_expect(not _main.use_active_skill(ability, 0) and _main._elixir.elixir == 7.0, "三次耗尽拒绝且不再扣费")
	source.free()
	_main._deck = deck

func _check_visual_contract() -> void:
	var stats: Dictionary = CardDB.get_card("pantheon")
	_expect(stats.size_tier == CardDB.SIZE_MEDIUM and stats.radius == CardDB.RADIUS_MEDIUM, "中体型与权威半径")
	_expect(stats.deploy_zone == CardDB.get_card("twisted_fate").deploy_zone, "与卡牌大师相同部署范围")
	_expect(stats.visual_animations.deploy == ["Spell4_Hit", "Spell4_Hit_ToIdle"], "落地和收势完整部署序列")
	var model = load(stats.visual_scene_path).instantiate()
	_main.add_child(model)
	model.prepare_visual_animations()
	_expect(model._rage_materials.size() >= 4, "满怒附着在武器及身体部件")
	model.advance_skill_resource_visual(true, 0.1)
	_expect(model._rage_materials[0].get_shader_parameter("strength") == 1.0, "满四层立即显现模型特效")
	model.advance_skill_resource_visual(false, 0.1)
	_expect(model._rage_materials[0].get_shader_parameter("strength") == 0.0, "耗怒或失去资格立即停止附着")
	model.update_animation_parts(&"Death", 76.0 / 30.0)
	_expect(model._body_mesh.mesh == model._living_mesh, "死亡切换节点前保留戴盔头")
	model.update_animation_parts(&"Death", 77.0 / 30.0)
	_expect(model._body_mesh.mesh == model._death_mesh and model._helmet_snap.active, "死亡第77帧显示Head并启用原生头盔挂点")
	_expect(model._death_mesh.get_surface_count() == model._living_mesh.get_surface_count(), "死亡只替换头部，不丢武器披风双臂")
	model.reset_pool_visual()
	_expect(model._body_mesh.mesh == model._living_mesh and not model._helmet_snap.active, "池复用恢复戴盔头与普通头盔骨骼")
	_expect(not model._rage_full, "回收清理满怒表现")
	model.free()

func _check_animation_routes() -> void:
	var stats := CardDB.get_card("pantheon").duplicate(true)
	stats.deploy_time = 0.0
	_expect(absf(0.299 - float(stats.first_hit)) < 0.021 and absf(0.26 - float(stats.first_hit)) < 0.021, "共用0.28秒近似节点与三种原动作误差不超过0.02秒")
	var unit := Unit.new()
	unit.setup(0, stats, stats.name)
	unit._attacking = true
	_main.add_child(unit)
	_expect(_main._battle_presentation.attach_unit(unit, stats), "真实3D代理加载潘森")
	for child in _main._battle_presentation._world_root.get_children():
		if not child is UnitModel3D or child._source != unit: continue
		var view := child as UnitModel3D
		for serial in range(1, 9):
			var index := (serial - 1) % 4
			view._play_attack(serial)
			_expect(view._active_attack_animation == [&"Attack1", &"Attack2", &"Attack3", &"Attack2"][index], "两轮攻击顺序1-2-3-2")
			view._update_attack_stages(unit.first_hit_time + 0.001)
			_expect(not view._attack_hit_pending and is_equal_approx(view._attack_clip_start, 0.0) and is_equal_approx(view._attack_clip_end, 0.9), "各普攻保持单段连续播放，不在命中处拆分")
			view._transition_to_basic_state(2, -1.0, &"attack")
			_expect(view._animation_player.current_animation == &"Run_Base", "未满怒普攻退出接基础跑步")
		unit._attacking = false
		unit._move_intent = Vector2.UP
		unit.configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
		for stacks in range(5):
			unit.skill_resource_value = stacks
			view._play_attack(1)
			view._transition_to_basic_state(2, -1.0, &"attack")
			if stacks == 4:
				_expect(view._animation_player.current_animation == &"Attack1_To_PassiveRun", "满怒普攻接强化转跑")
				view._on_animation_finished(&"Attack1_To_PassiveRun")
			_expect(view._animation_player.current_animation == (&"Run_Passive" if stacks == 4 else &"Run_Base"), "只有满四层使用强化跑步")
			view._play_visual_action(&"spear_tap")
			view._seek_visual_action(0.3)
			view._finish_visual_action()
			var transition := &"Spell1_Hit_To_Passiverun" if stacks == 4 else &"Spell1_Hit_Torun"
			_expect(view._animation_player.current_animation == transition, "短Q按当前红怒选择转跑")
			view._on_animation_finished(transition)
			_expect(view._animation_player.current_animation == (&"Run_Passive" if stacks == 4 else &"Run_Base"), "短Q转跑结束保持正确循环")
		view.free()
		break
	unit.free()

func _check_resource_audio() -> void:
	var manager: GameAudioManager = _main._audio_manager
	manager.begin_battle()
	var cues: Array[StringName] = []
	var callback := func(card: String, cue: StringName, _position: Vector2):
		if card == "pantheon": cues.append(cue)
	manager.cue_played.connect(callback)
	var unit: Unit = _main._spawn_unit(0, "pantheon", Vector2(360, 900), 0.0)
	manager.attach_unit(unit, CardDB.get_card("pantheon"))
	unit.add_skill_resource(4)
	manager._tick_attached_units()
	_expect(cues.count(&"resource_full") == 0, "未携带技能不会误响满怒音")
	unit.configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
	unit.add_skill_resource(3)
	manager._tick_attached_units()
	unit.add_skill_resource(1)
	manager._tick_attached_units()
	unit.add_skill_resource(1)
	manager._tick_attached_units()
	_expect(cues.count(&"resource_full") == 1, "进入四层播放一次，满层继续普攻不重播")
	unit.consume_skill_resource_ratio()
	manager._tick_attached_units()
	unit.add_skill_resource(3)
	manager._tick_attached_units()
	_main._active_skill_effect_system.prepare_cast(unit, CardDB.active_skills_for("pantheon")[0])
	manager._tick_attached_units()
	_expect(cues.count(&"resource_full") == 2, "三层普通Q叠满也响满怒音")
	unit.take_damage(99999)
	_expect(cues.count(&"death") == 1 and cues.count(&"death:voice") == 1, "死亡原生SFX与中文语音分别接入")
	manager.cue_played.disconnect(callback)
	unit.free()
	manager.begin_battle()

func _check_pre_deployment() -> void:
	var presentation: BattlePresentation3D = _main._battle_presentation
	var path := preload("res://scripts/battle/pre_deployment_sweep.gd")
	var stats := CardDB.get_card("pantheon")
	for team in [0, 1]:
		var center: Vector2 = _main._snap_card_position("pantheon", Vector2(360, 900 if team == 0 else 380), team)
		var forward := Vector2.UP if team == 0 else Vector2.DOWN
		var rear := path.start_position(center, team, stats)
		_expect(rear == center - forward * 120.0, "双方彗星着地位置都在下牌点己方侧3格")
		var enemy: Unit = _main._spawn_unit(1-team, "garen", rear + Vector2(60, 0), 0.0)
		var far: Unit = _main._spawn_unit(1-team, "garen", center + forward * 80.0, 0.0)
		var ally: Unit = _main._spawn_unit(team, "garen", rear, 0.0)
		var air: Unit = _main._spawn_unit(1-team, "anivia", rear, 0.0)
		var outside: Unit = _main._spawn_unit(1-team, "garen", center + Vector2(160, 0), 0.0)
		var hp: Array = [enemy.hp, far.hp, ally.hp, air.hp, outside.hp]
		var count := _main.get_tree().get_nodes_in_group("combatants").size()
		_main.play_card(team, "pantheon", center, {"immediate": true, "validate_position": false})
		var pending: Array = _main._commands.inspect_deployments()
		_expect(pending.size() == 1 and enemy.hp == hp[0], "长矛落下不提前造成伤害")
		presentation.sync_pre_deployments(pending)
		presentation.sync_pre_deployments(pending)
		_expect(presentation._pre_deploy_views.size() == 1, "重复快照不重复创建预部署表现")
		var view: PreDeploymentVisual3D = presentation._pre_deploy_views[int(pending[0].id)].view
		view.advance_visual(0.1 / 1.3)
		var spear_delta: Vector3 = view._spear.position - view.ground(center)
		_expect(is_equal_approx(spear_delta.y, Vector2(spear_delta.x, spear_delta.z).length() * view.VISUAL_RISE) and spear_delta.dot(view._direction) < 0.0, "长矛从己方侧按镜头补偿倾角斜落")
		view.advance_visual(0.65 / 1.3)
		_expect(view._ghost.position.distance_to(view.ground(rear)) < 0.001, "彗星准确落在后方3格")
		view.advance_visual(1.0)
		_expect(view._ghost.position.distance_to(view.ground(center)) < 0.001 and enemy.hp == hp[0], "表现推进到终点不结算伤害")
		for tick in 12: _main._tick_pending_card_pre_deployments(0.05)
		_expect(enemy.hp == hp[0] and far.hp == hp[1], "前12Tick长矛和空中阶段无伤害")
		_main._tick_pending_card_pre_deployments(0.05)
		_expect(enemy.hp == hp[0] - 100 and far.hp == hp[1], "第13Tick后方着地先命中近处，未波及前方不扣血")
		for tick in 12: _main._tick_pending_card_pre_deployments(0.05)
		_expect(_main.get_tree().get_nodes_in_group("combatants").size() == count, "滑行冲击波没有单位、碰撞或可攻击实体")
		_expect(enemy.hp == hp[0] - 100 and far.hp == hp[1] - 100, "波前推进才命中前方，沿途每人一次")
		_expect(ally.hp == hp[2] and air.hp == hp[3] and outside.hp == hp[4], "不伤友军、空军和范围外目标")
		_main._tick_pending_card_pre_deployments(0.05)
		var unit: Unit = _main._latest_unit_for_card("pantheon", team)
		_expect(unit != null and unit.position.distance_to(center) < 0.001 and unit._deploy_timer == 1.0, "第26Tick抵达长矛后生成并开始完整1秒拿矛收势")
		_expect(enemy.hp == hp[0] - 100 and far.hp == hp[1] - 100, "拿矛时不重复结算登场伤害")
		presentation.sync_pre_deployments(_main._commands.inspect_deployments())
		_expect(presentation._pre_deploy_views.is_empty() and not view.visible, "实体生成移除残影")
		for actor in [unit, enemy, far, ally, air, outside]: actor.free()
	# 权威跨步扫掠必须覆盖两帧之间，不漏过整段路径；取消和视觉副本不得伤害。
	var enemy: Unit = _main._spawn_unit(1, "garen", Vector2(360, 840), 0.0)
	var hp := enemy.hp
	_main.play_card(0, "pantheon", Vector2(360, 780), {"immediate": true, "validate_position": false})
	_main._commands.tick_deployment_visuals(0.7)
	_expect(enemy.hp == hp, "客户端计时入口不能触发伤害")
	_main._commands.clear_deployments()
	_main._tick_pending_card_pre_deployments(2.0)
	_expect(enemy.hp == hp, "清场取消未完成冲击波")
	_main.play_card(0, "pantheon", Vector2(360, 780), {"immediate": true, "validate_position": false})
	_main._tick_pending_card_pre_deployments(1.3)
	_expect(enemy.hp == hp - 100, "一次跨完整滑行也扫过路径中间的敌人")
	_main._latest_unit_for_card("pantheon", 0).free()
	enemy.free()
	# 两次独立出牌分别命中，单次排程的命中记录不会被另一排程复用。
	var victim: Unit = _main._spawn_unit(1, "garen", Vector2(360, 840), 0.0)
	hp = victim.hp
	for cast in 2:
		_main.play_card(0, "pantheon", Vector2(360, 780), {"immediate": true, "validate_position": false})
	_main._tick_pending_card_pre_deployments(0.65)
	_expect(victim.hp == hp - 200, "两次独立登场各结算一次，命中集合不共享")
	_main._commands.clear_deployments()
	victim.free()
	var tower: Tower = _main._towers[0]
	var tower_hp := tower.hp
	var entry := {"card_id": "pantheon", "team": 1 - tower.team, "pos": tower.global_position}
	path.advance(entry, 0.0, 1.3, [tower])
	path.advance(entry, 0.0, 1.3, [tower])
	_expect(tower.hp == tower_hp - 100, "地面冲击波伤害建筑，同一条目重复推进不会重复扣血")
	for field in ["pre_deploy_sweep_start", "pre_deploy_sweep_distance", "pre_deploy_sweep_radius", "pre_deploy_sweep_damage"]:
		for bad in [-1.0, "wrong"]:
			var invalid := stats.duplicate(true)
			invalid[field] = bad
			_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"pantheon": invalid}, false).is_empty(), "拒绝非法预部署冲击波字段")
	var invalid := stats.duplicate(true)
	invalid.pre_deploy_sweep_start = invalid.pre_deploy_time
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"pantheon": invalid}, false).is_empty(), "拒绝滑行起点不早于单位生成")
	invalid = stats.duplicate(true)
	invalid.deploy_sweep_damage = 100
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"pantheon": invalid}, false).is_empty(), "禁止预部署和生成双重伤害")
	var events: Dictionary = stats.audio.events
	_expect(events.has("pre_deploy:start") and not events.has("deploy:start"), "登场音轨覆盖长矛彗星冲击，拿矛时不重复播放落地声音")

func _check_directional_comet() -> void:
	var presentation: BattlePresentation3D = _main._battle_presentation
	var before := _main.get_tree().get_nodes_in_group("combatants").size()
	var native := preload("res://assets/units/pantheon/r_original/particles.gd")
	_expect(native.systems().size() == 6, "六组原版系统支撑插地、飞行、滑行、掀土、撞地与余波")
	for definitions: Array in native.systems().values():
		for definition: Dictionary in definitions:
			_expect(definition.offset.size() == 3 and definition.birthOffset.base.size() == 3, "原版出生偏移正确解析为vec3，不混入嵌套概率表")
	for team in [0, 1]:
		var view := preload("res://assets/units/pantheon/pantheon_arrival.tscn").instantiate()
		presentation._world_root.add_child(view)
		view.setup(presentation._world_root.get_viewport().get_camera_3d(), Vector2(340, 820), team)
		view.advance_visual(0.1 / 1.3)
		var sky_screen: Vector2 = view.camera.unproject_position(view._spear.position)
		var end_screen: Vector2 = view.camera.unproject_position(view._end)
		_expect((sky_screen.y - end_screen.y) * (1.0 if team == 0 else -1.0) > 0.0, "画面长矛从己方侧向敌方推进")
		var basis: Basis = view._spear.basis
		var grip: Vector3 = -basis.y.normalized()
		_expect(grip.y > 0.0 and grip.dot(view._direction) < 0.0, "枪柄向后上方倾斜")
		view.advance_visual(0.4 / 1.3)
		_expect(view._spear.basis.is_equal_approx(basis) and view._spear.position.is_equal_approx(view._end), "下落与斜插保持同一长矛和倾角")
		_expect(view._comet._effects.has("update_missile") and not view._comet._effects.has("Damage_Mis"), "空中启用原版彗星，未提前显示地面伤害波")
		view.advance_visual(0.85 / 1.3)
		var wave: Node3D = view._comet._effects.Damage_Mis
		_expect(wave.global_basis.y.dot(view._direction) > 0.999 and wave.global_basis.z.dot(Vector3.UP) > 0.999, "双方原版波的局部+Y转换为前进方向、+Z转换为高度")
		_expect(view._comet._effects.Sliding_Comet.global_position.distance_to(view._ghost.position) < 0.001 and wave.global_position.distance_to(view._ghost.position) < 0.001, "原版火光与掀土波跟随同一权威滑行点")
		_expect(view._proxy.scale.is_equal_approx(Vector3.ONE * view.METRICS.PROP_SCALE) and view._spear.scale.is_equal_approx(view._proxy.scale), "剪影与长矛按中体型比例同步缩小")
		for particle: Dictionary in view._comet._effects.Sliding_Comet._particles:
			if String(particle.c.mesh).contains("wave_comet_mesh"):
				var tail_direction: Vector3 = -particle.node.global_basis.x.normalized()
				_expect(tail_direction.dot(view._direction) < -0.999, "原版彗星网格-X尾部朝后，不从侧面伸出")
		_expect(not view._comet._effects.has("Ending_Shockwave"), "收尾余波不得提前叠加在滑行中途")
		var ending := preload("res://assets/units/pantheon/pantheon_view.tscn").instantiate()
		presentation._world_root.add_child(ending)
		ending.global_transform = Transform3D(Basis(Vector3.UP, atan2(view._direction.x, view._direction.z)), view._end)
		ending.advance_deployment_visual(0.1, 1.0, true)
		var tail: Node3D = ending._ending_wave
		var anchor: Vector3 = tail.global_position
		var front: MeshInstance3D = tail._particles[0].node
		var first: Vector3 = front.global_position
		ending.rotation.y += PI / 2.0
		ending.position.x += 3.0
		ending.advance_deployment_visual(0.3, 1.0, true)
		var travel: Vector3 = front.global_position - first
		_expect(travel.dot(view._direction) > 0.1 and absf(travel.dot(view._direction.cross(Vector3.UP))) < 0.001, "收尾波真实粒子沿前方推进，无横向漂移")
		_expect(tail.global_position.is_equal_approx(anchor) and front.global_basis.y.normalized().dot(Vector3.UP) > 0.999, "收尾波固定到点位置，单位转身/推挤不扭转波头且网格向上")
		ending.advance_deployment_visual(0.95, 1.0, true)
		_expect(ending._ending_wave == null, "收尾余波结束完整回收")
		ending.reset_pool_visual()
		ending.advance_deployment_visual(0.1, 1.0, true)
		ending.advance_deployment_visual(0.2, 1.0, false)
		_expect(ending._ending_wave == null, "死亡/取消立即清除余波，池复用可再次创建")
		ending.free()
		# Isolate a falling rock in a +Y-forward frame: world gravity must not
		# become local backward acceleration as it did before this correction.
		var gravity := native.new()
		presentation._world_root.add_child(gravity)
		gravity.global_basis = wave.global_basis
		var rock: Dictionary = native.systems().Damage_Mis[10].duplicate(true)
		rock.birthVelocity = {"base": [0, 0, 0]}
		rock.birthOffset = {"base": [0, 0, 0]}
		rock.birthAcceleration = {"base": [0, 0, 0]}
		rock.worldAcceleration = {"base": [0, -2500, 0]}
		rock.life = {"base": 1.0}
		gravity._spawn(rock, 0.0, native._material(rock))
		gravity.advance(0.2)
		var fall: Vector3 = gravity._particles[0].node.global_position
		_expect(fall.y < -0.1 and absf(fall.dot(view._direction)) < 0.001, "世界重力向下，不随飞行/滑行基底旋转")
		gravity.free()
		var stripe_centers: Array[float] = []
		for particle: Dictionary in wave._particles:
			if String(particle.c.mesh).contains("mis_air_streaks"):
				var mesh_node: MeshInstance3D = particle.node
				var center: Vector3 = mesh_node.global_transform * mesh_node.mesh.get_aabb().get_center()
				stripe_centers.append((center - view._ghost.global_position).dot(view._direction.cross(Vector3.UP)))
		_expect(stripe_centers.size() == 2 and absf(stripe_centers[0] + stripe_centers[1]) < 0.001, "原版黄色空气线两组几何中心对称于人物滑行轴")
		for particle: Dictionary in wave._particles:
			if particle.c.ground and String(particle.c.mesh).is_empty():
				_expect(particle.node.global_basis.z.normalized().dot(Vector3.UP) > 0.999 and absf(particle.node.global_position.y - 0.045) < 0.001, "原版地面标记法线向上并贴地")
		for effect: Node3D in view._comet._effects.values():
			effect.stop_emitting()
			effect.advance(20.0)
			_expect(effect._particles.is_empty(), "原版粒子到期完整回收")
		view.free()
	_expect(_main.get_tree().get_nodes_in_group("combatants").size() == before, "原版特效不创建战斗对象")

func _check_medium_scale() -> void:
	var heights: Array[float] = []
	for card in ["pantheon", "twisted_fate"]:
		var stats := CardDB.get_card(card)
		var model = load(stats.visual_scene_path).instantiate()
		_main.add_child(model)
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		player.play(stats.visual_animations.idle)
		player.seek(0.1, true)
		player.advance(0.0)
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var head: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
		heights.append(head.y)
		if card == "pantheon":
			_expect(model.get_node("Model").scale == Vector3.ONE * preload("res://assets/units/pantheon/visual_metrics.gd").BODY_SCALE, "中体型包装缩放与共享表现标尺一致")
		model.free()
	_expect(absf(heights[0] - heights[1]) < 0.08, "潘森待机头高与中体型卡牌大师对齐，避免高于大型盖伦")
	var stats := CardDB.get_card("pantheon")
	_expect(stats.radius == CardDB.RADIUS_MEDIUM and stats.pre_deploy_sweep_distance == 120.0 and stats.pre_deploy_sweep_radius == 90.0 and stats.active_skills[0].length == 120.0, "中体型保持身体、三格路径和冲击波范围，短Q收至120")
