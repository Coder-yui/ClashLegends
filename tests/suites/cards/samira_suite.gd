extends "res://tests/suites/battle_suite.gd"
func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	_expect(is_equal_approx(preload("res://scripts/presentation/samira_projectile_effect_3d.gd").BULLET_SCALE, 0.0102), "原版弹体采用源骨骼到用户GLB的0.0085比例乘模型1.2")
	for gap in [63.9, 64.0, 64.1]:
		var actor := _spawn_ready_unit("samira", 0, Vector2(300, 950))
		var victim := _spawn_ready_unit("target_dummy", 1, Vector2.ZERO)
		victim.position = actor.position + Vector2(actor.body_radius + victim.body_radius + gap, 0.0)
		actor.move_speed = 0.0
		actor.sim_tick(0.05)
		_expect(actor.close_attack == (gap <= 64.0), "1.6格按身体表面间距选择近战：%.1f" % gap)
		actor.free()
		victim.free()
	for field in ["attack_stance_duration", "attack_idle"]:
		var bad: Dictionary = CardDB.get_card("samira").duplicate(true)
		bad.visual_animations[field] = -1.0 if field == "attack_stance_duration" else ["Idle_Gun_anm"]
		_expect(not CardDB.VALIDATOR.validate_all({"samira":bad}, false).is_empty(), "持械配置拒绝非法时长/动作段数：" + field)
	for index in [-1, 4, 0.5]:
		var bad: Dictionary = CardDB.get_card("samira").duplicate(true)
		bad.visual_animations.transitions["Spell4>move"].attack_stance_index = index
		_expect(not CardDB.VALIDATOR.validate_all({"samira":bad}, false).is_empty(), "R结束姿态拒绝非法攻击段索引")
	var skill: Dictionary = CardDB.active_skills_for("samira")[0]
	_expect(skill.radius == 180.0 and is_equal_approx(preload("res://assets/effects/samira/player.gd").NATIVE_SCALE * 600.0 * ArenaRules.TILE_SIZE, skill.radius), "R指定180像素半径与原生600单位的特效缩放一致")
	var unit := _spawn_ready_unit("samira", 0, Vector2(300, 950))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(430, 950))
	unit.configure_carried_active_skill(skill)
	_expect(not unit.can_start_active_skill(skill), "零评分不能施法")
	var roster := ActiveSkillRoster.new()
	unit.active_ability_id = 901
	unit.active_ability_slot = 0
	roster.register(unit, "samira", 0, skill)
	var allowed := func(_team, _card): return true
	_expect(not roster.qualified(901, 0, allowed), "不足评分不能请求入队或扣费")

	unit._target = target
	unit._attacking = true
	unit._attack(0.05)
	_expect(_main._projectile_system.projectiles.size() == 1 and unit.skill_resource_value == 0.0 and is_equal_approx(unit.attack_timeline.cooldown, 1.4), "远程1.4秒间隔出手生成弹体且不提前评分")
	unit.close_attack = true
	var before := target.hp
	for tick in 10: _main._projectile_system.tick(0.05)
	_expect(target.hp == before - 72.0 and unit.skill_resource_value == 1.0, "切换近战后旧子弹仍造成72伤害、仅得1分")
	target.position = Vector2(340, 950)
	unit.attack_timeline.cancel(true)
	unit._attack_visual_pending = true
	unit._attack(0.05)
	_expect(target.hp == before - 180.0 and unit.skill_resource_value == 3.0, "近战108伤害并得2分")
	_expect(posmod(unit.get_attack_visual_serial() - 1, 4) >= 2 and is_equal_approx(unit.attack_timeline.cooldown, 1.0), "近战动作槽和1秒攻击间隔发布")
	unit.on_attack_landed(0, 10.0, -1, -1, 2.0)
	_expect(unit.skill_resource_value == 5.0 and unit.can_start_active_skill(skill), "评分封顶5并解锁技能")
	_expect(roster.qualified(901, 0, allowed), "满评分满足主动资格")
	roster.consume(901)
	roster.tick(5.0)
	_expect(roster.qualified(901, 0, allowed) and roster.entry(901).uses_remaining == 0, "不限次数技能次数为零仍可再用")
	var snapshots := NetworkSnapshotSystem.new(_main, _main._projectile_system)
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload: Array = fixture.snapshot_payload(snapshots, 901, unit)
	var packet: Array = fixture.packet(snapshots, [payload], [], fixture.tower_payloads(snapshots), 0.0, 180.0, false)
	var decoded = snapshots.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
	_expect(decoded != null and payload[NetworkSnapshotSystem.U_ATTACK_SERIAL] == unit.get_attack_visual_serial() and payload[NetworkSnapshotSystem.U_SKILL_RESOURCE_RATIO] == 1.0, "枪刀动作槽与满评分通过现有压缩快照")
	var previous_mode: String = _main.runtime.mode
	_main.runtime.mode = "client"
	unit.net_skill_resource_enabled = true
	unit.net_skill_resource_ratio = 0.8
	_expect(not unit.has_required_skill_resource(skill), "客户端按复制评分禁用不足分技能")
	unit.net_skill_resource_ratio = 1.0
	_expect(unit.has_required_skill_resource(skill), "客户端满分复制状态解锁按钮")
	_main.runtime.mode = previous_mode
	var prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(unit, skill)
	_expect(unit.skill_resource_value == 0.0, "施法开始清空评分")
	unit.begin_active_skill_cast(2.0, Vector2.UP, skill.cast_locks)
	unit.play_visual_action(&"inferno", 2.0)
	unit.on_attack_landed(0, 72.0, -1, -1, 1.0)
	_expect(unit.skill_resource_value == 0.0 and not unit.is_active_skill_movement_locked() and unit.is_active_skill_attack_locked(), "施法期间在途命中不充能、允许移动但锁普攻")
	_main._active_skill_effect_system.apply(unit, prepared)
	var air := _spawn_ready_unit("target_dummy", 1, Vector2(300, 850))
	air.is_air = true
	var outside := _spawn_ready_unit("target_dummy", 1, Vector2(620, 950))
	before = target.hp
	var air_before := air.hp
	var outside_before := outside.hp
	for tick in 3: _main._active_skill_effect_system.tick_effects(0.05)
	_expect(target.hp == before, "0.2秒前不提前脉冲")
	_main._active_skill_effect_system.tick_effects(0.05)
	_expect(target.hp == before - 24.0 and air.hp == air_before - 24.0 and outside.hp == outside_before, "首脉冲对地对空并排除圈外")
	for tick in 36: _main._active_skill_effect_system.tick_effects(0.05)
	_expect(target.hp == before - 240.0 and air.hp == air_before - 240.0 and _main._active_skill_effect_system.continuous_area_effects.is_empty(), "2秒十次脉冲总240伤害并结束")
	_expect(unit.skill_resource_value == 0.0, "R伤害不积累评分")
	unit.clear_carried_active_skill_resource()
	unit.on_attack_landed(0, 10.0, -1, -1, 2.0)
	_expect(unit.skill_resource_value == 0.0, "施法窗口中即使移除主动也不能叠被动")
	var invalid: Dictionary = CardDB.get_card("samira").duplicate(true)
	invalid.close_attack_range = invalid.range + 1.0
	_expect(not CardDB.VALIDATOR.validate_all({"samira": invalid}, false).is_empty(), "拒绝近战范围大于远程")
	invalid = CardDB.get_card("samira").duplicate(true)
	invalid.visual_animations.attack = "Attack1_Gun_Start_anm"
	_expect(not CardDB.VALIDATOR.validate_all({"samira": invalid}, false).is_empty(), "单字符串攻击配置安全拒绝而非类型崩溃")
	invalid = CardDB.get_card("samira").duplicate(true)
	invalid.erase("close_attack_range")
	_expect(not CardDB.VALIDATOR.validate_all({"samira": invalid}, false).is_empty(), "拒绝没有距离启用条件的近战倍率")
	_main._projectile_system.clear_all()
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit: actor.free()
	unit = _spawn_ready_unit("samira", 0, Vector2(300, 950))
	target = _spawn_ready_unit("target_dummy", 1, Vector2(340, 950))
	unit.configure_carried_active_skill(skill)
	unit.sim_tick(0.05)
	_expect(unit.close_attack, "正式行动按目标间距选择近战")
	target.position = Vector2(450, 950)
	for tick in 6: unit.sim_tick(0.05)
	_expect(unit.skill_resource_value == 0.0, "近战前摇中目标离开不能隔空命中")
	unit._attacking = false
	unit.attack_timeline.cancel(true)
	unit._attack_visual_pending = true
	unit.sim_tick(0.05)
	_expect(not unit.close_attack, "重新起手按远距离改回双枪")
	unit.skill_resource_value = 4.0
	_expect(not _main.preview_active_skill(unit, skill) and unit.skill_resource_value == 4.0, "实际施法入口拒绝不足5分且不消费")
	unit.skill_resource_value = 5.0
	_expect(_main.preview_active_skill(unit, skill), "正式施法入口接受满评分")
	var effects = _main._active_skill_effect_system
	_main._sim_step(0.05)
	_expect(not effects.continuous_area_effects.is_empty(), "冰冻前R后段已实际建立")
	unit.freeze(1.0)
	effects.tick_effects(0.2)
	_expect(effects.continuous_area_effects.is_empty(), "冰冻取消跟随施法者的R后段")
	var particles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/samira/cas/sampled.json"))
	var ember_index := -1
	for index in particles.emitters.size():
		if particles.emitters[index].get("source_key", "") == "11.0:0": ember_index = index
	var max_width := 0.0
	var max_count := 0
	if ember_index >= 0:
		for frame in particles.frames:
			max_count = maxi(max_count, frame[ember_index].size())
			for particle in frame[ember_index]: max_width = maxf(max_width, float(particle[4]))
	_expect(ember_index >= 0 and max_count > 1 and max_width > 0.0 and max_width <= 120.01, "R子火星独立采样，宽度不超过源60乘2，不能混入主层655宽度")
	var buff = preload("res://assets/effects/samira/buff.gd").new()
	_main.add_child(buff)
	buff.configure(unit.visual_radius, unit.team)
	var model = preload("res://assets/units/samira/view.gd").new()
	model.unit_ref = weakref(unit)
	buff.bind_model(model)
	var overlay: ShaderMaterial = buff.make_overlay(null)
	unit.play_visual_action(&"inferno", 2.0)
	unit._visual_action_time_left = 1.4
	buff.advance_status(true, true, 0.0)
	_expect(bool(overlay.get_shader_parameter("attached_enabled")) and overlay.get_shader_parameter("p") == PackedFloat32Array(buff._particles._data.frames[buff._particles._frame][1][0]), "R附着层与本帧主粒子同钟，不滞后一帧")
	buff.advance_status(false, false, 0.0)
	_expect(not bool(overlay.get_shader_parameter("attached_enabled")), "R隐藏时同帧关闭角色附着层")
	model.free()
	buff.free()
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit: actor.free()
	unit = _spawn_ready_unit("samira", 0, Vector2(200, 950))
	target = _spawn_ready_unit("target_dummy", 1, Vector2(440, 950))
	unit.configure_carried_active_skill(skill)
	unit.skill_resource_value = 5.0
	_expect(_main.preview_active_skill(unit, skill), "移动R从正式入口开始")
	_expect(is_equal_approx(unit.attack_range + unit.body_radius, 180.0), "移动R导航按技能中心半径而非普攻射程")
	var start := unit.global_position
	var attacks_before := unit.get_attack_visual_serial()
	for tick in 20: _main._sim_step(0.05)
	_expect(unit.position.x > start.x + 15.0 and unit.global_position.distance_to(target.global_position) <= 180.0 + target.body_radius, "R向圈外目标移动直至进入技能范围")
	_expect(unit.get_attack_visual_serial() == attacks_before and unit.skill_resource_value == 0.0, "移动R不偷普攻且不积累评分")
	var settled := unit.global_position
	for tick in 3: _main._sim_step(0.05)
	_expect(unit.global_position.distance_to(settled) < 0.1, "目标在R范围内停止追赶")
	target.position.x += 90.0
	for tick in 4: _main._sim_step(0.05)
	_expect(unit.position.x > settled.x, "目标离开R范围后继续追赶")
	target.free()
	var march_start := unit.global_position
	for tick in 5: _main._sim_step(0.05)
	_expect(unit._target is Tower and unit.global_position.y < march_start.y - 1.0, "R无附近敌军时恢复向敌塔正常推进")
	_expect(unit.active_skill_cast_timer > 0.0 and unit.get_attack_visual_serial() == attacks_before, "无目标推进保持R施法且不普攻")
	unit.freeze(1.0)
	_expect(is_equal_approx(unit.attack_range, 165.0), "取消R恢复基础射程")
	for actor in _main.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit: actor.free()
	for segment in 4:
		unit = _spawn_ready_unit("samira", 0, Vector2(360, 900))
		target = _spawn_ready_unit("target_dummy", 1, unit.position + Vector2(130.0 if segment < 2 else 50.0, 0.0))
		target.lifespan_hp_decay = false
		target.max_hp = 10000.0
		target.hp = 10000.0
		unit.move_speed = 0.0
		unit._attack_swing_count = segment % 2
		var releases: Array[int] = []
		var hits: Array[int] = []
		var last_swing := unit._attack_swing_count
		var last_hp := target.hp
		for tick in 65:
			_main._sim_step(0.05)
			if unit._attack_swing_count != last_swing:
				releases.append(tick)
				last_swing = unit._attack_swing_count
			if target.hp != last_hp:
				hits.append(tick)
				last_hp = target.hp
		_expect(releases.size() >= 2 and releases[0] == (4 if segment < 2 else 3), "动作%d首次节点落在远程第5/近战第4个Tick" % segment)
		_expect(releases.size() >= 2 and releases[1] - releases[0] == (28 if segment < 2 else 20), "动作%d保持1.4秒/1秒实际攻击间隔" % segment)
		_expect(not hits.is_empty() and (hits[0] > releases[0] if segment < 2 else hits[0] == releases[0]), "动作%d区分远程出弹后命中与近战即时命中" % segment)
		unit.free()
		target.free()
		_main._projectile_system.clear_all()
	unit = _spawn_ready_unit("samira", 0, Vector2(360, 950))
	unit.can_attack = false
	unit.move_speed = 0.0
	_expect(unit.skill_resource_enabled and unit.skill_resource_max == 5.0, "普通槽出生即拥有悍勇本色")
	unit.on_attack_landed(0, 72.0, -1, -1, 1.0)
	_expect(unit.skill_resource_value == 1.0 and is_equal_approx(unit._effective_movement_multiplier(), 1.05), "远程命中1层加5%移速")
	for tick in 60: _main._sim_step(0.05)
	unit.on_attack_landed(0, 108.0, -1, -1, 2.0)
	_expect(unit.skill_resource_value == 3.0 and is_equal_approx(unit._effective_movement_multiplier(), 1.15) and is_equal_approx(unit.skill_resource_time_left, 4.0), "近战叠2层并刷新整组4秒")
	for tick in 79: _main._sim_step(0.05)
	_expect(unit.skill_resource_value == 3.0, "刷新后3.95秒仍持有层数")
	_main._sim_step(0.05)
	_expect(unit.skill_resource_value == 0.0 and is_equal_approx(unit._effective_movement_multiplier(), 1.0), "4秒边界全部层数和移速同时到期")
	unit.add_skill_resource(5.0)
	_expect(unit.skill_resource_value == 5.0 and is_equal_approx(unit._effective_movement_multiplier(), 1.3), "满层改为30%而非25%或55%")
	unit._tick_skill_resource_decay(3.5)
	unit.add_skill_resource(1.0)
	unit.clear_carried_active_skill_resource()
	_expect(unit.skill_resource_value == 5.0 and unit.skill_resource_time_left == 4.0 and unit.skill_resource_enabled, "满层命中刷新时间且移除主动保留被动")
	unit.configure_carried_active_skill(skill)
	_expect(_main.preview_active_skill(unit, skill) and unit.skill_resource_value == 0.0 and is_equal_approx(unit._effective_movement_multiplier(), 1.0), "大招消耗被动全部层数和移速")
	unit.add_skill_resource(2.0)
	_expect(unit.skill_resource_value == 0.0 and unit.skill_resource_time_left == 0.0, "大招期间不叠层也不刷新期限")
	for field in ["skill_resource_duration", "skill_resource_move_per_stack", "skill_resource_full_move_bonus"]:
		invalid = CardDB.get_card("samira").duplicate(true)
		invalid[field] = -1.0
		_expect(not CardDB.VALIDATOR.validate_all({"samira": invalid}, false).is_empty(), "拒绝非法被动字段" + field)
	_main.free()
	_main = null
