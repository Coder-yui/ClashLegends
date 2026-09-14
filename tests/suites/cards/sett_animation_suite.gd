extends RefCounted
## 真正推进权威攻击，检查变速、表现阶段、可中断收尾；不从动画触发命中。

func run(harness: Object, main: Node2D) -> void:
	for rate in [0.5, 1.0, 2.0, 4.0]:
		_check_rhythm(harness, main, rate)
	_check_rate_changes_and_seek(harness, main)
	_check_source_blends(harness, main)
	_check_cancelled_punch(harness, main)
	_check_skill_exits(harness, main)
	_check_w_timing(harness, main)
	_check_deploy(harness, main)
	_check_schema(harness)

func _spawn(main: Node2D, dummy: bool = false) -> Unit:
	var stats := CardDB.get_card("sett").duplicate(true)
	stats.deploy_time = 0.0
	stats.hp = 99999.0
	stats.sight = 10.0
	if dummy:
		stats = SuiteUtils.sweep_dummy_stats(stats)
	var unit := Unit.new()
	unit.setup(1 if dummy else 0, stats, "攻速验收")
	unit.position = Vector2(550, 1060 if dummy else 1110)
	main.add_child(unit)
	return unit

func _check_w_timing(harness: Object, main: Node2D) -> void:
	var unit := _spawn(main)
	var view := _view(main, unit)
	var aligned := true
	var seamless_and_authoritative := true
	var skill: Dictionary = CardDB.active_skills_for("sett")[0]
	unit.configure_carried_active_skill(skill)
	for action in [&"active", &"active_strong"]:
		unit.skill_resource_value = unit.skill_resource_max if action == &"active_strong" else 0.0
		var prepared: Dictionary = main._active_skill_effect_system.prepare_cast(unit, skill)
		unit.begin_active_skill_cast(float(prepared.cast_duration), Vector2.UP, prepared.cast_locks)
		unit.play_visual_action(StringName(prepared.visual_action), float(prepared.cast_duration))
		view._sync_visual(false, 0.0)
		var player := view._animation_player
		aligned = aligned and is_equal_approx(player.get_playing_speed(), 1.0)
		player.advance(0.4)
		aligned = aligned and absf(player.current_animation_position - 0.4) < 0.001
		# advance 真实越过 section 结束回调，不能只检查 seek 后的配置值。
		player.advance(0.401)
		seamless_and_authoritative = seamless_and_authoritative and (
			view._action_sequence.index == 1
			and is_zero_approx(view._last_clip_blend_time)
			and is_equal_approx(player.get_section_start_time(), 0.8)
			and StringName(prepared.visual_action) == action
			and is_equal_approx(float(prepared.impact_delay), 0.8)
			and is_equal_approx(float(prepared.cast_duration), 1.4)
			and is_equal_approx(float(prepared.damage), float(skill.damage) * (2.0 if action == &"active_strong" else 1.0))
			and is_equal_approx(unit.active_skill_cast_timer, 1.4)
		)
		view._seek_visual_action(0.8)
		aligned = aligned and view._action_sequence.index == 1 and absf(player.current_animation_position - 0.8) < 0.001
		var end := player.get_animation(player.current_animation).length
		view._seek_visual_action(1.1)
		aligned = aligned and absf(player.current_animation_position - (0.8 + (end - 0.8) * 0.5)) < 0.001
		view._seek_visual_action(1.4)
		aligned = aligned and absf(player.current_animation_position - end) < 0.001
	harness._expect(aligned, "腕豪两种 W 前 0.8 秒原速出拳，收尾适配共同 1.4 秒窗口，晚到进度保持分段对齐")
	harness._expect(seamless_and_authoritative, "腕豪两种 W 的第二 section 实际零混合，保留 0.8 秒命中/1.4 秒施法及豪意伤害倍率，动画不提前解锁施法")
	view.free()
	unit.free()

func _check_deploy(harness: Object, main: Node2D) -> void:
	var stats := CardDB.get_card("sett")
	var unit := Unit.new()
	unit.setup(0, stats, "部署验收")
	unit.card_id = "sett"
	main.add_child(unit)
	var cues: Array[StringName] = []
	var callback := func(id: String, cue: StringName, _pos: Vector2):
		if id == "sett": cues.append(cue)
	main._audio_manager.cue_played.connect(callback)
	main._audio_manager.attach_unit(unit, stats)
	main._audio_manager.attach_unit(unit, stats)
	var view := _view(main, unit)
	var speed := view._state_playback_speed(0, &"Respawn")
	var correct := absf(speed - 1.0) < 0.001 and cues.count(&"deploy:start") == 1
	view._play_clip(&"Respawn", &"action_in", speed)
	view._animation_player.seek(1.0, true)
	unit._deploy_timer = 0.0
	unit._attacking = true
	view._play_attack(1)
	correct = correct and is_equal_approx(view._last_clip_blend_time, 0.1)
	view.free()
	unit.free()
	var late := Unit.new()
	late.setup(0, stats, "晚到部署")
	late.card_id = "sett"
	late._deploy_timer = 0.4
	main.add_child(late)
	main._audio_manager.attach_unit(late, stats)
	correct = correct and cues.count(&"deploy:start") == 1
	harness._expect(correct, "腕豪部署只播原速 Respawn 前一秒、接攻击用 0.1 混合；部署音重绑不重复、晚到不补播")
	late.free()
	main._audio_manager.cue_played.disconnect(callback)

func _view(main: Node2D, unit: Unit) -> UnitModel3D:
	main._battle_presentation.attach_unit(unit, CardDB.get_card("sett"))
	for child in main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			child.set_process(false)
			return child
	return null

func _check_rhythm(harness: Object, main: Node2D, rate: float) -> void:
	var unit := _spawn(main)
	var dummy := _spawn(main, true)
	unit._target = dummy
	if rate < 1.0:
		unit.apply_attack_speed_slow(60.0, rate)
	else:
		unit.apply_active_buff(60.0, 1.0, 1.0, rate)
	var view := _view(main, unit)
	var hits: Array[float] = []
	var old_hp := dummy.hp
	var aligned := true
	for tick in 600:
		unit.sim_tick(0.05)
		view._process(0.05)
		if dummy.hp < old_hp:
			hits.append(float(tick + 1) * 0.05)
			aligned = aligned and (not view._attack_hit_pending or view._attack_hit_timer <= rate * 0.05 + 0.001)
			old_hp = dummy.hp
		if hits.size() >= 6:
			break
	var rhythm := hits.size() == 6
	for i in range(1, hits.size()):
		var expected := (0.6 if i % 2 == 1 else 1.4) / rate
		rhythm = rhythm and absf((hits[i] - hits[i - 1]) - expected) <= 0.051
	harness._expect(rhythm and aligned, "腕豪 %.1fx 攻速下真实六次命中保持左右拳节奏，前摇与命中在一 Tick 内对齐" % rate)
	view.free()
	unit.free()
	dummy.free()

func _check_rate_changes_and_seek(harness: Object, main: Node2D) -> void:
	var unit := _spawn(main)
	unit._attacking = true
	unit._attack_visual_serial = 2
	unit._attack_visual_pending = false
	unit.attack_timeline.windup = 0.15
	unit.attack_timeline.cooldown = 0.15
	unit.attack_timeline.visual_elapsed = 0.15
	var view := _view(main, unit)
	view._sync_visual(false, 0.0)
	var pose_time := view._animation_player.current_animation_position
	unit.apply_active_buff(1.0, 1.0, 1.0, 2.0)
	view._sync_visual(false, 0.0)
	var faster := is_equal_approx(unit.attack_timeline.windup, 0.075) and is_equal_approx(view._animation_player.speed_scale, 2.0)
	var no_restart := unit.get_attack_visual_serial() == 2 and is_equal_approx(view._animation_player.current_animation_position, pose_time)
	unit._tick_active_statuses(1.0)
	view._sync_visual(false, 0.0)
	var expired := is_equal_approx(unit.attack_timeline.windup, 0.15) and is_equal_approx(view._animation_player.speed_scale, 1.0)
	unit.apply_attack_speed_slow(1.0, 0.5)
	view._sync_visual(false, 0.0)
	var slower := is_equal_approx(unit.attack_timeline.windup, 0.3) and is_equal_approx(view._animation_player.speed_scale, 0.5)
	unit._tick_active_statuses(1.0)
	unit.attack_timeline.visual_elapsed = unit.first_hit_time + 0.4
	view._play_attack(2)
	var hit_seek := view._animation_player.current_animation == "Sett_Attack1_Passive_anm" and absf(view._animation_player.current_animation_position - 0.4) < 0.001
	var raw_speed := is_equal_approx(view._current_clip_speed, 1.0)
	unit.attack_timeline.visual_elapsed = unit.first_hit_time + view._attack_recover_delay(1) + 0.2
	view._play_attack(2)
	var recover_seek := view._animation_player.current_animation == "Attack1_Passive_Into_Idle" and absf(view._animation_player.current_animation_position - 0.2) < 0.001
	unit.attack_interval *= 2.0
	unit.first_hit_time *= 2.0
	unit.attack_timeline.visual_elapsed = unit.first_hit_time + 0.4
	view._play_attack(2)
	var base_change := is_equal_approx(view._current_clip_speed, 0.5) and absf(view._animation_player.current_animation_position - 0.2) < 0.001
	unit.freeze(0.5)
	view._sync_visual(false, 0.0)
	var frozen := is_zero_approx(view._animation_player.speed_scale)
	harness._expect(faster and no_restart and expired and slower and frozen, "腕豪前摇中 Buff 生效/到期、减攻速和冻结保留当前拳段及姿态进度")
	harness._expect(hit_seek and recover_seek and raw_speed and base_change, "腕豪晚到进度准确定位 Hit/收势，基础间隔修改同步缩放素材且不再四倍压缩右拳")
	view.free()
	unit.free()

func _check_skill_exits(harness: Object, main: Node2D) -> void:
	var unit := _spawn(main)
	var view := _view(main, unit)
	var idle_ok := true
	for action in [&"active", &"active_strong"]:
		unit._attacking = false
		unit._move_intent = Vector2.ZERO
		unit.play_visual_action(action, 1.4)
		view._sync_visual(false, 0.0)
		view._finish_visual_action()
		var recovery := &"Spell2_Into_Idle" if action == &"active" else &"Spell2_Strong_Into_Idle"
		idle_ok = idle_ok and view._animation_player.current_animation == recovery
		view._on_animation_finished(recovery)
		idle_ok = idle_ok and view._animation_player.current_animation == "Idle_Base"
	unit.play_visual_action(&"active_strong", 1.4)
	view._sync_visual(false, 0.0)
	unit._attacking = true
	unit._attack_visual_serial = 3
	view._pending_attack_serial = 3
	view._finish_visual_action()
	var attacks_directly := view._animation_player.current_animation == "Attack2_Start"
	var serial := unit.get_attack_visual_serial()
	var health := unit.hp
	view._on_source_died()
	var death := view._animation_player.current_animation == "Death" and is_equal_approx(view._current_clip_speed, 1.7 / 0.8) and is_equal_approx(view._animation_player.get_section_end_time(), 1.7)
	harness._expect(idle_ok and attacks_directly and death and unit.hp == health and unit.get_attack_visual_serial() == serial, "腕豪 W 停住接对应收势、继续攻击不强插转跑；死亡取前 1.7 秒压到 0.8 秒且表现不改权威")
	view.free()
	unit.free()

func _check_source_blends(harness: Object, main: Node2D) -> void:
	var unit := _spawn(main)
	unit._attacking = true
	var view := _view(main, unit)
	var matches_source := true
	var expected := [0.02, 0.04, 0.0, 0.0]
	for i in 4:
		view._play_attack(i + 1)
		view._update_attack_stages(unit.first_hit_time)
		matches_source = matches_source and is_equal_approx(view._last_clip_blend_time, expected[i])
		if i % 2 == 1:
			view._update_attack_stages(view._attack_recover_delay(i))
			matches_source = matches_source and is_zero_approx(view._last_clip_blend_time)
	harness._expect(matches_source, "腕豪 Start→Hit 与收势恢复原表混合值")
	view.free()
	unit.free()

func _check_cancelled_punch(harness: Object, main: Node2D) -> void:
	var unit := _spawn(main)
	var dummy := _spawn(main, true)
	unit._target = dummy
	unit._attacking = true
	unit._attack_hit_index = 1 # 左拳已命中，下一拳必须仍然是右拳
	unit._attack_visual_serial = 1
	unit._attack_visual_pending = true
	unit._try_start_attack_visual(unit.first_hit_time)
	var cancelled_serial := unit.get_attack_visual_serial()
	unit.begin_active_skill_cast(0.1, Vector2.UP, ["movement", "attack", "facing"])
	unit.sim_tick(0.1)
	var resumed_serial := unit.get_attack_visual_serial()
	var view := _view(main, unit)
	view._sync_visual(false, 0.0)
	var same_punch := view._animation_player.current_animation == "Attack1_Passive_Start" and resumed_serial > cancelled_serial and (resumed_serial - 1) % 4 == 1
	var before := dummy.hp
	for i in 10:
		unit.sim_tick(0.05)
		if dummy.hp < before:
			break
	var same_damage_and_gap := is_equal_approx(before - dummy.hp, unit.damage * 1.5) and is_equal_approx(unit.attack_timeline.cooldown, 1.4)
	harness._expect(same_punch and same_damage_and_gap, "技能取消右拳后仍从该右拳继续，动作、1.5倍伤害与长间隔保持一致，事件序号不复用")
	view.free()
	unit.free()
	dummy.free()

func _check_schema(harness: Object) -> void:
	var stats := CardDB.get_card("sett").duplicate(true)
	stats.visual_animations.clip_blends = {"broken": -1.0}
	stats.visual_animations.attack_reference_interval = 0.0
	stats.visual_animations.death_clip_end = -1.0
	var errors := PackedStringArray()
	CardDB.VALIDATOR._validate_card("bad_timing", stats, errors)
	var invalid_values := errors.size() >= 4
	stats = CardDB.get_card("sett").duplicate(true)
	stats.visual_animations.clip_blends = {"MissingClip>Attack1_Start": 0.0}
	stats.visual_animations.transitions["Sett_spell2_anm>move"].start_time = 999.0
	stats.visual_animations.death_clip_end = 999.0
	var contract_errors := SuiteUtils.visual_contract_errors("bad_clip", stats)
	harness._expect(invalid_values and contract_errors.size() >= 3, "动画配置拒绝非法混合边、参考间隔、缺失片段、越界转场起点与死亡裁剪")
