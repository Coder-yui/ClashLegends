extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var unit := _spawn_ready_unit("malphite", 0, Vector2(300, 900))
	_expect(unit.shield_hp == 400.0, "部署获得400独立护盾")
	var initial_mode: String = main.runtime.mode
	main.runtime.mode = "client"
	_expect(unit.deployment_shield_active_visual(), "可靠出生到首份快照之间显示有盾外观")
	main.runtime.mode = initial_mode
	unit.shields.tick(10000.0)
	_expect(unit.shield_hp == 400.0, "部署盾无自然到期或再生计时")
	unit.take_damage(200.0)
	_expect(unit.shield_hp == 300.0 and unit.hp == 1600.0, "有盾期间50%减伤先于护盾吸收")
	unit.add_shield(50.0, 5.0)
	unit.take_damage(100.0)
	_expect(unit.shield_hp == 300.0 and unit.deployment_shield_active_visual(), "其他盾优先到期吸收且不改变部署盾身份")
	unit.take_damage(800.0)
	_expect(unit.hp == 1500.0 and unit.shield_hp == 0.0, "破盾当次先减伤，溢出伤害扣生命")
	unit.add_shield(40.0, 5.0)
	unit.take_damage(100.0)
	_expect(unit.hp == 1440.0 and not unit.deployment_shield_active_visual(), "新盾不能恢复花岗岩减伤")
	var snapshot: Array = preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(main._snapshot_system, 4401, unit)
	_expect(snapshot[NetworkSnapshotSystem.U_DEPLOYMENT_SHIELD] == false, "快照明确同步专属盾破碎")
	unit.free()
	unit = _spawn_ready_unit("malphite", 0, Vector2(300, 900))
	var center := _spawn_ready_unit("garen", 1, Vector2(320, 900))
	var edge := _spawn_ready_unit("garen", 1, Vector2(117, 900))
	var outside := _spawn_ready_unit("garen", 1, Vector2(485, 900))
	var diagonal := _spawn_ready_unit("garen", 1, Vector2(440, 1040))
	var air := _spawn_ready_unit("anivia", 1, Vector2(320, 920))
	var friend := _spawn_ready_unit("garen", 0, Vector2(320, 880))
	var targets := [center, edge, outside, diagonal, air, friend]
	var hp_before: Array = targets.map(func(target): return target.hp)
	var skill: Dictionary = CardDB.active_skills_for("malphite")[0]
	_expect(is_equal_approx(edge.global_position.distance_to(unit.global_position), 183.0), "边界夹具不受塔体部署避让影响")
	main._active_skill_effect_system.activate_nova(unit, skill)
	for i in targets.size():
		_expect(targets[i].hp == hp_before[i] - (160.0 if i < 2 else 0.0), "圆形接触边界、敌我及对地筛选 %d" % i)
	_expect(is_equal_approx(center.control.slow_multiplier, 0.7), "减移速30%")
	_expect(is_equal_approx(center.control.attack_speed_slow_multiplier, 0.3), "减攻速70%")
	center.control.tick_slows(2.0)
	_expect(center.control.slow_multiplier == 1.0 and center.control.attack_speed_slow_multiplier == 1.0, "两秒后双减速解除")
	unit.clear_shields()
	_expect(not unit.deployment_shield_active_visual(), "清场移除部署盾状态")
	for target in targets: target.free()
	unit.free()
	for invalid in [-0.1, 1.1]:
		var cards := CardDB.all().duplicate(true)
		cards.malphite.deployment_shield_reduction = invalid
		_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "拒绝非法减伤倍率")

	var xin := _spawn_ready_unit("xin", 0, Vector2(300, 800))
	xin.play_visual_action(&"active", 0.65)
	_expect(xin.active_sweep_visual_radius() > 0.0, "赵信仍保留通用环身枪芒")
	xin.free()
	_presentation()

func _presentation() -> void:
	var world := Node3D.new()
	_main.add_child(world)
	var effects = preload("res://scripts/presentation/malphite_effect_3d.gd").new()
	world.add_child(effects)
	effects.set_process(false)
	var proxy := Node3D.new()
	world.add_child(proxy)
	var model = load("res://assets/units/malphite/malphite_view.tscn").instantiate()
	# Headless lifecycle fixture keeps the real skeleton; materials are checked in rendered review.
	for mesh in model.find_children("*", "MeshInstance3D", true, false): mesh.free()
	proxy.add_child(model)
	proxy.rotation.y = 0.4
	var animation_player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	animation_player.play("Spell3")
	animation_player.seek(animation_player.get_animation("Spell3").length * (8.0 / 19.0), true)
	animation_player.advance(0.0)
	model._skeleton.force_update_all_bone_transforms()
	var event_pose: Transform3D = model._skeleton.global_transform * model._skeleton.get_bone_global_pose(model._hand)
	_expect(model._cast_hand_pose.is_equal_approx(model._skeleton.get_bone_global_pose(model._hand)), "事件骨骼采样与真实Spell3第8帧一致")
	animation_player.seek(0.45, true)
	animation_player.advance(0.0)
	var unit := _spawn_ready_unit("malphite", 0, Vector2(300, 900))
	model.configure_unit_visual(unit)
	_expect(unit.body_radius == CardDB.RADIUS_LARGE, "模型缩放不改变大体型半径24")
	_expect(model._hand >= 0, "源右手挂点映射到GLB大写骨名")
	unit.play_visual_action(&"active", 0.65)
	_expect(unit.active_sweep_visual_radius() == 0.0, "原版E不叠加通用nova金色枪芒")
	var previous_mode: String = _main.runtime.mode
	_main.runtime.mode = "client"
	unit.net_visual_action_name = &"active"
	unit.net_visual_action_duration = 0.65
	unit.net_visual_action_time_left = 0.35
	_expect(unit.active_sweep_visual_radius() == 0.0, "客户端快照动作也不叠加枪芒")
	_main.runtime.mode = previous_mode
	model.advance_ambient_visual(0.0)
	unit._visual_action_time_left = 0.4
	model.advance_ambient_visual(0.0)
	_expect(effects._detached.is_empty(), "E施放粒子等待第8帧而非起手或权威伤害时刻")
	unit._visual_action_time_left = 0.35
	model.advance_ambient_visual(0.0)
	_expect(effects._detached.size() == 1, "跨过源动画事件只释放一次施放粒子")
	var cast: Node3D = effects._detached[0]
	_expect(cast.scale.is_equal_approx(Vector3.ONE * 0.01), "E使用独立160像素范围等比缩放")
	var origin := cast.global_position
	_expect(origin.is_equal_approx(event_pose.origin), "晚帧仍从第8帧右手位置释放，不取偏晚姿势")
	_expect(cast.cast_orientation.is_equal_approx(event_pose.basis.orthonormalized()), "完整传递手部旋转并移除骨骼缩放")
	var orientation: Basis = cast.cast_orientation
	cast.seek(0.3)
	for i in cast._data.emitters.size():
		var emitter: Dictionary = cast._data.emitters[i]
		var follows := bool(emitter.localOrientation) or bool(emitter.particleLocalOrientation)
		for item in cast._pools[i]:
			_expect(item.basis.is_equal_approx(orientation if follows else Basis.IDENTITY), "源局部层跟随手部，世界层重力不上翻：" + String(emitter.name))
	var palette_material: ShaderMaterial = cast._pools[1][0].material_override
	_expect(palette_material.get_shader_parameter("has_palette") == true, "Trigger_3接入源火焰调色板")
	_expect(is_equal_approx(float(palette_material.get_shader_parameter("palette_row")), 9.5 / 16.0), "调色板使用源第9行中心，不取默认行")
	_expect(palette_material.get_shader_parameter("palette_texture") is Texture2D, "调色板是正式可加载依赖")
	proxy.position += Vector3(3, 0, 1)
	proxy.rotation.y += 1.2
	model.advance_ambient_visual(0.0)
	_expect(cast.global_position.is_equal_approx(origin) and effects._detached.size() == 1, "施放粒子脱离单位移动且不重复创建")
	_expect(cast.cast_orientation.is_equal_approx(orientation), "施放后单位转身不再旋转已释放特效")
	unit.clear_shields()
	model.advance_ambient_visual(0.0)
	_expect(effects._detached.size() == 2, "破盾粒子也由独立表现所有者持有")
	var broken: Node3D = effects._detached[1]
	_expect(broken.global_position.is_equal_approx(model.global_position), "破盾保留源相对偏移，不添加未经证实的spine挂点")
	broken.advance(0.05)
	proxy.position.x += 1.0
	broken.advance(0.05)
	var partial := false
	for state in broken._motion_particles.values():
		if state.offset.x > 0.0 and state.offset.x < 1.0: partial = true
	_expect(partial, "破盾已出生粒子仅部分继承位移")
	model.begin_visual_death(0.8)
	unit.free()
	unit = _spawn_ready_unit("malphite", 0, Vector2(300, 900))
	model.configure_unit_visual(unit)
	unit.clear_shields()
	model.begin_visual_death(0.8)
	_expect(effects._detached.size() == 3, "破盾与死亡同帧也先释放破碎粒子")
	model.begin_visual_death(0.8)
	model.reset_pool_visual()
	_expect(effects._detached.size() == 3, "重复死亡和回池不重复释放破碎粒子")
	proxy.queue_free()
	unit.free()
	effects._process(0.1)
	_expect(effects._detached.size() == 3 and is_instance_valid(cast), "模型死亡回收不截断已释放的碎石与施放粒子")
	effects._process(4.1)
	_expect(effects._detached.is_empty(), "独立粒子到期回收")
	for degrees in range(0, 360, 45):
		var facing := Basis(Vector3.UP, deg_to_rad(float(degrees)))
		var rotated := Transform3D(facing * event_pose.basis.orthonormalized(), Vector3.ZERO)
		var directional = effects.spawn_detached("cas", rotated)
		directional.seek(0.3)
		var values: Array = directional._data.frames[36][0][0]
		var normal := Vector3(values[13], values[16], values[19])
		var world_normal: Vector3 = directional._pools[0][0].global_basis.orthonormalized() * normal
		_expect(absf(world_normal.dot(Vector3.UP)) > 0.85, "八方向裂地网格接近平躺，不再竖立：%d" % degrees)
		var debris: Node3D = directional._pools[3][0]
		_expect(debris.global_basis.orthonormalized().is_equal_approx(Basis.IDENTITY), "八方向碎石仍使用世界重力：%d" % degrees)
	var errors := PackedStringArray()
	var resources := preload("res://scripts/presentation/effect_resource_manifest.gd").files({"provider": "res://assets/effects/malphite/player.gd", "variant": "cas"}, errors)
	_expect(errors.is_empty() and "res://assets/effects/malphite/cas/assets/characters/malphite/skins/skin16/particles/flame_trail_gradient.png" in resources.resources, "调色板进入赛前预加载资源清单")
	effects.clear_detached()
	_expect(effects._detached.is_empty(), "清场显式回收独立粒子")
	world.queue_free()
