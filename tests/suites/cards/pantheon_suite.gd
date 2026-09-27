extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_pre_deployment()
	_check_directional_comet()
	_check_arrival_sampling()
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
		var source: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "pantheon", Vector2(360, 900), {"deploy_time_override": 0.0}))
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
		var enemy: Unit = _main._spawn_unit(UnitSpawnRequest.new(1-team, "garen", source.position + Vector2(0, -60), {"deploy_time_override": 0.0}))
		var ally: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "garen", source.position + Vector2(0, -60), {"deploy_time_override": 0.0}))
		var air: Unit = _main._spawn_unit(UnitSpawnRequest.new(1-team, "anivia", source.position + Vector2(0, -60), {"deploy_time_override": 0.0}))
		var behind: Unit = _main._spawn_unit(UnitSpawnRequest.new(1-team, "garen", source.position + Vector2(0, 80), {"deploy_time_override": 0.0}))
		var before: Array = [enemy.hp, ally.hp, air.hp, behind.hp]
		_main._active_skill_effect_system.apply_frontal(source, skill, Vector2.UP)
		_expect(enemy.hp == before[0] - 120 and ally.hp == before[1] and air.hp == before[2] and behind.hp == before[3], "短Q仅刺中前方地面敌人")
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
	var source: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "pantheon", Vector2(360, 1000), {"deploy_time_override": 0.0, "active_slot": 0}))
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
		unit.configure_carried_active_skill(CardDB.active_skills_for("pantheon")[0])
		for full in [false, true]:
			unit.skill_resource_value = 4 if full else 0
			unit._attacking = true
			for serial in range(1, 9):
				var index := (serial - 1) % 4
				var attack: StringName = [&"Attack1", &"Attack2", &"Attack3", &"Attack2"][index]
				view._play_attack(serial)
				_expect(view._active_attack_animation == attack, "两轮攻击顺序1-2-3-2，满怒=%s" % full)
				view._update_attack_stages(unit.first_hit_time + 0.001)
				_expect(not view._attack_hit_pending and is_equal_approx(view._attack_clip_start, 0.0) and is_equal_approx(view._attack_clip_end, 0.9), "各普攻保持单段连续播放，不在命中处拆分")
				view._transition_to_basic_state(2, -1.0, &"attack")
				if full:
					var transition := StringName(String(attack) + "_To_PassiveRun")
					_expect(view._animation_player.current_animation == transition, "满怒普攻接各段对应PassiveRun过渡")
					view._on_animation_finished(transition)
				_expect(view._animation_player.current_animation == (&"Run_Passive" if full else &"Run_Base"), "普攻出口按实际红怒选择跑步循环")
			unit._attacking = false
			unit._move_intent = Vector2.UP
			for action in [&"spear_tap", &"spear_tap_empowered"]:
				view._play_visual_action(action)
				view._seek_visual_action(0.3)
				_expect(view._action_sequence.index == 0, "普通与强化Q保留单段短刺动作")
				# 走真实动作完成入口，先释放技能覆盖权再进入转跑。
				view._on_animation_finished(&"Spell1_Hit")
				var transition: StringName = &"Spell1_Hit_To_Passiverun" if full else &"Spell1_Hit_Torun"
				_expect(view._animation_player.current_animation == transition, "短Q按释放后红怒选择转跑过渡")
				view._on_animation_finished(transition)
				_expect(view._animation_player.current_animation == (&"Run_Passive" if full else &"Run_Base"), "短Q过渡结束进入对应跑步循环")
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
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "pantheon", Vector2(360, 900), {"deploy_time_override": 0.0}))
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
		var enemy: Unit = _main._spawn_unit(UnitSpawnRequest.new(1-team, "garen", rear + Vector2(60, 0), {"deploy_time_override": 0.0}))
		var far: Unit = _main._spawn_unit(UnitSpawnRequest.new(1-team, "garen", center + forward * 80.0, {"deploy_time_override": 0.0}))
		var ally: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "garen", rear, {"deploy_time_override": 0.0}))
		var air: Unit = _main._spawn_unit(UnitSpawnRequest.new(1-team, "anivia", rear, {"deploy_time_override": 0.0}))
		var outside: Unit = _main._spawn_unit(UnitSpawnRequest.new(1-team, "garen", center + Vector2(160, 0), {"deploy_time_override": 0.0}))
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
		_expect(view._point_at(0.65).distance_to(view.ground(rear)) < 0.001, "彗星准确落在后方3格")
		view.advance_visual(1.0)
		_expect(view._point_at(1.3).distance_to(view.ground(center)) < 0.001 and enemy.hp == hp[0], "表现推进到终点不结算伤害")
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
	var enemy: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "garen", Vector2(360, 840), {"deploy_time_override": 0.0}))
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
	var victim: Unit = _main._spawn_unit(UnitSpawnRequest.new(1, "garen", Vector2(360, 840), {"deploy_time_override": 0.0}))
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
	var native := preload("res://assets/units/pantheon/arrival/particle_player.gd")
	_expect(native.systems().size() == 7, "七组原版系统包含长矛飞行与插地、俯冲、滑行、掀土、撞地、余波")
	for definitions: Array in native.systems().values():
		for definition: Dictionary in definitions:
			_expect(definition.offset.size() == 3 and definition.birthOffset.base.size() == 3, "原版出生偏移正确解析为vec3，不混入嵌套概率表")
	for team in [0, 1]:
		var view := preload("res://assets/units/pantheon/pantheon_arrival.tscn").instantiate()
		presentation._world_root.add_child(view)
		view.setup(presentation._world_root.get_viewport().get_camera_3d(), Vector2(340, 820), team)
		view.advance_visual(0.1 / 1.3)
		_expect(not view._comet._effects.has("Spear_Landing") and not view._comet._effects.has("Spear_Impact"), "简化长矛只保留本体，不创建轨迹或插地粒子")
		var sky_screen: Vector2 = view.camera.unproject_position(view._spear.position)
		var end_screen: Vector2 = view.camera.unproject_position(view._end)
		_expect((sky_screen.y - end_screen.y) * (1.0 if team == 0 else -1.0) > 0.0, "画面长矛从己方侧向敌方推进")
		var basis: Basis = view._spear.basis
		_expect((-basis.y.normalized()).y > 0.0 and (-basis.y.normalized()).dot(view._direction) < 0.0, "恢复标记下牌点的原独立斜插长矛")
		view.advance_visual(0.4 / 1.3)
		_expect(view._spear.basis.is_equal_approx(basis) and view._spear.position.is_equal_approx(view._end), "下落与斜插保持同一长矛和倾角")
		_expect(view._comet._effects.has("update_missile") and not view._comet._effects.has("Damage_Mis"), "空中启用原版彗星，未提前显示地面伤害波")
		_expect(not view._comet._effects.has("Spear_Impact"), "长矛插地后不出现地面特效")
		for p: Dictionary in view._comet._effects.update_missile._particles:
			if p.c.name in ["Temp_GroundGlow1", "Temp_GroundGlow2"]:
				_expect(p.node.global_basis.orthonormalized().is_equal_approx(view._comet._effects.update_missile.global_basis * Basis.from_euler(p.rotation * PI / 180.0)), "俯冲光片保留原版局部旋转")
		var fly_frame: Transform3D = view._comet._transform(view.PROFILE.data().systems.update_missile, view._point_at(0.4), view._end, view._slide_start, 0.4)
		_expect(view._player.assigned_animation == "pantheon_spell4_fly" and view._ghost.global_position.is_equal_approx(fly_frame * (Vector3(0, -50, -250) * view.METRICS.PARTICLE_SCALE)), "俯冲彗星使用第一剪影及原始发射器偏移")
		view.advance_visual(0.85 / 1.3)
		var slide_frame: Transform3D = view._comet._transform(view.PROFILE.data().systems.Sliding_Comet, view._point_at(0.85), view._end, view._slide_start, 0.85)
		_expect(view._player.assigned_animation == "pantheon_spell4_slide" and view._ghost.global_position.is_equal_approx(slide_frame * (Vector3(0, -100, -70) * view.METRICS.PARTICLE_SCALE)), "滑行彗星使用第二剪影及原始发射器偏移")
		for p: Dictionary in view._comet._effects.Update_Impact._particles:
			if p.c.name in ["Groundhole_LIGHT", "groundcrack"]:
				_expect((-p.node.global_basis.y.normalized()).dot(view._direction) > 0.999, "撞地坑口贴图底边接滑行方向，蓝红一致")
		for effect: Node3D in view._comet._effects.values():
			for emitter: Dictionary in effect._emitters:
				_expect(emitter.c.adaptation.get("enabled", true), "用户停用层不创建发射器")
		for trail: Dictionary in view._comet._effects.Sliding_Comet._trails:
			_expect(not trail.c.adaptation.has("anchor_bone"), "滑行轨迹恢复原版发射器位置，不再按脚骨重排")
			var effect: Node3D = view._comet._effects.Sliding_Comet
			var authored: Vector3 = effect.global_position + effect.global_basis * (native.vec3(native.sample(trail.c.birthOffset, effect._time)) + native.vec3(native.sample(trail.c.emitterPosition, effect._time))) * view.METRICS.PARTICLE_SCALE
			_expect(not trail.points.is_empty() and trail.points.back().pos.distance_to(authored) <= 0.051, "轨迹位置使用原始偏移和系统坐标系")
		var wave: Node3D = view._comet._effects.Damage_Mis
		_expect(wave.global_basis.y.dot(view._direction) > 0.999 and wave.global_basis.z.dot(Vector3.UP) > 0.999, "双方原版波的局部+Y转换为前进方向、+Z转换为高度")
		_expect(view._comet._effects.Sliding_Comet.global_position.distance_to(view._point_at(0.85)) < 0.001 and wave.global_position.distance_to(view._point_at(0.85)) < 0.001, "原版火光与掀土波跟随同一权威滑行点")
		_expect(view._proxy.scale.is_equal_approx(Vector3.ONE * view.METRICS.PARTICLE_SCALE) and view._spear.scale.is_equal_approx(Vector3.ONE * view.METRICS.PROP_SCALE), "滑行剪影使用原版统一缩放，独立长矛恢复自身比例")
		for particle: Dictionary in view._comet._effects.Sliding_Comet._particles:
			if String(particle.c.mesh).contains("wave_comet_mesh"):
				var tail_direction: Vector3 = -particle.node.global_basis.x.normalized()
				_expect(tail_direction.dot(view._direction) < -0.999, "原版彗星网格-X尾部朝后，不从侧面伸出")
		_expect(not view._comet._effects.has("Ending_Shockwave"), "收尾余波不得提前叠加在滑行中途")
		var ending := preload("res://assets/units/pantheon/pantheon_view.tscn").instantiate()
		presentation._world_root.add_child(ending)
		ending.global_transform = Transform3D(Basis(Vector3.UP, atan2(view._direction.x, view._direction.z)), view._end)
		ending.advance_deployment_visual(0.04, 1.0, true)
		_expect(ending._ending_wave == null and ending._ending_parent._particles.size() > 0, "冲击罩原版0.7秒寿命结束前不产生余波")
		var parent_particle: Dictionary = ending._ending_parent._particles[0]
		var parent_origin: Vector3 = parent_particle.node.global_position
		var parent_basis: Basis = parent_particle.node.global_basis.orthonormalized()
		ending.advance_deployment_visual(0.1, 1.0, true)
		var tail: Node3D = ending._ending_wave
		_expect(tail.global_position.is_equal_approx(parent_origin) and tail.global_basis.is_equal_approx(parent_basis), "子余波继承冲击罩消亡处的原点与朝向")
		_expect(is_equal_approx(ending._ending_birth_elapsed, 0.05), "原版父粒子寿命驱动子效果时间，不提前在单位出生时触发")
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
		for particle: Dictionary in wave._particles:
			if particle.c.name == "Temp_GroundGlow1":
				var phase: Vector2 = particle.node.material_override.get_shader_parameter("mult_phase")
				_expect(phase.y < -0.9, "地面碎屑乘色层读取原版出生滚速，不冻结成静止纹理")
		var stripe_centers: Array[float] = []
		for particle: Dictionary in wave._particles:
			if String(particle.c.mesh).contains("mis_air_streaks"):
				var mesh_node: MeshInstance3D = particle.node
				var center: Vector3 = mesh_node.global_transform * mesh_node.mesh.get_aabb().get_center()
				stripe_centers.append((center - view._ghost.global_position).dot(view._direction.cross(Vector3.UP)))
		_expect(stripe_centers.size() == 2 and absf(stripe_centers[0] + stripe_centers[1]) < 0.001 and is_equal_approx(absf(stripe_centers[1] - stripe_centers[0]), 250.0 * view.METRICS.PARTICLE_SCALE), "流光组整体居中，保留原版两层250单位横向间距")
		for particle: Dictionary in wave._particles:
			if particle.c.ground and String(particle.c.mesh).is_empty():
				_expect(particle.node.global_basis.z.normalized().dot(Vector3.UP) > 0.999 and absf(particle.node.global_position.y - 0.045) < 0.001, "原版地面标记法线向上并贴地")
		var shell_nodes: Array[Node3D] = []
		var shell_positions: Array[Vector3] = []
		for particle: Dictionary in wave._particles:
			if not String(particle.c.mesh).is_empty() and float(native.sample(particle.c.bind, 0.2)) > 0.999:
				shell_nodes.append(particle.node)
				shell_positions.append(particle.node.global_position)
		var shift: Vector3 = view._direction * 0.5
		wave.global_position += shift
		wave.advance(0.0)
		for index in shell_nodes.size():
			_expect((shell_nodes[index].global_position - shell_positions[index]).is_equal_approx(shift), "气罩网格及附着层共享位移，不作为横向游离粒子")
		wave.advance(0.05)
		for trail: Dictionary in wave._trails:
			if not trail.node.visible: continue
			var arrays: Array = trail.node.mesh.surface_get_arrays(0)
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			_expect(is_equal_approx(uv[0].x, uv[1].x) and uv[0].y != uv[1].y and uv[0].x < uv[uv.size()-2].x, "拖尾U沿前后长度、V沿横向宽度，避免横向扫纹")
			var distance: float = float(trail.points.back().distance) - float(trail.points.front().distance)
			var tiling: float = float(native.sample(trail.c.trail_tiling, 0.0)[0]) * wave._factor
			_expect(is_equal_approx(uv[uv.size()-2].x - uv[0].x, distance / tiling), "拖尾UV按原始平铺长度累计距离，删旧点不重拉整张纹理")
			var phase: Vector2 = trail.node.material_override.get_shader_parameter("uv_phase")
			_expect(phase.x >= 0.0 and is_zero_approx(phase.y), "拖尾纹理向旧轨迹后流，不沿横向宽度播放")
		for effect: Node3D in view._comet._effects.values():
			effect.stop_emitting()
			effect.advance(20.0)
			_expect(effect._particles.is_empty(), "原版粒子到期完整回收")
		view.free()
	var deceleration := {"base": [4.0, 0.0], "times": [0.0, 1.0], "values": [[4.0, 0.0], [0.0, 0.0]]}
	_expect(native.integrated_flow(deceleration, 0.5, 1.0).is_equal_approx(Vector2(1.5, 0.0)), "罩面纹理按原版减速曲线积分，不冻结首帧或发生相位倒退")
	_expect(native.integrated_flow(deceleration, 0.75, 1.0).x > native.integrated_flow(deceleration, 0.5, 1.0).x, "减速过程中纹理仍沿同一方向连续流动")
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
	_expect(stats.radius == CardDB.RADIUS_MEDIUM and stats.pre_deploy_sweep_distance == 120.0 and stats.pre_deploy_sweep_radius == 90.0 and stats.active_skills[0].length == 120.0, "表现缩小不改变身体、三格路径、冲击波伤害范围和Q判定")

## Real failure modes: skipped snapshots, different render rates, and timeline rewind.
func _arrival_fingerprint(view: Node3D) -> Array:
	var result: Array = []
	for name: String in view._comet._effects:
		var effect: Node3D = view._comet._effects[name]
		result.append(name)
		for particle: Dictionary in effect._particles:
			result.append([particle.c.name, particle.birth, particle.origin, particle.velocity, particle.node.global_position])
		for trail: Dictionary in effect._trails:
			result.append(trail.points.duplicate(true))
	return result

func _check_arrival_sampling() -> void:
	var profile := preload("res://assets/units/pantheon/arrival/profile.gd").data()
	var stats := CardDB.get_card("pantheon")
	_expect(is_equal_approx(float(profile.systems.Damage_Mis.start), float(stats.pre_deploy_sweep_start)) and is_equal_approx(float(profile.systems.Ending_Shockwave.start), float(profile.systems.Damage_Mis.start) + 0.7), "滑行读取权威起点，余波时刻来自原版父粒子寿命")
	var world: Node3D = _main._battle_presentation._world_root
	for team in [0, 1]:
		var view := preload("res://assets/units/pantheon/pantheon_arrival.tscn").instantiate()
		world.add_child(view)
		view.setup(_main._battle_presentation._camera, Vector2(340, 820), team)
		for i in range(1, 61): view.advance_visual(float(i) / 60.0 / 1.3)
		var expected := _arrival_fingerprint(view)
		view.advance_visual(0.0)
		for i in range(1, 31): view.advance_visual(float(i) / 30.0 / 1.3)
		_expect(_arrival_fingerprint(view) == expected, "30/60FPS出生位置、随机碎石和拖痕采样完全一致")
		view.advance_visual(0.0)
		view.advance_visual(1.0 / 1.3)
		_expect(_arrival_fingerprint(view) == expected, "首次迟到快照直达1秒也复原完整轨迹，不堆在终点")
		view.advance_visual(0.4 / 1.3)
		_expect(not view._comet._effects.has("Damage_Mis") and view._comet._effects.update_missile.visible, "时间轴倒拖清除未来系统并恢复飞行阶段")
		view.advance_visual(1.0 / 1.3)
		_expect(_arrival_fingerprint(view) == expected, "倒拖后重播复现同一结果，无旧拖尾残留")
		view.advance_visual(1.0 / 1.3)
		_expect(_arrival_fingerprint(view) == expected, "重复快照不追加出生或拖尾采样")
		view.free()
