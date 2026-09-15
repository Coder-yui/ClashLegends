class_name AudioPresentationSuite
extends RefCounted

func run(harness: Object, main: Node2D) -> void:
	_check_selected_deploy_audio(harness, main)
	_check_voice_budget(harness, main)
	_check_team_audio_routes(harness, main)
	_check_match_announcements(harness, main)
	_check_tombstone_sustain(harness, main)
	_check_tombstone_active_cast(harness, main)
	_check_tower_damage_audio(harness, main)
	_check_building_audio_lifecycle(harness, main)
	_check_event_expansion(harness, main)
	_check_shield_audio(harness, main)
	await _check_apex_audio_timing(harness, main)
	_check_projectile_launch_lifetime(harness, main)
	_check_launch_segments(harness, main)
	_check_audited_audio(harness, main)
	await _check_batch_audio(harness, main)
	_check_zone_audio(harness, main)
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
	harness._expect(cues == [&"empowered_ready", &"empowered_buff:start", &"empowered_swing"], "强化普攻播放 Q 准备和专用挥击，不叠加普攻挥击且重复帧不重播")
	cues.clear()
	unit.play_visual_action(&"judgment", 3.0)
	audio._process(0.0)
	audio._process(0.0)
	var sustained: AudioStreamPlayer2D = audio._sustain_players.get(audio._sustain_key(unit.get_instance_id()))
	# AudioStreamPlayer2D 在内部物理帧启动 playback，不能同一同步帧断言暂停状态。
	await main.get_tree().physics_frame
	await main.get_tree().process_frame
	unit.global_position = Vector2(250, 700)
	unit._prev_pos = unit.global_position
	unit.control.frozen_timer = 1.0
	audio._process(0.0)
	var follows_and_pauses := sustained != null and sustained.global_position.is_equal_approx(unit.get_visual_screen_position()) and sustained.stream_paused
	unit.control.frozen_timer = 0.0
	audio._process(0.0)
	harness._expect(follows_and_pauses and not sustained.stream_paused and cues.count(&"judgment:sustain") == 1, "审判空转有独立持续音，跟随角色、控制暂停/恢复且重复帧不重启")
	unit._visual_action_time_left = 0.0
	audio._process(0.0)
	harness._expect(cues == [&"judgment:start", &"judgment:sustain", &"judgment:end"] and not audio._sustain_players.has(audio._sustain_key(unit.get_instance_id())), "审判随动作起止播放，结束停止持续音，空挥没有命中声")
	cues.clear()
	unit.play_visual_action(&"judgment", 3.0)
	audio._process(0.0)
	unit.notify_visual_death()
	unit.notify_visual_death()
	unit._visual_action_time_left = 0.0
	audio._process(0.0)
	harness._expect(cues == [&"judgment:start", &"judgment:sustain", &"death"] and not audio._unit_entries.has(unit.get_instance_id()) and not audio._sustain_players.has(audio._sustain_key(unit.get_instance_id())), "死亡声只播放一次，死亡停止审判持续音且不补播结束事件")
	var invalid_stats := stats.duplicate(true)
	invalid_stats.audio.events["unknown:start"] = {"pool": ["res://missing.wav"]}
	var errors := PackedStringArray()
	CardDB.VALIDATOR._validate_audio_config("invalid", invalid_stats, errors)
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
	# 新增部署语音属于绑定阶段事件；本段只断言后续攻击/技能时序。
	yi_cues.clear()
	yi._attack_visual_serial = 1
	audio._process(0.0)
	yi.active_buff_timer = 5.0
	audio._process(0.0)
	yi.active_buff_timer = 0.0
	audio._process(0.0)
	harness._expect(
		yi_cues == [&"attack_swing", &"active_buff:start", &"active_buff:sustain", &"active_buff:end"]
		and not audio._sustain_players.has(audio._sustain_key(yi.get_instance_id())),
		"剑圣播放三段普攻挥击池，并在高原血统开启/持续/结束时接入对应音频且结束释放持续播放器",
	)
	audio.cue_played.disconnect(yi_listener)
	yi.free()
	# Headless 不等待短音自然播完；首击时序用例与之前的语音预算隔离。
	for player in audio._world_players: player.stop()
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
	mf_cues.clear()
	mf._attack_visual_serial = 1
	audio._process(0.0)
	mf.active_buff_timer = 3.0
	audio._process(0.0)
	var mf_sustain: AudioStreamPlayer2D = audio._sustain_players.get(audio._sustain_key(mf.get_instance_id(), &"buff"))
	mf.active_buff_timer = 0.0
	audio._process(0.0)
	harness._expect(
		mf_cues == [&"attack_swing", &"active_buff:start", &"active_buff:sustain", &"active_buff:end"]
		and mf_sustain != null and not audio._sustain_players.has(audio._sustain_key(mf.get_instance_id(), &"buff")),
		"赏金猎人 W 按施放/激活/结束事件播放大步流星音效，并在 Buff 结束时释放持续播放器",
	)
	mf_cues.clear()
	var mf_target := Unit.new()
	mf_target.card_id = "garen"
	mf_target.setup(1, stats, stats.name)
	main.add_child(mf_target)
	mf_target.global_position = Vector2(360.0, 600.0)
	var target_hp_before := mf_target.hp
	var passive_landed: bool = main._combat.resolve_attack_hit(0, mf.global_position, mf_target, 20.0, 0.0, 0.0, mf, mf.global_position, -1, {"first_strike": true})
	var regular_landed: bool = main._combat.resolve_attack_hit(0, mf.global_position, mf_target, 20.0, 0.0, 0.0, mf, mf.global_position)
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
	harness._expect(not audio._sustain_players.has(audio._sustain_key(first_id)) and audio._sustain_players.has(audio._sustain_key(second_id)), "销毁一个盖伦立即释放其持续音，不影响其他盖伦")
	owners[1].play_visual_action(&"replacement", 1.0)
	audio._process(0.0)
	harness._expect(not audio._sustain_players.has(audio._sustain_key(second_id)), "动作被替换时停止旧动作持续音")
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
	# 本用例验证事件顺序；此前套件的未播完短音不参与这里的拥挤竞争。
	for player in audio._world_players: player.stop()
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
	# 本段只断言普攻时序，不把新增部署语音算入序列。
	cues.clear()
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
	main._commands.tick_impacts(float(skill.impact_delay) - 0.02)
	harness._expect(cues == [&"active:start"] and is_equal_approx(victims[0].hp, hp_a), "万箭齐发权威释放节点前不播放释放或命中")
	main._commands.tick_impacts(0.02)
	harness._expect(cues == [&"active:start", &"active:release"] and is_equal_approx(victims[0].hp, hp_a), "万箭齐发释放只创建弹体与离弦声，飞行抵达前不伤害或播命中声")
	main._tick_projectiles(0.25)
	harness._expect(cues == [&"active:start", &"active:release", &"active:hit"] and is_equal_approx(victims[0].hp, hp_a - 70.0) and is_equal_approx(victims[1].hp, hp_b - 70.0), "万箭齐发实际释放时发声，多目标分别受伤但只播放一次技能命中声")
	cues.clear()
	main._active_skill_effect_system.apply_frontal(source, skill, Vector2.LEFT)
	harness._expect(cues == [&"active:release"], "万箭齐发空扇区有释放音而无命中音")
	cues.clear()
	var previous_mode: String = main.mode
	main.mode = "client"
	main._client_units[987654] = source
	preload("res://tests/suites/network_fixture.gd").deliver(main, "_rpc_unit_audio_event", [987654, "attack_launch", source.global_position])
	preload("res://tests/suites/network_fixture.gd").deliver(main, "_rpc_unit_audio_event", [987654, "active:release", source.global_position])
	preload("res://tests/suites/network_fixture.gd").deliver(main, "_rpc_unit_audio_event", [987654, "active:hit", source.global_position])
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

func _check_batch_audio(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var dragon := Unit.new()
	dragon.card_id = "aurelionsol"
	dragon.setup(0, CardDB.get_card(dragon.card_id), "龙王")
	main.add_child(dragon)
	dragon.set_battle_context(main.battle_context)
	var old_mode: String = main.mode
	main.mode = "client"
	audio.attach_unit(dragon, CardDB.get_card(dragon.card_id))
	var cues: Array[StringName] = []
	var listener := func(id: String, cue: StringName, _pos: Vector2):
		if id == "aurelionsol": cues.append(cue)
	audio.cue_played.connect(listener)
	dragon.net_visual_state = 3
	dragon.net_has_continuous_target = true
	audio._process(0.0)
	audio._process(0.0)
	var key := audio._sustain_key(dragon.get_instance_id(), &"attack")
	var player: AudioStreamPlayer2D = audio._sustain_players.get(key)
	harness._expect(player != null and cues == [&"continuous_attack:start", &"continuous_attack:release", &"continuous_attack:sustain"], "龙王 Q 吐息随快照开始一次，不调用 LoL 普攻池")
	await main.get_tree().physics_frame
	await main.get_tree().process_frame
	dragon.control.frozen_timer = 1.0
	audio._process(0.0)
	harness._expect(player.stream_paused and audio._sustain_players.get(key) == player, "吐息控制期间暂停并保留单个持续播放器")
	audio.set_battle_paused(true)
	audio.set_battle_paused(false)
	harness._expect(player.stream_paused, "工作台恢复保留冻结导致的独立声音暂停")
	dragon.control.frozen_timer = 0.0
	audio._process(0.0)
	audio._on_sustain_finished(key, player)
	harness._expect(audio._sustain_players.get(key) == player and cues.size() == 3, "吐息片段结束续播但不重发开始事件")
	dragon.net_has_continuous_target = false
	audio._process(0.0)
	harness._expect(not audio._sustain_players.has(key) and cues.back() == &"continuous_attack:end", "丢失吐息目标停止持续层并只播放一次收尾")
	dragon.net_has_continuous_target = true
	audio._process(0.0)
	dragon.notify_visual_death()
	harness._expect(not audio._sustain_players.has(key) and cues.back() == &"death", "死亡彻底清理吐息层")
	audio.cue_played.disconnect(listener)
	dragon.free()
	main.mode = old_mode
	var teemo := Unit.new()
	teemo.card_id = "teemo"
	teemo.setup(0, CardDB.get_card("teemo"), "提莫")
	main.add_child(teemo)
	teemo._attack_visual_serial = 7
	teemo._empowered_attack_visual_serial = 7
	var captured := PresentationConfig.attack_source(teemo)
	teemo._attack_visual_serial = 8
	teemo.free()
	var empowered_pool: Array = CardDB.get_card("teemo").audio.empowered_hit
	var played := audio.play_attack_source(captured, Vector2.ZERO)
	harness._expect(played and bool(captured.empowered) and audio._stream_pool_cache.has("\n".join(PackedStringArray(empowered_pool))), "强化在途攻击使用出手时来源，攻击者销毁后仍播放提莫 Q 命中")
	var tf_audio: Dictionary = CardDB.get_card("twisted_fate").audio
	var tf_cast_pool: Array = tf_audio.attack_swing[4]
	var tf_cast_played := audio._play_attack_swing("twisted_fate", tf_audio, Vector2.ZERO, 5)
	harness._expect(tf_cast_played and audio._stream_pool_cache.has("\n".join(PackedStringArray(tf_cast_pool))), "卡牌第五次出手选择原版 E CardmasterStack_cast 声音池")
	var tf_pool: Array = CardDB.get_card("twisted_fate").audio.attack_hit_by_segment[4]
	audio.play_attack_source({"card_id": "twisted_fate", "form": 0, "serial": 5}, Vector2.ZERO)
	harness._expect(audio._stream_pool_cache.has("\n".join(PackedStringArray(tf_pool))), "卡牌第五次命中按来源序号选择 E 声音，不使用第一段")
	var bad := CardDB.get_card("teemo").duplicate(true)
	bad.audio.attack_hit_by_segment = [empowered_pool, empowered_pool]
	var errors := PackedStringArray()
	CardDB.VALIDATOR._validate_audio_config("bad_segments", bad, errors)
	harness._expect(not errors.is_empty(), "分段命中声音数量必须匹配动作数量")

func _check_zone_audio(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var cues: Array[StringName] = []
	var on_cue := func(card_id: String, cue: StringName, _position: Vector2):
		if card_id == "anivia" and "zone_" in String(cue):
			cues.append(cue)
	audio.cue_played.connect(on_cue)
	var unit := Unit.new()
	unit.card_id = "anivia"
	unit.setup(0, CardDB.get_card("anivia"), "凤凰区域音频")
	unit.position = Vector2(360, 820)
	main.add_child(unit)
	var skill: Dictionary = CardDB.get_card("anivia").active_skills[0]
	main._active_skill_effect_system.apply_forward_area(unit, skill, Vector2.UP)
	var event_id: int = main._presentation_event_id
	var entry: Dictionary = audio._zone_players.get(event_id, {})
	var fixed_position: Vector2 = entry.get("position", Vector2.ZERO)
	audio.start_zone_audio(event_id, "anivia", 0, "frost_storm", fixed_position, 3.0)
	unit.free()
	audio.set_battle_paused(true)
	audio.set_battle_paused(true)
	audio._process(0.5)
	var paused_with_world := is_equal_approx(float(audio._zone_players[event_id].time_left), 3.0)
	main._active_skill_effect_system.tick_visuals(1.0)
	harness._expect(is_equal_approx(float(audio._zone_players[event_id].time_left), 3.0), "技能效果更新不再修改声音生命周期")
	audio.set_battle_paused(false)
	audio._process(2.9)
	var persists := audio._zone_players.has(event_id) and cues.count(&"frost_storm:zone_sustain") == 1
	audio._process(0.1)
	var ended_once := not audio._zone_players.has(event_id) and cues.count(&"frost_storm:zone_end") == 1
	main._presentation_event_id += 1
	audio.start_zone_audio(main._presentation_event_id, "anivia", 0, "frost_storm", fixed_position, 3.0)
	audio.begin_battle()
	harness._expect(paused_with_world and persists and ended_once and audio._zone_players.is_empty() and cues.count(&"frost_storm:zone_end") == 1, "冰风暴区域音频去重、独立于施法者销毁、满 3 秒结束一次，场景清理不补结束声")
	audio.cue_played.disconnect(on_cue)

func _check_launch_segments(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var unit := Unit.new()
	var stats := CardDB.get_card("twisted_fate")
	unit.card_id = "twisted_fate"
	unit.setup(0, stats, stats.name)
	main.add_child(unit)
	audio.attach_unit(unit, stats)
	var pools: Array = stats.audio.attack_launch_by_segment
	var passed := true
	var hp_before := unit.hp
	for serial in [1, 4, 5, 6, 10]:
		for player in audio._world_players: player.stop()
		unit._attack_visual_serial = 2 # 模拟客户端快照滞后；以事件携带序号为准。
		passed = audio.play_event(unit, &"attack_launch", unit.global_position, serial) and passed
		var expected := audio._randomized_stream(PackedStringArray(pools[(serial - 1) % pools.size()]))
		passed = audio._world_players[0].stream == expected and passed
	harness._expect(passed and unit.hp == hp_before, "普攻发射声按事件来源序号选择普通/第五击，跨轮及滞后快照正确且不改伤害")
	audio._detach_unit(unit.get_instance_id())
	unit.free()

func _check_audited_audio(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var unit := Unit.new()
	var stats := CardDB.get_card("anivia").duplicate(true)
	stats["deploy_time"] = 0.0
	for player in audio._world_players: player.stop()
	unit.card_id = "anivia"
	unit.setup(0, stats, stats.name)
	main.add_child(unit)
	audio.attach_unit(unit, stats)
	unit._attacking = true
	unit._attack_visual_serial = 1
	var cues: Array = []
	var listener := func(card, cue, _pos):
		if card in ["anivia", "gwen"]: cues.append(String(cue))
	audio.cue_played.connect(listener)
	unit.attack_timeline.visual_elapsed = 0.59
	audio._process(0.0)
	var delayed := cues.is_empty()
	unit.control.frozen_timer = 1.0
	unit.attack_timeline.visual_elapsed = 0.61
	audio._process(0.0)
	var paused := cues.is_empty()
	unit.control.frozen_timer = 0.0
	audio._process(0.0)
	audio._process(0.0)
	var once := cues == ["attack_swing"]
	var playing_before := 0
	for player in audio._world_players:
		if player.playing: playing_before += 1
	audio.play_event(unit, &"attack_launch", unit.position)
	var playing_after := 0
	for player in audio._world_players:
		if player.playing: playing_after += 1
	harness._expect(delayed and paused and once and playing_after > playing_before and cues.back() == "attack_launch" and is_equal_approx(unit.first_hit_time, 0.68), "冰鸟 0.60 秒挥翼声、0.68 秒权威出弹，冻结等待/不重播且发射声独立重叠")
	audio._detach_unit(unit.get_instance_id())
	unit.free()
	cues.clear()
	audio._preview_hit_queue.clear()
	audio.preview_attack("anivia", stats, Vector2.ZERO)
	audio._tick_preview_hits(0.61)
	audio._tick_preview_hits(0.07)
	var preview_launch := cues == ["attack_swing", "attack_launch"]
	audio._tick_preview_hits(0.5)
	harness._expect(preview_launch and cues.back() == "attack_hit", "远程普攻试听包含真实对应发射池，按示例飞行时间加入命中而不等待音频结束")
	cues.clear()
	var gwen := Unit.new()
	var gwen_stats := CardDB.get_card("gwen")
	gwen.card_id = "gwen"
	gwen.setup(0, gwen_stats, gwen_stats.name)
	main.add_child(gwen)
	audio.attach_unit(gwen, gwen_stats)
	cues.clear() # 本段只检查后续缠流状态，部署声音已独立验证。
	gwen._shroud_active = true
	audio._process(0.0)
	audio._process(0.0)
	var key := audio._sustain_key(gwen.get_instance_id(), &"shroud")
	var silent := cues.is_empty() and not audio._sustain_players.has(key)
	gwen._shroud_active = false
	audio._process(0.0)
	audio._detach_unit(gwen.get_instance_id())
	harness._expect(silent and cues.is_empty(), "格温移除缠流音频，即使旧状态出现也不发声")
	gwen.free()
	audio.cue_played.disconnect(listener)
	var lifecycle: Array = []
	var on_lifecycle := func(card, cue, _pos):
		if card in ["anivia", "anivia_egg"] and cue in [&"revival:sustain", &"revival:end", &"death"]: lifecycle.append(String(cue))
	audio.cue_played.connect(on_lifecycle)
	var phoenix := Unit.new()
	phoenix.card_id = "anivia"
	phoenix.setup(0, stats, stats.name)
	phoenix.position = Vector2(360, 1000)
	main.add_child(phoenix)
	audio.attach_unit(phoenix, stats)
	phoenix.take_damage(100000.0, null, 1)
	var egg: Unit = main._latest_unit_for_card("anivia_egg", 0)
	var full_player: AudioStreamPlayer2D = null
	var tail_key := ""
	if egg != null:
		var incubation_key := audio._sustain_key(egg.get_instance_id(), &"revival")
		full_player = audio._sustain_players.get(incubation_key)
		tail_key = incubation_key + "_tail"
		egg._tick_timed_revival(3.1)
	harness._expect(lifecycle == ["revival:sustain"] and full_player != null and audio._sustain_players.get(tail_key) == full_player and full_player.playing, "成功孵化保留同一播放器自然播完尾音，不拆分或重启")
	audio._stop_sustain_key(tail_key)
	var reborn: Unit = main._latest_unit_for_card("anivia", 0)
	if reborn != null and not reborn.is_queued_for_deletion(): reborn.queue_free()
	lifecycle.clear()
	var broken_egg := Unit.new()
	broken_egg.card_id = "anivia_egg"
	var egg_stats := CardDB.get_card("anivia_egg")
	broken_egg.setup(0, egg_stats, egg_stats.name)
	main.add_child(broken_egg)
	audio.attach_unit(broken_egg, egg_stats)
	var egg_key := audio._sustain_key(broken_egg.get_instance_id(), &"revival")
	var incubation_started := audio._sustain_players.has(egg_key)
	broken_egg.take_damage(100000.0, null, 1)
	harness._expect(incubation_started and not audio._sustain_players.has(egg_key) and lifecycle == ["revival:sustain", "death"], "蛋被打碎立即停止孵化音并播放死亡音，不播放成功破壳音")
	audio.cue_played.disconnect(on_lifecycle)
	var double_source := {"card_id": "masteryi", "unit_id": 987654321, "form": 0, "serial": 3}
	var first_double := audio.play_attack_source(double_source, Vector2.ZERO)
	var repeated_double := audio.play_attack_source(double_source, Vector2.ZERO)
	double_source.serial = 6
	var next_double := audio.play_attack_source(double_source, Vector2.ZERO)
	double_source.serial = 4
	var ordinary_a := audio.play_attack_source(double_source, Vector2.ZERO)
	var ordinary_b := audio.play_attack_source(double_source, Vector2.ZERO)
	harness._expect(first_double and not repeated_double and next_double and ordinary_a and ordinary_b, "双重打击整组两刀音每个攻击序号只播一次，下一轮与非分组命中不受影响")
	var xin := Unit.new()
	var xin_stats := CardDB.get_card("xin")
	xin.card_id = "xin"
	xin.setup(0, xin_stats, xin_stats.name)
	main.add_child(xin)
	var sweep_cues: Array = []
	var on_sweep := func(card, cue, _position):
		if card == "xin": sweep_cues.append(String(cue))
	audio.cue_played.connect(on_sweep)
	audio.attach_unit(xin, xin_stats)
	audio.attach_unit(xin, xin_stats)
	harness._expect(sweep_cues.count("deploy:start") == 1 and sweep_cues.count("deploy:voice") == 1, "赵信部署横扫与喊声各播一次，重绑不重播")
	xin.play_visual_action(&"active", 1.0)
	audio._process(0.0)
	audio._process(0.0)
	harness._expect(sweep_cues.count("active:start") == 1 and sweep_cues.count("active:voice") == 1 and not xin_stats.audio.events.has("active:sustain"), "赵信主动只播一次起手横扫与喊声，不接持续护卫音")
	var sweep_stream = load(xin_stats.audio.events["active:start"].pool[0])
	harness._expect(is_equal_approx(sweep_stream.get_length(), 0.65) and xin_stats.audio.events["active:voice"].pool.size() == 4, "赵信横扫裁为 0.65 秒，中文 R 喊声保留四个随机变体")
	audio.cue_played.disconnect(on_sweep)
	var heals: Array = []
	var on_heal := func(card, cue, _position):
		if card == "xin" and cue == &"passive_heal": heals.append(cue)
	audio.cue_played.connect(on_heal)
	xin.hp = xin.max_hp - 30.0
	xin._attack_swing_count = 3
	xin._try_heal_on_hit()
	xin._try_heal_on_hit()
	harness._expect(heals.size() == 1 and is_equal_approx(xin.hp, xin.max_hp), "赵信实际回血才播被动声，满血第三击不伪造回复音")
	audio.cue_played.disconnect(on_heal)
	audio._detach_unit(xin.get_instance_id())
	xin.free()
	var invalid := CardDB.get_card("anivia").duplicate(true)
	invalid.audio.attack_swing_lead_time = -0.1
	var errors := PackedStringArray()
	CardDB.VALIDATOR._validate_audio_config("lead_probe", invalid, errors)
	harness._expect(not errors.is_empty(), "出手声前导时间拒绝负值")

func _check_projectile_launch_lifetime(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var projectiles: ProjectileSystem = main._projectile_system
	projectiles.clear_all()
	var stats := CardDB.get_card("gnar").duplicate(true)
	stats["deploy_time"] = 0.0
	var source := Unit.new()
	source.card_id = "gnar"
	source.setup(0, stats, stats.name)
	source.position = Vector2(360, 900)
	main.add_child(source)
	audio.attach_unit(source, stats)
	var target := Unit.new()
	target.setup(1, CardDB.training_dummy_stats(), "发射声木桩")
	target.position = Vector2(360, 750)
	main.add_child(target)
	var hp_before := target.hp
	var first_id := projectiles._next_id
	projectiles.launch(source, target, 50, 420, 0, 0, source.color)
	var second_id := projectiles._next_id
	projectiles.launch(source, target, 50, 30, 0, 0, source.color)
	var first_player = audio._projectile_launch_players.get(first_id)
	var second_player = audio._projectile_launch_players.get(second_id)
	var separate: bool = is_instance_valid(first_player) and is_instance_valid(second_player) and first_player != second_player
	for _tick in 8:
		projectiles.tick(0.05)
	harness._expect(separate and not audio._projectile_launch_players.has(first_id) and not first_player.playing and audio._projectile_launch_players.has(second_id) and second_player.playing and target.hp == hp_before - 50.0, "小纳尔命中只停止对应弹体的 launch，另一枚仍在飞行发声，伤害不变")
	# 来源死亡/变形不改变已发射弹体所属音频，目标失效才终止它。
	source.free()
	harness._expect(audio._projectile_launch_players.has(second_id), "来源释放后，在途发射声仍由原弹体持有")
	target.hp = 0.0
	projectiles.tick(0.05)
	harness._expect(audio._projectile_launch_players.is_empty() and not second_player.playing, "目标死亡使弹体消失时，发射声也停止")
	target.free()
	var previous_mode: String = main.mode
	main.mode = "client"
	var remote_id := projectiles._next_id
	projectiles._next_id += 1
	var saved_source := {"card_id": "gnar", "form": 0, "serial": 1}
	preload("res://tests/suites/network_fixture.gd").deliver(main, "_rpc_projectile_launch_audio", [remote_id, saved_source, Vector2.ZERO, true])
	var remote_player = audio._projectile_launch_players.get(remote_id)
	preload("res://tests/suites/network_fixture.gd").deliver(main, "_rpc_projectile_launch_audio", [remote_id, saved_source, Vector2.ZERO, true])
	var once: bool = audio._projectile_launch_players.size() == 1 and audio._projectile_launch_players.get(remote_id) == remote_player
	preload("res://tests/suites/network_fixture.gd").deliver(main, "_rpc_projectile_launch_audio", [remote_id, {}, Vector2.ZERO, false])
	preload("res://tests/suites/network_fixture.gd").deliver(main, "_rpc_projectile_launch_audio", [remote_id, saved_source, Vector2.ZERO, true])
	harness._expect(once and audio._projectile_launch_players.is_empty(), "客户端开始/命中停止按弹体 ID 重放，重复及结束后的旧开始不重播")
	remote_id = projectiles._next_id
	projectiles._next_id += 1
	preload("res://tests/suites/network_fixture.gd").deliver(main, "_rpc_projectile_launch_audio", [remote_id, saved_source, Vector2.ZERO, true])
	projectiles.clear_all()
	harness._expect(audio._projectile_launch_players.is_empty(), "客户端清场清理所有弹体持有的发射声")
	main.mode = previous_mode

func _check_apex_audio_timing(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var cues: Array[StringName] = []
	var listener := func(card, cue, _position):
		if card == "apex_turret": cues.append(cue)
	audio.cue_played.connect(listener)
	var stats := CardDB.get_card("apex_turret")
	var source := Unit.new()
	source.card_id = "apex_turret"
	source.setup(0, stats, stats.name)
	main.add_child(source)
	source.set_battle_context(main.battle_context)
	source.position = Vector2(-2000, -2000)
	audio.attach_unit(source, stats)
	audio.attach_unit(source, stats)
	harness._expect(cues.count(&"deploy:start") == 1 and cues.count(&"deploy:voice") == 0 and stats.audio.events["deploy:start"].pool.size() == 3, "大炮台部署仅播三选一 Q 炮台生成 SFX，重绑不重复，不播英雄语音或引擎")
	var idle_key := audio._sustain_key(source.get_instance_id(), &"idle")
	audio._process(0.0)
	harness._expect(not audio._sustain_players.has(idle_key), "炮台部署阶段不启动待机引擎")
	source._deploy_timer = 0.0
	audio._process(0.0)
	audio._process(0.0)
	var idle_player: AudioStreamPlayer2D = audio._sustain_players.get(idle_key)
	harness._expect(idle_player != null and cues.count(&"idle:sustain") == 1, "炮台待机只启动一个引擎播放器")
	audio._on_sustain_finished(idle_key, idle_player)
	harness._expect(audio._sustain_players.get(idle_key) == idle_player and cues.count(&"idle:sustain") == 1, "引擎片段播完续播，不重复触发事件")
	await main.get_tree().physics_frame
	await main.get_tree().process_frame
	source.control.frozen_timer = 1.0
	audio._process(0.0)
	harness._expect(idle_player.stream_paused, "冻结暂停待机引擎，保留播放器")
	source.control.frozen_timer = 0.0
	source._attacking = true
	audio._process(0.0)
	harness._expect(not audio._sustain_players.has(idle_key), "进入普攻停止待机引擎")
	var victim := Unit.new()
	victim.setup(1, CardDB.get_card("garen"), "laser target")
	main.add_child(victim)
	victim.position = source.position + Vector2(150, 0)
	cues.clear()
	source._attack_visual_serial = 1
	audio._process(0.0)
	main.launch_attack(source, victim, 130, 420, 32, 0, Color.WHITE)
	var hp_before := victim.hp
	harness._expect(cues == [&"attack_swing", &"attack_launch"] and victim.hp == hp_before, "大炮台普攻出手和实际弹体发射分离，飞行时不播命中")
	main._projectile_system.tick(1.0)
	harness._expect(cues.back() == &"attack_hit" and victim.hp < hp_before, "大炮台普攻命中音跟随真实炮弹伤害")
	cues.clear()
	var skill: Dictionary = CardDB.active_skills_for("apex_turret")[0].duplicate(true)
	skill["cast_forward"] = Vector2.RIGHT
	main._start_active_skill_cast(source, skill)
	audio._process(0.0)
	hp_before = victim.hp
	harness._expect(cues == [&"laser:sustain"], "大炮台激光先播 OnCast 蓄能，不提前发射或命中")
	main._commands.tick_impacts(0.40)
	source.control.frozen_timer = 1.0
	main._commands.tick_impacts(0.5)
	harness._expect(cues == [&"laser:sustain"] and victim.hp == hp_before, "激光出膛前冻结同时暂停发射声与伤害排程")
	source.control.frozen_timer = 0.0
	main._commands.tick_impacts(0.05)
	harness._expect(cues == [&"laser:sustain", &"laser:release"] and victim.hp == hp_before, "激光 0.45 秒出膛发射声，飞行尚未伤害")
	main._projectile_system.tick(0.04)
	harness._expect(victim.hp == hp_before and cues.back() == &"laser:release", "激光离开炮口但未接触目标时无伤害和命中音")
	main._projectile_system.tick(0.26)
	harness._expect(cues == [&"laser:sustain", &"laser:release", &"laser:hit"] and victim.hp < hp_before, "激光弹体真实接触才播放命中音，发射声不重复")
	cues.clear()
	source.active_skill_cast_facing = Vector2.LEFT
	main._queue_active_skill_impact(source, skill, 0.45)
	main._commands.tick_impacts(0.45)
	main._projectile_system.tick(0.3)
	harness._expect(cues == [&"laser:release"], "激光空击有发射声，无命中音")
	cues.clear()
	main._queue_active_skill_impact(source, skill, 0.45)
	source.hp = 0.0
	main._commands.tick_impacts(1.0)
	harness._expect(cues.is_empty(), "炮台死亡取消尚未发射的激光音频和伤害")
	source.hp = source.max_hp
	source._attacking = false
	source._visual_action_time_left = 0.0
	audio._process(0.0)
	harness._expect(audio._sustain_players.has(idle_key), "炮台返回待机恢复引擎")
	source.notify_visual_death()
	harness._expect(not audio._sustain_players.has(idle_key) and cues.count(&"death") == 1 and stats.audio.events.death.pool.size() == 3, "炮台死亡清理引擎并播放三选一销毁音")
	source.notify_visual_death()
	harness._expect(cues.count(&"death") == 1, "炮台重复死亡通知不重复播放销毁音")

	audio.cue_played.disconnect(listener)
	audio._detach_unit(source.get_instance_id())
	source.free()
	victim.free()

func _check_shield_audio(harness: Object, main: Node2D) -> void:
	var stats := CardDB.get_card("sun_disc")
	var source := Unit.new()
	source.card_id = "sun_disc"
	source.setup(0, stats, stats.name)
	main.add_child(source)
	source.global_position = Vector2(-2000, -2000)
	main._audio_manager.attach_unit(source, stats)
	var ally := Unit.new()
	ally.setup(0, CardDB.get_card("garen"), "ally")
	main.add_child(ally)
	ally.global_position = source.global_position + Vector2(60, 0)
	var enemy := Unit.new()
	enemy.setup(1, CardDB.get_card("garen"), "enemy")
	main.add_child(enemy)
	enemy.global_position = ally.global_position
	var applied: Array[Vector2] = []
	var casts: Array[Vector2] = []
	var listener := func(card_id: String, cue: StringName, position: Vector2):
		if card_id == "sun_disc":
			if cue == &"shield:cast": casts.append(position)
			if cue == &"shield:applied": applied.append(position)
	main._audio_manager.cue_played.connect(listener)
	main._active_skill_effect_system.shield_effects.clear()
	main._active_skill_effect_system.apply_area_shield(source, stats.active_skills[0])
	var waves: Array = main._active_skill_effect_system.shield_effects
	harness._expect(waves.size() == 1 and is_equal_approx(float(waves[0].radius), float(stats.radius) + float(stats.range)), "护盾施放只生成一圈黄色波，使用自身表面加攻击射程的边界")
	var event_id: int = main._last_card_event_id
	main._play_card_event(event_id, "sun_disc", "shield:cast", source.global_position)
	harness._expect(waves.size() == 1, "重复可靠护盾事件不重复生成特效")
	main._active_skill_effect_system.tick_visuals(0.6)
	harness._expect(waves.is_empty() and ally.shield_hp == 180.0, "护盾波自然消失不改变已生效护盾")
	harness._expect(casts.size() == 1 and applied.is_empty()
		and ally.shield_hp == 180.0 and enemy.shield_hp == 0.0,
		"太阳圆盘仅播放施放声，护盾实际生效保持静音")
	harness._expect(PresentationEvents.supports(stats, "shield:applied")
		and not PresentationEvents.supports(CardDB.get_card("garen"), "shield:applied"),
		"护盾音频事件只允许实际具备范围护盾技能的卡牌")
	main._audio_manager.cue_played.disconnect(listener)
	source.free()
	ally.free()
	enemy.free()

func _check_event_expansion(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	for id in ["melee_minion", "ranged_minion", "siege_minion", "super_minion"]:
		var stats := CardDB.get_card(id)
		var blue := PresentationConfig.audio_for(stats, 0)
		var red := PresentationConfig.audio_for(stats, 1)
		harness._expect(blue.attack_hit_by_segment != red.attack_hit_by_segment,
			"%s 双方音库独立，普攻命中按阵营选择" % id)
		var unit := Unit.new()
		unit.card_id = id
		unit.setup(1, stats, stats.name)
		unit._attack_visual_serial = 2
		var source := PresentationConfig.attack_source(unit)
		unit.free()
		harness._expect(int(source.team) == 1 and audio.play_attack_source(source, Vector2(360, 700)),
			"%s 来源销毁后仍保留红方第二段命中声" % id)
	var bad := CardDB.get_card("melee_minion").duplicate(true)
	bad.audio.team_overrides = [{"team_overrides": []}, {}]
	var errors := PackedStringArray()
	CardDB.VALIDATOR._validate_audio_config("invalid_team", bad, errors)
	harness._expect(not errors.is_empty(), "音频 validator 拒绝递归阵营覆盖")
	for team in 2:
		var tower := Tower.new()
		tower.setup(team, CardDB.PRINCESS_TOWER_STATS, false)
		var source := PresentationConfig.attack_source(tower)
		tower.free()
		harness._expect(audio.play_attack_source(source, Vector2(360, 700)), "防御塔销毁后在途弹体仍可播放命中声")
	var deaths: Array[String] = []
	var death_listener := func(id: String, cue: StringName, _position: Vector2):
		if cue == &"death" and id.begins_with("world_"): deaths.append(id)
	audio.cue_played.connect(death_listener)
	for king in [false, true]:
		var building := Tower.new()
		building.setup(0, CardDB.NEXUS_STATS if king else CardDB.PRINCESS_TOWER_STATS, king)
		main.add_child(building)
		var id := PresentationConfig.world_card_id(building)
		building.destroyed.connect(main._on_world_building_destroyed.bind(id, weakref(building)))
		building.take_damage(building.hp + 1)
		building.notify_visual_destroyed()
		building.free()
	harness._expect(deaths == ["world_tower_order", "world_nexus_order"], "塔与水晶实际摧毁只播一次，重复表现通知不重播")
	audio.cue_played.disconnect(death_listener)
	harness._expect(CardDB.get_card("twisted_fate").pre_deploy_time == 1.3, "正式卡牌预部署设置保持不变")
	for definition in preload("res://scripts/data/world_audio.gd").DEFINITIONS.values():
		for event in definition.audio.events.values():
			for path in event.pool:
				harness._expect(load(path) is AudioStream, "系统建筑事件音频可加载")

func _check_building_audio_lifecycle(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var tower := Tower.new()
	tower.setup(0, CardDB.NEXUS_STATS, true)
	main.add_child(tower)
	var id := tower.get_instance_id()
	audio.attach_building_audio(tower, CardDB.NEXUS_VISUAL_CONFIG)
	var entry: Dictionary = audio._building_audio[id]
	var player: AudioStreamPlayer2D = entry.player
	audio.attach_building_audio(tower, CardDB.NEXUS_VISUAL_CONFIG)
	harness._expect(audio._building_audio[id].player == player, "水晶重复附着不重播出生声音")
	harness._expect(entry.idle and entry.tail != null and entry.tail.playing and player.playing, "原生出生节点同时启动出生声与持续运转声")
	var loop_pool := player.stream as AudioStreamRandomizer
	var loop_wav := loop_pool.get_stream(0) as AudioStreamWAV
	harness._expect(loop_wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop_wav.loop_end > 0, "运转声在音频流内部连续循环，不等待画面帧重启")
	var tail: AudioStreamPlayer2D = entry.tail
	tail.stop()
	audio._tick_building_audio(0.1)
	harness._expect(entry.tail == null and player.playing and is_equal_approx(player.volume_db, 0.0), "出生尾声结束只释放一次性层，持续层不切换")
	player = entry.player
	var hp_before := tower.hp
	player.stop()
	audio._tick_building_audio(0.1)
	harness._expect(entry.idle and tower.hp == hp_before, "待机片段可续播，音频不改变权威生命值")
	tower.hp = 0
	audio._tick_building_audio(0.0)
	harness._expect(not audio._building_audio.has(id) and player.stream == null, "水晶死亡立即清除出生与待机声音")
	tower.free()
	harness._expect(not CardDB.get_card("sun_disc").audio.events.has("shield:applied"),
		"护盾生效声已按用户要求禁用")

func _check_tower_damage_audio(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var tower := Tower.new()
	tower.setup(0, CardDB.PRINCESS_TOWER_STATS, false)
	main.add_child(tower)
	var cues: Array[StringName] = []
	var listener := func(id: String, cue: StringName, _pos: Vector2):
		if id == "world_tower_order" and String(cue).begins_with("damage:"): cues.append(cue)
	audio.cue_played.connect(listener)
	audio.attach_building_audio(tower, CardDB.PRINCESS_TOWER_VISUAL_CONFIG)
	tower.take_damage(tower.max_hp * 0.35)
	audio._tick_building_damage_audio()
	audio._tick_building_damage_audio()
	tower.take_damage(tower.max_hp * 0.34)
	audio._tick_building_damage_audio()
	harness._expect(cues == [&"damage:stage1", &"damage:stage2"], "防御塔两段破损各播放一次，重复帧不重播")
	tower.free()
	cues.clear()
	tower = Tower.new()
	tower.setup(0, CardDB.PRINCESS_TOWER_STATS, false)
	main.add_child(tower)
	audio.attach_building_audio(tower, CardDB.PRINCESS_TOWER_VISUAL_CONFIG)
	tower.take_damage(tower.max_hp * 0.7)
	audio._tick_building_damage_audio()
	harness._expect(cues == [&"damage:stage2"], "跨阶段伤害只播放当前阶段，不叠加补播")
	tower.take_damage(tower.max_hp)
	audio._tick_building_damage_audio()
	harness._expect(cues.size() == 1, "最终摧毁由独立死亡事件播放，不补中间破损声")
	tower.free()
	audio.cue_played.disconnect(listener)

func _check_tombstone_sustain(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var unit := Unit.new()
	var stats := CardDB.get_card("tombstone")
	unit.card_id = "tombstone"
	unit.setup(0, stats, stats.name)
	main.add_child(unit)
	unit.set_battle_context(main.battle_context)
	audio.attach_unit(unit, stats)
	var key := audio._sustain_key(unit.get_instance_id(), &"idle")
	audio._process(0.0)
	var ok := not audio._sustain_players.has(key)
	unit._deploy_timer = 0.0
	audio._process(0.0)
	var player: AudioStreamPlayer2D = audio._sustain_players.get(key)
	ok = ok and player != null
	if player != null:
		audio._on_sustain_finished(key, player)
		ok = ok and audio._sustain_players.get(key) == player
	audio._on_unit_death(unit.get_instance_id())
	ok = ok and not audio._sustain_players.has(key)
	harness._expect(ok, "墓碑部署后启动持续声，片段续播保留所有权，死亡立即停止")
	audio._detach_unit(unit.get_instance_id())
	unit.free()


func _check_tombstone_active_cast(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var cues: Array[StringName] = []
	var listener := func(card_id: String, cue: StringName, _position: Vector2):
		if card_id == "tombstone": cues.append(cue)
	audio.cue_played.connect(listener)
	var unit := Unit.new()
	var stats := CardDB.get_card("tombstone")
	unit.card_id = "tombstone"
	unit.setup(0, stats, stats.name)
	main.add_child(unit)
	unit.set_battle_context(main.battle_context)
	audio.attach_unit(unit, stats)
	cues.clear()
	var skill: Dictionary = CardDB.active_skills_for("tombstone")[0]
	skill["impact_delay"] = 999.0
	var started: bool = main._start_active_skill_cast(unit, skill)
	var ok: bool = started and cues == [&"active:cast"]
	main._commands.impacts.clear()
	audio.cue_played.disconnect(listener)
	audio._detach_unit(unit.get_instance_id())
	unit.free()
	harness._expect(ok, "墓碑亡者集结在 Cast Start 播放一次 Yorick W OnCast 音效，不依赖不存在的技能动画")


func _check_match_announcements(harness: Object, main: Node2D) -> void:
	var cues: Array[StringName] = []
	var listener := func(card, cue, _position):
		if card == "match": cues.append(cue)
	main._audio_manager.cue_played.connect(listener)
	var saved_elapsed: float = main._battle_elapsed
	var saved_next: float = main._next_minion_wave_time
	var saved_pending: Array = main._pending_lane_minions.duplicate(true)
	var saved_mode: String = main.mode
	var saved_over: bool = main.game_over
	var saved_finished: bool = main._match_rules.finished
	var old_children: Array = main.get_children()
	main.mode = "local"
	main.game_over = false
	main._battle_elapsed = 4.9
	main._next_minion_wave_time = 5.0
	main._pending_lane_minions.clear()
	main._tick_minion_waves(0.05)
	harness._expect(cues.is_empty(), "首波播报在4.95秒前不提前播放")
	main._tick_minion_waves(0.05)
	main._tick_minion_waves(0.05)
	harness._expect(cues == [&"minions_spawn"], "第5秒首波兵线只播一次全军出击")
	main.mode = "client"
	preload("res://tests/suites/network_fixture.gd").deliver(main, "_rpc_card_event", [main._last_card_event_id, "match", "minions_spawn", Vector2.ZERO])
	harness._expect(cues.size() == 1, "可靠首波播报重放按事件ID去重")
	main._end_game(0, "nexus")
	main._end_game(0, "nexus")
	harness._expect(cues.count(&"defeat") == 1 and cues.count(&"victory") == 0, "主机胜利时客户端只播一次失败")
	main.mode = "local"
	main.game_over = false
	main._audio_manager.begin_battle()
	main._end_game(0, "nexus")
	harness._expect(cues.count(&"victory") == 1, "本地胜利播放胜利播报")
	for child in main.get_children():
		if child not in old_children: child.free()
	main._battle_elapsed = saved_elapsed
	main._next_minion_wave_time = saved_next
	main._pending_lane_minions.assign(saved_pending)
	main.mode = saved_mode
	main.game_over = saved_over
	main._match_rules.finished = saved_finished
	main._audio_manager.begin_battle()
	main._hand.show()
	main._active_skill_bar.show()
	main._audio_manager.cue_played.disconnect(listener)
	for id in ["melee_minion", "ranged_minion", "siege_minion", "super_minion"]:
		for team in range(2):
			var audio := PresentationConfig.audio_for(CardDB.get_card(id), team)
			harness._expect(audio.events["spawn:start"].pool.size() == 3, "%s 阵营%d兵线与部署共用三个生成变体" % [id,team])

func _check_voice_budget(harness: Object, main: Node2D) -> void:
	var audio := GameAudioManager.new()
	main.add_child(audio)
	audio.set_process(false)
	var pool: Array = CardDB.get_card("ashe").audio.events["active:release"].pool
	for index in 20:
		harness._expect(audio._play_pool("ashe", &"attack_swing", pool, Vector2.ZERO, -80.0), "常规短音使用普通预算位")
	var ordinary := audio.budget_snapshot()
	harness._expect(ordinary.active.short == 20 and audio._world_players.slice(20).all(func(p): return not p.playing), "普通攻击不能占用 4 个重要短音保留位")
	for index in 4:
		harness._expect(audio._play_pool("ashe", &"active:release", pool, Vector2.ZERO, -80.0), "拥挤时技能使用保留位")
	harness._expect(audio.budget_snapshot().active.short == 24, "短音同时播放总数保持 24")
	audio._play_pool("ashe", &"death", pool, Vector2.ZERO, -80.0, &"Voice")
	harness._expect(audio.budget_snapshot().counters.short.interrupted == 1 and audio._world_players[0].bus == &"Voice", "满池死亡声替换最早的最低优先级声音")
	for index in 23: audio._play_pool("ashe", &"death", pool, Vector2.ZERO, -80.0, &"Voice")
	var before := audio.budget_snapshot()
	harness._expect(not audio._play_pool("ashe", &"attack_swing", pool, Vector2.ZERO, -80.0) and audio.budget_snapshot().counters.short.dropped == 1, "普通声不打断满池重要声音，丢弃可观测")
	audio.play_match_event("minions_spawn")
	harness._expect(is_instance_valid(audio._announcer) and audio.budget_snapshot().active.short == 24, "播报使用独立播放器，不争抢战斗短音位")
	before.counters.short.dropped = 999
	harness._expect(audio.budget_snapshot().counters.short.dropped == 1, "音频预算诊断返回独立副本")
	var sources: Array[Unit] = []
	for index in 25:
		var source := Unit.new()
		main.add_child(source)
		sources.append(source)
		if index < 24:
			audio._start_sustain(source, {"card_id": "gnar", "audio": _team_audio_fixture(-80.0)}, &"probe", &"action")
	audio._start_sustain(sources.back(), {"card_id": "gnar", "audio": _team_audio_fixture(-80.0)}, &"probe", &"idle")
	harness._expect(audio._sustain_players.size() == 24 and audio.budget_snapshot().counters.sustain.dropped == 1, "持续声满池时待机不能挤掉技能，计数保持上限")
	for source in sources: source.free()
	audio.end_battle()
	harness._expect(audio.budget_snapshot().active.values().all(func(count): return count == 0), "终局释放所有预算占用")
	audio.free()

func _team_audio_fixture(volume: float) -> Dictionary:
	var pool: Array = CardDB.get_card("ashe").audio.events["active:release"].pool
	var events := {}
	for cue in ["probe:start", "probe:sustain", "attack_launch", "pulse:zone_sustain", "pulse:zone_end", "spawn:start", "idle:sustain", "damage:stage1", "death"]:
		events[cue] = {"pool": pool, "volume_db": volume}
	return {"events": events, "attack_swing": [pool], "attack_swing_volume_db": volume,
		"attack_hit": pool, "attack_hit_volume_db": volume, "attack_launch_until_impact": true}

func _check_team_audio_routes(harness: Object, main: Node2D) -> void:
	var fixture := CardDB.get_card("gnar").duplicate(true)
	fixture.audio = _team_audio_fixture(-10.0)
	fixture.audio.team_overrides = [_team_audio_fixture(-10.0), _team_audio_fixture(-20.0)]
	fixture.transformed_stats.audio = _team_audio_fixture(-30.0)
	fixture.transformed_stats.audio.team_overrides = [_team_audio_fixture(-30.0), _team_audio_fixture(-40.0)]
	var audio := GameAudioManager.new()
	audio.definition_lookup = func(_card): return fixture
	main.add_child(audio)
	audio.set_process(false)
	var event_id := 0
	for form in [0, 1]:
		for team in [0, 1]:
			var expected: float = -10.0 - team * 10.0 - form * 20.0
			for player in audio._world_players: player.stop()
			harness._expect(audio.play_card_event("gnar", "probe:start", Vector2.ZERO, form, team) and audio._world_players[0].volume_db == expected, "卡牌事件同时选择阵营与形态音频")
			for player in audio._world_players: player.stop()
			harness._expect(audio.play_attack_source({"card_id": "gnar", "team": team, "form": form}, Vector2.ZERO) and audio._world_players[0].volume_db == expected, "在途来源命中音保留阵营与原形态")
			event_id += 1
			audio.start_projectile_launch(event_id, {"card_id": "gnar", "team": team, "form": form}, Vector2.ZERO)
			harness._expect(audio._projectile_launch_players[event_id].volume_db == expected, "独占飞行声遵守阵营与形态覆盖")
			audio.start_zone_audio(event_id, "gnar", form, "pulse", Vector2.ZERO, 1.0, team)
			harness._expect(audio._zone_players[event_id].player.volume_db == expected and audio._zone_players[event_id].ending.volume_db == expected, "固定区域保存正确阵营形态的持续和结束声")
			var unit := Unit.new()
			unit.card_id = "gnar"
			unit.setup(team, CardDB.get_card("gnar"), "音频路由")
			unit.form_index = form
			main.add_child(unit)
			audio.attach_unit(unit, fixture)
			for player in audio._world_players: player.stop()
			harness._expect(audio.play_event(unit, &"probe:start", Vector2.ZERO) and audio._world_players[0].volume_db == expected, "挂载单位语义事件选择对应阵营形态")
			audio._start_sustain(unit, audio._unit_entries[unit.get_instance_id()], &"probe")
			harness._expect(audio._sustain_players[audio._sustain_key(unit.get_instance_id())].volume_db == expected, "单位持续声与单次事件使用同一覆盖配置")
			for player in audio._world_players: player.stop()
			audio.preview_attack("gnar", fixture, Vector2.ZERO, team, form)
			harness._expect(audio._world_players[0].volume_db == expected, "预览攻击也按选择的阵营形态发声")
			unit.free()
			audio.clear_zone_audio()
			audio.clear_projectile_launch_audio()
	for team in [0, 1]:
		var tower := Tower.new()
		tower.setup(team, CardDB.PRINCESS_TOWER_STATS, false)
		main.add_child(tower)
		audio.attach_building_audio(tower, {})
		harness._expect(audio._building_audio[tower.get_instance_id()].player.volume_db == -10.0 - team * 10.0, "系统建筑出生与持续配置也选择实际阵营")
		tower.free()
	# 真正的客户端 RPC 解码参数包含阵营；用可区分的红方形态配置观察最终播放器。
	var saved_audio: GameAudioManager = main._audio_manager
	var saved_mode: String = main.mode
	var saved_card_event: int = main._last_card_event_id
	main._audio_manager = audio
	main.mode = "client"
	for player in audio._world_players: player.stop()
	preload("res://tests/suites/network_fixture.gd").deliver(main, &"_rpc_card_event", [saved_card_event + 1, "gnar", "probe:start", Vector2.ZERO, 1, 1])
	harness._expect(audio._world_players[0].volume_db == -40.0, "卡牌 RPC 从红方大形态一路传到音频选择入口")
	preload("res://tests/suites/network_fixture.gd").deliver(main, &"_rpc_zone_audio", [100, "gnar", 1, "pulse", Vector2.ZERO, 1.0, 1])
	harness._expect(audio._zone_players[100].player.volume_db == -40.0, "区域 RPC 保存红方大形态来源")
	main._audio_manager = saved_audio
	main.mode = saved_mode
	main._last_card_event_id = saved_card_event
	audio.free()

func _check_selected_deploy_audio(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	for card_id in ["garen", "gwen"]:
		for team in [0, 1]:
			var stats := CardDB.get_card(card_id)
			var config := PresentationConfig.audio_for(stats, team, 0)
			var randomizer := audio._randomized_stream(PackedStringArray(config.events["deploy:voice"].pool))
			var cues: Array[StringName] = []
			var listener := func(id: String, cue: StringName, _pos: Vector2):
				if id == card_id: cues.append(cue)
			audio.cue_played.connect(listener)
			var unit := Unit.new()
			unit.card_id = card_id
			unit.setup(team, stats, stats.name)
			main.add_child(unit)
			audio.attach_unit(unit, stats)
			audio.attach_unit(unit, stats)
			var once := cues == [&"deploy:voice"]
			audio._detach_unit(unit.get_instance_id())
			unit.free()
			cues.clear()
			unit = Unit.new()
			unit.card_id = card_id
			unit.setup(team, stats, stats.name)
			unit._deploy_timer = 0.0
			main.add_child(unit)
			audio.attach_unit(unit, stats)
			var late_silent := cues.is_empty()
			audio._detach_unit(unit.get_instance_id())
			unit.free()
			audio.cue_played.disconnect(listener)
			harness._expect(once and late_silent and randomizer.streams_count == 3
				and randomizer.playback_mode == AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS,
				"%s 阵营%d部署三选一且不连续重复，重绑和晚到不补播" % [card_id, team])
