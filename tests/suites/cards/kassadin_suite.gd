extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var effect_provider = preload("res://assets/effects/kassadin/player.gd")
	for kind in ["appear", "vanish", "idle_blade"]:
		var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/kassadin/"+kind+"/sampled.json"))
		var disabled := 0
		for emitter in sample.emitters:
			var shader: Shader = load(effect_provider.resource_shader_path(emitter))
			var expected := (int(emitter.miscRenderFlags) & 1) != 0
			_expect(shader != null and shader.code.contains("depth_test_disabled") == expected, "原始深度测试标志落实到实际着色器："+kind+"/"+String(emitter.name))
			if expected: disabled += 1
		_expect(disabled == (0 if kind == "idle_blade" else 3), "只关闭原版指定层深度测试，不影响其他层")
	var source := _spawn("kassadin", 0, Vector2(360, 700))
	_expect(not source.is_air and source.river_traversal, "浮空仍为地面单位")
	_expect(source.ignores_unit_collision(), "虚空之石永久穿过普通单位")
	_expect(source.is_walkable_at(Vector2(360, 640)), "中路河道可通过")
	var view := _view_for(source)
	_expect(view != null, "模型表现已创建")
	if view != null:
		view._animation_player.play("Idle1")
		view._transition_to_basic_state(2, -1.0, &"idle")
		_expect(view._animation_player.assigned_animation == "Run_Base" and view._last_clip_blend_time > 0.0, "待机转移动直接混合，不使用Run_In")
		view._animation_player.play("Spell4")
		view._transition_to_basic_state(2, -1.0, &"active")
		_expect(view._move_sequence.size() == 1 and view._animation_player.assigned_animation == "Spell4_To_Run", "保留R转移动专用衔接")
		view._advance_move_sequence()
		_expect(view._animation_player.assigned_animation == "Run_Base", "R移动衔接结束进入移动循环")
		for clip in ["Spell4", "Run_Base"]:
			view._animation_player.play(clip)
			view._transition_to_basic_state(1, -1.0, &"active")
			_expect(view._animation_player.assigned_animation == "Idle1" and view._last_clip_blend_time > 0.0, "转待机直接混合，不使用收尾片段")
		view._animation_player.play("Respawn")
		view._transition_to_basic_state(2, -1.0, &"deploy")
		_expect(view._animation_player.assigned_animation == "Run_Base" and is_equal_approx(view._last_clip_blend_time,0.18), "出场转移动使用0.18秒混合")
		for serial in [1,2]:
			view._animation_player.play("Respawn")
			view._play_attack(serial)
			_expect(view._animation_player.assigned_animation in ["Attack1","Attack2"] and is_equal_approx(view._last_clip_blend_time,0.14), "出场转两套攻击使用0.14秒混合")
		var model = view._model_root
		model.advance_ambient_visual(0.1)
		_expect(is_instance_valid(model._blade) and model._blade.get_parent().bone_name == "BUFFBONE_GLB_WEAPON_1", "原版能量刃绑定源武器骨骼")
		_expect(is_equal_approx(model.get_node("Model").position.y, 0.4), "模型离地高度只修改表现")
		model.advance_ambient_visual(9.95)
		_expect(model._blade.visible and model._blade._data.emitters.size() == 3, "常驻循环保留三层能量刃")
		model.begin_visual_death(0.8)
		_expect(not model._blade.visible, "死亡及时隐藏常驻刀刃")
		model.reset_pool_visual()
		model.configure_unit_visual(source)
		model.advance_ambient_visual(0.1)
		_expect(model._blade.visible, "模型复用后恢复常驻刀刃")
	var ordinary := _spawn("garen", 0, Vector2(360, 700))
	_expect(not ordinary.is_walkable_at(Vector2(360, 640)), "普通地面单位仍受河流阻挡")
	var building := _spawn("target_dummy", 1, Vector2(360, 500))
	_expect(not source.is_walkable_at(building.position), "仍受建筑圆柱阻挡")
	var route: PackedVector2Array = main.world.find_ground_path(Vector2(360, 700), Vector2(360, 580), null, 18.0, true)
	_expect(route.size() >= 2, "浮空导航可直接跨越中路河道")
	for point in route: _expect(absf(point.x - 360.0) <= 30.0, "跨河路线不绕桥")
	# 河流本身不改变攻击、移动或主动技能资格，双方一致。
	for team in [0, 1]:
		var river_unit := _spawn("kassadin", team, Vector2(280, 640))
		var river_enemy := _spawn("kassadin", 1-team, Vector2(320, 640))
		river_unit.teleport_to(Vector2(280,640))
		river_enemy.teleport_to(Vector2(320,640))
		river_unit.attack_timeline.cooldown = 0.0
		river_unit.attack_timeline.windup = 0.0
		river_unit._attack_visual_serial = 1
		river_unit._target = river_enemy
		var river_hp := river_enemy.hp
		river_unit._attack(0.3)
		_expect(river_enemy.hp < river_hp, "河面可以正常近战命中")
		var river_skill: Dictionary = CardDB.active_skills_for("kassadin")[0].duplicate(true)
		river_skill.cast_forward = Vector2.RIGHT
		main._active_skill_effect_system.apply(river_unit, river_skill)
		_expect(river_unit.position.distance_to(Vector2(440,640)) < 0.1, "河面可施法并落在河面")
		_expect(river_unit.is_walkable_at(river_unit.position), "河面落点为正常可行走位置")
		var before_move := river_unit.position
		river_enemy.move_speed = 0.0
		_run_main_ticks(35)
		_expect(river_unit.position.distance_to(before_move) > 1.0 and absf(river_unit.position.y-640.0)<20.0, "河面持续正常移动，不被推出河道")
		river_unit.free()
		river_enemy.free()
	var old_source := source.position
	var old_ordinary := ordinary.position
	main._movement._resolve_unit_collisions(main.SIM_DT, main._movement._active_mobile_units())
	_expect(source.position == old_source and ordinary.position == old_ordinary, "幽灵与普通单位重叠不产生推挤")
	for tower in main.world.towers_snapshot():
		_expect(not source.is_walkable_at(tower.position), "公主塔与水晶不能穿行")
	var skill: Dictionary = CardDB.active_skills_for("kassadin")[0].duplicate(true)
	source.position = Vector2(260, 900)
	skill.cast_forward = Vector2.RIGHT
	var enemy := _spawn("garen", 1, Vector2(430, 900))
	var air := _spawn("nocturne", 1, Vector2(440, 920))
	var ally := _spawn("garen", 0, Vector2(420, 880))
	var health := [enemy.hp, air.hp, ally.hp]
	main._active_skill_effect_system.apply(source, skill)
	_expect(source.position.distance_to(Vector2(420, 900)) < 0.1, "虚空行走瞬移160像素")
	_expect(enemy.hp == health[0]-80 and air.hp == health[1]-80 and ally.hp == health[2], "落地范围伤害对地对空且不伤友军")
	var edge_in := _spawn("garen", 1, Vector2(800, 1000))
	var edge_out := _spawn("garen", 1, Vector2(800, 1100))
	edge_in.teleport_to(source.position + Vector2(70.0 + edge_in.body_radius - 0.1, 0))
	edge_out.teleport_to(source.position + Vector2(0, 70.0 + edge_out.body_radius + 0.1))
	var edge_health := [edge_in.hp, edge_out.hp]
	main._active_skill_effect_system.activate_nova(source,skill)
	_expect(edge_in.hp == edge_health[0]-80, "70半径边界内身体相交命中，覆盖旧65范围外")
	_expect(edge_out.hp == edge_health[1], "70半径边界外身体不相交不命中")
	edge_in.free()
	edge_out.free()
	source.position = Vector2(360, 700)
	skill.cast_forward = Vector2.UP
	skill.length = 200.0
	main._active_skill_effect_system.apply(source, skill)
	_expect(source.is_walkable_at(source.position), "结构中的预期终点回退到最近合法落点")
	# 延伸优先，超出60+实时半径+2的预算时退回近侧。
	source.teleport_to(Vector2(360,700))
	building.position = Vector2(360,500)
	skill.cast_forward = Vector2.UP
	skill.length = 180.0
	main._active_skill_effect_system.apply(source,skill)
	_expect(source.position.y < 500.0 and 700.0-source.position.y <= 180.0+60.0+source.body_radius+2.0, "落点在建筑中优先前延且不超过60加半径加2")
	source.teleport_to(Vector2(360,700))
	skill.length = 140.0
	building.body_radius = 65.0
	main._active_skill_effect_system.apply(source,skill)
	_expect(source.position.y > 500.0, "远侧出口超过延伸上限时退回建筑近侧")
	source.teleport_to(Vector2(360,700))
	building.body_radius = 30.0
	skill.length = 180.0
	source.body_radius = 30.0
	main._active_skill_effect_system.apply(source,skill)
	_expect(source.position.y < 500.0 and 700.0-source.position.y <= 272.0, "落点延伸使用实时身体半径")
	source.teleport_to(Vector2(360,700))
	building.body_radius = 60.0
	skill.length = 200.0
	var without_margin := UnitLandingQuery.displacement_endpoint(source,source.position,Vector2.UP,200.0,60.0+source.body_radius)
	_expect(without_margin.y > 500.0, "预算仅到结构几何边缘时因分离间距回退")
	main._active_skill_effect_system.apply(source,skill)
	_expect(source.position.y < 500.0 and 700.0-source.position.y <= 200.0+60.0+source.body_radius+2.0 and UnitLandingQuery.displacement_legal(source,source.position), "2像素预算覆盖结构分离间距，前延仍严格有界")
	for unit in [source,ordinary,building,enemy,air,ally]:
		if is_instance_valid(unit): unit.free()
	var old_deck: Array = main.runtime._deck.duplicate()
	main.runtime._deck[0] = "kassadin"
	var paid: Unit = main.runtime._spawn_card_units(0, "kassadin", Vector2(250, 1100), 0.0, 0)[0]
	var id := paid.active_ability_id
	main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = 10.0
	for use in 6:
		var expected_cost := mini(use,2)
		var prepared: Dictionary = main.runtime._active_skills.skill_for_cast(id)
		_expect(main.runtime._active_skills.cost(id) == expected_cost and prepared.damage == [80,120,160][mini(use,2)], "连续使用费用和伤害封顶")
		_expect(main.use_active_skill(id, 0), "技能不限使用次数")
		_expect(main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir == 10.0-expected_cost, "请求按本次动态费用付款")
		_expect(not main.use_active_skill(id,0), "排队重复请求被拒绝")
		_run_main_ticks(12)
		_expect(not main.use_active_skill(id,0), "实际起手后2秒冷却拒绝连发")
		_run_main_ticks(45)
		main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = 10.0
		paid.position = Vector2(250,1100)
	main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = 0.0
	_expect(not main.use_active_skill(id,0) and main.runtime._active_skills.cost(id) == 2,"金币不足拒绝请求且不改变进度")
	_expect(CardDB.active_skills_for("kassadin")[0].cost == 0, "共享技能定义保持原值")
	var payload: Array = preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(main._snapshot_system, 12345,paid)
	_expect(payload.size() == NetworkSnapshotSystem.UNIT_PAYLOAD_SIZE and int(payload[NetworkSnapshotSystem.U_TELEPORT_SERIAL]) == paid.teleport_serial, "快照携带瞬移序号")
	var serial := paid.teleport_serial
	paid.teleport_to(Vector2(300,900))
	_expect(paid.teleport_serial == serial+1 and paid.get_visual_screen_position() == Vector2(300,900), "瞬移重置本地插值，不表现为滑行")
	var entry: Dictionary = main.runtime._active_skills.entry(id)
	main.runtime._active_skills.replace_replica(id, int(entry.uses_remaining), float(entry.cooldown_left))
	_expect(main.runtime._active_skills.cost(id) == 2, "快照次数进度恢复后仍按2金币封顶")
	var renewed: Unit = main.runtime._spawn_card_units(0,"kassadin",Vector2(350,1100),0.0,0)[0]
	_expect(main.runtime._active_skills.cost(renewed.active_ability_id) == 0 and not main.runtime._active_skills.has(id),"重新部署费用归零并替换旧主动资格")
	main.runtime._deck = old_deck
func _spawn(card: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, card, pos, {"deploy_time_override": 0.0}))
