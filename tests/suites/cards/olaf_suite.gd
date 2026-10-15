extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for team in [0, 1]:
		var old: Array[Unit] = main._spawn_card_units(team, "olaf", Vector2(250, 1000), 0.0)
		var group: Array[Unit] = main._spawn_card_units(team, "olaf", Vector2(420, 1000), 0.0)
		var enemy: Array[Unit] = main._spawn_card_units(1 - team, "olaf", Vector2(400, 250), 0.0)
		_expect(group.size() == 2 and is_equal_approx(group[0].position.distance_to(group[1].position), 64.0), "狂战士双方横排间隔1.6格")
		var skill: Dictionary = CardDB.active_skills_for("olaf")[0]
		main._active_skill_effect_system.apply(group[0], skill)
		_expect(old[0].shield_hp == 0 and enemy[0].shield_hp == 0, "W不影响旧部署和敌方")
		for member in group:
			_expect(member.shield_hp == 180 and is_equal_approx(member.active_attack_speed_multiplier, 1.3), "双方成员各获得护盾和30%攻速")
			member.hp = 300
			member._try_attack_lifesteal(100)
			_expect(member.hp == 330, "限时吸血按实际伤害30%回血")
			member._try_attack_lifesteal(0)
			_expect(member.hp == 330, "空挥和纯护盾伤害不吸血")
			member.take_damage(180)
			_expect(member.shield_hp == 0 and member.hp == 330 and member.active_buff_timer > 0, "盾破不终止攻速和吸血")
			member.buffs.advance(4.95)
			member._try_attack_lifesteal(100)
			_expect(member.hp == 360, "第99Tick仍有吸血")
			member.buffs.advance(0.05)
			member._try_attack_lifesteal(100)
			_expect(member.hp == 360 and member.active_attack_speed_multiplier == 1.0, "第100Tick攻速吸血同时到期")
		# 未受伤的护盾自然到期，攻速和吸血继续至第100个权威Tick。
		main._active_skill_effect_system.apply(old[0], skill)
		for member in old:
			member.hp = 300
			for tick in 49: member._tick_active_statuses(0.05)
			_expect(member.shield_hp == 180, "第49Tick护盾仍存在")
			member._tick_active_statuses(0.05)
			member._try_attack_lifesteal(100)
			_expect(member.shield_hp == 0 and member.hp == 330 and is_equal_approx(member.active_attack_speed_multiplier, 1.3), "第50Tick护盾自然消失但攻速吸血继续")
			for tick in 49: member._tick_active_statuses(0.05)
			member._try_attack_lifesteal(100)
			_expect(member.hp == 360 and is_equal_approx(member.active_attack_speed_multiplier, 1.3), "第99Tick仍有攻速吸血")
			member._tick_active_statuses(0.05)
			member._try_attack_lifesteal(100)
			_expect(member.hp == 360 and member.active_attack_speed_multiplier == 1.0, "第100Tick攻速吸血自然到期")
		for actor in old + group + enemy: actor.free()
	var solo: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "olaf_single", Vector2(350, 1000), {"deploy_time_override": 0.0}))
	main._active_skill_effect_system.apply(solo, CardDB.active_skills_for("olaf_single")[0])
	_expect(solo.shield_hp == 180 and solo.buffs.remaining(&"timed_lifesteal") == 5.0, "单只系统对象也能施放完整W")
	solo.hp = solo.max_hp - 1
	solo._try_attack_lifesteal(100)
	_expect(solo.hp == solo.max_hp, "限时吸血不突破生命上限")
	solo.apply_stasis(1.0)
	solo.hp = 300
	solo._try_attack_lifesteal(100)
	_expect(solo.hp == 300, "凝滞抑制吸血")
	solo.free()
	for value in [-0.3, 0.0, NAN]:
		var stats: Dictionary = CardDB.get_card("olaf").duplicate(true)
		stats.active_skills[0].heal_ratio = value
		_expect(not CardDB.VALIDATOR.validate_all({"olaf": stats}, false).is_empty(), "拒绝非法限时吸血比例")

	# 音频走真实生成入口；每组两人只产生一次 Voice，其他批次与阵营独立。
	var audio := GameAudioManager.new()
	main.add_child(audio)
	var count := [0]
	audio.cue_played.connect(func(_card: String, cue: StringName, _at: Vector2):
		if cue == &"deploy:voice": count[0] += 1)
	var audio_stats: Dictionary = CardDB.get_card("olaf")
	_expect(audio_stats.audio.events["deploy:voice"].pool.size() == 3, "部署语音池恰好三句")
	var audio_units: Array[Unit] = []
	for team in [0, 1]:
		for batch in [3001, 3002]:
			for member in 2:
				var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team, "olaf", Vector2(350, 900 if team == 0 else 300), {"deployment_group_id": batch}))
				audio_units.append(unit)
				audio.attach_unit(unit, audio_stats)
				audio.attach_unit(unit, audio_stats)
	_expect(count[0] == 4, "两阵营两批部署各一次，重绑不补播")
	_expect(not audio.play_event(audio_units[1], &"deploy:voice", Vector2.ZERO), "同组第二人显式重复事件也被抑制")
	audio.begin_battle()
	audio.attach_unit(audio_units[0], audio_stats)
	_expect(count[0] == 5, "新局相同组ID恢复部署语音")
	var picks := {}
	audio._clip_rng.seed = 445
	for index in 24:
		audio_units[0].deployment_group_id = 4000 + index
		audio.play_event(audio_units[0], &"deploy:voice", Vector2.ZERO)
		for selected in audio._last_adjusted_clip.values(): picks[selected] = true
	_expect(picks.size() == 3, "独立批次随机覆盖全部三句")
	for unit in audio_units: unit.free()
	audio.free()
	_expect(CardDB.VALIDATOR.validate_all({"olaf": audio_stats}, false).is_empty(), "正式部署语音范围通过校验")
	var invalid_audio := audio_stats.duplicate(true)
	invalid_audio.audio.events["deploy:voice"].scope = "all"
	_expect(not CardDB.VALIDATOR.validate_all({"olaf": invalid_audio}, false).is_empty(), "拒绝未知部署语音范围")

	var visual = load("res://assets/effects/olaf/buff.tscn").instantiate()
	main.add_child(visual)
	visual.configure(22.5)
	visual.status_state = Vector2(1.0, 5.0)
	visual.shield_active = true
	visual.advance_status(true, true, 0.0)
	_expect(visual.visible and visual._parts[1].visible, "W窗口内显示护盾")
	visual.shield_active = false
	visual.advance_status(true, true, 0.0)
	_expect(visual.visible and not visual._parts[1].visible and visual._parts[2].visible, "盾破只隐藏盾层，双斧发光保留")
	visual.advance_status(true, false, 0.0)
	_expect(not visual.visible, "凝滞隐藏但不重新创建状态")
	visual.status_state = Vector2(5.0, 5.0)
	visual.advance_status(true, true, 0.0)
	_expect(not visual.visible, "表现时钟保留尾部不延长五秒增益光效")
	_expect(visual._parts.size() == 6 and visual.PART_BONES[0] == "L_BUFFBONE_GLB_HAND_LOC" and visual.PART_BONES[4] == "R_BUFFBONE_GLB_HAND_LOC", "原版双手起手闪光挂点")
	var original := StandardMaterial3D.new()
	visual.make_overlay(original)
	_expect(visual._parts[1]._attached.size() == 2 and visual._parts[5]._attached.size() == 1, "护盾和血色层使用蒙皮材质叠加")
	visual.status_state = Vector2(0.15, 5.0)
	visual.shield_active = true
	visual.advance_status(true, true, 0.0)
	_expect(visual._parts[1]._attached[0].material.get_shader_parameter("attached_enabled"), "激活时显示护盾蒙皮层")
	visual.shield_active = false
	visual.advance_status(true, true, 0.0)
	_expect(not visual._parts[1]._attached[0].material.get_shader_parameter("attached_enabled") and visual._parts[5]._attached[0].material.get_shader_parameter("attached_enabled"), "破盾关闭盾蒙皮但保留增益层")
	visual.advance_status(true, false, 0.0)
	_expect(not visual._parts[5]._attached[0].material.get_shader_parameter("attached_enabled"), "隐藏同步关闭模型上的叠加")
	var model := load("res://assets/units/olaf/olaf_view.tscn").instantiate() as Node3D
	main.add_child(model)
	visual.bind_model(model)
	visual.status_state = Vector2(0.8, 5.0)
	visual.shield_active = true
	visual.advance_status(true, true, 0.0)
	var shield: Node3D = visual._parts[1]
	var ground := shield.to_global(Vector3(0, -100, 0))
	_expect(absf(ground.y - model.global_position.y) < 0.0001, "护盾保留原版负100偏移且地面层落在脚底")
	var before: Vector3 = shield.global_basis.get_scale()
	model.scale *= 1.5
	visual.advance_status(true, true, 0.0)
	_expect(shield.global_basis.get_scale().is_equal_approx(before * 1.5), "模型大小变化时全部粒子同比缩放")
	for index in [0, 2, 3, 4]:
		var bone: int = visual._bones[index]
		_expect(bone >= 0, "正式模型包含特效挂接骨骼")
		var pose: Transform3D = visual._skeleton.global_transform * visual._skeleton.get_bone_global_pose(bone)
		_expect(visual._parts[index].global_position.is_equal_approx(pose.origin), "双手与武器挂接位置跟随真实骨骼")
		if index in [2, 3]:
			_expect(visual._parts[index].global_basis.y.normalized().dot(-pose.basis.x.normalized()) > 0.999, "原版武器正Y映射到模型斧柄负X")
	visual.advance_status(false, false, 0.0)
	_expect(not visual.visible and not visual._parts[5]._attached[0].material.get_shader_parameter("attached_enabled"), "死亡或状态结束清除体表叠加")
	model.free()
	visual.free()
