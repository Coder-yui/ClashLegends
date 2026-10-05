extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var rat := _spawn("twitch", 0, Vector2(200, 900))
	var transitions: Array[bool] = []
	rat.stealth.changed.connect(func(hidden: bool): transitions.append(hidden))
	var front := _spawn("sett", 1, Vector2(300, 900))
	var back := _spawn("garen", 1, Vector2(400, 900))
	var aside := _spawn("garen", 1, Vector2(350, 1000))
	_expect(rat.stealth_hidden() and not front._target_is_attackable(rat), "隐身图奇不能被敌方新锁定")
	_expect(rat.visible_to_team(0) and rat.visible_to_team(1), "双方玩家始终看见隐身模型")
	_expect(CombatInteraction.allows(rat, front), "隐身仍允许范围及已释放命中")
	rat.take_damage(10.0, front)
	_expect(rat.stealth_hidden(), "受伤刷新脱战时钟但不破隐")
	rat._target = front
	rat._attack_visual_pending = true
	rat._try_start_attack_visual(0.0)
	_expect(not rat.stealth_hidden() and front._target_is_attackable(rat), "真实攻击前摇起手破隐")
	_age(rat, 39)
	_expect(not rat.stealth_hidden(), "脱战1.95秒不提前隐身")
	_age(rat, 1)
	_expect(rat.stealth_hidden(), "脱战第40个Tick恢复隐身")
	rat.begin_active_skill_cast(0.25, Vector2.RIGHT, [])
	_expect(rat.stealth_hidden(), "开启技能不破隐")
	_expect(transitions == [false, true], "攻击破隐与入隐各派发一次，技能不派发破隐")
	_age(rat, 5)
	_expect(transitions == [false, true], "持续隐身不重复派发表现事件")
	var sounds: Array[StringName] = []
	var record_sound := func(id: String, cue: StringName, _position: Vector2):
		if id == "twitch": sounds.append(cue)
	main._audio_manager.cue_played.connect(record_sound)
	var skill: Dictionary = CardDB.get_card("twitch").active_skills[0]
	var system: ActiveSkillEffectSystem = main._active_skill_effect_system
	system.apply(rat, skill)
	_expect(rat.attack_range == 200.0 and is_equal_approx(rat.active_attack_speed_multiplier, 1.5) and rat.piercing_attacks_active(), "火力全开同时改变攻速射程与弹体类型")
	var projectile: ProjectileSystem = main._projectile_system
	rat.set_meta("projectile_model_offset", Vector2(14, -48))
	projectile.launch(rat, front, 68.0, 520.0, 0.0, 0.0, rat.color)
	_expect(float(projectile.projectiles.values()[0].remaining) == 300.0, "穿透飞行距离独立于目标距离及身体半径")
	var bolt: Dictionary = projectile.projectiles.values()[0]
	_expect(bolt.speed == 1040.0 and bool(bolt.effects.presentation_source.active_buff), "大招弹速翻倍且出手固化专属音频状态")
	var muzzle := projectile._visual_position(bolt)
	_expect(muzzle.is_equal_approx(rat.position + Vector2(14, -48)), "穿透弩箭画面从武器挂点出发")
	rat.set_meta("projectile_model_offset", Vector2(-70, 20))
	bolt.pos += Vector2(26, 0)
	_expect(projectile._visual_position(bolt).is_equal_approx(muzzle + Vector2(26, 0)), "离弦后不跟随武器偏移，保持直线")
	bolt.pos -= Vector2(26, 0)
	var distant := _spawn("garen", 1, Vector2(485, 900))
	var distant_hp := distant.hp
	var beyond := _spawn("garen", 1, Vector2(700, 900))
	var beyond_hp := beyond.hp
	var before_front := front.hp
	var before_back := back.hp
	var before_aside := aside.hp
	# 出手后来源死亡和增益结束不改变在途弩箭。
	rat._tick_active_statuses(5.0)
	_expect(rat.attack_range == 170.0 and not rat.piercing_attacks_active() and rat.active_attack_speed_multiplier == 1.0, "5秒后全部增益到期")
	_expect(bolt.speed == 1040.0 and bool(bolt.effects.presentation_source.active_buff), "技能结束不改变在途弹速和音频归属")
	rat.free()
	for i in 20: projectile.tick(0.05)
	_expect(front.hp == before_front - 68.0 and back.hp == before_back - 68.0, "穿透同一直线前后排各一次且来源死亡后仍飞行")
	_expect(distant.hp == distant_hp - 68.0 and beyond.hp == beyond_hp, "弩箭命中攻击射程外后排并在固定距离结束")
	_expect(sounds.has(&"active_buff:attack_launch") and sounds.has(&"active_buff:attack_hit"), "大招发射和真实穿透碰撞使用原版R专属声音")
	main._audio_manager.cue_played.disconnect(record_sound)
	_expect(aside.hp == before_aside and projectile.projectiles.is_empty(), "侧面目标不命中，射程结束销毁")
	var mover_source := _spawn("twitch", 0, Vector2(100, 1100))
	var mover := _spawn("sett", 1, Vector2(260, 1100))
	system.apply(mover_source, skill)
	projectile.launch(mover_source, mover, 68.0, 520.0, 0.0, 0.0, mover_source.color)
	var launch_direction: Vector2 = projectile.projectiles.values()[0].direction
	var mover_hp := mover.hp
	mover.position.y += 120.0
	projectile.tick(0.05)
	_expect(projectile.projectiles.values()[0].direction == launch_direction, "目标横移后弩箭不转弯")
	for i in 20: projectile.tick(0.05)
	_expect(mover.hp == mover_hp, "高速横移目标可躲过穿透普攻")
	mover_source.free()
	mover.free()
	var hidden := _spawn("twitch", 0, Vector2(200, 900))
	hidden.record_combat_activity(true)
	projectile.launch(front, hidden, 20.0, 100.0, 0.0, 0.0, front.color)
	_age(hidden, 40)
	var before := hidden.hp
	for i in 30: projectile.tick(0.05)
	_expect(hidden.hp == before - 20.0 and hidden.stealth_hidden(), "先前发出的追踪弹体继续命中隐身单位")
	var cards := CardDB.all().duplicate(true)
	cards.twitch.stealth_delay = -1.0
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "隐身拒绝非正延迟")
	cards = CardDB.all().duplicate(true)
	cards.twitch.active_skills[0].piercing_attacks = "yes"
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "穿透开关拒绝非布尔值")
	cards = CardDB.all().duplicate(true)
	cards.twitch.active_skills[0].range_bonus = -1.0
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "射程增益拒绝负数")

	cards = CardDB.all().duplicate(true)
	cards.twitch.active_skills[0].erase("piercing_distance")
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "穿透普攻拒绝缺失固定距离")
	cards.twitch.active_skills[0].piercing_distance = "far"
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "固定距离拒绝字符串")
	cards = CardDB.all().duplicate(true)
	cards.twitch.active_skills[0].projectile_speed_multiplier = 0.0
	_expect(not CardDB.VALIDATOR.validate_all(cards, false).is_empty(), "弹速倍率必须为正数")
	_check_control_entry()
	_check_ghost_materials()
	_check_animation_mapping()
	_check_deployment_first_frame()
	_check_stealth_effect_resources()
	var old_deck: Array = main._deck.duplicate()
	main._deck[0] = "twitch"
	var units: Array[Unit] = main._spawn_card_units(0, "twitch", Vector2(500, 1050), 0.0, 0)
	var paid := units[0]
	var ability := paid.active_ability_id
	main._elixir.elixir = 8.0
	_expect(main.use_active_skill(ability, 0) and main._elixir.elixir == 6.0, "正式技能请求扣2金币")
	_expect(paid.stealth_hidden(), "等待命令缓冲期间不提前破隐")
	main._sim_tick_id += 10
	main._tick_pending_active_skills(0.05)
	main._commands.tick_impacts(0.05)
	_expect(paid.stealth_hidden() and paid.piercing_attacks_active(), "正式技能起手保持隐身并进入穿透窗口")
	_expect(main._active_skills.entry(ability).uses_remaining == 0 and not main.use_active_skill(ability, 0), "一次使用后拒绝重复请求")
	main._deck = old_deck

func _spawn(id: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))

func _check_ghost_materials() -> void:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var original := StandardMaterial3D.new()
	mesh.mesh.material = original
	root.add_child(mesh)
	var resources := ModelVisualResources.new()
	resources.bind_model(root)
	resources.apply_overlays(false, false, false, false, true)
	var ghost := mesh.get_active_material(0) as BaseMaterial3D
	_expect(ghost != original and ghost.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and ghost.albedo_color.a < 0.5, "隐身创建实例独立半透明材质")
	_expect(original.albedo_color.a == 1.0 and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "隐身不污染共享材质且不留下实体阴影")
	resources.apply_overlays(false, false, false, true, true)
	_expect(mesh.get_active_material(0) == original, "凝滞金身优先于虚化")
	resources.apply_overlays(false, false, false, false, true)
	resources.clear()
	_expect(mesh.get_active_material(0) == original and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "清理和模型回收恢复原材质与阴影")
	root.free()

func _control(rat: Unit, family: String, duration: float) -> void:
	match family:
		"stun": rat.stun(duration)
		"freeze": rat.freeze(duration)
		"stasis": rat.apply_stasis(duration)

func _age(rat: Unit, ticks: int) -> void:
	for i in ticks:
		rat._tick_active_statuses(0.05)
		rat.prepare_action_clocks(0.05)

func _check_control_entry() -> void:
	for family in ["stun", "freeze", "stasis"]:
		var rat := _spawn("twitch", 0, Vector2(300,1050))
		_control(rat, family, 3)
		_age(rat, 45)
		_expect(rat.stealth_hidden(), "已有隐身不被%s打破" % family)
		rat.free()
		rat = _spawn("twitch", 0, Vector2(300,1050))
		rat.record_combat_activity(true)
		_control(rat, family, 3)
		_age(rat, 59)
		_expect(not rat.stealth_hidden() and is_equal_approx(rat.stealth.remaining, 2.0), "%s期间公共空闲保持零，不能新入隐" % family)
		_age(rat, 1)
		_expect(not rat.stealth_hidden(), "%s最终解除仍需连续空闲2秒" % family)
		_age(rat, 39)
		_expect(not rat.stealth_hidden(), "%s解除后1.95秒不提前入隐" % family)
		_age(rat, 1)
		_expect(rat.stealth_hidden(), "%s解除后2秒入隐，无第二重等待" % family)
		rat.free()
	var rat := _spawn("twitch", 0, Vector2(300,1050))
	rat.record_combat_activity(true)
	rat.stun(2)
	rat.freeze(3)
	rat.apply_stasis(4)
	_age(rat, 60)
	_expect(not rat.stealth_hidden() and rat.control.stun_timer == 0 and rat.control.frozen_timer == 0 and rat.control.stasis_timer > 0, "部分控制解除后仍有凝滞，继续禁止入隐")
	_age(rat, 20)
	_expect(not rat.stealth_hidden(), "叠加三控全部解除才开始空闲")
	_age(rat, 40)
	_expect(rat.stealth_hidden(), "三控解除后连续空闲2秒入隐")
	rat.free()
	rat = _spawn("twitch", 0, Vector2(300,1050))
	rat.record_combat_activity(true)
	rat.stun(1)
	_age(rat, 10)
	rat.stun(3)
	_age(rat, 40)
	_expect(not rat.stealth_hidden(), "同类控制续期不能越过入隐门禁")
	_age(rat, 20)
	_expect(not rat.stealth_hidden(), "续期控制到期没有继承控制期间空闲")
	_age(rat, 40)
	_expect(rat.stealth_hidden(), "续期控制结束后空闲2秒入隐")
	rat.free()
	rat = _spawn("twitch", 0, Vector2(300,1050))
	rat.record_combat_activity(true)
	rat.apply_slow(4, 0.5)
	_age(rat, 40)
	_expect(not rat.stealth_hidden() and rat.control.slow_timer > 0, "有效移动减速阻止脱战")
	_age(rat, 80)
	_expect(rat.stealth_hidden(), "减速结束后空闲2秒入隐")
	rat.free()

func _check_animation_mapping() -> void:
	var rat := _spawn("twitch", 0, Vector2(300, 1000))
	var view := UnitModel3D.new()
	var camera := Camera3D.new()
	_main.add_child(camera)
	camera.position = Vector3(0, 10, 20)
	camera.look_at(Vector3.ZERO)
	_main.add_child(view)
	var stats := CardDB.get_card("twitch")
	view.setup(rat, load(stats.visual_scene_path), camera, stats.visual_animations, 0.0)
	view.set_process(false)
	view._animation_player.play("Run")
	_expect(is_equal_approx(view._resolve_clip_blend(&"Run_Stealth", &"locomotion"), 0.1), "普通跑入潜行保留0.1秒混合")
	view._animation_player.play("Run_Stealth")
	_expect(is_equal_approx(view._resolve_clip_blend(&"Run", &"locomotion"), 0.1), "潜行跑转普通跑保留0.1秒混合")
	_expect(view._resolve_clip_blend(&"Death", &"death", 0.2) == 0.0, "原版片段对零混合优先于通用覆盖")
	view._play_state(1)
	_expect(view._animation_player.current_animation == "Idle_Stealth", "隐身待机使用实际潜行动作")
	view._play_state(2)
	_expect(view._animation_player.current_animation == "Run_Stealth", "隐身移动使用实际潜行动作")
	rat.record_combat_activity(true)
	view._play_state(1)
	_expect(view._animation_player.current_animation == "Idle1_Base", "破隐恢复普通待机")
	_main._active_skill_effect_system.apply(rat, stats.active_skills[0])
	view._play_attack(1)
	_expect(view._active_attack_animation == &"Spell4", "技能期间每次普攻使用Spell4")
	_expect(is_equal_approx(view._state_playback_speed(0, &"Respawn"), 1.0), "部署只播Respawn原速前1秒")
	_expect(view._projectile_anchor is BoneAttachment3D and view._projectile_anchor.bone_name == "Arrow", "炮口跟随弩箭骨骼而非胸部")
	view._projectile_anchor.free()
	view._projectile_anchor = preload("res://scripts/presentation/projectile_model_anchor.gd").create(view._model_root)
	_expect(view._projectile_anchor is BoneAttachment3D and view._projectile_anchor.bone_name == "Arrow", "模型复用重建武器挂点")
	view.free()
	camera.free()
	rat.free()

func _check_deployment_first_frame() -> void:
	for team in [0, 1]:
		var rat: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "twitch", Vector2(300, 1000 if team == 0 else 400)))
		var view := _view_for(rat)
		_expect(view != null and view._animation_player != null, "图奇双方部署生成正式模型代理")
		if view == null or view._animation_player == null:
			rat.free()
			continue
		var player := view._animation_player
		var skeleton := view.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var first_pose: Array[Transform3D] = []
		for bone in skeleton.get_bone_count(): first_pose.append(skeleton.get_bone_pose(bone))
		# 首次绘制前应已采到部署动作；零时间求值不能再把默认骨架变成部署姿势。
		player.advance(0.0)
		var pose_ready := true
		for bone in skeleton.get_bone_count():
			pose_ready = pose_ready and first_pose[bone].is_equal_approx(skeleton.get_bone_pose(bone))
		_expect(pose_ready, "图奇部署首帧已应用骨骼姿势，不闪现身体与弩分离的默认模型")
		var hidden_material_ready := true
		for mesh in view._model_resources.meshes():
			for surface in mesh.get_surface_override_material_count():
				var material := mesh.get_active_material(surface) as BaseMaterial3D
				hidden_material_ready = hidden_material_ready and material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color.a < 0.5
			hidden_material_ready = hidden_material_ready and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_expect(hidden_material_ready, "图奇部署首帧已应用隐身材质与阴影状态，不闪现实体")
		_expect(player.current_animation == "Respawn" and is_zero_approx(player.current_animation_position) and is_equal_approx(rat._deploy_timer, 1.0), "首帧初始化不推进部署计时或跳过出场动作")
		view.free()
		rat.free()

func _check_stealth_effect_resources() -> void:
	var entering := StealthTransition3D.new()
	var exiting := StealthTransition3D.new()
	var repeated := StealthTransition3D.new()
	for effect in [entering, exiting, repeated]: _main.add_child(effect)
	entering.setup(true)
	exiting.setup(false)
	repeated.setup(false)
	var shaders_shared := true
	var materials_private := true
	for key in ["material", "streak_material", "wave_material"]:
		var first := entering.get(key) as ShaderMaterial
		var second := exiting.get(key) as ShaderMaterial
		var third := repeated.get(key) as ShaderMaterial
		shaders_shared = shaders_shared and first.shader == second.shader and second.shader == third.shader
		materials_private = materials_private and first != second and second != third and first != third
	_expect(shaders_shared, "入隐、破隐及再次破隐复用同三份着色器，避免按事件重新编译")
	_expect(materials_private, "同时发生的隐身烟雾各自持有材质，不串用动画参数")
	entering._process(0.2)
	var fading_independent := true
	for key in ["material", "streak_material", "wave_material"]:
		var first := entering.get(key) as ShaderMaterial
		var second := exiting.get(key) as ShaderMaterial
		fading_independent = fading_independent and float(first.get_shader_parameter("fade")) > 0.0 and is_zero_approx(float(second.get_shader_parameter("fade")))
	_expect(fading_independent and is_zero_approx(exiting.elapsed), "一个烟雾推进不改变另一个烟雾的透明度或计时")
	_expect(entering.material.get_shader_parameter("tint") != exiting.material.get_shader_parameter("tint") and entering.streak_material.get_shader_parameter("inward") and not exiting.streak_material.get_shader_parameter("inward"), "共享着色器仍分别保留入隐色调与收拢、破隐色调与散开")
	for effect in [entering, exiting, repeated]: effect.free()
	var children := _main.get_child_count()
	var combatants := _main.get_tree().get_nodes_in_group("combatants").size()
	StealthTransition3D.prepare_visual(_main)
	_expect(_main.get_child_count() == children and _main.get_tree().get_nodes_in_group("combatants").size() == combatants, "烟雾预热不留下可见样本或生成权威战斗对象")
