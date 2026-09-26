class_name GwenSuite
extends "res://tests/suites/battle_suite.gd"
## 格温卡牌领域：百分比被动、推塔回归与美术接入。

func _view_for(unit: Unit) -> UnitModel3D:
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			return child as UnitModel3D
	return null

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_gwen_target_and_damage()
	_check_gwen_mechanic()
	_check_gwen_tower_combat()
	_check_gwen_snip_snip_skill()
	_check_gwen_art_integration()
	_check_hallowed_mist()
	_check_mist_cost_and_cooldown()
	_check_mist_audio_lifecycle()

func _check_gwen_snip_snip_skill() -> void:
	var stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	stats["deploy_time"] = 0.0
	var skill: Dictionary = stats.active_skills[0]
	var gwen := Unit.new()
	gwen.position = Vector2(360.0, 900.0)
	gwen.setup(0, stats, stats.name)
	_main.add_child(gwen)
	gwen.on_attack_landed()
	var disabled_without_loadout := not gwen.is_skill_resource_visible() and is_zero_approx(gwen.skill_resource_value)
	gwen.configure_carried_active_skill(skill)
	for _hit in range(3):
		gwen.on_attack_landed()
	var charged_full := is_equal_approx(gwen.skill_resource_value, 3.0)
	var prepared_full: Dictionary = _main._active_skill_effect_system.prepare_cast(gwen, skill)
	var full_tier: bool = (
		charged_full and is_zero_approx(gwen.skill_resource_value)
		and String(prepared_full.visual_action) == "active_3"
		and is_equal_approx(float(prepared_full.cast_duration), 1.5)
		and prepared_full.prepared_hit_damages == [40, 20, 20, 20, 60]
		and is_equal_approx(float(prepared_full.first_hit_heal), 100.0)
	)
	var partial := Unit.new()
	partial.position = Vector2(560.0, 900.0)
	partial.setup(0, stats, stats.name)
	partial.configure_carried_active_skill(skill)
	partial.add_skill_resource(2.0)
	_main.add_child(partial)
	var prepared_partial: Dictionary = _main._active_skill_effect_system.prepare_cast(partial, skill)
	var zero := Unit.new()
	zero.setup(0, stats, stats.name)
	zero.configure_carried_active_skill(skill)
	_main.add_child(zero)
	var prepared_zero: Dictionary = _main._active_skill_effect_system.prepare_cast(zero, skill)
	var one := Unit.new()
	one.setup(0, stats, stats.name)
	one.configure_carried_active_skill(skill)
	one.add_skill_resource(1.0)
	_main.add_child(one)
	var prepared_one: Dictionary = _main._active_skill_effect_system.prepare_cast(one, skill)
	var all_tiers: bool = (
		String(prepared_zero.visual_action) == "active_0" and prepared_zero.prepared_hit_damages == [40, 60]
		and String(prepared_one.visual_action) == "active_1" and prepared_one.prepared_hit_damages == [40, 20, 60]
		and String(prepared_partial.visual_action) == "active_2" and prepared_partial.prepared_hit_damages == [40, 20, 20, 60]
		and String(prepared_full.visual_action) == "active_3" and prepared_full.prepared_hit_damages == [40, 20, 20, 20, 60]
	)
	var visual_actions: Dictionary = stats.visual_animations.visual_actions
	var spell_0_time_scale := float(visual_actions.active_0.durations[0]) / 1.6666667
	var uncompressed_b_timing := true
	for tier in range(1, 4):
		var descriptor: Dictionary = visual_actions["active_%d" % tier]
		var durations: Array = descriptor.durations
		var animations: Array = descriptor.animation
		var total_duration := 0.0
		for clip_index in range(durations.size()):
			total_duration += float(durations[clip_index])
			if String(animations[clip_index]) == "Spell1_B":
				uncompressed_b_timing = uncompressed_b_timing and is_equal_approx(float(durations[clip_index]), 0.1666667)
		var spell_0_source_duration := float(descriptor.clip_ranges[0][1]) - float(descriptor.clip_ranges[0][0])
		uncompressed_b_timing = (
			uncompressed_b_timing
			and is_equal_approx(total_duration, 1.5)
			and is_equal_approx(float(durations[0]) / spell_0_source_duration, spell_0_time_scale)
		)
	_main._active_skill_effect_system.begin_frontal_visual(gwen, prepared_full, Vector2.UP)
	var range_effect: Dictionary = _main._active_skill_effect_system.frontal_effects.back()
	var reference_range: bool = (
		String(range_effect.shape) == "fan"
		and is_equal_approx(float(range_effect.arc_degrees), 78.0)
		and is_equal_approx(float(range_effect.length), 135.0)
		and is_equal_approx(float(range_effect.center_width), 30.0)
		and is_equal_approx(float(range_effect.duration), 1.04)
	)
	_main._active_skill_effect_system.frontal_effects.clear()
	_expect(
		disabled_without_loadout and full_tier and all_tiers and uncompressed_b_timing and reference_range,
		"格温只有携带快刀乱剪时普攻命中才充能；四档总时长均为 1.5 秒且 Spell1 B 保持原速，圆弧扇区和恒宽核心提示持续到最后一剪",
	)
	var dummy_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))
	var center := Unit.new()
	var edge := Unit.new()
	var behind := Unit.new()
	var outside_arc := Unit.new()
	center.position = Vector2(360.0, 790.0)
	edge.position = Vector2(414.0, 790.0)
	behind.position = Vector2(360.0, 990.0)
	# 该点位于旧三角形远端角落内，但落在新圆弧半径外，用于锁定参考图式扇区。
	outside_arc.position = Vector2(460.0, 737.0)
	for target in [center, edge, behind, outside_arc]:
		target.setup(1, dummy_stats, "剪切木桩")
		_main.add_child(target)
	gwen.begin_active_skill_cast(float(prepared_full.cast_duration), Vector2.UP, prepared_full.cast_locks)
	gwen.hp = 300.0
	var center_before := center.hp
	var edge_before := edge.hp
	var behind_before := behind.hp
	var outside_arc_before := outside_arc.hp
	gwen.card_id = "gwen"
	_main._audio_manager.attach_unit(gwen, stats)
	var hit_cues: Array = []
	var on_hit_cue := func(card, cue, _position):
		if card == "gwen" and ":hit_" in String(cue): hit_cues.append(String(cue))
	_main._audio_manager.cue_played.connect(on_hit_cue)
	_main._queue_active_skill_impact(gwen, prepared_full, float(prepared_full.impact_delay))
	for _tick in 3:
		_main._commands.tick_impacts(0.05)
	var first_cut := is_equal_approx(gwen.hp, 400.0) and gwen.restoration_fx_timer > 0.0 and is_equal_approx(center_before - center.hp, 40.0 * 1.2 + roundf(center.max_hp * 0.05))
	for _tick in 25:
		_main._commands.tick_impacts(0.05)
	var all_cuts := (
		is_equal_approx(center_before - center.hp, 160.0 * 1.2 + 5.0 * roundf(center.max_hp * 0.05))
		and is_equal_approx(edge_before - edge.hp, 160.0 + 5.0 * roundf(edge.max_hp * 0.05))
		and is_equal_approx(behind.hp, behind_before)
		and is_equal_approx(outside_arc.hp, outside_arc_before)
	)
	for _tick in 12:
		_main._commands.tick_impacts(0.05)
	_expect(
		first_cut and all_cuts and is_equal_approx(gwen.hp, 400.0)
		and gwen.is_active_skill_movement_locked() and gwen.is_active_skill_attack_locked() and gwen.is_active_skill_facing_locked(),
		"格温按 40→20×3→60 分次剪切，恒宽中央长条逐次乘 1.2，圆弧扇区不误伤远端角落或身后；满层首次命中立即回复 100 生命，多目标和后续剪击不重复回复",
	)
	_expect(hit_cues == ["active_3:hit_first_center", "active_3:hit_middle_center", "active_3:hit_middle_center", "active_3:hit_middle_center", "active_3:hit_last_center"], "格温实际五剪命中分别播首/中/末音效，多目标同剪只播一次")
	var empty_cut := prepared_full.duplicate(true)
	empty_cut["hit_audio_phase"] = "last"
	_main._active_skill_effect_system.apply_frontal(gwen, empty_cut, Vector2.RIGHT)
	_expect(hit_cues.size() == 5, "格温空剪不播放命中声")
	_main._audio_manager.cue_played.disconnect(on_hit_cue)
	_main._audio_manager._detach_unit(gwen.get_instance_id())
	# 通过真实逐剪排程验证空剪、延迟首次命中以及每次施法独立的去重状态。
	var saved_position := gwen.position
	gwen.position = Vector2(5000, 5000)
	for scenario in ["miss", "late", "immune", "partial"]:
		gwen.hp = 200.0
		gwen.restoration_fx_timer = 0.0
		center.position = Vector2(5000, 4890) if scenario in ["immune", "partial"] else Vector2(5500, 5000)
		if scenario == "immune": center.target_protection.begin(center.position, 30.0, 2.0)
		var cast: Dictionary = prepared_partial if scenario == "partial" else prepared_full
		gwen.begin_active_skill_cast(1.5, Vector2.UP, cast.cast_locks)
		_main._queue_active_skill_impact(gwen, cast, float(cast.impact_delay))
		for tick in range(1, 32):
			if scenario == "late" and tick == 4: center.position = Vector2(5000, 4890)
			_main._commands.tick_impacts(0.05)
			if scenario == "late" and tick == 3:
				_expect(is_equal_approx(gwen.hp, 200.0), "格温满层首剪落空不提前回血")
			if scenario == "late" and tick == 13:
				_expect(is_equal_approx(gwen.hp, 300.0) and gwen.restoration_fx_timer > 0.0, "格温后续剪首次命中立即回血并触发通用特效")
		_expect(is_equal_approx(gwen.hp, 300.0 if scenario == "late" else 200.0), "格温回血边界：%s；空剪、免疫和非满层无回血，满层只触发一次" % scenario)
		if scenario == "immune": center.target_protection.clear()
	gwen.position = saved_position
	center.position = Vector2(360, 790)
	_main._battle_presentation.attach_unit(gwen, stats)
	var view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == gwen:
			view = child as UnitModel3D
			break
	var animation_chain := false
	if view != null:
		gwen.play_visual_action(&"active_3", float(prepared_full.cast_duration))
		view._sync_visual(false, 0.05)
		var clip_0 := view._animation_player.current_animation == "Spell1_0"
		view._on_animation_finished(&"Spell1_0")
		var clip_b_1 := view._animation_player.current_animation == "Spell1_B" and is_zero_approx(view._last_clip_blend_time)
		view._on_animation_finished(&"Spell1_B")
		var clip_b_2 := view._animation_player.current_animation == "Spell1_B" and is_zero_approx(view._last_clip_blend_time)
		view._on_animation_finished(&"Spell1_B")
		var clip_b_3 := view._animation_player.current_animation == "Spell1_B" and is_zero_approx(view._last_clip_blend_time)
		view._on_animation_finished(&"Spell1_B")
		var clip_c := view._animation_player.current_animation == "Spell1_C_anm"
		var clip_c_no_blend := is_zero_approx(view._last_clip_blend_time)
		gwen.active_skill_cast_timer = 0.0
		gwen.active_skill_cast_locks.clear()
		gwen._move_intent = Vector2.UP * gwen.move_speed
		view._on_animation_finished(&"Spell1_C_anm")
		var transition_entry_short := (
			view._animation_player.current_animation == "Spell1_C_to_Run_anm"
			and is_equal_approx(view._last_clip_blend_time, view._transition_blend(&"sequence"))
		)
		view._on_animation_finished(&"Spell1_C_to_Run_anm")
		var transition_to_run_short := (
			view._animation_player.current_animation == "Run_anm"
			and is_zero_approx(view._last_clip_blend_time)
		)
		animation_chain = clip_0 and clip_b_1 and clip_b_2 and clip_b_3 and clip_c and clip_c_no_blend and transition_entry_short and transition_to_run_short
	_expect(animation_chain, "格温满层技能在 Spell1 0 的 1.5 秒总时槽内无混合直连 B×3→C，技能后移动直接衔接 Spell1 C ToRun")
	for unit in [gwen, partial, zero, one, center, edge, behind, outside_arc]:
		if is_instance_valid(unit):
			unit.free()

func _check_gwen_mechanic() -> void:
	var stats := CardDB.get_card("gwen").duplicate(true)
	stats["deploy_time"] = 0.0
	var gwen := Unit.new()
	gwen.setup(0, stats, stats.name)
	_main.add_child(gwen)
	var target := Unit.new()
	var target_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))
	target_stats["hp"] = 1010.0
	target.setup(1, target_stats, "被动木桩")
	_main.add_child(target)
	_main.launch_attack(gwen, target, 62.0, 0.0, 0.0, 0.0, gwen.color)
	_expect(target.hp == 897.0, "格温普攻 62 + 最大生命 5%（50.5 四舍五入为 51）")
	var before := target.hp
	_main.launch_attack(gwen, target, 62.0 * 1.5, 0.0, 0.0, 0.0, gwen.color)
	_expect(before - target.hp == 144.0, "强化倍率只影响普攻基础值，被动不放大")
	for tower in [_main._towers[3], _main._king_enemy]:
		before = tower.hp
		_main.launch_attack(gwen, tower, 62.0, 0.0, 0.0, 0.0, gwen.color)
		_expect(before - tower.hp == 82.0, "防御塔与水晶被动固定附加 20 点")
		tower.hp = before
	target.take_damage(10.49)
	_expect(target.hp == 743.0, "普通伤害小于半点向下取整")
	target.heal(10.5)
	_expect(target.hp == 754.0, "治疗半点向上取整")
	gwen.position = Vector2(360, 900)
	gwen.hp = 300.0
	gwen.configure_carried_active_skill(stats.active_skills[0])
	gwen.add_skill_resource(3.0)
	var skill: Dictionary = _main._active_skill_effect_system.prepare_cast(gwen, stats.active_skills[0])
	skill["cast_forward"] = Vector2.UP
	target.position = Vector2(600, 1100)
	_main._queue_active_skill_impact(gwen, skill, float(skill.impact_delay))
	for _tick in 35:
		_main._commands.tick_impacts(0.05)
	_expect(gwen.hp == 300.0, "满层技能完全空放不回血")
	# 只在首剪击杀也算本次命中；结束后空放不能继承上一轮命中。
	target.position = Vector2(360, 790)
	target.hp = 1.0
	_main._queue_active_skill_impact(gwen, skill, float(skill.impact_delay))
	for _tick in 35:
		_main._commands.tick_impacts(0.05)
	_expect(gwen.hp == 400.0, "满层首剪击杀、后续空剪仍只回复一次 100")
	_main._queue_active_skill_impact(gwen, skill, float(skill.impact_delay))
	for _tick in 35:
		_main._commands.tick_impacts(0.05)
	_expect(gwen.hp == 400.0, "后续空放不会复用上一次施法命中记录")
	var tower: Tower = _main._towers[3]
	var tower_before := tower.hp
	gwen.position = tower.position + Vector2.DOWN * 100.0
	var tower_cut: Dictionary = stats.active_skills[0].duplicate(true)
	_main._active_skill_effect_system.apply_frontal(gwen, tower_cut, Vector2.UP)
	_expect(tower_before - tower.hp == 68.0, "剪切防御塔中央伤害为 40×1.2+20，固定被动不放大")
	tower.hp = tower_before
	gwen.add_shield(10.5, 1.0, true)
	gwen._tick_active_statuses(0.05)
	var hp_before := gwen.hp
	gwen.take_damage(20.5)
	_expect(gwen.hp == hp_before - 11.0 and gwen.hp == roundf(gwen.hp), "护盾量与衰减四舍五入，破盾后生命仍为整数")
	var invalid_stats := stats.duplicate(true)
	invalid_stats["on_hit_max_health_ratio"] = -0.05
	var errors := PackedStringArray()
	CardDB.VALIDATOR._validate_combat_stats("passive_probe", invalid_stats, true, errors)
	_expect(not errors.is_empty(), "被动 schema 拒绝负百分比")
	target.free()
	gwen.free()

func _check_gwen_tower_combat() -> void:
	var gwen_stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	gwen_stats["deploy_time"] = 0.0
	gwen_stats["hp"] = 100000.0
	# —— 场景一：攻击敌方公主塔 ——
	var tower: Tower = _main._towers[3]
	var stop_distance: float = tower.body_radius + gwen_stats.radius + gwen_stats.range
	var gwen := Unit.new()
	gwen.position = tower.position + Vector2.DOWN * (stop_distance + 12.0)
	gwen.setup(0, gwen_stats, gwen_stats.name)
	_main.add_child(gwen)
	gwen._target = tower
	var tower_hp := tower.hp
	var gwen_hp := gwen.hp
	for _tick in 100:
		_main._sim_step(_main.SIM_DT)
	_expect(tower.hp < tower_hp, "格温对公主塔持续输出")
	_expect(gwen.hp < gwen_hp, "公主塔能正常锁定并反击格温")
	# 塔也接入受击闪白：3D 代理收到限频表现事件，且闪白强度已减淡。
	var tower_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == tower:
			tower_view = child as TowerModel3D
			break
	_expect(tower_view != null and tower_view._hit_flash_timer > 0.0 and tower_view._hit_flash_timer <= TowerModel3D.HIT_FLASH_DURATION, "公主塔受击后 3D 模型同步轻微闪白")
	gwen.free()
	tower.hp = tower_hp
	# —— 场景二：攻击敌方水晶（国王塔）——
	# 冻结两座敌方公主塔做隔离，保证水晶战斗期间对格温的伤害只可能来自水晶。
	var left_princess: Tower = _main._towers[2]
	left_princess.freeze(999.0)
	tower.freeze(999.0)
	var king: Tower = _main._king_enemy
	var king_was_active := king.activated
	var king_hp := king.hp
	var king_stop: float = king.body_radius + gwen_stats.radius + gwen_stats.range
	var attacker := Unit.new()
	attacker.position = king.position + Vector2.DOWN * (king_stop + 12.0)
	attacker.setup(0, gwen_stats, gwen_stats.name)
	_main.add_child(attacker)
	attacker._target = king
	var attacker_hp := attacker.hp
	for _tick in 100:
		_main._sim_step(_main.SIM_DT)
	_expect(king.hp < king_hp, "格温对水晶持续输出")
	_expect(not king.activated, "水晶受到攻击后仍不激活攻击能力")
	_expect(is_equal_approx(attacker.hp, attacker_hp), "水晶不索敌、不发射弹体也不造成伤害")
	# 水晶同样接入受击闪白表现。
	var king_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == king:
			king_view = child as TowerModel3D
			break
	_expect(king_view != null and king_view._hit_flash_timer > 0.0, "水晶受击后 3D 模型同步轻微闪白")
	attacker.free()
	# 还原现场：公主塔解冻、水晶回到初始血量与休眠状态，不影响后续测试。
	SuiteUtils.set_control_window(left_princess.control, &"freeze", 0.0)
	SuiteUtils.set_control_window(tower.control, &"freeze", 0.0)
	king.hp = king_hp
	king.activated = king_was_active

func _check_gwen_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	stats["deploy_time"] = 0.0
	var packed := load(stats.visual_scene_path) as PackedScene
	if packed == null:
		return
	var anim_names: Dictionary = stats.visual_animations
	var sample := packed.instantiate() as Node3D
	var model_node := sample.get_node_or_null("Model") as Node3D
	_expect(model_node != null and is_equal_approx(model_node.position.y, -0.0585), "格温放大后脚底校正同步缩放，模型仍落在地面")
	var attacks: Array = anim_names.attack
	_expect(attacks == ["Attack1", "Attack2", "Attack3"], "格温三套攻击动作按表现序号交替选择")
	var attack_to_move: Array = anim_names.attack_to_move
	_expect(attack_to_move == ["Into_Run", "INTO_Run_-90_anm", "INTO_Run_180_anm"], "格温三段攻击按原表零朝向分支分别接 Into_Run、-90°、180°转跑")
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	var attack_move_routes_ok := false
	var model_view := _view_for(unit)
	if attached and model_view != null:
		attack_move_routes_ok = true
		for serial in range(1, 4):
			model_view._play_attack(serial)
			model_view._transition_to_basic_state(2, model_view._transition_blend(&"action_out"), &"attack")
			var expected_transition := StringName(attack_to_move[serial - 1])
			attack_move_routes_ok = attack_move_routes_ok and model_view._animation_player.current_animation == expected_transition
			model_view._on_animation_finished(expected_transition)
	_expect(attack_move_routes_ok, "格温攻击 1/2/3 退出到移动时分别播放 Into_Run、INTO_Run_-90_anm、INTO_Run_180_anm")
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var death_view := child as UnitModel3D
			death_view_found = death_view._dying and death_view._animation_player.current_animation == "Death"
			death_view.free()
			break
	_expect(attached and death_view_found, "格温死亡时由独立 3D 代理播放 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

func _check_gwen_target_and_damage() -> void:
	var gwen := Unit.new()
	gwen.setup(0, CardDB.get_card("gwen"), "格温")
	gwen.position = Vector2(360, 700)
	_main.add_child(gwen)
	var attacker := Unit.new()
	attacker.setup(1, SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen")), "攻击者")
	attacker.building_only = false
	attacker.position = Vector2(360, 950)
	_main.add_child(attacker)
	gwen.on_attack_landed()
	_expect(attacker._target_is_attackable(gwen) and gwen._target_is_attackable(attacker), "格温出手后仍与敌军互为合法目标")
	var hp := gwen.hp
	_expect(_main.launch_attack(attacker, gwen, 10.0, 0.0, 0.0, 0.0, Color.WHITE) and gwen.hp == hp - 10.0, "格温正常承受已释放近战")
	hp = gwen.hp
	_main.launch_attack(attacker, gwen, 10.0, 10000.0, 0.0, 0.0, Color.WHITE)
	_main._projectile_system.tick(0.05)
	_expect(gwen.hp == hp - 10.0, "格温正常承受远程弹体")
	hp = gwen.hp
	_main.combat_service().resolve_attack_hit(1, attacker.position, gwen, 10.0, 100.0, 0.0, attacker)
	_expect(gwen.hp == hp - 10.0, "格温正常承受范围命中")
	var tower: Tower = _main._towers[2]
	var pos := gwen.position
	gwen.position = tower.position + Vector2.DOWN * 100.0
	_expect(tower._target_is_valid(gwen), "敌塔正常选中格温")
	gwen.position = pos
	gwen.free()
	attacker.free()

func _check_hallowed_mist() -> void:
	var skill: Dictionary = CardDB.active_skills_for("gwen")[1]
	_expect(skill.kind == "sanctuary" and skill.radius == 120.0 and skill.duration == 4.0 and skill.max_uses == 2 and skill.cost == 1 and skill.cooldown == 8.0, "圣霭可选技能的费用、次数、半径和时长")
	for side in [0, 1]:
		var gwen: Unit = _main._spawn_unit(side, "gwen", Vector2(360, 900), 0.0)
		var enemy: Unit = _main._spawn_unit(1 - side, "ashe", Vector2(520, 900), 0.0)
		gwen.configure_carried_active_skill(skill)
		gwen.stun(2.0, &"old_stun")
		gwen.apply_slow(3.0, 0.5, &"old_slow")
		gwen.apply_active_buff(3.0, 1.2, 1.0, 1.0)
		gwen.add_shield(30, 3.0)
		_main._active_skill_effect_system.apply(gwen, skill)
		_expect(not gwen.skill_resource_enabled and gwen.is_stunned() and gwen.control.slow_timer > 0.0 and gwen.active_buff_timer > 0.0, "圣霭不启用Q充能、不清除已有控制减益增益")
		_expect(not enemy._target_is_attackable(gwen), "圈外敌方不能新索敌")
		enemy._target = gwen
		enemy._update_target()
		_expect(enemy._target != gwen, "已有索敌从圣霭目标脱离")
		var hp := gwen.hp
		var shield := gwen.shield_hp
		_expect(not gwen.take_damage(50, enemy) and gwen.hp == hp and gwen.shield_hp == shield, "圈外直接伤害不扣血不耗盾")
		_main._combat.begin_batch(1, "sanctuary")
		var rejected := BattleNumbers.hit(gwen, 50, enemy, enemy.team, enemy.global_position)
		_main._combat.commit_batch()
		_expect(not rejected.accepted and not rejected.landed and gwen.hp == hp and gwen.shield_hp == shield, "批量伤害拒绝也没有命中收益")
		var nova := {"kind": "nova", "radius": 220.0, "damage": 100, "knockback": 80.0, "slow_duration": 5.0, "slow_multiplier": 0.1}
		_main._active_skill_effect_system.apply(enemy, nova)
		_expect(gwen.hp == hp and gwen.shield_hp == shield and gwen._knockback_timer == 0.0 and gwen.control.slow_timer <= 3.0, "圈外圆形技能整组伤害、击退和减速均被阻止")
		_main._active_skill_effect_system.apply_frontal_stun(enemy, {"length": 250.0, "width": 100.0, "damage": 100, "stun_duration": 5.0}, Vector2.LEFT)
		_expect(gwen.hp == hp and gwen.shield_hp == shield and gwen.control.stun_timer <= 2.0, "圈外前方技能不能伤害或刷新控制")
		var tower: Tower = _main._towers[0 if side == 1 else 2]
		var old_tower_position := tower.position
		var old_tower_team := tower.team
		tower.team = 1 - side
		tower.position = gwen.position + Vector2(150, 0)
		_expect(not tower._target_is_valid(gwen), "圈外防御塔不能选取圣霭内格温")
		tower.position = gwen.position + Vector2(120, 0)
		_expect(tower._target_is_valid(gwen), "塔中心进入结界后正常选取")
		tower.position = old_tower_position
		tower.team = old_tower_team
		var context := CombatInteraction.effect_context(enemy)
		gwen.freeze(4.0, &"new_freeze", context)
		gwen.stun(5.0, &"new_stun", context)
		gwen.apply_slow(5.0, 0.1, &"new_slow", context)
		gwen.apply_attack_speed_slow(5.0, 0.1, &"new_attack_slow", context)
		gwen.apply_blind(2, context)
		gwen.apply_knockback(enemy.global_position, 50.0, 0.2, 1.4, [], context)
		_expect(not gwen.is_frozen() and gwen.control.stun_timer <= 2.0 and gwen.control.slow_timer <= 3.0 and gwen._knockback_timer == 0.0, "圈外新增控制与击退入口拒绝，已有计时不刷新")
		# 已附着伤害保留来源并继续消耗现有盾；新的范围脉冲不能借用该标记。
		_expect(gwen.take_damage(10, enemy, enemy.team, enemy.global_position, true) and gwen.shield_hp == 20, "既有附着效果在不可选取期间继续结算")
		gwen.hp -= 40
		gwen.heal(20, CombatInteraction.effect_context(null, side, Vector2.ZERO))
		_expect(gwen.hp == hp - 20, "友方治疗不受不可选取影响")
		gwen.heal(20, context)
		_expect(gwen.hp == hp - 20, "圈外敌方即使提供治疗也不能新增效果")
		enemy.global_position = Vector2(480, 900)
		_expect(enemy._target_is_attackable(gwen) and gwen.take_damage(5, enemy), "敌方中心在120px边界属于圈内，正常选取和命中")
		enemy.global_position.x += 0.01
		_expect(not enemy._target_is_attackable(gwen), "半径外0.01px即受保护，不借用身体半径")
		# 法术来源是水晶；即使落点在结界中心也不能绕过保护。
		_main._spell_system.apply_freeze(Vector2(500, 900), 180.0, 1.0, enemy.team)
		_expect(not gwen.is_frozen(), "圈外法术落点即使范围覆盖也不能新增控制")
		_main._spell_system.apply_freeze(Vector2(360, 900), 20.0, 1.0, enemy.team)
		_expect(not gwen.is_frozen() and gwen.target_protection.active(), "圈外水晶释放的圈内落点法术不能控制格温")
		_main._spell_system.apply_freeze(gwen.position, 20.0, 0.0, enemy.team, 5.0, 0.1)
		_main._spell_system.tick(0.05)
		_expect(gwen.control.slow_timer <= 3.0, "圈内法术区域也不能新增或刷新减速")
		var nexus: Tower = _main._king_player if enemy.team == 0 else _main._king_enemy
		var nexus_position := nexus.position
		nexus.position = gwen.position + Vector2(120, 0)
		_main._spell_system.apply_freeze(gwen.position, 20.0, 1.0, enemy.team)
		_expect(gwen.is_frozen(), "法术释放者水晶中心在结界内时正常施加控制")
		nexus.position = nexus_position
		_main._spell_system.clear()
		gwen.prepare_action_clocks(3.95)
		_expect(gwen.target_protection.active(), "圣霭第79Tick仍有效")
		gwen.prepare_action_clocks(0.05)
		_expect(not gwen.target_protection.active(), "圣霭第80Tick准确结束")
		_main._active_skill_effect_system.apply(gwen, skill)
		gwen.position.x += 60
		gwen.target_protection.check_position(gwen.global_position)
		_expect(gwen.target_protection.center == Vector2(360, 900) and gwen.target_protection.active(), "格温圈内移动不平移结界")
		gwen.position.x = 481
		gwen.on_movement_applied(61, 0.05)
		gwen.position.x = 360
		_expect(not gwen.target_protection.active(), "出圈立即消失，回圈不复活")
		_main._projectile_system.clear_all()
		gwen.target_protection.clear()
		enemy.global_position = Vector2(520, 900)
		_expect(_main._projectile_system.launch(enemy, gwen, 20, 100, 0, 0, Color.WHITE), "开启前能发射追踪弹体")
		_main._active_skill_effect_system.apply(gwen, skill)
		enemy.global_position.x = 420
		_main._projectile_system.tick(0.05)
		_expect(_main._projectile_system.projectiles.is_empty(), "开启后敌人同Tick入圈也不能恢复旧追踪弹体")
		enemy.global_position.x = 420
		_expect(_main._projectile_system.launch(enemy, gwen, 20, 100, 0, 0, Color.WHITE), "敌人进入结界后可发射新的弹体")
		_main._projectile_system.tick(0.05)
		_expect(not _main._projectile_system.projectiles.is_empty(), "圈内来源的在途弹体继续追踪")
		_main._projectile_system.clear_all()
		enemy.position = Vector2(520, 900)
		var arrow := {"damage": 50, "length": 300.0, "projectile_count": 1, "projectile_flight_duration": 1.0, "arc_degrees": 0.0}
		_main._projectile_system.launch_skill_fan(enemy, arrow, Vector2.LEFT)
		var before_hp := gwen.hp
		_main._projectile_system.tick(0.6)
		_expect(gwen.hp == before_hp and not _main._projectile_system.projectiles.is_empty(), "非追踪弹体穿过不可命中目标，不碰撞爆炸或停住")
		_main._projectile_system.clear_all()
		gwen.take_damage(99999)
		_expect(not gwen.target_protection.active(), "死亡清除结界")
		gwen.free()
		enemy.free()
	_main._spell_system.clear()

func _check_mist_cost_and_cooldown() -> void:
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "gwen"
	var choices: Dictionary = _main._active_skill_choices.duplicate(true)
	_main._active_skill_choices["gwen"] = 1
	var gwen: Unit = _main._spawn_unit(0, "gwen", Vector2(360, 1000), 0.0, 0)
	var ability := gwen.active_ability_id
	gwen.move_speed = 0.0
	_main._elixir.elixir = 10
	_expect(_main.use_active_skill(ability, 0) and _main._elixir.elixir == 9.0, "正式请求丝缕缠流扣1金币")
	_main._sim_tick_id += 10
	_main._tick_pending_active_skills(0.05)
	_expect(gwen.target_protection.active() and _main._active_skills.entry(ability).uses_remaining == 1 and _main._active_skills.entry(ability).cooldown_left == 8.0, "开始时消费次数并启动8秒冷却")
	_expect(not _main.use_active_skill(ability, 0) and _main._elixir.elixir == 9.0, "冷却中拒绝请求且不额外扣费")
	gwen.prepare_action_clocks(4.0)
	_main._tick_active_skill_cooldowns(4.0)
	_expect(not gwen.target_protection.active() and not _main.use_active_skill(ability, 0) and _main._elixir.elixir == 9.0, "结界4秒结束时仍需等待4秒冷却且不扣费")
	gwen.prepare_action_clocks(4.0)
	_main._tick_active_skill_cooldowns(4.0)
	_expect(_main.use_active_skill(ability, 0) and _main._elixir.elixir == 8.0, "冷却结束允许第二次且再扣1金币")
	_main._sim_tick_id += 10
	_main._tick_pending_active_skills(0.05)
	_expect(_main._active_skills.entry(ability).uses_remaining == 0 and gwen.target_protection.active(), "第二次结界重新建立并耗尽次数")
	gwen.prepare_action_clocks(4.0)
	_main._tick_active_skill_cooldowns(4.0)
	_main._tick_active_skill_cooldowns(4.0)
	_expect(not _main.use_active_skill(ability, 0) and _main._elixir.elixir == 8.0, "两次后不可继续施放")
	gwen.take_damage(99999)
	gwen.free()
	_main._active_skill_choices = choices
	_main._deck = deck

func _check_mist_audio_lifecycle() -> void:
	var audio: GameAudioManager = _main._audio_manager
	audio.begin_battle()
	var cues: Array[StringName] = []
	var callback := func(card: String, cue: StringName, _position: Vector2):
		if card == "gwen": cues.append(cue)
	audio.cue_played.connect(callback)
	var gwen: Unit = _main._spawn_unit(0, "gwen", Vector2(360, 900), 0.0)
	_main.preview_active_skill(gwen, CardDB.active_skills_for("gwen")[1])
	audio._tick_attached_units()
	var key := audio._sustain_key(gwen.get_instance_id(), &"sanctuary")
	_expect(cues.count(&"hallowed_mist:start") == 1 and cues.count(&"sanctuary:sustain") == 1 and audio._sustain_players.has(key), "Spell2施放音与结界独立持续音各播放一次")
	gwen.freeze(0.5)
	gwen.position.x += 40
	audio._tick_attached_units()
	_expect(audio._sustain_players.has(key) and audio._sustain_players[key].global_position == Vector2(360, 900), "冻结施法与圈内移动不会停止或移动结界音轨")
	gwen.position.x += 90
	gwen.target_protection.check_position(gwen.position)
	audio._tick_attached_units()
	audio._tick_attached_units()
	_expect(not audio._sustain_players.has(key) and cues.count(&"sanctuary:end") == 1, "出圈停止结界长音并只播放一次原版解除音")
	_main._active_skill_effect_system.apply(gwen, CardDB.active_skills_for("gwen")[1])
	audio._tick_attached_units()
	gwen.prepare_action_clocks(4.0)
	audio._tick_attached_units()
	_expect(not audio._sustain_players.has(key) and cues.count(&"sanctuary:end") == 2, "自然到期停止结界音轨")
	_main._active_skill_effect_system.apply(gwen, CardDB.active_skills_for("gwen")[1])
	audio._tick_attached_units()
	gwen.take_damage(99999)
	_expect(not audio._sustain_players.has(key), "死亡同步清理结界音轨")
	audio.cue_played.disconnect(callback)
	gwen.free()
	audio.begin_battle()
