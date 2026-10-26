extends "res://tests/suites/battle_suite.gd"
func run(harness: Object) -> void:
	_harness = harness
	_check_trail_history(harness)
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	var unit := _spawn_ready_unit("ekko", 0, Vector2(250, 950))
	_check_optional_visual(unit)
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(290, 950))
	# Exercise the authority's surface-distance acquisition at the new 1.2-tile edge.
	target.position = unit.position + Vector2(unit.body_radius + target.body_radius + 47.9, 0)
	_expect(unit._find_nearest_attackable_in_range() == target, "1.2格内目标可进入攻击范围")
	target.position.x += 0.2
	_expect(unit._find_nearest_attackable_in_range() != target, "超过1.2格目标不提前进入攻击范围")
	target.position = Vector2(290, 950)
	target.max_hp = 10000.0
	target.hp = 10000.0
	var other := _spawn_ready_unit("target_dummy", 1, Vector2(330, 950))
	other.max_hp = 10000.0
	other.hp = 10000.0
	for i in 2:
		unit._deal_attack_damage_to(target, 110.0)
		unit._deal_attack_damage_to(other, 110.0)
	_expect(target.hp == 9780.0 and other.hp == 9780.0, "交替目标分别累计两次普通伤害")
	other.control.hard.apply(&"untargetable", &"test", 1.0, {})
	unit._deal_attack_damage_to(other, 110.0)
	_expect(other.hp == 9780.0 and unit.repeat_hit_bonus(other, 110.0) == 110.0, "拒绝命中不消耗第三击")
	other.control.hard.clear_family(&"untargetable")
	unit._deal_attack_damage_to(target, 110.0)
	_expect(target.hp == 9560.0, "切换回来仍是第三击双倍")
	_expect(is_equal_approx(unit.get_active_speed_multiplier_visual(), 1.8), "第三击获得80%加速")
	unit._tick_active_statuses(3.1)
	unit._deal_attack_damage_to(other, 110.0)
	_expect(other.hp == 9560.0 and is_equal_approx(unit.get_active_speed_multiplier_visual(), 1.8), "第二目标独立触发第三击和加速")
	unit._tick_active_statuses(3.1)
	for i in 6:
		unit._deal_attack_damage_to(target, 110.0)
		unit._deal_attack_damage_to(other, 110.0)
	_expect(target.hp == 8900.0 and other.hp == 8900.0, "每个目标第四至第九击均不再次翻倍")
	_expect(is_equal_approx(unit.get_active_speed_multiplier_visual(), 1.0), "已触发目标不再次刷新加速")
	var second := _spawn_ready_unit("ekko", 0, Vector2(400, 1000))
	for i in 3: second._deal_attack_damage_to(target, 110.0)
	_expect(target.hp == 8460.0, "不同时间刺客各自持有目标计数")
	var animations: Dictionary = CardDB.get_card("ekko").visual_animations
	_expect(animations.attack == ["Attack_P_1", "Attack_P_2", "Attack_P_3"] and animations.attack_hit == animations.attack, "三段普攻及命中续播均使用Attack_P")
	for i in 101:
		unit.position = Vector2(250 + i, 950)
		unit.prepare_action_clocks(0.05)
	_expect(unit._position_history.size() <= 82, "回溯历史有界")
	_expect(unit.historical_position(4.0).distance_to(Vector2(270, 950)) < 0.01, "按20Hz记录精确四秒前位置")
	var skill: Dictionary = CardDB.active_skills_for("ekko")[0]
	unit.configure_carried_active_skill(skill)
	unit.hp = 100.0
	var landing := unit.historical_position(4.0)
	var effects = _main._active_skill_effect_system
	var prepared: Dictionary = effects.prepare_cast(unit, skill)
	var before_damage := target.hp
	effects.apply_cast_start(unit, prepared)
	_expect(unit.hp == unit.max_hp and target.hp == before_damage, "开始回溯即满血，但不提前造成伤害")
	unit.hp = 500.0
	_expect(not CombatInteraction.can_acquire(unit, 1) and not CombatInteraction.allows(unit, target, 1), "回溯期间不能索敌或被外部伤害控制选中")
	_expect(not CombatInteraction.allows_allied_target(unit, 0), "回溯期间不能被友方技能选中")
	unit.position = Vector2(400, 950)
	for i in 15: unit.control.tick_hard_controls(0.05)
	effects.apply(unit, prepared)
	_expect(unit.hp == 500.0 and unit.teleport_serial == 1, "落地不重复治疗，仅发布瞬移与伤害")
	_expect(target.hp < before_damage, "伤害在落地时发生")
	_expect(unit.position.distance_to(landing) < 45.0, "落地使用施法时锁定的历史点并避让占位")
	_expect(CombatInteraction.can_acquire(unit, 1), "落地恢复选中")
	var newborn := _spawn_ready_unit("ekko", 0, Vector2(200, 1050))
	_expect(newborn.historical_position(4.0) == newborn.position, "无历史回到出生位置")
	var roster := ActiveSkillRoster.new()
	unit.active_ability_id = 902
	unit.active_ability_slot = 0
	roster.register(unit, "ekko", 0, skill)
	roster.consume(902)
	roster.tick(15.0)
	_expect(not roster.qualified(902, 0, func(_team, _card): return true), "冷却结束仍只有一次使用次数")
	var timed := _spawn_ready_unit("ekko", 0, Vector2(150, 1000))
	timed.configure_carried_active_skill(skill)
	timed.hp = 100.0
	_main._combat.begin_batch(900, "ekko_cast_start")
	_expect(_main._skill_lifecycle.start(timed, skill), "正式施法生命周期成功开始")
	_main._combat.commit_batch()
	_expect(timed.hp == timed.max_hp, "实战批次中回溯不可选中不会拒绝自身满血收益")
	timed.hp -= 10.0
	timed.heal(10.0)
	_expect(timed.hp == timed.max_hp - 10.0, "回溯期间仍拒绝普通外部治疗")
	timed.hp = timed.max_hp
	timed.freeze(1.0, &"test", CombatInteraction.effect_context(target))
	_expect(not timed.is_frozen(), "回溯拒绝敌方冰冻")
	for i in 14:
		timed._tick_active_statuses(0.05)
		timed.prepare_action_clocks(0.05)
		_main.runtime._commands.tick_impacts(0.05)
	_expect(timed.hp == 780.0 and timed.teleport_serial == 0, "第14Tick前不提前落地")
	timed._tick_active_statuses(0.05)
	timed.prepare_action_clocks(0.05)
	_main.runtime._commands.tick_impacts(0.05)
	_expect(timed.hp == 780.0 and timed.teleport_serial == 1, "第15Tick正式排程原子落地满血")
	_expect(not timed.is_active_skill_casting(), "落地不再额外锁定1.1秒")
	_expect(float(skill.radius) == 140.0, "伤害范围保持140像素")
	var snapshots := NetworkSnapshotSystem.new(_main, _main._projectile_system)
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload: Array = fixture.snapshot_payload(snapshots, 902, timed)
	var packet: Array = fixture.packet(snapshots, [payload], [], fixture.tower_payloads(snapshots), 0.0, 180.0, false)
	_expect(snapshots.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)) != null, "回溯动作和瞬移沿既有压缩快照合法传输")
	var cancelled := _spawn_ready_unit("ekko", 0, Vector2(600, 1050))
	cancelled.configure_carried_active_skill(skill)
	_main._skill_lifecycle.start(cancelled, skill)
	cancelled.cancel_skill_cast()
	for i in 17:
		cancelled._tick_active_statuses(0.05)
		cancelled.prepare_action_clocks(0.05)
		_main.runtime._commands.tick_impacts(0.05)
	_expect(cancelled.teleport_serial == 0, "被取消的动作不补发回溯落地")
	_main.queue_free()

func _check_trail_history(harness: Object) -> void:
	var player := preload("res://assets/effects/ekko/player.gd").new()
	harness.root.add_child(player)
	player._data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/ekko/r-RewindIndicator/sampled.json"))
	player._age=float(player._data.duration)
	player.history_window=4.0
	var particles: Array = player._data.frames.back()[2]
	for clock in [3.95,4.05,7.95,8.05]:
		player.motion_time=clock
		player.motion_history=[{"time":0.0,"position":Vector3.ZERO,"distance":0.0},{"time":clock,"position":Vector3(clock,0,0),"distance":clock}]
		var ribbon: Array = player._ribbon_particles(particles)
		var head: float = clock-player._age+float(ribbon.front()[38])
		var tail: float = clock-player._age+float(ribbon.back()[38])
		_expect(is_equal_approx(head,clock) and is_equal_approx(tail,maxf(0.0,clock-4.0)), "连接线跨4秒边界仍连接本体与历史影子")
		var valid := true
		for point in ribbon:
			var birth: float = clock-player._age+float(point[38])
			valid=valid and birth>=tail-0.00001 and birth<=head+0.00001
		_expect(valid,"连接线不越过影子，也不取未来位置")
	_expect(is_equal_approx(player._history_distance(6.0),6.0),"WAKE纹理使用出生点累计路程")
	player.free()

func _check_optional_visual(unit: Unit) -> void:
	var view = load("res://assets/units/ekko/ekko_view.tscn").instantiate()
	_harness.root.add_child(view)
	view.set_process(false)
	view.configure_unit_visual(unit)
	view._process(0.0)
	_expect(not view._ready_visual and view.get_child_count() == 1 and view._history.is_empty(), "普通槽艾克不创建影子、装置、连接线或采样历史")
	unit.active_ability_id = 12345
	unit.active_ability_slot = 0
	view._process(0.0)
	_expect(view._ready_visual and view.get_child_count() > 1, "携带技能艾克创建主动表现")
	unit.active_ability_id = -1
	unit.active_ability_slot = -1
	view._process(0.0)
	_expect(not view._ready_visual and view.get_child_count() == 1 and view.get_node("Model").visible, "失去主动资格清理特效并恢复本体")
	view.free()
