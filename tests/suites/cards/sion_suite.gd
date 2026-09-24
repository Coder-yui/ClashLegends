extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_revival()
	_check_shield()
	_check_shield_animation()
	_check_shield_freeze_transition()
	_check_schema()
	_check_authoritative_timing()
	_check_audio_lifecycle()
	_check_paid_skill()
	_check_whole_attack_animation()
	_check_frozen_revival()

func _unit(card: String, team: int, pos: Vector2) -> Unit:
	return _main._spawn_unit(team, card, pos, 0.0)

func _check_revival() -> void:
	var unit := _unit("sion", 0, Vector2(300, 900))
	var enemy := _unit("garen", 1, Vector2(500, 900))
	_expect(unit.building_only and unit.hp == 2400, "赛恩常态高血量且只攻击建筑")
	_main._combat.begin_batch(0, "sion_lethal")
	unit.take_damage(2500, enemy)
	unit.take_damage(2500, enemy)
	_main._combat.commit_batch()
	_expect(Unit.valid_action_cancellation(unit.last_action_cancellation), "复生真实动作取消载荷须被网络校验接受")
	_expect(unit.death_form.waiting() and unit.hp == 0 and not unit.is_queued_for_deletion(), "同批多刀致死仅进入一次复生，不释放实体")
	_expect(not CombatInteraction.allows(unit, enemy) and not CombatInteraction.allows(unit, null, 0) and not CombatInteraction.allows(unit, enemy, -1, Vector2.ZERO, true), "复生对敌我及已附着效果均拒绝交互")
	unit.heal(1000)
	unit.add_shield(1000, 2.0)
	_expect(unit.hp == 0 and unit.shield_hp == 0 and unit.action_permissions() == 0, "复生拒绝己方治疗护盾且禁止全部自主动作")
	# 直接推进领域状态，模拟40个固定步；取消同Tick防重扣仅用于本夹具。
	unit.death_form.created_tick = -1
	for tick in 39: unit.death_form.advance(unit, 0.05)
	_expect(unit.hp == 0 and unit.death_form.waiting(), "复生第39Tick仍不可选取")
	unit.death_form.advance(unit, 0.05)
	_expect(unit.hp == 2400 and unit.form_index == 1 and not unit.building_only and unit.move_speed == 76 and unit.attack_interval == 0.6, "第40Tick满血狂暴并切换攻速移速与目标")
	_expect((unit.action_permissions() & ControlState.START_SKILL) == 0, "狂暴永久禁用主动技能")
	_expect(not _main.preview_active_skill(unit, CardDB.active_skills_for("sion")[0]), "工作台同样不能在狂暴阶段施法")
	unit.death_form.advance(unit, 0.05)
	_expect(unit.hp == 2376, "狂暴每Tick衰减24生命，五秒预算2400")
	unit.hp = 2200
	unit.on_attack_landed(1, 100.0)
	_expect(unit.hp == 2250, "狂暴按实际生命伤害50%吸血")
	unit.on_attack_landed(1, 1000.0)
	_expect(unit.hp == 2400, "狂暴普攻实际伤害吸血且不超过上限")
	for tick in 99: unit.death_form.advance(unit, 0.05)
	_expect(unit.hp == 24 and not unit.is_queued_for_deletion(), "回血后自然存活时间延长且第99Tick仍存活")
	unit.death_form.advance(unit, 0.05)
	_expect(unit.hp == 0 and unit.is_queued_for_deletion() and not unit.death_form.waiting(), "狂暴衰减死亡不再次复生")
	enemy.queue_free()

func _check_shield() -> void:
	var unit := _unit("sion", 0, Vector2(300, 900))
	var air := _unit("anivia", 1, Vector2(340, 900))
	var skill := CardDB.active_skills_for("sion")[0]
	_main._active_skill_effect_system.apply(unit, skill)
	unit.take_damage(399)
	for tick in 39: unit._tick_active_statuses(0.05)
	_main._active_skill_effect_system.tick_effects(0.05)
	_expect(unit.shield_hp == 1 and air.hp == 620, "未满2秒保留剩余盾且不提前爆炸")
	unit._tick_active_statuses(0.05)
	_main._combat.begin_batch(0, "sion_explosion")
	_main._active_skill_effect_system.tick_effects(0.05)
	_main._combat.commit_batch()
	_expect(unit.shield_hp == 0 and air.hp == 380, "剩余1盾自然到期移除并造成对空240伤害")
	_main._active_skill_effect_system.apply(unit, skill)
	unit.take_damage(400)
	unit.add_shield(500, 4.0)
	for tick in 40: unit._tick_active_statuses(0.05)
	_main._active_skill_effect_system.tick_effects(0.05)
	_expect(air.hp == 380 and unit.shield_hp == 500, "W盾破裂后其他盾不能代替爆炸资格")
	unit.clear_shields()
	_main._active_skill_effect_system.apply(unit, skill)
	unit.take_damage(10000)
	for tick in 40: unit._tick_active_statuses(0.05)
	_main._active_skill_effect_system.tick_effects(0.05)
	_expect(air.hp == 380, "致死复生清除护盾不得触发延迟爆炸")
	unit.queue_free()
	air.queue_free()

func _check_shield_animation() -> void:
	var unit := _unit("sion", 0, Vector2(300, 900))
	unit._deploy_timer = 0.0
	unit._move_intent = Vector2.RIGHT
	unit._body_facing_direction = Vector2.RIGHT
	var view: UnitModel3D
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit: view = child
	view._process(0.01)
	var permissions := unit.action_permissions()
	var serial := unit.get_visual_action_serial()
	var position_before := unit.position
	var facing_before := unit._body_facing_direction
	var movement_before := unit._move_intent
	_main.notify_unit_audio_event(unit, &"shield:explode", unit.position)
	_expect(view._animation_player.current_animation == "Spell2_B" and view._playing_visual_action, "移动期间爆炸播放原版Spell2_B")
	_expect(unit.action_permissions() == permissions and unit._move_intent == movement_before and unit._body_facing_direction == facing_before and unit.position == position_before and unit.get_visual_action_serial() == serial, "爆炸动画不写权威移动、朝向、权限或动作时间线")
	unit._attacking = true
	view._play_attack(1)
	_expect(not view._playing_visual_action and view._animation_player.current_animation == "Attack_Tower2", "新普攻立即打断爆炸表现，不延迟攻击")
	var attack_position := view._animation_player.current_animation_position
	_main.notify_unit_audio_event(unit, &"shield:explode", unit.position)
	_expect(view._animation_player.current_animation == "Attack_Tower2" and view._animation_player.current_animation_position == attack_position, "攻击期间爆炸不覆盖或重播攻击")
	unit._attacking = false
	view._playing_attack = false
	view._holding_attack_pose = false
	unit.freeze(2.0)
	view._process(0.01)
	_main.notify_unit_audio_event(unit, &"shield:explode", unit.position)
	_expect(not view._playing_visual_action, "受控时不以爆炸动作绕过模型冻结")
	unit.queue_free()

func _check_shield_freeze_transition() -> void:
	for next_state in [1, 2, 3]:
		var unit := _unit("sion", 0, Vector2(300, 900))
		unit._deploy_timer = 0.0
		var view: UnitModel3D
		for child in _main._battle_presentation._world_root.get_children():
			if child is UnitModel3D and child._source == unit: view = child
		view._process(0.01)
		_main.notify_unit_audio_event(unit, &"shield:explode", unit.position)
		var player := view._animation_player
		player.advance(0.2)
		var frozen_position := player.current_animation_position
		unit.freeze(0.2)
		view._process(0.01)
		player.advance(0.1)
		_expect(player.current_animation == "Spell2_B" and is_equal_approx(player.current_animation_position, frozen_position) and is_zero_approx(player.speed_scale), "技能动画中冰冻保持当前片段与姿势，不前进、不切待机")
		var started: Array[StringName] = []
		var collect := func(clip: StringName): started.append(clip)
		player.animation_started.connect(collect)
		unit.control.tick_hard_controls(0.2)
		unit._move_intent = Vector2.RIGHT if next_state == 2 else Vector2.ZERO
		if next_state == 3:
			unit._attacking = true
			unit._attack_visual_serial += 1
		view._process(0.01)
		player.advance(0.0)
		var expected := "Attack_Tower2" if next_state == 3 else ("Run" if next_state == 2 else "Idle1_Base")
		_expect(player.current_animation == expected and view._last_clip_blend_time > 0.0, "解冻直接混合至%s，不续播旧技能" % expected)
		_expect(not started.has(&"Spell2_B") and (next_state == 1 or not started.has(&"Idle1_Base")), "解冻移动/攻击不经过中间待机或重播技能")
		player.animation_started.disconnect(collect)
		unit.queue_free()

func _check_schema() -> void:
	for value in ["1", -1.0, NAN]:
		var stats := CardDB.get_card("sion").duplicate(true)
		stats.death_form_delay = value
		_expect(not CardDB.VALIDATOR.validate_all({"sion": stats}, false).is_empty(), "致死换形拒绝非法时长 %s" % str(value))
	for fade in ["fade_in", "fade_out"]:
		for value in ["bad", -0.1, NAN]:
			var stats := CardDB.get_card("sion").duplicate(true)
			stats.transformed_stats.audio.events["berserk:sustain"][fade] = value
			_expect(not CardDB.VALIDATOR.validate_all({"sion": stats}, false).is_empty(), "持续音拒绝非法渐变参数")
	_expect(not DeathFormState.valid_snapshot([false, 20]) and not DeathFormState.valid_snapshot([true, -1]), "拒绝非法复生快照")

func _check_authoritative_timing() -> void:
	var unit := _unit("sion", 0, Vector2(350, 900))
	unit.take_damage(10000)
	_main._net_units[98000] = unit
	_expect(_main.authoritative_units_snapshot().has(98000), "主机实体索引保留零血等待者，快照不可误删")
	_main._net_units.erase(98000)
	unit.prepare_natural_lifecycle(0.05)
	_expect(unit.death_form.waiting_ticks == 40, "致死当Tick自然生命周期不得提前扣复生时间")
	_run_main_ticks(39)
	_expect(unit.hp == 0 and unit.death_form.waiting_ticks == 1, "真实主循环第39Tick仍等待复生")
	_run_main_ticks(1)
	_expect(unit.hp == unit.max_hp and unit.form_index == 1, "真实主循环第40Tick复生满血且不当场扣衰减")
	unit.queue_free()

func _check_audio_lifecycle() -> void:
	var unit := _unit("sion", 0, Vector2(350, 900))
	var manager: GameAudioManager = _main._audio_manager
	var cues: Array[StringName] = []
	var collect := func(card: String, cue: StringName, _position: Vector2):
		if card == "sion": cues.append(cue)
	manager.cue_played.connect(collect)
	var id := unit.get_instance_id()
	var shield_key := manager._sustain_key(id, &"explosive_shield")
	var berserk_key := manager._sustain_key(id, &"berserk")
	_main._active_skill_effect_system.apply(unit, CardDB.active_skills_for("sion")[0])
	manager._process(0.05)
	_expect(manager._sustain_players.has(shield_key), "W独立盾存续启动原版循环音")
	unit.take_damage(400)
	manager._process(0.05)
	_expect(not manager._sustain_players.has(shield_key), "W破盾停止循环，不被其他状态续播")
	unit.take_damage(10000)
	unit.death_form.created_tick = -1
	_expect(cues.count(&"rebirth:begin") == 1 and cues.count(&"rebirth:voice") == 1, "首次致死同步派发复生SFX与VO一次")
	for tick in 39: unit.death_form.advance(unit, 0.05)
	manager._process(0.05)
	_expect(not cues.has(&"rebirth:ready") and not manager._sustain_players.has(berserk_key), "等待39Tick不提前播放狂暴启动或循环")
	unit.death_form.advance(unit, 0.05)
	_expect(cues.count(&"rebirth:ready") == 1, "第40Tick只触发一次狂暴启动声")
	manager._process(0.05)
	_expect(manager._sustain_players.has(berserk_key), "满血复生启动狂暴原版持续音")
	var player: AudioStreamPlayer2D = manager._sustain_players[berserk_key]
	_expect(is_zero_approx(player.volume_linear), "狂暴循环从零振幅淡入")
	manager._tick_sustain_fades(0.125)
	_expect(is_equal_approx(player.volume_linear, db_to_linear(-8.0) * 0.5), "原版0.25秒线性淡入中点")
	manager._tick_sustain_fades(0.125)
	unit.take_damage(10000)
	_expect(manager._sustain_players.has(berserk_key + ":tail"), "狂暴结束保留原版0.5秒淡出尾音")
	manager.set_battle_paused(true)
	manager._process(1.0)
	_expect(manager._sustain_players.has(berserk_key + ":tail"), "工作台暂停冻结淡出")
	manager.set_battle_paused(false)
	manager._tick_sustain_fades(0.5)
	_expect(not manager._sustain_players.has(berserk_key + ":tail"), "淡出完成释放播放器")
	manager.cue_played.disconnect(collect)
	_expect(not manager._sustain_players.has(berserk_key), "最终死亡立即停止狂暴持续音")

func _check_paid_skill() -> void:
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "sion"
	var unit := _unit("sion", 0, Vector2(350, 900))
	unit.move_speed = 0.0
	unit.active_ability_id = 98001
	unit.active_ability_slot = 0
	_main._register_active_skill(unit, "sion", 0)
	_main._elixir.elixir = 5.0
	_expect(_main.use_active_skill(98001, 0) and _main._elixir.elixir == 4.0, "W入队扣1金币")
	_run_main_ticks(10)
	var state: Dictionary = _main.get_active_skill_snapshot(98001)
	_expect(unit.shield_hp == 400 and state.uses_remaining == 1 and is_equal_approx(state.cooldown_left, 8.0), "W真正开始消耗1次并启动8秒冷却")
	_expect(not _main.use_active_skill(98001, 0), "W冷却中拒绝再次提交")
	_run_main_ticks(160)
	_expect(_main.use_active_skill(98001, 0), "W8秒冷却结束允许第二次")
	_run_main_ticks(10)
	_expect(_main.get_active_skill_snapshot(98001).uses_remaining == 0 and not _main.use_active_skill(98001, 0), "W最多2次，不允许第三次")
	unit.queue_free()
	# 等待命令期间致死复生：保留实例使付款原路退回，不耗次数。
	unit = _unit("sion", 0, Vector2(350, 900))
	unit.active_ability_id = 98002
	unit.active_ability_slot = 0
	_main._register_active_skill(unit, "sion", 0)
	_main._elixir.elixir = 5.0
	_expect(_main.use_active_skill(98002, 0), "复生前可正常提交W")
	unit.take_damage(10000)
	_run_main_ticks(10)
	_expect(_main._elixir.elixir >= 5.0 and int(_main.get_active_skill_snapshot(98002).get("uses_remaining", -1)) == 2 and unit.shield_hp == 0, "等待命令期间致死复生取消W，退款且不耗次数")
	unit.queue_free()
	_main._deck = deck

func _check_whole_attack_animation() -> void:
	for form in [0, 1]:
		var unit := _unit("sion", 0, Vector2(350, 900))
		if form == 1: unit._apply_form(1, false)
		var view: UnitModel3D
		for child in _main._battle_presentation._world_root.get_children():
			if child is UnitModel3D and child._source == unit: view = child
		_expect(view != null, "赛恩建立实际模型代理")
		if view == null: continue
		view.set_process(false)
		unit._attacking = true
		for serial in [1, 2]:
			unit._attack_swing_count = serial - 1
			view._play_attack(serial)
			var player := view._animation_player
			var hit := unit._attack_first_hit_for_segment(serial - 1)
			player.advance(hit)
			_expect(not view._attack_hit_pending and absf(player.current_animation_position - 11.0 / 30.0) < 0.01, "赛恩形态%d第%d段完整动画在换算命中时抵达原版第11帧（百分秒精度内）" % [form, serial])
			_expect(is_equal_approx(player.get_section_end_time(), player.get_animation(player.current_animation).length), "普攻使用完整原片，不切分也不裁剪")
		view.free()
		unit.queue_free()

func _check_frozen_revival() -> void:
	var unit := _unit("sion", 0, Vector2(350, 900))
	var view: UnitModel3D
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit: view = child
	unit.hp = 1.0
	unit.freeze(5.0, &"first")
	unit.freeze(8.0, &"second")
	unit.stun(6.0)
	view._process(0.01)
	_expect(is_zero_approx(view._animation_player.speed_scale), "致死前冰冻确实定格赛恩模型")
	unit.take_damage(2.0)
	view._process(0.01)
	var player := view._animation_player
	_expect(not unit.is_frozen() and not unit.is_stunned() and unit.death_form.waiting(), "首次致死清除全部旧冰冻与眩晕来源")
	_expect(player.current_animation == "Passive_Death" and player.speed_scale > 0.0 and not view._was_controlled, "从冻结姿势直接进入复生动画，不等旧冰冻结束")
	player.advance(0.25)
	_expect(player.current_animation_position >= 0.24 and view._playing_visual_action, "复生动画实际推进，不被旧控制覆盖吞掉")
	var state := unit.presentation_state()
	state.advance_health_bar(0.0)
	_expect(is_zero_approx(state.health_ratio) and unit.hp == 0, "复生血条从零开始，真实生命为零")
	unit.death_form.created_tick = -1
	for tick in 20: unit.death_form.advance(unit, 0.05)
	state.advance_health_bar(0.0)
	_expect(is_equal_approx(state.health_ratio, 0.5) and unit.hp == 0, "复生一秒显示半条血但不产生真实回血")
	state.advance_health_bar(0.02)
	_expect(state.health_ratio > 0.5 and state.health_ratio < 0.525, "复生血条在权威Tick之间连续填充")
	state.advance_health_bar(10.0)
	_expect(state.health_ratio <= 0.525 and unit.hp == 0, "无新状态时最多外推一个Tick，不伪造完成复生")
	unit.heal(999)
	unit.freeze(10.0)
	_expect(unit.hp == 0 and not unit.is_frozen(), "血条显示回血不放开治疗或冰冻准入")
	for tick in 20: unit.death_form.advance(unit, 0.05)
	_expect(unit.hp == unit.max_hp and is_equal_approx(state.health_ratio, 1.0) and not unit.is_frozen(), "复生结束真实满血，旧冰冻不进入第二条命")
	_expect(view._animation_player == player, "复生换形保留播放器与原姿势用于混合")
	for clip in ["Sion_Passive_Run_anm", "Passive_Attack1", "Passive_Attack2", "Passive_Idle1"]:
		player.play("Passive_Death")
		player.seek(1.99, true)
		view._play_clip(clip)
		_expect(is_equal_approx(view._last_clip_blend_time, 0.18), "复生末姿势到%s使用0.18秒混合" % clip)
	_expect(bool(view._model_root.get("_berserk")), "原位换形仍隐藏狂暴斧头")
	view.free()
	unit.queue_free()
