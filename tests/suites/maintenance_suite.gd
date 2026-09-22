extends RefCounted

func run(harness: Object) -> void:
	_check_clock_budget(harness)
	_check_status_instances(harness)
	var unit := Unit.new()
	unit.setup(0, CardDB.get_unit_stats("garen"), "probe")
	unit.attack_timeline.windup = 0.4
	unit.attack_timeline.cooldown = 1.0
	unit.attack_timeline.recovery = 0.6
	unit.apply_attack_speed_slow(2.0, 0.5)
	harness._expect(is_equal_approx(unit.attack_timeline.windup, 0.8), "首次减攻速保留正常前摇缩放")
	unit.apply_attack_speed_slow(3.0, 0.5)
	unit.apply_attack_speed_slow(1.0, 0.8, &"other")
	harness._expect(is_equal_approx(unit.attack_timeline.windup, 0.8), "同倍率刷新与较弱减攻速不重复延长前摇")
	unit._tick_active_statuses(3.0)
	harness._expect(is_equal_approx(unit.attack_timeline.windup, 0.4), "减攻速到期恢复当前阶段进度")
	unit.apply_active_buff(2.0, 1.0, 1.0, 2.0)
	unit.apply_active_buff(3.0, 1.0, 1.0, 2.0)
	harness._expect(is_equal_approx(unit.attack_timeline.windup, 0.2), "重复加攻速仅刷新持续时间")
	unit._tick_active_statuses(3.0)
	harness._expect(is_equal_approx(unit.attack_timeline.windup, 0.4), "加攻速到期恢复当前阶段进度")
	unit.free()
	var gold := ElixirManager.new()
	gold.sim_tick(6.0)
	harness._expect(gold.elixir == 7.0 and is_equal_approx(gold._timer, 0.4), "金币跨多个周期回复并保留余量")
	gold.free()

func check_contracts(harness: Object, main: Node2D) -> void:
	main._process(0.0)
	harness._expect(is_same(main._effects_view.spells, main._spell_system), "渲染推进不切断法术系统与冰冻表现集合的所有权")
	var ai_timer: float = main._ai._think_timer
	main._ai.enabled = true
	main._ai._think_timer = 1.0
	main._sim_step(0.05)
	harness._expect(is_equal_approx(main._ai._think_timer, 0.95), "AI 决策计时由权威 Tick 推进")
	main._ai.enabled = false
	main._ai._think_timer = ai_timer
	var definitions := CardDB.all()
	var original := CardDB.get_card("garen")
	var skills := CardDB.active_skills_for("garen")
	skills[0]["cost"] = 99
	harness._expect(is_same(definitions, CardDB.all()) and original.is_read_only() and original.audio.is_read_only() and original.audio.attack_swing.is_read_only() and CardDB.active_skills_for("garen")[0].cost != 99, "定义只构建一次且递归只读，技能运行副本不污染定义")
	var fixture := CardDB.compile_definition({
		"gameplay": {"name": "接入夹具", "type": "unit", "cost": 1, "description": "不进入正式注册表", "hp": 100.0, "damage": 10.0, "range": 32.0, "speed": 44.0, "interval": 1.0, "first_hit": 0.3, "radius": CardDB.RADIUS_SMALL, "size_tier": CardDB.SIZE_SMALL, "mass": 2.0, "sight": 200.0, "is_air": false, "building_only": false, "can_attack_air": false},
		"visual": {"color": Color.BLUE, "visual_radius": CardDB.RADIUS_SMALL + CardDB.VISUAL_RADIUS_PADDING, "visual_scene_path": original.visual_scene_path, "visual_animations": original.visual_animations},
		"card_art": {"path": CardArt.texture_for("garen").resource_path},
		"audio": {"events": {"death": original.audio.events.death}},
	})
	var errors := PackedStringArray()
	CardDB.VALIDATOR._validate_card("content_fixture", fixture, errors)
	errors.append_array(SuiteUtils.visual_contract_errors("content_fixture", fixture))
	var fixture_unit := Unit.new()
	fixture_unit.setup(0, fixture, "fixture")
	main.add_child(fixture_unit)
	var fixture_attached: bool = main._battle_presentation.attach_unit(fixture_unit, fixture)
	main._audio_manager.attach_unit(fixture_unit, fixture)
	harness._expect(errors.is_empty() and fixture_attached and not CardDB.has_card("content_fixture"), "四域夹具通过定义、模型动画、卡面与死亡音契约，不新增正式卡牌")
	fixture_unit.free()
	var optional := PackedStringArray()
	CardDB.VALIDATOR._validate_audio_config("death_only", {"type": "building", "damage": 0.0, "audio": {"events": {"death": original.audio.events.death}}}, optional)
	CardDB.VALIDATOR._validate_audio_config("no_model", {"type": "unit", "damage": 10.0, "audio": {"attack_swing": [original.audio.attack_swing[0]]}}, optional)
	CardDB.VALIDATOR._validate_audio_config("spell", {"type": "spell", "audio": {"events": {"spell:cast": original.audio.events.death}}}, optional)
	harness._expect(optional.is_empty(), "只有死亡音、无攻击建筑、无模型单位和纯法术的可选音频通过能力校验")
	var impossible := PackedStringArray()
	CardDB.VALIDATOR._validate_audio_config("no_emitter", {"type": "unit", "damage": 0.0, "visual_animations": {"visual_actions": {"phantom": "Idle"}}, "audio": {"events": {"phantom:hit": original.audio.events.death}}}, impossible)
	harness._expect(not impossible.is_empty(), "有动画名但没有真实命中派发机制的音频配置被拒绝")
	var schedule_a: Array[float] = []
	var schedule_b: Array[float] = []
	for index in 240:
		schedule_a.append(0.025)
	for index in 12:
		schedule_b.append(0.13)
		schedule_b.append(0.37)
	harness._expect(_run_schedule(schedule_a) == _run_schedule(schedule_b), "同一组 120 Tick 输入在细帧/积压渲染安排下，金币、比赛与攻击状态完全一致")
	var resources := MatchResources.new()
	resources.prepare(["anivia", "gnar", "tombstone"])
	harness._expect(resources.cards.has("anivia_egg") and resources.cards.has("imp") and resources.resources.has(String(CardDB.get_card("gnar").transformed_stats.visual_scene_path)), "本局预备递归加载复生、召唤与变形资源，循环引用终止")
	_check_projectile_source(harness, main)
	_check_layers(harness, main)
	_check_control_and_isolation(harness, main)
	_check_network_presentation(harness, main)

func _run_schedule(frames: Array[float]) -> Array:
	var clock := FixedStepClock.new()
	var rules := MatchRules.new()
	var gold := ElixirManager.new()
	var unit := Unit.new()
	unit.setup(0, CardDB.get_card("garen"), "clock")
	unit.attack_timeline.windup = 0.4
	clock.running = func(): return true
	clock.step = func(dt: float):
		if clock.ticks == 2 or clock.ticks == 4:
			unit.apply_attack_speed_slow(2.0, 0.5)
		if clock.ticks == 6:
			unit.apply_active_buff(1.0, 1.0, 1.0, 2.0, false, true)
		unit._tick_active_statuses(dt)
		gold.sim_tick(dt)
		rules.advance(dt, 100.0, 100.0, 0, 0)
	for delta in frames:
		clock.advance(delta)
	var result := [clock.ticks, rules.time_left, gold.elixir, gold._timer, unit.attack_timeline.windup, unit.control.attack_speed_slow_timer]
	clock.step = Callable()
	gold.free()
	unit.free()
	return result

func _check_projectile_source(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var heard: Array[StringName] = []
	var callback := func(card: String, cue: StringName, _pos: Vector2):
		if card == "missfortune": heard.append(cue)
	audio.cue_played.connect(callback)
	var source := Unit.new()
	source.card_id = "missfortune"
	source.setup(0, CardDB.get_card("missfortune"), "source")
	main.add_child(source)
	audio.attach_unit(source, CardDB.get_card("missfortune"))
	var target := Unit.new()
	target.setup(1, CardDB.get_card("garen"), "target")
	target.position = Vector2(300, 600)
	source.position = Vector2(300, 700)
	main.add_child(target)
	var hp := target.hp
	main._projectile_system.launch(source, target, 10.0, 1000.0, 0.0, 0.0, Color.WHITE)
	source.free()
	heard.clear()
	main._projectile_system.tick(1.0)
	harness._expect(target.hp < hp and heard == [&"attack_hit"], "攻击者已销毁后，在途弹体仍命中并按出手来源播放命中声")
	target.free()
	audio.cue_played.disconnect(callback)
	var gnar := Unit.new()
	gnar.card_id = "gnar"
	gnar.setup(0, CardDB.get_card("gnar"), "form")
	var captured := PresentationConfig.attack_source(gnar)
	gnar.form_index = 1
	harness._expect(captured.form == 0 and PresentationConfig.attack_source(gnar).form == 1 and PresentationConfig.for_form(CardDB.get_card("gnar"), 1) == CardDB.get_card("gnar").transformed_stats, "变形只改变后续来源配置，旧攻击保留出手形态")
	gnar.hp = 0.0
	gnar.on_attack_landed(0, 100.0)
	harness._expect(gnar.hp == 0.0 and gnar.transform_hit_count == 0, "死者命中不获得回血与变形收益")
	gnar.free()

func _check_layers(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var stats := CardDB.get_card("garen").duplicate(true)
	stats.audio.events["active_buff:sustain"] = stats.audio.events["judgment:sustain"]
	var unit := Unit.new()
	unit.card_id = "garen"
	unit.setup(0, stats, "layers")
	main.add_child(unit)
	audio.attach_unit(unit, stats)
	unit.play_visual_action(&"judgment", 3.0)
	unit.active_buff_timer = 4.0
	audio._process(0.0)
	var id := unit.get_instance_id()
	var both := audio._sustain_players.has(audio._sustain_key(id, &"action")) and audio._sustain_players.has(audio._sustain_key(id, &"buff"))
	unit._visual_action_time_left = 0.0
	audio._process(0.0)
	var buff_survives := audio._sustain_players.has(audio._sustain_key(id, &"buff"))
	unit.free()
	harness._expect(both and buff_survives and not audio._sustain_players.has(audio._sustain_key(id, &"buff")), "动作与 Buff 长音可并存，动作结束不误停 Buff，销毁清理全部层")

func _check_control_and_isolation(harness: Object, main: Node2D) -> void:
	var stats := CardDB.get_card("garen").duplicate(true)
	stats.deploy_time = 0.0
	# 已有片段仅作结构夹具，不声称正式卡牌有眩晕素材。
	stats.visual_animations["stun_loop"] = "Idle1_Base"
	var units: Array[Unit] = []
	var views: Array[UnitModel3D] = []
	for index in 2:
		var unit := Unit.new()
		unit.setup(index, stats, "control")
		main.add_child(unit)
		main._battle_presentation.attach_unit(unit, stats)
		units.append(unit)
		for child in main._battle_presentation._world_root.get_children():
			if child is UnitModel3D and child._source == unit:
				views.append(child)
	var unit := units[0]
	var view := views[0]
	unit._attacking = true
	unit.attack_timeline.windup = 0.3
	unit.freeze(0.1)
	unit.stun(0.2)
	unit.sim_tick(0.05)
	var cancelled := unit.attack_timeline.windup == 0 and unit.attack_timeline.cooldown == 0
	view._process(0.0)
	var ice_holds := view._animation_player.speed_scale == 0.0
	unit.control.frozen_timer = 0.0
	view._process(0.0)
	var stun_plays := view._animation_player.speed_scale == 1.0 and view._current_state == 1
	var independent := view._animation_player.get_animation("Idle1_Base") != views[1]._animation_player.get_animation("Idle1_Base")
	view._on_source_visual_hit()
	independent = independent and view._model_resources.meshes()[0].material_overlay != views[1]._model_resources.meshes()[0].material_overlay
	unit.hp = 0.0
	unit.notify_visual_death()
	harness._expect(cancelled and ice_holds and stun_plays and view._dying and view._animation_player.speed_scale > 0.0, "前摇被硬控取消，冰冻定格后眩晕混合Idle，死亡正常接管")
	harness._expect(independent, "同类单位独立持有动画与叠加材质，修改控制循环与闪白不污染另一实例")
	for item in views: item.free()
	for item in units: item.free()

func profile(harness: Object, main: Node2D) -> void:
	for count in [32, 64, 128]:
		var units: Array[Unit] = []
		var stats := CardDB.get_card("melee_minion").duplicate(true)
		stats.deploy_time = 0.0
		for index in count:
			var unit := Unit.new()
			unit.setup(index % 2, stats, "profile")
			unit.position = Vector2(90 + (index % 12) * 42, 780 + (index / 12) * 30)
			main.add_child(unit)
			unit._move_intent = Vector2.UP * 44.0
			units.append(unit)
		var target_usec := 0
		var move_usec := 0
		var collision_usec := 0
		for tick in 10:
			var start := Time.get_ticks_usec()
			for unit in units:
				unit._update_target()
			target_usec += Time.get_ticks_usec() - start
			main._movement.tick(0.05)
			move_usec += main._movement.last_movement_usec
			collision_usec += main._movement.last_collision_usec
		var serialization_start := Time.get_ticks_usec()
		var payload := []
		for index in units.size():
			payload.append(main._snapshot_system._unit_snapshot_payload(index, units[index]))
		var bytes := var_to_bytes(payload)
		var serialization_usec := Time.get_ticks_usec() - serialization_start
		var compression_start := Time.get_ticks_usec()
		var compressed := bytes.compress(FileAccess.COMPRESSION_DEFLATE)
		var compression_usec := Time.get_ticks_usec() - compression_start
		print("[性能采样] n=%d targeting=%dus movement=%dus collision=%dus serialize=%dus compress=%dus bytes=%d/%d" % [count, target_usec / 10, move_usec / 10, collision_usec / 10, serialization_usec, compression_usec, bytes.size(), compressed.size()])
		harness._expect(not compressed.is_empty(), "性能采样快照可压缩（%d 单位）" % count)
		for unit in units: unit.free()

func _check_network_presentation(harness: Object, main: Node2D) -> void:
	var stats := CardDB.get_card("garen").duplicate(true)
	stats.deploy_time = 0.0
	var unit := Unit.new()
	unit.card_id = "garen"
	unit.setup(0, stats, "network")
	main.add_child(unit)
	unit._attacking = true
	unit._attack_visual_serial = 10
	unit.attack_timeline.visual_elapsed = 0.25
	unit.apply_attack_speed_slow(2.0, 0.5)
	unit.apply_slow(2.0, 0.6)
	var payload: Array = main._snapshot_system._unit_snapshot_payload(999999, unit)
	var mode: String = main.mode
	main._client_units[999999] = unit
	main.mode = "client"
	main._snapshot_system._apply_units([payload])
	main._audio_manager.attach_unit(unit, stats)
	main._snapshot_system._apply_units([payload])
	var state := unit.presentation_state()
	var shared := is_same(state, unit.presentation_state()) and is_equal_approx(state.attack_rate, 0.5) and is_equal_approx(state.movement_rate, 0.6) and is_equal_approx(state.attack_elapsed, 0.25) and state.can_attack
	main._battle_presentation.attach_unit(unit, stats)
	var aligned := false
	var view: UnitModel3D
	for child in main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			view = child
			aligned = child._animation_player.current_animation_position > 0.0
	harness._expect(shared and aligned, "客户端重复载荷保持统一有效速率/权限，晚到普攻序号按权威进度 seek")
	main._client_units.erase(999999)
	main.mode = mode
	if view != null: view.free()
	unit.free()
	var seen: Array[StringName] = []
	var callback := func(_card: String, cue: StringName, _pos: Vector2): seen.append(cue)
	main._audio_manager.cue_played.connect(callback)
	var old_event: int = main._last_card_event_id
	main._play_card_event(old_event + 2, "garen", "death", Vector2.ZERO)
	main._play_card_event(old_event + 2, "garen", "death", Vector2.ZERO)
	main._play_card_event(old_event + 1, "garen", "death", Vector2.ZERO)
	harness._expect(seen == [&"death"], "可靠重要事件按 ID 拒绝重复与晚到重放")
	main._audio_manager.cue_played.disconnect(callback)
	main._last_card_event_id = old_event

func _check_clock_budget(harness: Object) -> void:
	var clock := FixedStepClock.new()
	clock.max_ticks_per_advance = 4
	clock.running = func(): return true
	var applied: Array[float] = []
	clock.step = func(dt): applied.append(dt)
	clock.advance(0.525)
	harness._expect(clock.ticks == 4 and is_equal_approx(clock.remainder, 0.325), "赶步达到数量预算时保留全部积压及小数余量")
	clock.advance(0.0)
	clock.advance(0.0)
	harness._expect(clock.ticks == 10 and is_equal_approx(clock.remainder, 0.025) and applied.all(func(dt): return dt == 0.05), "后续渲染帧无新增时间仍按顺序补完全部固定步，不丢 Tick")
	clock.max_ticks_per_advance = 0
	clock.max_work_usec = 1000
	clock.step = func(_dt): OS.delay_usec(2000)
	clock.advance(0.2)
	harness._expect(clock.ticks == 11 and is_equal_approx(clock.remainder, 0.175), "单 Tick 超出时间预算后停止继续赶步，当前 Tick 完整执行")
	clock.step = Callable()

func _check_status_instances(harness: Object) -> void:
	var unit := Unit.new()
	unit.setup(0, CardDB.get_unit_stats("garen"), "status_probe")
	unit.apply_slow(0.5, 0.3, &"strong")
	unit.apply_slow(4.0, 0.8, &"weak")
	harness._expect(is_equal_approx(unit.control.slow_multiplier, 0.3), "异源减速取当前最强")
	unit._tick_active_statuses(0.5)
	harness._expect(is_equal_approx(unit.control.slow_multiplier, 0.8), "短强减速到期不借用长弱窗口")
	unit.apply_slow(0.051, 0.6, &"weak")
	harness._expect(is_equal_approx(unit.control.slow_timer, 0.1), "同源改强度整体替换且正时长向上取整")
	unit._tick_active_statuses(0.05)
	harness._expect(unit.control.slow_timer > 0, "不足一 Tick 的余量继续贡献")
	unit._tick_active_statuses(0.05)
	harness._expect(unit.control.slow_timer == 0, "整数 Tick 边界恰好到期")
	unit.apply_active_buff(2, 1, 1, 2, false, false, &"attack")
	unit.apply_active_buff(8, 2, 1, 1, false, false, &"move")
	unit._tick_active_statuses(2)
	harness._expect(unit.active_attack_speed_multiplier == 1 and unit.active_speed_multiplier == 2, "攻速与移速增益独立到期")
	unit.apply_slow(4, 0.5, &"old")
	unit.apply_active_buff(1, 1, 1, 1, true, true, &"immune")
	unit.apply_slow(8, 0.2, &"new")
	unit._tick_active_statuses(1)
	harness._expect(not unit.active_buff_ignores_movement_slow and unit.control.slow_multiplier == 0.5 and unit.control.slow_timer == 3, "免疫抑制旧减速且拒绝新减速，结束仅恢复剩余贡献")
	unit.freeze(0)
	unit.stun(-1)
	harness._expect(not unit.is_frozen() and not unit.is_stunned(), "零负时长不创建控制")
	unit.free()
