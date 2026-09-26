extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_attack_hit_timing()
	_growth()
	_terrain()
	_terrain_audio()
	_deploy_voice()
	_terrain_attack_exit()
	_terrain_external_movement()
	_dash_collision_and_timing()
	_dash()
	_control_and_growth_deployment()
	_dash_edges()
	_queued_form()
	_schema()
	_workbench_forms_and_animation()
	_weapon_blend_and_q()
	var invalid := CardDB.all().duplicate(true)
	invalid.kayn_slayer.heal_on_hit_name = 12
	_expect(not CardDB.VALIDATOR.validate_all(invalid,false).is_empty(), "命中回复显示名拒绝非文本类型")

func _make(id: String, team: int, point: Vector2) -> Unit:
	return _main._spawn_unit(team, id, point, 0.0)

func _growth() -> void:
	_main._card_growth.clear()
	var a := _make("kayn", 0, Vector2(300,900))
	var b := _make("kayn", 0, Vector2(350,900))
	var ranged := _make("ashe", 1, Vector2(400,900))
	ranged.hp = 10000
	a.apply_blind(1)
	_main._combat.begin_batch(0, "blind_growth")
	a._perform_attack_strike(ranged, 80)
	_main._combat.commit_batch()
	_expect(ranged.hp == 10000 and _main._card_growth.progress(0, "kayn").is_empty() and a.blind_attack_charges == 0, "致盲普攻消费致盲但不伤害、不获得能量")
	for hit in 3: _main._combat.resolve_attack_hit(0,a.position,ranged,1,0,0,a,a.position,0)
	_expect(_main._card_growth.resolved_id(0,"kayn") == "kayn", "远程3次尚未解锁")
	_main._combat.begin_batch(0,"growth")
	_main._combat.resolve_attack_hit(0,b.position,ranged,1,0,0,b,b.position,0)
	_main._combat.commit_batch()
	_expect(_main._card_growth.resolved_id(0,"kayn") == "kayn_assassin", "同队第二凯隐共享第四次命中解锁蓝凯")
	_expect(a.card_id == "kayn" and a.damage == 80, "场上旧凯隐保持普通")
	_expect(_main._card_growth.resolved_id(1,"kayn") == "kayn", "双方成长隔离")
	for hit in 6: _main._card_growth.record_hit(a,b) # 队友不计
	_expect(_main._card_growth.resolved_id(0,"kayn") == "kayn_assassin", "解锁不反转")
	a.free();b.free();ranged.free()
	_main._card_growth.clear()

func _terrain() -> void:
	var a := _make("kayn",0,Vector2(360,850))
	a.hp = 300
	a.position = Vector2(360,ArenaRules.RIVER_Y)
	a.terrain_traversal.update(a)
	_expect(a.hp == 370 and a.terrain_traversal.inside, "首次入河回复70")
	for tick in 5: a.terrain_traversal.update(a)
	_expect(a.hp == 370, "留在地形不重复回血")
	var target := _make("garen", 1, Vector2(360, ArenaRules.RIVER_Y - 70))
	target.position = Vector2(360, ArenaRules.RIVER_Y - 70)
	a._target = target
	a.position.y = ArenaRules.RIVER_Y - 40
	_expect(a.terrain_traversal.leave_for_attack(a), "地形中攻击瞬间挤出后可开始正常前摇")
	for tick in 40:
		if not a.terrain_traversal.inside: break
		_main._movement._try_apply_velocity(a, a._move_intent, 0.05)
		a.terrain_traversal.leave_for_attack(a)
	_expect(not a.terrain_traversal.inside and a.is_walkable_at(a.position), "出地形落点完整合法")
	a.position = Vector2(360,ArenaRules.RIVER_Y)
	a.terrain_traversal.update(a)
	_expect(a.hp == 440, "完整离开再入河可再次回复")
	var blocker := _make("garen",1,a.position)
	var point: Vector2 = UnitLandingQuery.find_position(a,a.position,true)
	_expect(point.distance_to(blocker.position) >= a.body_radius+blocker.body_radius-0.001, "Q落点允许河道但避开单位")
	a.free();blocker.free();target.free()

func _dash() -> void:
	var a := _make("kayn_slayer",0,Vector2(360,950))
	var enemy := _make("garen",1,Vector2(360,865))
	enemy.max_hp = 1000;enemy.hp = 1000
	a.hp = 400
	a.active_skill_cast_facing = Vector2.UP
	var skill: Dictionary = CardDB.active_skills_for("kayn_slayer")[0]
	var dash := DashStrikeState.new(a,skill)
	for tick in 10:
		_main._combat.begin_batch(tick,"dash_test")
		dash.tick(0.05)
		_main._combat.commit_batch()
		_contact_step(a, enemy)
	_expect(enemy.hp == 760, "突进与旋转各90+最大生命3%，沿途不重复")
	_expect(a.hp == 500, "红凯两段各回复50")
	_expect(not a.skill_dash_active and a.position.distance_to(enemy.position) >= a.body_radius+enemy.body_radius-0.1, "末端恢复通用碰撞并分离")
	a.free();enemy.free()

func _control_and_growth_deployment() -> void:
	_main._card_growth.clear()
	var source := _make("kayn",0,Vector2(360,950))
	var target := _make("garen",1,Vector2(360,850))
	for hit in 6: _main._card_growth.record_hit(source,target)
	_expect(_main._card_growth.resolved_id(0,"kayn") == "kayn_slayer", "六次近战解锁红凯")
	var old_deck: Array = _main._deck.duplicate()
	_main._deck[0] = "kayn"
	_expect(_main.play_card(0,"kayn",Vector2(250,950),{"immediate":true,"validate_position":false}), "正式出牌入口接受已成长来源卡")
	var grown: Unit = _main._latest_unit_for_card("kayn",0)
	_expect(grown != null and grown.card_id == "kayn_slayer" and grown.max_hp == 950 and grown.active_skill_card_id == "kayn", "后续部署红凯且保留原牌主动归属")
	if grown != null: grown.free()
	_main._card_growth.clear()
	for hit in 4: _main._card_growth.record_hit(source, _make("ashe",1,Vector2(650,1100)))
	_main.play_card(0,"kayn",Vector2(250,950),{"immediate":true,"validate_position":false})
	grown = _main._latest_unit_for_card("kayn",0)
	if grown != null:
		grown.active_ability_id = 99030
		grown.active_ability_slot = 0
		_main._register_active_skill(grown,"kayn",0)
	_expect(grown != null and grown.card_id == "kayn_assassin" and _main._active_skills.cost(grown.active_ability_id) == 1, "蓝凯从普通来源卡部署后主动实际费用为1")
	if grown != null: grown.free()
	_main._deck = old_deck
	var skill: Dictionary = CardDB.active_skills_for("kayn")[0]
	source.active_skill_cast_facing = Vector2.UP
	var dash := DashStrikeState.new(source,skill)
	source.freeze(1.0)
	var before := source.position
	_expect(not dash.tick(0.05) and not source.skill_dash_active and source.position == before, "冰冻取消突进和后段且解除穿单位")
	source.control.tick_hard_controls(2.0)
	source.active_skill_cast_serial += 1
	dash = DashStrikeState.new(source,skill)
	source.stun(1.0)
	dash.tick(0.05)
	_expect(source.position != before and source.skill_dash_active, "眩晕不取消已开始Q")
	source.take_damage(30)
	_expect(source.hp == 620, "突进仍可被伤害命中")
	source.free();target.free()
	for unit in _main.get_tree().get_nodes_in_group("combatants"):
		if unit is Unit and unit.card_id == "ashe" and unit.position == Vector2(650,1100): unit.free()
	_main._card_growth.clear()

func _schema() -> void:
	for field in ["growth_ranged_hits","growth_melee_hits","terrain_entry_heal"]:
		var cards := CardDB.all().duplicate(true)
		cards.kayn[field] = -1
		_expect(not CardDB.VALIDATOR.validate_all(cards,false).is_empty(), "非法新增字段被拒绝："+field)
	var cards := CardDB.all().duplicate(true)
	cards.kayn.terrain_traversal = "yes"
	_expect(not CardDB.VALIDATOR.validate_all(cards,false).is_empty(), "穿地形布尔字段类型校验")

func _queued_form() -> void:
	_main._card_growth.clear()
	_main._commands.clear()
	_main._deck = ["kayn","garen","ashe","teemo","xin","freeze","heal","pix"]
	preload("res://tests/suites/network_fixture.gd").fixed_cycle(_main,0,_main._deck)
	_main._elixir.elixir = 10.0
	_expect(_main.play_card(0,"kayn",Vector2(300,900),{"elixir":_main._elixir}), "未成长时成功付款入队")
	var source := _make("kayn",0,Vector2(600,1100))
	var target := _make("ashe",1,Vector2(650,1100))
	for hit in 4: _main._card_growth.record_hit(source,target)
	var command: Dictionary = _main._commands.inspect_cards()[0]
	_main._sim_tick_id = int(command.execute_tick)
	_main._tick_pending_card_deployments(0.05)
	var result: Unit = _main._latest_unit_for_card("kayn",0)
	_expect(result.card_id == "kayn", "等待期间解锁不追溯改变已接受的普通部署")
	_expect(_main._elixir.elixir == 6.0 and "kayn" in _main.get_authoritative_queue(0), "成长不额外扣费且来源牌正常进入递补")
	result.free();source.free();target.free()
	_main._card_growth.clear()

func _dash_edges() -> void:
	var a := _make("kayn_slayer",0,Vector2(360,1000))
	a.hp = 300
	a.active_skill_cast_facing = Vector2.UP
	var skill: Dictionary = CardDB.active_skills_for("kayn_slayer")[0]
	var dash := DashStrikeState.new(a,skill)
	for tick in 10: dash.tick(0.05)
	_expect(a.hp == 300, "红凯空Q不回血")
	a.position = Vector2(360,1000)
	var targets: Array[Unit] = []
	for x in [340,360,380]: targets.append(_make("garen",1,Vector2(x,920)))
	dash = DashStrikeState.new(a,skill)
	for tick in 10:
		_main._combat.begin_batch(tick,"multi_dash")
		dash.tick(0.05)
		_main._combat.commit_batch()
	_expect(a.hp == 400, "多目标命中仍只按两段各回复50")
	for target in targets: target.free()
	a.position = Vector2(360,1000)
	dash = DashStrikeState.new(a,skill)
	dash.tick(0.05)
	var position_before := a.position
	a.apply_knockback(a.position+Vector2.RIGHT*10.0,40.0)
	dash.tick(0.05)
	_expect(not a.skill_dash_active and a.position == position_before, "击退接管后停止剩余自主突进")
	for tick in 8: dash.tick(0.05)
	_expect(dash.stopped and not dash.cancelled, "击退保留旋转阶段，区别于冰冻取消")
	a.free()

func _workbench_forms_and_animation() -> void:
	var catalog := preload("res://scripts/ui/workbench/card_catalog.gd")
	var entries := catalog.entries(CardDB.all())
	_expect(catalog.canonical_id("kayn_slayer", CardDB.all()) == "kayn:2" and catalog.canonical_id("gnar", CardDB.all()) == "gnar", "旧红凯快捷槽迁移且不误选纳尔形态")
	_expect(entries.filter(func(entry): return entry.base_id == "kayn").size() == 3, "凯隐工作台目录统一三形态，红凯可独立入快捷栏")
	_expect(entries.filter(func(entry): return entry.id in ["kayn_assassin", "kayn_slayer"]).is_empty(), "凯隐派生卡不重复占用模型入口")
	_expect(catalog.deployment_id("gnar", 1) == "gnar", "纳尔仍通过原地变形预览")
	for form in 3:
		var id := catalog.deployment_id("kayn", form)
		var stats := catalog.stats_for_form(CardDB.get_card("kayn"), form)
		_expect(stats.size_tier == CardDB.SIZE_MEDIUM and stats.radius == CardDB.RADIUS_MEDIUM, "凯隐三形态共用中体型：" + id)
		_expect(catalog.form_index(catalog.selection_id("kayn", form)) == form, "工作台三档形态编码往返：" + id)
		var unit := _make(id, 0, Vector2(360, 950))
		var view: UnitModel3D
		for child in _main._battle_presentation._world_root.get_children():
			if child is UnitModel3D and child._source == unit: view = child
		_expect(view != null, "凯隐模型可实例化：" + id)
		if view != null:
			var deploy_clip := StringName(stats.visual_animations.deploy)
			_expect(deploy_clip == [&"Deploy_Base", &"Deploy_Assassin", &"Deploy_Slayer"][form], "部署选择对应裁剪片段：" + id)
			_expect(is_equal_approx(view._animation_player.get_animation(deploy_clip).length, 1.0), "部署片段压缩至一秒：" + id)
			var focus: Vector3 = view._model_root.get_preview_focus(Vector3(-2, 1, 3))
			_expect(is_equal_approx(focus.x, view._model_root.global_position.x) and is_equal_approx(focus.z, view._model_root.global_position.z) and focus.y == 1.0, "模型展台按主体水平居中：" + id)
			var meshes := view._model_root.find_children("*", "MeshInstance3D", true, false)
			var visible_names: Array = []
			for mesh in meshes:
				if mesh.visible: visible_names.append(String(mesh.name))
			var expected := [["Kayn_Base_Mat"], ["Kayn_Base_Assassin_Mat", "Kayn_Assassin_Hair_Mat"], ["Kayn_Base_Slayer_Mat"]]
			_expect(visible_names.size() == expected[form].size() and visible_names.all(func(name): return name in expected[form]), "只显示当前形态部件：" + id)
			for state in [1, 2]:
				view._animation_player.play("Spell1_Circle")
				view._transition_to_basic_state(state, -1.0, &"skill")
				var clip: String = String(stats.visual_animations.idle) if state == 1 else ("Spell2_Slayer_Run" if form == 2 else "Spell1_Exit_To_Run")
				_expect(view._animation_player.current_animation == clip, "Q出口按待机/移动分支：" + id + "/" + clip)
				view._on_animation_finished(StringName(clip))
				_expect(view._animation_player.current_animation == String(stats.visual_animations.idle if state == 1 else stats.visual_animations.move), "Q过渡后进入对应形态基础动作：" + id)
			unit._deploy_timer = 0.0
			unit._move_intent = Vector2.UP * unit.move_speed
			unit.hp = 300
			unit.position = Vector2(360, ArenaRules.RIVER_Y)
			view._sync_visual(false, 0.05)
			_expect(view._animation_player.current_animation == "Spell3_Run", "移动中入河切换穿地形跑步：" + id)
			_expect(not unit.terrain_traversal.inside and unit.hp == 300, "表现查询不推进权威入地形状态、不回血：" + id)
			_expect(view._animation_player.get_animation("Spell3_Run").loop_mode == Animation.LOOP_LINEAR, "穿地形跑步循环：" + id)
			view._animation_player.play("Spell1_Circle")
			view._transition_to_basic_state(2, -1.0, &"skill")
			_expect(view._animation_player.current_animation == "Spell1_Exit_To_Run", "地形内Q按原表统一转入Spell3跑步：" + id)
			view._on_animation_finished(&"Spell1_Exit_To_Run")
			_expect(view._animation_player.current_animation == "Spell3_Run", "地形内Q出口不退回地面跑步：" + id)
			unit.position = Vector2(ArenaRules.BRIDGE_X_LEFT, ArenaRules.RIVER_Y)
			view._sync_visual(false, 0.05)
			_expect(view._animation_player.current_animation == String(stats.visual_animations.move), "离开地形到桥面恢复本形态跑步：" + id)
			unit.position = Vector2(360, ArenaRules.RIVER_Y)
			unit.play_visual_action(&"active", 0.7)
			view._sync_visual(false, 0.05)
			_expect(view._animation_player.current_animation == "Spell1_Dash", "进入地形不能覆盖正在进行的Q：" + id)
			view.free()
		unit.free()
	var invalid_terrain := CardDB.all().duplicate(true)
	invalid_terrain.kayn.visual_animations.terrain_move = 42
	_expect(not CardDB.VALIDATOR.validate_all(invalid_terrain, false).is_empty(), "穿地形动画拒绝非片段类型")

func _weapon_blend_and_q() -> void:
	for id in ["kayn", "kayn_assassin", "kayn_slayer"]:
		var unit := _make(id, 0, Vector2(360, 950))
		unit._deploy_timer = 0.0
		var view: UnitModel3D
		for child in _main._battle_presentation._world_root.get_children():
			if child is UnitModel3D and child._source == unit: view = child
		var player := view._animation_player
		var modifier = view._model_root._weapon_blend
		var skeleton: Skeleton3D = modifier.get_skeleton()
		var weapon := skeleton.find_bone("C_Weapon")
		var stats := CardDB.get_card(id)
		# 新模型的 Rest 和复用模型的旧动作都不能成为首次部署混合起点。
		for reused in [false, true]:
			player.play("Spell1_Circle", 0.0)
			player.seek(0.2, true)
			if not reused: skeleton.reset_bone_poses()
			modifier.reset_pool_visual()
			view._play_clip(StringName(stats.visual_animations.idle), &"locomotion", 1.0, 0.1)
			for step in [0.0, 0.0167, 0.0333, 0.05]:
				player.advance(step)
				skeleton.force_update_all_bone_transforms()
				modifier._process_modification()
				var initial := skeleton.get_bone_global_pose(weapon)
				var native: Transform3D = modifier.sample_weapon(stats.visual_animations.idle, player.current_animation_position)
				_expect(initial.origin.distance_to(native.origin) < 0.02 and initial.basis.get_rotation_quaternion().angle_to(native.basis.get_rotation_quaternion()) < 0.002, "首次部署直接采用当前动作镰刀姿势：%s/reused=%s" % [id, reused])
		for phase in [0.0, 0.3, 0.7]:
			player.play(stats.visual_animations.idle, 0.0)
			player.seek(phase, true)
			skeleton.force_update_all_bone_transforms()
			modifier.reset_pool_visual()
			modifier._process_modification()
			var source := skeleton.get_bone_global_pose(weapon)
			var sampled: Transform3D = modifier.sample_weapon(stats.visual_animations.idle, phase)
			_expect(source.origin.distance_to(sampled.origin) < 0.02 and source.basis.get_rotation_quaternion().angle_to(sampled.basis.get_rotation_quaternion()) < 0.002, "武器独立采样保留原片姿势：" + id)
			view._play_clip(StringName(stats.visual_animations.move), &"locomotion", 1.0, 0.1)
			player.advance(0.05)
			skeleton.force_update_all_bone_transforms()
			modifier._process_modification()
			var actual := skeleton.get_bone_global_pose(weapon)
			var target: Transform3D = modifier.sample_weapon(stats.visual_animations.move, player.current_animation_position)
			var expected := source.interpolate_with(target, 0.5)
			_expect(actual.origin.distance_to(expected.origin) < 0.02 and actual.basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion()) < 0.002, "镰刀混合中点沿两端最短方向、不绕Rest长弧：" + id)
			var held := actual
			player.speed_scale = 0.0
			modifier._process_modification()
			_expect(skeleton.get_bone_global_pose(weapon).is_equal_approx(held), "冻结时武器混合不推进：" + id)
			player.speed_scale = 1.0
		if id == "kayn_slayer":
			for edge in [[&"Run_Slayer", &"Spell3_Run"], [&"Spell3_Run", &"Run_Slayer"]]:
				for phase in [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.05]:
					player.play(edge[0], 0.0)
					player.seek(fmod(phase, player.get_animation(edge[0]).length), true)
					skeleton.force_update_all_bone_transforms()
					modifier.reset_pool_visual()
					modifier._process_modification()
					var source: Transform3D = skeleton.get_bone_global_pose(weapon)
					view._play_clip(edge[1], &"locomotion", 1.0, 0.1)
					player.advance(0.05)
					skeleton.force_update_all_bone_transforms()
					modifier._process_modification()
					var actual := skeleton.get_bone_global_pose(weapon)
					var turn := source.basis.get_rotation_quaternion().inverse() * actual.basis.get_rotation_quaternion()
					if turn.w < 0.0: turn = -turn
					var axis: Vector3 = -modifier._outside_axis if edge[0] == &"Spell3_Run" else modifier._outside_axis
					_expect(modifier._outside_turn and Vector3(turn.x, turn.y, turn.z).dot(axis) > 0.1, "红凯不同跑步相位进出地形始终沿外侧方向旋转")
					var held := actual
					player.speed_scale = 0.0
					modifier._process_modification()
					_expect(skeleton.get_bone_global_pose(weapon).is_equal_approx(held), "红凯外侧过渡冻结不推进")
					player.speed_scale = 1.0
					player.advance(0.05)
					skeleton.force_update_all_bone_transforms()
					modifier._process_modification()
					actual = skeleton.get_bone_global_pose(weapon)
					var target: Transform3D = modifier.sample_weapon(edge[1], 0.1)
					_expect(actual.origin.distance_to(target.origin) < 0.02 and actual.basis.get_rotation_quaternion().angle_to(target.basis.get_rotation_quaternion()) < 0.002, "红凯外侧过渡准确落回原片")
		modifier.reset_pool_visual()
		_expect(not modifier._has_pose and modifier._duration == 0.0, "模型池重置清除上个单位的混合姿势：" + id)
		unit.play_visual_action(&"active", 0.7)
		view._sync_visual(false, 0.0)
		for sample in [[0.2, "Spell1_Dash"], [0.35, "Spell1_Stop"], [0.5, "Spell1_Circle"]]:
			view._seek_visual_action(sample[0])
			_expect(player.assigned_animation == sample[1], "Q三段按权威窗口定位：" + id + "/" + sample[1])
			if sample[0] > 0.3: _expect(is_zero_approx(view._last_clip_blend_time), "Q内部连续片段零混合：" + id)
		view.free()
		unit.free()

func _terrain_external_movement() -> void:
	var a := _make("kayn", 0, Vector2(360, ArenaRules.RIVER_Y + ArenaRules.RIVER_HALF + 19))
	a.hp = 100
	var outside := a.position
	a.terrain_traversal.update(a)
	_main._movement._apply_knockback_step(a, Vector2(0, -10))
	a.terrain_traversal.update(a)
	_expect(a.terrain_traversal.inside and a.hp == 170, "击退可将凯隐推进河流并触发一次回血")
	a.position = outside
	a.terrain_traversal.update(a)
	var blocker := _make("garen", 0, outside + Vector2(0, 25))
	_contact_step(a, blocker)
	_expect(a.position.y < outside.y and a.terrain_traversal.inside and a.hp == 240, "普通单位接触可将凯隐挤进河流并回血")
	blocker.free()
	a.position = Vector2(360, 950)
	a.terrain_traversal.update(a)
	var center := a.position
	_main._push_units_around(center, 30)
	_expect(a.position.distance_to(center) >= a.body_radius + 30 - 0.001, "建筑落地通用推挤也处理凯隐")
	var building := _make("tombstone", 0, center)
	a.position = center
	a.terrain_traversal.update(a)
	var hp_before := a.hp
	building.hp = 0
	a.terrain_traversal.update(a)
	_expect(not a.terrain_traversal.inside and a.position == center and a.hp == hp_before, "脚下建筑摧毁只解除地形状态，不挪位也不再回血")
	building.free()
	a.position = Vector2(a.body_radius, 950)
	_main._movement._apply_knockback_step(a, Vector2(-100, 0))
	_expect(a.position.x >= a.body_radius - 0.001, "击退不能把凯隐推出竞技场")
	a.free()

func _dash_collision_and_timing() -> void:
	var a := _make("kayn", 0, Vector2(360, 1000))
	a.active_skill_cast_facing = Vector2.UP
	var target := _make("garen", 1, Vector2(360, 880))
	target.hp = 1000
	var skill: Dictionary = CardDB.active_skills_for("kayn")[0]
	var dash := DashStrikeState.new(a, skill)
	_main._push_units_around(a.position, 30)
	_expect(a.position == Vector2(360, 1000), "突进穿碰撞阶段也不被新建筑的部署推挤挪位")
	dash.tick(0.05)
	_expect(target.hp == 1000, "Q首步不会提前伤害整条未来路径上的目标")
	for tick in 5: dash.tick(0.05)
	_expect(target.hp == 910 and not a.skill_dash_active and a.position.distance_to(Vector2(360, 880)) < 0.001, "突进到达目标才伤害一次，结束恢复碰撞且不瞬移落点")
	_contact_step(a, target)
	_expect(a.position.distance_to(target.position) > 0.0, "Stop阶段重叠由通用接触机制分离")
	# 第一段打中过，但旋转节点已离开范围，不能再受伤。
	target.position = Vector2(600, 880)
	for tick in 4: dash.tick(0.05)
	_expect(target.hp == 910, "第一段命中不锁定第二段：旋转前离圈则不受旋转伤害")
	a.position = Vector2(360, 1000)
	target.position = Vector2(600, 880)
	dash = DashStrikeState.new(a, skill)
	for tick in 6: dash.tick(0.05)
	# 没有经过突进路径的敌人在第二段节点前入圈，也应该被命中。
	target.position = a.position + Vector2(50, 0)
	for tick in 3: dash.tick(0.05)
	_expect(target.hp == 910, "旋转在0.45秒尚未命中")
	dash.tick(0.05)
	_expect(target.hp == 820, "旋转独立查询当时范围，后来入圈的敌人也受伤")
	a.free()
	target.free()

func _contact_step(a: Unit, b: Unit) -> void:
	var units: Array[Unit] = [a, b]
	_main._movement._resolve_unit_collisions(0.05, units)

func _terrain_attack_exit() -> void:
	for team in [0, 1]:
		var forward := -1.0 if team == 0 else 1.0
		var target := _make("garen", 1-team, Vector2(360, ArenaRules.RIVER_Y + forward * 60))
		var a := _make("kayn", team, Vector2(360, ArenaRules.RIVER_Y - forward * 5))
		target.position = Vector2(360, ArenaRules.RIVER_Y + forward * 60)
		a.position = Vector2(360, ArenaRules.RIVER_Y - forward * 5)
		a._target = target
		a.hp = 200
		a.terrain_traversal.update(a)
		var healed := a.hp
		var exited := false
		for tick in 40:
			var before := a.position
			a._move_intent = Vector2.ZERO
			_expect(a.terrain_traversal.leave_for_attack(a), "准备攻击当步直接挤出，不走向出口")
			_expect(a._move_intent == Vector2.ZERO, "挤出不产生自主移动意图")
			_expect(before.distance_to(a.position) <= ArenaRules.TILE_SIZE * 2.0 + 0.001, "出地形修正限制在两格内")
			if not a.terrain_traversal.inside:
				exited = true
				break
			_main._movement._try_apply_velocity(a, a._move_intent, 0.05)
		_expect(exited and (a.position.y - ArenaRules.RIVER_Y) * forward > 0, "贴河目标从对岸接近后在目标岸出地形")
		_expect(a._target_gap(target) <= a.attack_range and a.hp == healed, "出地形即在攻击距离内，不反复入河刷回血")
		var point := a.position
		for tick in 5: _expect(a.terrain_traversal.leave_for_attack(a) and a.position == point, "合法攻击站位不再反复挪位")
		a.free();target.free()
	# 目标深在河中央、所有攻击站位仍是河道时，不退到射程外的岸边。
	var target := _make("kayn", 1, Vector2(360, ArenaRules.RIVER_Y))
	var a := _make("kayn", 0, Vector2(360, ArenaRules.RIVER_Y + 20))
	target.position = Vector2(360, ArenaRules.RIVER_Y)
	a.position = Vector2(360, ArenaRules.RIVER_Y + 20)
	a._target = target
	target.body_radius = 1
	a.attack_range = 1
	var before := a.position
	_expect(not a.terrain_traversal.leave_for_attack(a) and a.position == before, "无合法攻击站位时等待，不往射程外退出")
	a.free();target.free()

func _terrain_audio() -> void:
	var audio = _main._audio_manager
	audio.begin_battle()
	for id in ["kayn", "kayn_assassin", "kayn_slayer"]:
		var unit := _make(id, 0, Vector2(360, 850))
		audio.attach_unit(unit, CardDB.get_card(id))
		var key: String = audio._sustain_key(unit.get_instance_id(), &"terrain")
		unit.position = Vector2(360, ArenaRules.RIVER_Y)
		# 不更新权威inside，也能从快照几何启动，不给表现层回血权限。
		audio._tick_attached_units()
		var player = audio._sustain_players.get(key)
		_expect(player != null and not unit.terrain_traversal.inside, "地形循环支持只读快照几何：" + id)
		if player != null:
			var stream: AudioStreamWAV = player.stream.get_stream(0)
			_expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "E持续音真正循环：" + id)
			audio._tick_attached_units()
			_expect(audio._sustain_players.get(key) == player, "留在地形不重启循环：" + id)
			unit.freeze(1.0)
			audio._tick_attached_units()
			_expect(audio._sustain_players.get(key) == player, "地形内冰冻不终止E循环：" + id)
		unit.position = Vector2(360, 850)
		audio._tick_attached_units()
		_expect(not audio._sustain_players.has(key), "离开地形停止循环：" + id)
		unit.position = Vector2(360, ArenaRules.RIVER_Y)
		audio._tick_attached_units()
		unit.take_damage(100000)
		audio._tick_attached_units()
		_expect(not audio._sustain_players.has(key), "死亡停止地形循环：" + id)
		unit.free()
	audio.end_battle()
	_expect(audio._sustain_players.is_empty(), "清场释放全部地形音轨")
	audio.begin_battle()

func _deploy_voice() -> void:
	var audio = _main._audio_manager
	audio.begin_battle()
	var heard: Array[String] = []
	var callback := func(id: String, cue: StringName, _point: Vector2):
		if cue == &"deploy:voice": heard.append(id)
	audio.cue_played.connect(callback)
	for id in ["kayn", "kayn_assassin", "kayn_slayer"]:
		var event: Dictionary = CardDB.get_card(id).audio.events["deploy:voice"]
		_expect(event.pool.size() == 3 and event.bus == "Voice", "三形态各3条独立部署语音：" + id)
		for team in [0, 1]:
			var before := heard.size()
			var unit: Unit = _main._spawn_unit(team, id, Vector2(360, 900))
			audio.attach_unit(unit, CardDB.get_card(id))
			_expect(heard.size() == before + 1 and heard.back() == id, "部署发声一次，重复绑定不重播：%s/%s" % [id, team])
			unit.free()
	audio.cue_played.disconnect(callback)
	audio.end_battle()
	audio.begin_battle()

func _attack_hit_timing() -> void:
	for id in ["kayn", "kayn_assassin", "kayn_slayer"]:
		var unit := _make(id, 0, Vector2(300, 1000))
		var target := _make("garen", 1, Vector2(330, 1000))
		unit._target = target
		unit._attacking = true
		var mapped: float = unit.attack_interval * 11.5 / 79.0
		_expect(absf(unit.first_hit_time - mapped) <= 0.005, "凯隐普攻前摇按原片第11.5/79帧和本形态攻速映射：" + id)
		for rate in [1.0, 2.0]:
			target.hp = 10000.0
			unit.attack_timeline.cancel(true)
			unit.attack_timeline.begin_windup(unit.first_hit_time, rate)
			var ticks := ceili(unit.first_hit_time / rate / 0.05)
			for tick in ticks - 1: unit._attack(0.05)
			_expect(target.hp == 10000.0, "普攻前摇到期前不扣血：%s/%s" % [id, rate])
			unit._attack(0.05)
			_expect(target.hp < 10000.0, "普攻在首个到期20Hz Tick扣血：%s/%s" % [id, rate])
		unit.free()
		target.free()
	_main._card_growth.clear()
