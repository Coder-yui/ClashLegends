extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_ragnarok(main)
	_check_ragnarok_audio(main)
	for team in [0, 1]:
		var old: Array[Unit] = main.runtime._spawn_card_units(team, "olaf", Vector2(250, 1000), 0.0)
		var group: Array[Unit] = main.runtime._spawn_card_units(team, "olaf", Vector2(420, 1000), 0.0)
		var enemy: Array[Unit] = main.runtime._spawn_card_units(1 - team, "olaf", Vector2(400, 250), 0.0)
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
	_expect(visual._parts.size() == 10 and visual.PART_BONES[0] == "L_BUFFBONE_GLB_HAND_LOC" and visual.PART_BONES[4] == "R_BUFFBONE_GLB_HAND_LOC", "原版双手起手闪光挂点")
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
	visual.status_state = Vector2(1.0, 6.0)
	visual.control_immunity_clock = Vector2(1.0, 6.0)
	visual.advance_status(true, true, 0.0)
	_expect(visual._parts[6].visible and visual._parts[7].visible and visual._parts[8].visible and visual._parts[9].visible and not visual._parts[2].visible, "R切换到原版施放体表与双手层，W层不混播")
	_expect(visual._parts[8]._ribbons.size() == 2, "两条R原版带状层以轨迹网格绘制")
	for index in [8, 9]:
		var pose: Transform3D = visual._skeleton.global_transform * visual._skeleton.get_bone_global_pose(visual._bones[index])
		_expect(visual._parts[index].global_position.is_equal_approx(pose.origin), "R双手遵循原版脚本挂点")
	var mesh_nodes := model.find_children("*", "MeshInstance3D", true, false)
	var normals_ok := not mesh_nodes.is_empty()
	for mesh_node in mesh_nodes:
		for surface in mesh_node.mesh.get_surface_count():
			var arrays: Array = mesh_node.mesh.surface_get_arrays(surface)
			normals_ok = normals_ok and arrays[Mesh.ARRAY_NORMAL] != null and arrays[Mesh.ARRAY_NORMAL].size() == arrays[Mesh.ARRAY_VERTEX].size()
	_expect(normals_ok, "原版SKN法线完整进入GLB，R轮廓光不能依赖缺省法线")
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_expect(player.has_animation("Run") and not player.has_animation("RagnarokRun") and not CardDB.get_card("olaf").visual_animations.has("control_immune_move"), "R保留原版Run，不生成或切换合成移动动作")
	visual.advance_status(true, false, 0.0)
	_expect(not visual.visible and not visual._parts[7]._attached[0].material.get_shader_parameter("attached_enabled"), "R凝滞隐藏蒙皮和粒子")
	visual.advance_status(false, false, 0.0)
	_expect(not visual.visible and not visual._parts[5]._attached[0].material.get_shader_parameter("attached_enabled"), "死亡或状态结束清除体表叠加")
	var r_draws := [0]
	visual.prepare_resource_sample([CardDB.active_skills_for("olaf")[1]], func():
		if visual._parts[6].visible and visual._parts[8].visible and not visual._parts[0].visible: r_draws[0] += 1)
	_expect(r_draws[0] == 5 and not visual.visible and visual.control_immunity_clock == Vector2.ZERO, "开局按所选R实际绘制预热，并清理样本状态")
	model.free()
	visual.free()

func _check_ragnarok(main: Node2D) -> void:
	var skill: Dictionary = CardDB.active_skills_for("olaf")[1]
	for team in [0, 1]:
		var group: Array[Unit] = main.runtime._spawn_card_units(team, "olaf", Vector2(300, 900), 0.0)
		var old: Array[Unit] = main.runtime._spawn_card_units(team, "olaf", Vector2(500, 900), 0.0)
		var enemy: Unit = main._spawn_unit(UnitSpawnRequest.new(1 - team, "target_dummy", Vector2(300, 700), {"deploy_time_override": 0.0}))
		var source := group[0]
		for member in group:
			member.stun(10.0)
			member.freeze(10.0)
			member.root(10.0)
			member.silence(10.0)
			member.taunt(enemy, 10.0)
			member.apply_slow(10.0, 0.3)
			member.apply_attack_speed_slow(10.0, 0.4)
			member.apply_blind(3)
			member.knockback.replace(Vector2.RIGHT, 20.0, 1.0)
		_expect(source.can_start_active_skill(skill), "R可在眩晕冰冻沉默嘲讽和位移中起手")
		_expect(not source.can_start_active_skill(CardDB.active_skills_for("olaf")[0]), "W仍遵守普通受控起手门禁")
		_expect(main.preview_active_skill(source, skill), "R经正式Cast Start解控并即时生效")
		for member in group:
			_expect(not member.is_frozen() and not member.is_stunned() and member.control.hard.remaining(&"root") == 0.0 and member.control.hard.remaining(&"silence") == 0.0 and member.control.hard.remaining(&"taunt") == 0.0, "R净化全部已有硬控")
			_expect(member.control.slow_timer == 0.0 and member.control.attack_speed_slow_timer == 0.0 and member.blind_attack_charges == 0 and member.knockback.remaining == 0.0, "R清除双减速致盲及旧轨迹")
			_expect(member.control_immunity_active_visual() and member.control_immunity_clock_visual() == Vector2(0.0, 6.0), "R独立权威窗口")
			_expect(is_equal_approx(member.active_speed_multiplier, 1.3) and is_equal_approx(member.active_attack_speed_multiplier, 1.3) and is_equal_approx(member.active_damage_multiplier, 1.3), "R移速攻速伤害均增加30%")
			member.hp = 300
			member._try_attack_lifesteal(100)
			_expect(member.hp == 330.0, "R实际普攻生命伤害按30%吸血")
			member.stun(1.0); member.freeze(1.0); member.root(1.0); member.silence(1.0); member.taunt(enemy, 1.0)
			member.apply_slow(1.0, 0.2); member.apply_attack_speed_slow(1.0, 0.2); member.apply_blind(2)
			member.apply_stasis(1.0, &"enemy", CombatInteraction.effect_context(enemy))
			_expect(not member.is_frozen() and not member.is_stunned() and member.control.permissions() == ControlState.ALL_PERMISSIONS and member.blind_attack_charges == 0 and member.control.slow_timer == 0.0 and member.control.attack_speed_slow_timer == 0.0, "R拒绝新增硬控致盲双减速与敌方凝滞")
			_expect(not member.apply_forced_displacement(Vector2.RIGHT, 50.0, 0.5) and not member.can_receive_knockback(member.position, 50.0, 0.5, 1.0), "R拒绝击退推拉和持续吸引")
			member.take_damage(100.0)
			_expect(member.hp == 230.0, "控制免疫不提供伤害免疫")
			member._receive_stun(1.0, &"deferred")
			member._receive_freeze(1.0, &"deferred")
			_expect(not member.is_stunned() and not member.is_frozen(), "批次延迟提交复核免控状态")
			for tick in 119: member._tick_active_statuses(0.05)
			_expect(member.control_immunity_active_visual(), "R第119Tick仍免控")
			member._tick_active_statuses(0.05)
			member.stun(1.0)
			member._try_attack_lifesteal(100)
			_expect(not member.control_immunity_active_visual() and member.is_stunned() and member.active_damage_multiplier == 1.0 and member.hp == 230.0, "R第120Tick全部到期，旧控制不恢复，新控制可施加")
		_expect(not old[0].control_immunity_active_visual() and not enemy.control_immunity_active_visual(), "R不影响旧批次与敌方")
		var friend := old[0]
		main.preview_active_skill(friend, skill)
		for context in [CombatInteraction.effect_context(friend), CombatInteraction.effect_context(null, friend.team), {}]:
			friend.apply_stasis(1.0, &"friendly", context)
			friend._receive_stasis(1.0, &"deferred", context)
			_expect(not CombatInteraction.in_stasis(friend) and friend.control_immunity_active_visual() and is_equal_approx(friend.active_speed_multiplier, 1.3), "R拒绝己方、自身、无来源及延迟提交凝滞，不抑制增益")
		for tick in 20: friend._tick_active_statuses(0.05)
		_expect(friend.control_immunity_active_visual() and is_equal_approx(friend.control_immunity_clock_visual().x, 1.0), "被免疫的凝滞不刷新R时钟")
		for tick in 100: friend._tick_active_statuses(0.05)
		friend.apply_stasis(1.0, &"friendly", CombatInteraction.effect_context(friend))
		_expect(CombatInteraction.in_stasis(friend) and not friend.can_start_active_skill(skill), "R到期后己方凝滞恢复生效，凝滞中仍不能施放R")
		for actor in group + old: actor.free()
		enemy.free()
	for field in ["control_immunity", "cleanse_controls"]:
		var stats := CardDB.get_card("olaf").duplicate(true)
		stats.active_skills[1][field] = "true"
		_expect(not CardDB.VALIDATOR.validate_all({"olaf": stats}, false).is_empty(), "免控/净化拒绝错误字段类型")

func _check_ragnarok_audio(main: Node2D) -> void:
	var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "olaf_single", Vector2(350, 1000), {"deploy_time_override": 0.0}))
	var audio := GameAudioManager.new()
	main.add_child(audio)
	audio.attach_unit(unit, CardDB.get_card("olaf_single"))
	var cues: Array[StringName] = []
	audio.cue_played.connect(func(_card: String, cue: StringName, _at: Vector2): cues.append(cue))
	main.preview_active_skill(unit, CardDB.active_skills_for("olaf_single")[1])
	audio._tick_attached_units()
	var key := audio._sustain_key(unit.get_instance_id(), &"buff")
	var sustain = audio._sustain_players.get(key)
	_expect(sustain != null and cues.count(&"control_immunity:start") == 1 and cues.count(&"control_immunity:sustain") == 1 and not cues.has(&"active_buff:start"), "R播放独立起手及持续音轨，不混入W")
	var sustain_stream := load("res://assets/audio/units/olaf/play_sfx_olaf_olafr_onbuffactivate.wav") as AudioStreamWAV
	_expect(sustain_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and sustain_stream.loop_begin == 0 and sustain_stream.loop_end == 277874, "R持续声沿原Wwise完整277874采样点循环")
	unit.apply_stasis(1.0, &"friendly", CombatInteraction.effect_context(unit))
	audio._tick_attached_units()
	_expect(not CombatInteraction.in_stasis(unit) and unit.control_immunity_active_visual(), "己方凝滞被免疫，不隐藏R表现")
	for tick in 20: unit._tick_active_statuses(0.05)
	audio._tick_attached_units()
	_expect(audio._sustain_players.get(key) == sustain and cues.count(&"control_immunity:start") == 1 and not cues.has(&"active_buff:start"), "免疫己方凝滞保持同一R持续播放器，不重播起手或错播W")
	for tick in 100: unit._tick_active_statuses(0.05)
	audio._tick_attached_units()
	_expect(not audio._sustain_players.has(key) and audio._sustain_players.get(key + ":tail") == sustain, "六秒到期结束R持续层，同一播放器转入原停止尾音")
	audio._tick_sustain_fades(0.375)
	_expect(is_equal_approx(sustain.volume_linear, 0.5) and not unit.control_immunity_active_visual(), "原停止事件750ms线性淡出，中点半幅但权威免控已经结束")
	audio._tick_sustain_fades(0.375)
	_expect(not audio._sustain_players.has(key + ":tail"), "原停止事件750ms完成后释放尾音")
	main.preview_active_skill(unit, CardDB.active_skills_for("olaf_single")[1])
	audio._tick_attached_units()
	unit.take_damage(100000)
	audio._tick_attached_units()
	_expect(not audio._sustain_players.has(key) and audio._sustain_players.has(key + ":tail"), "死亡同样触发R停止淡出")
	audio.end_battle()
	_expect(audio._sustain_players.is_empty(), "清场立即清除R停止尾音")
	unit.free()
	audio.free()
