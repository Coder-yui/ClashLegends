class_name AudioPresentationSuite
extends RefCounted

func run(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var cues: Array[StringName] = []
	var on_cue := func(card_id: String, cue: StringName, _position: Vector2):
		if card_id == "garen":
			cues.append(cue)
	audio.cue_played.connect(on_cue)
	var stats := CardDB.get_card("garen")
	var previewed := audio.preview_attack("garen", stats, Vector2(360.0, 640.0))
	audio._process(float(stats.first_hit) + 0.01)
	var preview_timeline_ok := previewed and cues == [&"attack_swing", &"attack_hit"]

	var unit := Unit.new()
	unit.card_id = "garen"
	unit.setup(0, stats, stats.name)
	main.add_child(unit)
	audio.attach_unit(unit, stats)
	unit._attack_visual_serial = 1
	audio._process(0.0)
	var real_start_ok := cues.count(&"attack_swing") == 2
	var hp_before := unit.hp
	var real_hit_ok := audio.play_attack_hit(unit, Vector2(360.0, 600.0)) and cues.count(&"attack_hit") == 2
	harness._expect(
		preview_timeline_ok and real_start_ok and real_hit_ok and is_equal_approx(unit.hp, hp_before)
		and main.has_method("_rpc_attack_audio_hit"),
		"音频表现按攻击序号播放挥击、按命中事件播放冲击，开发面板试听不修改权威状态且客户端有独立重放入口",
	)
	cues.clear()
	unit.prepare_empowered_attack(2.0)
	audio._process(0.0)
	unit._attack_visual_serial = 2
	unit._empowered_attack_visual_serial = 2
	audio._process(0.0)
	audio._process(0.0)
	harness._expect(cues == [&"empowered_ready", &"empowered_swing"], "强化普攻播放 Q 准备和专用挥击，不叠加普攻挥击且重复帧不重播")
	cues.clear()
	unit.play_visual_action(&"judgment", 3.0)
	audio._process(0.0)
	audio._process(0.0)
	var sustained: AudioStreamPlayer2D = audio._sustain_players.get(unit.get_instance_id())
	# AudioStreamPlayer2D 在内部物理帧启动 playback，不能同一同步帧断言暂停状态。
	await main.get_tree().physics_frame
	await main.get_tree().process_frame
	unit.global_position = Vector2(250, 700)
	unit._prev_pos = unit.global_position
	unit.frozen_timer = 1.0
	audio._process(0.0)
	var follows_and_pauses := sustained != null and sustained.global_position.is_equal_approx(unit.get_visual_screen_position()) and sustained.stream_paused
	unit.frozen_timer = 0.0
	audio._process(0.0)
	harness._expect(follows_and_pauses and not sustained.stream_paused and cues.count(&"judgment:sustain") == 1, "审判空转有独立持续音，跟随角色、控制暂停/恢复且重复帧不重启")
	unit._visual_action_time_left = 0.0
	audio._process(0.0)
	harness._expect(cues == [&"judgment:start", &"judgment:sustain", &"judgment:end"] and not audio._sustain_players.has(unit.get_instance_id()), "审判随动作起止播放，结束停止持续音，空挥没有命中声")
	cues.clear()
	unit.play_visual_action(&"judgment", 3.0)
	audio._process(0.0)
	unit.notify_visual_death()
	unit.notify_visual_death()
	unit._visual_action_time_left = 0.0
	audio._process(0.0)
	harness._expect(cues == [&"judgment:start", &"judgment:sustain", &"death"] and not audio._unit_entries.has(unit.get_instance_id()) and not audio._sustain_players.has(unit.get_instance_id()), "死亡声只播放一次，死亡停止审判持续音且不补播结束事件")
	var invalid_stats := stats.duplicate(true)
	invalid_stats.audio.events["unknown:start"] = {"pool": ["res://missing.wav"]}
	var errors := PackedStringArray()
	CardDB._validate_audio_config("invalid", invalid_stats, errors)
	harness._expect(errors.size() >= 2, "音频事件 validator 拒绝未绑定动作与丢失的事件音频")
	# 客户端只读快照字段，不读取本地权威计时。
	var client_unit := Unit.new()
	client_unit.card_id = "garen"
	client_unit.setup(0, stats, stats.name)
	main.add_child(client_unit)
	client_unit.set_battle_context(main.battle_context)
	var previous_mode: String = main.mode
	main.mode = "client"
	audio.attach_unit(client_unit, stats)
	cues.clear()
	client_unit.net_attack_visual_serial = 1
	client_unit.net_empowered_attack_visual_serial = 1
	client_unit.net_visual_action_serial = 1
	client_unit.net_visual_action_name = &"judgment"
	client_unit.net_visual_action_time_left = 3.0
	audio._process(0.0)
	audio._process(0.0)
	client_unit.net_visual_action_time_left = 0.0
	audio._process(0.0)
	harness._expect(cues == [&"empowered_swing", &"judgment:start", &"judgment:sustain", &"judgment:end"], "客户端音频跟随快照动作与强化序号，重复快照不重播")
	main.mode = previous_mode
	client_unit.free()
	var yi_cues: Array[StringName] = []
	var yi_listener := func(card_id: String, cue: StringName, _position: Vector2):
		if card_id == "masteryi":
			yi_cues.append(cue)
	audio.cue_played.connect(yi_listener)
	var yi_stats := CardDB.get_card("masteryi")
	var yi := Unit.new()
	yi.card_id = "masteryi"
	yi.setup(0, yi_stats, yi_stats.name)
	main.add_child(yi)
	audio.attach_unit(yi, yi_stats)
	yi._attack_visual_serial = 1
	audio._process(0.0)
	yi.active_buff_timer = 5.0
	audio._process(0.0)
	yi.active_buff_timer = 0.0
	audio._process(0.0)
	harness._expect(
		yi_cues == [&"attack_swing", &"active_buff:start", &"active_buff:sustain", &"active_buff:end"]
		and not audio._sustain_players.has(yi.get_instance_id()),
		"剑圣播放三段普攻挥击池，并在高原血统开启/持续/结束时接入对应音频且结束释放持续播放器",
	)
	audio.cue_played.disconnect(yi_listener)
	yi.free()
	var mf_cues: Array[StringName] = []
	var mf_listener := func(card_id: String, cue: StringName, _position: Vector2):
		if card_id == "missfortune":
			mf_cues.append(cue)
	audio.cue_played.connect(mf_listener)
	var mf_stats := CardDB.get_card("missfortune")
	var mf := Unit.new()
	mf.card_id = "missfortune"
	mf.setup(0, mf_stats, mf_stats.name)
	main.add_child(mf)
	audio.attach_unit(mf, mf_stats)
	mf._attack_visual_serial = 1
	audio._process(0.0)
	mf.active_buff_timer = 3.0
	audio._process(0.0)
	var mf_sustain: AudioStreamPlayer2D = audio._sustain_players.get(mf.get_instance_id())
	mf.active_buff_timer = 0.0
	audio._process(0.0)
	harness._expect(
		mf_cues == [&"attack_swing", &"active_buff:start", &"active_buff:sustain", &"active_buff:end"]
		and mf_sustain != null and not audio._sustain_players.has(mf.get_instance_id()),
		"赏金猎人 W 按施放/激活/结束事件播放大步流星音效，并在 Buff 结束时释放持续播放器",
	)
	mf_cues.clear()
	var mf_target := Unit.new()
	mf_target.card_id = "garen"
	mf_target.setup(1, stats, stats.name)
	main.add_child(mf_target)
	mf_target.global_position = Vector2(360.0, 600.0)
	var target_hp_before := mf_target.hp
	var passive_landed: bool = main.resolve_attack_hit(0, mf.global_position, mf_target, 20.0, 0.0, 0.0, mf, mf.global_position, -1, {"first_strike": true})
	var regular_landed: bool = main.resolve_attack_hit(0, mf.global_position, mf_target, 20.0, 0.0, 0.0, mf, mf.global_position)
	harness._expect(
		passive_landed and regular_landed and mf_cues == [&"first_strike_hit", &"first_strike:hit_location", &"attack_hit"]
		and is_equal_approx(mf_target.hp, target_hp_before - 40.0),
		"赏金猎人被动首次真实命中替换普通命中音，后续命中恢复普通音且不改变伤害结算",
	)
	mf_cues.clear()
	mf._attack_visual_serial = 2
	mf._attack_visual_first_strike = true
	audio._process(0.0)
	harness._expect(mf_cues == [&"first_strike:cast"], "赏金猎人首击从攻击起手就切换到 PassiveAttack 音效链，不先播放普通挥击")
	mf_target.free()
	audio.cue_played.disconnect(mf_listener)
	mf.free()
	var owners: Array[Unit] = []
	for i in 2:
		var owner := Unit.new()
		owner.card_id = "garen"
		owner.setup(0, stats, stats.name)
		main.add_child(owner)
		audio.attach_unit(owner, stats)
		owner.play_visual_action(&"judgment", 3.0)
		owners.append(owner)
	audio._process(0.0)
	var first_id := owners[0].get_instance_id()
	var second_id := owners[1].get_instance_id()
	owners[0].free()
	harness._expect(not audio._sustain_players.has(first_id) and audio._sustain_players.has(second_id), "销毁一个盖伦立即释放其持续音，不影响其他盖伦")
	owners[1].play_visual_action(&"replacement", 1.0)
	audio._process(0.0)
	harness._expect(not audio._sustain_players.has(second_id), "动作被替换时停止旧动作持续音")
	owners[1].free()
	# 真实脉冲：空范围静音，多目标只响一次且仍各自受伤。
	var source := Unit.new()
	source.card_id = "garen"
	source.setup(0, stats, stats.name)
	main.add_child(source)
	source.global_position = Vector2(-1000, -1000)
	audio.attach_unit(source, stats)
	var effect := {"radius": 90.0, "damage": 60.0, "team": 0, "visual_action": "judgment"}
	cues.clear()
	main._active_skill_effect_system._apply_continuous_area_pulse(source, effect)
	var empty_silent := cues.is_empty()
	var victims: Array[Unit] = []
	for i in 2:
		var victim := Unit.new()
		victim.setup(1, stats, stats.name)
		main.add_child(victim)
		victim.global_position = source.global_position + Vector2(i * 20.0, 0.0)
		victims.append(victim)
	main._active_skill_effect_system._apply_continuous_area_pulse(source, effect)
	harness._expect(empty_silent and cues == [&"judgment:hit"] and is_equal_approx(victims[0].hp, float(stats.hp) - 60.0) and is_equal_approx(victims[1].hp, float(stats.hp) - 60.0), "审判空挥静音，真实范围脉冲多目标受伤只播放一次命中声")
	for victim in victims:
		victim.free()
	source.free()
	audio._process(0.0)
	audio.cue_played.disconnect(on_cue)
	unit.free()
	_check_ranged_audio(harness, main)

func _check_ranged_audio(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var cues: Array[StringName] = []
	var listener := func(card_id: String, cue: StringName, _position: Vector2):
		if card_id == "ashe":
			cues.append(cue)
	audio.cue_played.connect(listener)
	var stats := CardDB.get_card("ashe")
	var source := Unit.new()
	source.card_id = "ashe"
	source.setup(0, stats, stats.name)
	main.add_child(source)
	source.set_battle_context(main.battle_context)
	source.global_position = Vector2(-1000, -1000)
	audio.attach_unit(source, stats)
	var victims: Array[Unit] = []
	for i in 2:
		var victim := Unit.new()
		victim.setup(1, CardDB.get_card("garen"), "target")
		main.add_child(victim)
		victim.global_position = source.global_position + Vector2(100, i * 25.0)
		victims.append(victim)
	var hp_before := victims[0].hp
	source._attack_visual_serial = 1
	audio._process(0.0)
	audio._process(0.0)
	var cast_only := cues == [&"attack_swing"]
	main.launch_attack(source, victims[0], 58.0, 480.0, 0.0, 0.0, Color.WHITE)
	var launch_only := cues == [&"attack_swing", &"attack_launch"] and is_equal_approx(victims[0].hp, hp_before)
	main._projectile_system.tick(1.0)
	harness._expect(cast_only and launch_only and cues == [&"attack_swing", &"attack_launch", &"attack_hit"] and is_equal_approx(victims[0].hp, hp_before - 58.0), "寒冰拉弓/真实离弦/弹体命中音效分离，飞行前不提前扣血或响命中声")
	cues.clear()
	main.launch_attack(source, null, 58.0, 480.0, 0.0, 0.0, Color.WHITE)
	harness._expect(cues.is_empty(), "取消或无效目标不生成弹体，也不播放离弦声")
	var skill: Dictionary = CardDB.active_skills_for("ashe")[0]
	cues.clear()
	source.play_visual_action(&"active", float(skill.cast_duration))
	audio._process(0.0)
	harness._expect(cues == [&"active:start"], "万箭齐发准备阶段仅播放起手音，不提前播放释放与命中")
	var hp_a := victims[0].hp
	var hp_b := victims[1].hp
	source.active_skill_cast_facing = Vector2.RIGHT
	main._queue_active_skill_impact(source, skill, float(skill.impact_delay))
	main._tick_pending_active_skill_impacts(0.60)
	harness._expect(cues == [&"active:start"] and is_equal_approx(victims[0].hp, hp_a), "万箭齐发 0.62 秒权威延迟前不播放释放或命中")
	main._tick_pending_active_skill_impacts(0.02)
	harness._expect(cues == [&"active:start", &"active:release", &"active:hit"] and is_equal_approx(victims[0].hp, hp_a - 70.0) and is_equal_approx(victims[1].hp, hp_b - 70.0), "万箭齐发实际释放时发声，多目标分别受伤但只播放一次技能命中声")
	cues.clear()
	main._active_skill_effect_system.apply_frontal(source, skill, Vector2.LEFT)
	harness._expect(cues == [&"active:release"], "万箭齐发空扇区有释放音而无命中音")
	cues.clear()
	var previous_mode: String = main.mode
	main.mode = "client"
	main._client_units[987654] = source
	main._rpc_unit_audio_event(987654, "attack_launch", source.global_position)
	main._rpc_unit_audio_event(987654, "active:release", source.global_position)
	main._rpc_unit_audio_event(987654, "active:hit", source.global_position)
	harness._expect(cues == [&"attack_launch", &"active:release", &"active:hit"] and is_equal_approx(victims[0].hp, hp_a - 70.0), "客户端重放寒冰离弦和技能事件，不重复结算伤害")
	main._client_units.erase(987654)
	main.mode = previous_mode
	cues.clear()
	source.notify_visual_death()
	source.notify_visual_death()
	var voice_found := false
	for player in audio._world_players:
		voice_found = voice_found or player.bus == &"Voice"
	harness._expect(cues == [&"death"] and voice_found, "寒冰死亡原事件只播放一次，路由 Voice 总线")
	for victim in victims:
		victim.free()
	source.free()
	audio._process(0.0)
	audio.cue_played.disconnect(listener)
