extends "res://tests/suites/battle_suite.gd"
## 权威冲撞边界：不靠动画帧推进，也不只测试字段存在。
var units: Array[Unit] = []

class LaunchContext extends BattleContext:
	var blocked := true
	func is_ground_position_walkable(_position: Vector2, _radius: float, _excluded: Node = null) -> bool:
		return not blocked
	func is_ground_segment_walkable(_from: Vector2, _to: Vector2, _radius: float, _excluded: Node = null) -> bool:
		return not blocked
	func find_ground_path(_from: Vector2, goal: Vector2, _target: Node2D, _radius: float) -> PackedVector2Array:
		return PackedVector2Array([goal]) if not blocked else PackedVector2Array()

func spawn(id: String, team: int, point: Vector2) -> Unit:
	var unit: Unit = _main._spawn_unit(team, id, point, 0.0)
	units.append(unit)
	return unit

func view_for(unit: Unit) -> UnitModel3D:
	if _main._battle_presentation == null:
		return null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			return child as UnitModel3D
	return null

func structure(point: Vector2) -> Unit:
	var unit := Unit.new()
	unit.setup(1, CardDB.training_dummy_stats(), "dummy")
	unit.position = point
	unit.battle_context = _main.battle_context
	_main.add_child(unit)
	units.append(unit)
	return unit

func step(source: Unit, count: int = 1) -> void:
	for tick in count:
		_main._combat.begin_batch(tick, "rush_test")
		source.sim_tick(0.05)
		_main._combat.commit_batch()
		_main._movement.tick(0.05)

func clear_units() -> void:
	for c in _main.get_tree().get_nodes_in_group("combatants"):
		if c is Unit: c.free()
	units.clear()

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_failed_launch_search()
	for tower in main._towers: tower.can_attack = false
	var deployed: Unit = main._spawn_unit(0, "rift_herald", Vector2(360, 1050), 3.0)
	units.append(deployed)
	step(deployed, 59)
	_expect(deployed._deploy_timer > 0.0 and deployed.position.is_equal_approx(Vector2(360, 1050)), "先锋部署前2.95秒不能移动")
	step(deployed)
	_expect(deployed._deploy_timer <= 0.00001 and deployed.deploy_time == 3.0, "先锋部署3秒结束")
	clear_units()
	var source := spawn("rift_herald", 0, Vector2(360, 950))
	_expect(not source.is_active_skill_rush_locked() and (source.get_action_permissions_visual() & 2) != 0, "首次进入准备前的普通 READY 保留先锋主动技能权限")
	var building := structure(Vector2(360, 760))
	var enemy_left := spawn("melee_minion", 1, Vector2(345, 850))
	var enemy_right := spawn("melee_minion", 1, Vector2(375, 850))
	var ally := spawn("melee_minion", 0, Vector2(365, 870))
	var air := spawn("pix", 1, Vector2(360, 865))
	step(source)
	_expect(source.structure_rush.phase == StructureRushState.Phase.PREPARING, "进入建筑冲撞范围先停下准备")
	var rush_view := view_for(source)
	var preparation_visual_started := false
	var preparation_visual_cancelled := false
	var preparation_visual_restarted := false
	var no_rift_herald_stun_visual := false
	if rush_view != null:
		rush_view._sync_visual(false, 0.0)
		preparation_visual_started = (
			rush_view._animation_player.current_animation == "Dash_Windup"
			and is_zero_approx(rush_view._animation_player.current_animation_position)
		)
		rush_view._animation_player.advance(0.7)
	var start := source.position
	var audio: GameAudioManager = main._audio_manager
	var cues: Array[StringName] = []
	var on_cue := func(id: String, cue: StringName, _position: Vector2):
		if id == "rift_herald": cues.append(cue)
	audio.cue_played.connect(on_cue)
	audio._process(0.0)
	var audio_key := audio._sustain_key(source.get_instance_id())
	_expect(audio._sustain_players.has(audio_key), "准备动作启动准备持续声")
	source.apply_knockback(start + Vector2.UP, 40, 0.2)
	audio._process(0.0)
	if rush_view != null:
		rush_view._process(0.0)
		preparation_visual_cancelled = (
			not rush_view._playing_visual_action
			and rush_view._action_sequence.current().is_empty()
			and rush_view._active_visual_action == &""
		)
	_expect(source.structure_rush.phase == StructureRushState.Phase.READY and source.structure_rush.awaiting_reprepare and source.is_active_skill_rush_locked() and source.get_visual_action_time_left() == 0.0 and not audio._sustain_players.has(audio_key), "击退立即打断准备动作和声音，保留冲撞机会但继续锁定主动技能")
	step(source, 5)
	_expect(source.position.y > start.y and source._knockback_timer <= 0.00001, "准备中的先锋实际接受击退位移")
	step(source)
	if rush_view != null:
		rush_view._sync_visual(false, 0.0)
		preparation_visual_restarted = (
			rush_view._animation_player.current_animation == "Dash_Windup"
			and is_zero_approx(rush_view._animation_player.current_animation_position)
			and rush_view._action_sequence.index == 0
		)
	_expect(preparation_visual_started and preparation_visual_cancelled and preparation_visual_restarted, "准备取消清理旧序列，新一轮同名动作按 Dash_Windup 片段起点重播")
	audio._process(0.0)
	_expect(source.structure_rush.phase == StructureRushState.Phase.PREPARING and source.structure_rush.remaining == 2.5 and audio._sustain_players.has(audio_key), "击退结束按新位置重新完整准备和重播音频")
	source.freeze(0.15)
	audio._process(0.0)
	_expect(not audio._sustain_players.has(audio_key) and source.get_visual_action_time_left() == 0.0, "冰冻打断准备音频而非仅暂停")
	step(source, 4)
	_expect(source.structure_rush.phase == StructureRushState.Phase.PREPARING and source.structure_rush.remaining >= 2.4, "冻结结束后重新完整准备")
	audio._process(0.0)
	_expect(audio._sustain_players.has(audio_key), "冰冻解除后的准备声音从头重播")
	source.stun(0.1)
	audio._process(0.0)
	var control_restart_audio := false
	if rush_view != null:
		rush_view._process(0.0)
		no_rift_herald_stun_visual = rush_view._first_valid_animation("stun_loop") == &""
		# 只让表现层看到新的同名动作序号，跳过中间取消快照；控制覆盖仍保持当前姿势。
		var prepare_sustain_cues_before_restart := cues.count(&"rush_prepare:sustain")
		source.play_visual_action(&"", 0.0)
		source.play_visual_action(&"rush_prepare", 2.5)
		audio._process(0.0)
		rush_view._process(0.0)
		source.control.stun_timer = 0.0
		rush_view._process(0.0)
		var restart_audio_started := audio._sustain_players.has(audio_key) and cues.count(&"rush_prepare:sustain") == prepare_sustain_cues_before_restart + 1
		control_restart_audio = restart_audio_started
	var control_restart_visual := rush_view != null and (
		rush_view._animation_player.current_animation == "Dash_Windup"
		and is_zero_approx(rush_view._animation_player.current_animation_position)
		and rush_view._action_sequence.index == 0
		and rush_view._saved_control_action_serial == -1
	)
	_expect(audio._sustain_players.has(audio_key) and source.get_visual_action_time_left() > 0.0 and control_restart_visual and control_restart_audio and no_rift_herald_stun_visual, "先锋眩晕无专用 Stun 映射；取消旧动作后即使跳过取消帧也不恢复旧序列，准备从起点重启且准备音按新序号重播")
	# 让权威模拟保留原有“控制结束边界”Tick；上面的 0 只用于表现层断帧验证。
	source.control.stun_timer = Unit.SIM_DT * 2.0
	step(source, 3)
	_expect(source.structure_rush.remaining >= 2.4, "眩晕同样重置准备时间")
	step(source, 49)
	_expect(source.structure_rush.phase == StructureRushState.Phase.PREPARING, "准备不能提前进入冲撞")
	step(source)
	_expect(source.structure_rush.phase == StructureRushState.Phase.DASHING and source.is_active_skill_rush_locked() and source.get_action_permissions_visual() == 0, "准备满2.5秒开始冲撞且主动技能继续锁定")
	source.freeze(5); source.stun(5); source.apply_slow(5, 0.2); source.apply_attack_speed_slow(5, 0.2); source.apply_blind(2)
	source.apply_knockback(source.position + Vector2.UP, 100, 0.3)
	_expect(not source.is_frozen() and not source.is_stunned() and source.control.slow_timer == 0 and source.control.attack_speed_slow_timer == 0 and source.blind_attack_charges == 0 and source._knockback_timer == 0, "冲撞期间拒绝全部现有控制")
	var before := building.hp
	source.hp = 1000
	source.add_shield(200, 10)
	step(source, 12)
	_expect(cues.count(&"rush:hit") == 1 and not cues.has(&"attack_hit") and not cues.has(&"spinning_punch:hit"), "建筑冲撞只发一次冲撞命中声，不串普攻或技能")
	_expect(source.structure_rush.phase == StructureRushState.Phase.RECOVERY and source.is_active_skill_rush_locked() and source.get_visual_action_name() == &"rush_hit" and is_equal_approx(source.get_visual_action_duration(), 0.65), "成功撞击继续使用 Dash_Hit，0.65秒恢复仍锁定先锋主动技能")
	_expect(building.hp == before - 500, "冲撞建筑只结算一次500点伤害")
	_expect(source.hp == 700 and source.shield_hp == 200, "撞击扣当前生命30%，护盾不能抵消")
	_expect(enemy_left.hp == 110 and enemy_right.hp == 110, "路径上的每只地面敌军只受一次100伤害")
	_expect(enemy_left._knockback_velocity.x < 0 and enemy_right._knockback_velocity.x > 0, "路径两边的敌軍侧向挤开")
	_expect(ally.hp == 210 and air.hp == air.max_hp, "路径伤害排除友军和空军")
	var mites: Array = main.get_tree().get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.card_id == "voidmite")
	_expect(mites.all(func(c): return c._knockback_velocity.dot(-source.structure_rush.direction) > 0.0), "蠕虫从碰撞点朝建筑外侧爆出，不向塔内推出")
	_expect(mites.size() == 6, "撞击爆发恰好六只虚空蠕虫")
	_expect(mites.all(func(c): return c.hp == 135 and c.damage == CardDB.PRINCESS_TOWER_STATS.damage and c.building_only and c.team == 0 and c.is_walkable_at(c.position)), "蠕虫使用135生命/防御塔单次伤害且生成位置合法")
	step(source, 16)
	_expect(source.structure_rush.phase == StructureRushState.Phase.SPENT, "冲撞后恢复普攻且终身不再充能")
	_expect(not source._target_is_attackable(enemy_left), "先锋普通索敌无视敌军")
	clear_units()
	# 起冲后插入建筑：截停于第一座建筑，完整结算撞击，后排不受穿透伤害。
	for blocker_team in [1, 0]:
		source = spawn("rift_herald", 0, Vector2(360, 950))
		building = structure(Vector2(360, 720))
		step(source, 51)
		_expect(source.structure_rush.phase == StructureRushState.Phase.DASHING, "拦截建筑在起冲以后出现")
		var blocker := structure(Vector2(360, 845))
		blocker.team = blocker_team
		var rear_hp := building.hp
		var blocker_hp := blocker.hp
		source.hp = 1000
		step(source, 12)
		_expect(building.hp == rear_hp, "冲撞不能穿透挡路建筑伤害原目标")
		_expect(source.position.y >= blocker.position.y + blocker.body_radius + source.body_radius, "先锋停在拦截建筑表面之外")
		var summons := main.get_tree().get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.card_id == "voidmite")
		_expect(blocker.hp == blocker_hp - (500 if blocker_team == 1 else 0), "挡路敌方建筑承受撞击，友方不受伤")
		_expect(source.hp == (700 if blocker_team == 1 else 1000) and summons.size() == (6 if blocker_team == 1 else 0), "拦截敌方建筑完整自伤与孵化，友方只截停")
		step(source, 15)
		_expect(source.structure_rush.phase == StructureRushState.Phase.SPENT, "被建筑截停仍消耗一生一次冲撞")
		clear_units()
	# 部署前0.45秒外抛，后0.55秒停留完成孵化，不提前攻击。
	var mite := spawn("voidmite", 0, Vector2(360, 950))
	mite._deploy_timer = 1.0
	mite.apply_knockback(mite.position + Vector2.UP, 100, 0.45, 1.0)
	step(mite, 9)
	var landing := mite.position
	_expect(is_equal_approx(landing.y, 1050.0) and mite._deploy_timer > 0.5, "蠕虫前0.45秒外抛100px并仍处于部署")
	step(mite, 10)
	_expect(mite.position.distance_to(landing) < 0.01 and mite._deploy_timer > 0.0 and not mite._attacking, "落地后至0.95秒原地完成孵化，不继续外抛或攻击")
	step(mite)
	_expect(mite._deploy_timer == 0.0 and mite.attack_interval == 1.33 and mite.body_radius == CardDB.RADIUS_SMALL, "蠕虫1秒部署、1.33秒攻击周期、小体型半径")
	clear_units()
	# 隔河中央目标进入距离也不能直接撞水；桥中心的同样距离可以冲撞。
	for x in [360.0, ArenaRules.BRIDGE_X_LEFT]:
		source = spawn("rift_herald", 0, Vector2(x, 720))
		building = structure(Vector2(x, 560))
		step(source)
		_expect((source.structure_rush.phase == StructureRushState.Phase.PREPARING) == (x == ArenaRules.BRIDGE_X_LEFT), "冲撞路径水域禁止、桥面允许 x=%s" % x)
		if x == 360.0:
			var got_rush := false
			for tick in 500:
				step(source)
				_expect(main._is_ground_terrain_walkable(source.position, source.body_radius), "绕桥每步不进河水")
				if source.structure_rush.phase == StructureRushState.Phase.PREPARING:
					got_rush = true
					break
			_expect(got_rush, "隔河目标会绕桥走到合法位置再准备冲撞")
		clear_units()
	# 目标在准备期间死亡不消耗首次机会；冲撞已开始则不会重新获得第二次。
	source = spawn("rift_herald", 0, Vector2(360, 950))
	building = structure(Vector2(360, 760))
	step(source)
	building.hp = 0
	step(source)
	_expect(source.structure_rush.phase == StructureRushState.Phase.READY and not source.structure_rush.awaiting_reprepare and not source.is_active_skill_rush_locked(), "准备中目标失效退出本轮等待并恢复普通 READY 权限")
	building.hp = 10000
	step(source, 51)
	building.hp = 0
	step(source)
	_expect(source.structure_rush.phase == StructureRushState.Phase.RECOVERY, "冲撞中目标死亡取消且消耗首次机会")
	_expect(source.is_active_skill_rush_locked(), "空撞进入恢复时同样锁定先锋主动技能")
	_expect(main.get_tree().get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.card_id == "voidmite").is_empty(), "没有撞中建筑不召唤")
	clear_units()
	for simultaneous in [false, true]:
		source = spawn("rift_herald", 0, Vector2(360, 950))
		building = structure(Vector2(360, 760))
		step(source, 51)
		_expect(source.structure_rush.phase == StructureRushState.Phase.DASHING, "死亡测试已经消耗首次冲撞机会")
		if simultaneous:
			main._combat.begin_batch(999, "rush_death")
			source.structure_rush._impact(source)
			BattleNumbers.hit(source, 100000, building, 1, building.position)
			main._combat.commit_batch()
		else:
			source.take_damage(100000)
			step(source, 10)
		_expect(source.structure_rush.phase != StructureRushState.Phase.READY and source.hp <= 0, "冲撞死亡不返还次数")
		_expect(main.get_tree().get_nodes_in_group("combatants").filter(func(c): return c is Unit and c.card_id == "voidmite").is_empty(), "冲撞途中或同批撞击死亡均不孵化")
		clear_units()
	# 技能只命中前方半圆；180度是允许边界，181度仍拒绝。
	source = spawn("rift_herald", 0, Vector2(360, 950))
	_expect(source.attack_interval == 2.0 and source.first_hit_time == 0.5, "普攻2秒，原始25%前摇映射为0.50秒")
	cues.clear()
	source.play_visual_action(&"spinning_punch", 3.0)
	audio._process(0.0)
	_expect(cues.is_empty(), "旋转拳起手不提前启动第11帧吼声")
	source._visual_action_time_left = 2.70
	audio._process(0.0)
	_expect(cues.is_empty(), "0.30秒还未到吼声节点")
	source._visual_action_time_left = 2.69
	audio._process(0.0)
	_expect(cues == [&"spinning_punch:start"], "0.31秒映射第11帧吼声")
	source._visual_action_time_left = 2.14
	audio._process(0.0)
	_expect(cues.size() == 1, "0.86秒不提前播放第31帧释放声")
	source._visual_action_time_left = 2.13
	audio._process(0.0)
	audio._process(0.0)
	audio.play_event(source, &"spinning_punch:release", source.position)
	_expect(cues == [&"spinning_punch:start", &"spinning_punch:release"], "0.87秒播放释放声，重复帧和伤害节点通知不双播")
	source.play_visual_action(&"spinning_punch", 3.0)
	audio._process(0.0)
	source.play_visual_action(&"", 0.0)
	audio._process(0.0)
	_expect(cues.size() == 2, "取消动作不会留下定时声音")
	cues.clear()
	source.play_visual_action(&"spinning_punch", 3.0)
	audio._process(0.0)
	source._visual_action_time_left = 2.69
	source.freeze(0.5)
	audio._process(0.0)
	_expect(cues.is_empty(), "控制期间不启动动作定时音")
	source.control.frozen_timer = 0.0
	audio._process(0.0)
	_expect(cues == [&"spinning_punch:start"], "控制解除后按动作进度启动声音")
	source._visual_action_time_left = 2.75
	audio._process(0.0)
	source._visual_action_time_left = 2.69
	audio._process(0.0)
	_expect(cues.size() == 1, "同序号进度回调不重播已播放节点")
	source.play_visual_action(&"spinning_punch", 3.0)
	source._visual_action_time_left = 1.0
	cues.clear()
	audio._process(0.0)
	_expect(cues.is_empty(), "晚到动作不补播已过的吼声和释放声")
	source.play_visual_action(&"", 0.0)
	var skill_timing: Dictionary = CardDB.active_skills_for("rift_herald")[0]
	_expect(skill_timing.damage == 210 and skill_timing.impact_delay == 1.57 and skill_timing.cast_duration == 3.0, "旋转拳3秒/1.57秒命中/210伤害")
	var front := spawn("melee_minion", 1, Vector2(360, 860))
	var back := spawn("melee_minion", 1, Vector2(360, 1010))
	cues.clear()
	main._active_skill_effect_system.apply_frontal(source, CardDB.active_skills_for("rift_herald")[0], Vector2.UP)
	_expect(cues == [&"spinning_punch:hit"], "旋转拳命中只播技能命中声，无额外释放声或普攻命中声")
	_expect(front.hp == 0 and back.hp == 210, "旋转拳前方210伤害，背后不命中")
	front.position = Vector2(600, 1050)
	cues.clear()
	main._active_skill_effect_system.apply_frontal(source, CardDB.active_skills_for("rift_herald")[0], Vector2.UP)
	_expect(cues.is_empty(), "旋转拳空挥不播放命中声或额外释放声")
	audio.cue_played.disconnect(on_cue)
	clear_units()
	var invalid := CardDB.all().duplicate(true)
	invalid.rift_herald.rush_speed = "fast"
	_expect(not CardDB.VALIDATOR.validate_all(invalid).is_empty(), "冲撞字段拒绝错误类型")
	invalid = CardDB.all().duplicate(true)
	invalid.rift_herald.rush_self_health_ratio = 1.0
	_expect(not CardDB.VALIDATOR.validate_all(invalid).is_empty(), "冲撞自伤比例拒绝100%")
	invalid = CardDB.all().duplicate(true)
	invalid.rift_herald.rush_spawn_id = "missing"
	_expect(not CardDB.VALIDATOR.validate_all(invalid).is_empty(), "冲撞召唤引用必须存在")

	invalid = CardDB.all().duplicate(true)
	invalid.rift_herald.audio.events["spinning_punch:start"].action_time = 3.5
	_expect(not CardDB.VALIDATOR.validate_all(invalid).is_empty(), "动作音节点不能超出施法窗口")
	invalid = CardDB.all().duplicate(true)
	invalid.rift_herald.audio.events["spinning_punch:hit"].action_time = 1.0
	_expect(not CardDB.VALIDATOR.validate_all(invalid).is_empty(), "真实命中声不能改为定时伪命中")

func _check_failed_launch_search() -> void:
	var source := spawn("rift_herald", 0, Vector2(360, 950))
	var goal := structure(Vector2(360, 760))
	var context := LaunchContext.new(_main)
	source.battle_context = context
	var rush := source.structure_rush
	rush.target = goal
	source._path = PackedVector2Array([Vector2(100, 100)])
	for tick in 80: rush._approach_launch_point(source, 0.05)
	_expect(rush.search_count == 10 and source._path.is_empty(), "失败起点搜索4秒只执行10次，清除旧路径")
	var replacement := structure(Vector2(400, 760))
	rush.target = replacement
	rush._approach_launch_point(source, 0.05)
	_expect(rush.search_count == 11, "更换目标立即重新判断，不受失败冷却阻挡")
	context.blocked = false
	_main.nav.set_cells_blocked([Vector2i(0, 0)], true)
	rush._approach_launch_point(source, 0.05)
	_expect(rush.search_count == 12 and not source._path.is_empty() and source._path_target == replacement, "建筑阻挡变化立即重搜，恢复可达后持有新目标路线")
	_main.nav.set_cells_blocked([Vector2i(0, 0)], false)
	rush._approach_launch_point(source, 0.05)
	_expect(rush.search_count == 13, "建筑移除也使失败/成功结果失效")
	clear_units()
