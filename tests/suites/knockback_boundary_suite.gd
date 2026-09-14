extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in main._towers: tower.can_attack = false
	_check_continuous_takeover()
	_check_authoritative_launch_order()
	_check_terrain_and_independent_state()
	for reverse in [false, true]:
		var a: Unit = main._spawn_unit(0, "masteryi", Vector2(130, 800), 0)
		var b: Unit = main._spawn_unit(0, "masteryi", Vector2(230, 800), 0)
		var target: Unit = main._spawn_unit(1, "masteryi", Vector2(180, 800), 0)
		main._combat.begin_batch(100, "ordered_knockbacks")
		for source in ([b, a] if reverse else [a, b]):
			var order := [10 if source == a else 20, 1, 0]
			main._combat.resolve_attack_hit(0, source.position, target, 1, 0, 10 if source == b else 40, source, source.position, 0, {"displacement_order": order})
		main._combat.commit_batch()
		_expect(target._knockback_velocity.x < 0 and is_equal_approx(target._knockback_velocity.length(), 50), "同批后序合法事件接管：更短击退胜出，不依赖收集排列")
		for unit in [a, b, target]: unit.free()
	var unit: Unit = main._spawn_unit(0, "masteryi", Vector2(180, 800), 0)
	unit.apply_knockback(Vector2(100, 800), 40, 0.4)
	var velocity := unit._knockback_velocity
	unit.hp = 0
	unit.apply_knockback(Vector2(300, 800), 10, 0.1)
	_expect(unit._knockback_velocity == velocity and is_equal_approx(unit._knockback_timer, 0.4), "死亡目标的无效击退不接管旧状态")
	unit.free()

func _check_continuous_takeover() -> void:
	var unit: Unit = _main._spawn_unit(0, "masteryi", Vector2(180, 800), 0)
	unit.apply_knockback(Vector2(100, 800), 40, 0.4)
	unit.sim_tick(0.05)
	_main._movement.tick(0.05)
	var reached := unit.position
	_expect(reached.x > 180 and is_equal_approx(unit._knockback_timer, 0.35), "旧击退已产生实际位移")
	unit.apply_knockback(Vector2(300, 800), 10, 0.1)
	_expect(unit.position == reached and is_equal_approx(unit._knockback_velocity.x, -100) and is_equal_approx(unit._knockback_timer, 0.1), "反向短击退从当前位置接管，无残余距离或速度")
	for distance in [0.0, -1.0, NAN]:
		unit.apply_knockback(Vector2(100, 800), distance, 1)
		_expect(is_equal_approx(unit._knockback_velocity.x, -100) and is_equal_approx(unit._knockback_timer, 0.1), "非法距离不打断有效位移")
	unit.freeze(0.05)
	unit.sim_tick(0.05)
	_main._movement.tick(0.05)
	_expect(unit.position == reached and is_equal_approx(unit._knockback_timer, 0.1), "冻结暂停新击退")
	unit.stun(0.05)
	unit.sim_tick(0.05)
	_main._movement.tick(0.05)
	_expect(unit.position == reached and is_equal_approx(unit._knockback_timer, 0.1), "眩晕暂停新击退")
	for i in 2:
		unit.sim_tick(0.05)
		_main._movement.tick(0.05)
	_expect(is_equal_approx(unit.position.x, reached.x - 10) and unit._knockback_timer == 0, "恢复后恰好完成新位移，旧计时不恢复")
	unit.apply_knockback(Vector2(100, 800), 40, 0.4)
	unit.apply_knockback(Vector2(100, 800), 5, 0.05)
	_expect(is_equal_approx(unit._knockback_timer, 0.05) and is_equal_approx(unit._knockback_velocity.x, 100), "同方向更弱更短击退也接管")
	unit.free()
	for reverse in [false, true]:
		unit = _main._spawn_unit(0, "masteryi", Vector2(180, 800), 0)
		_main._combat.begin_batch(300, "source_sequence")
		for sequence in ([2, 1] if reverse else [1, 2]):
			unit.apply_knockback(Vector2(100 if sequence == 1 else 300, 800), 10, 0.1, 1.4, [42, sequence, 0])
		_main._combat.commit_batch()
		_expect(unit._knockback_velocity.x < 0, "来源内事件序号决定接管者，不受回调排列影响")
		_main._combat.begin_batch(301, "later_phase")
		unit.apply_knockback(Vector2(100, 800), 5, 0.1, 1.4, [1, 1, 0])
		_main._combat.commit_batch()
		_expect(unit._knockback_velocity.x > 0, "不同阶段保留真实先后，较小身份的后阶段事件照样接管")
		unit.free()

func _check_authoritative_launch_order() -> void:
	for reverse in [false, true]:
		var a: Unit = _main._spawn_unit(0, "masteryi", Vector2(130, 800), 0)
		var b: Unit = _main._spawn_unit(0, "masteryi", Vector2(230, 800), 0)
		var target: Unit = _main._spawn_unit(1, "masteryi", Vector2(180, 800), 0)
		var ids := [a.combat_source_id, b.combat_source_id]
		_main.move_child(b, a.get_index())
		_main._combat.begin_batch(400, "normal_launch")
		for source in ([b, a] if reverse else [a, b]):
			_main.launch_attack(source, target, 1, 0, 0, 10, Color.WHITE)
		_main._combat.commit_batch()
		_expect(ids[0] < ids[1] and target._knockback_velocity.x < 0, "正式出手入口固定出生身份，节点与出手收集顺序不改变同阶段接管者")
		for unit in [a, b, target]: unit.free()
	var building: Unit = _main._spawn_unit(0, "tombstone", Vector2(180, 800), 0)
	building.apply_knockback(Vector2(100, 800), 100, 1)
	_expect(building._knockback_timer == 0 and building._knockback_velocity == Vector2.ZERO, "建筑仍拒绝击退")
	building.free()

func _check_terrain_and_independent_state() -> void:
	var unit: Unit = _main._spawn_unit(0, "masteryi", Vector2(100, 800), 0)
	unit.add_shield(50, 10)
	unit.freeze(0.1)
	unit.stun(0.1)
	unit.apply_slow(1, 0.5)
	unit.apply_knockback(Vector2(0, 800), 10, 0.4)
	unit.apply_knockback(Vector2(200, 800), 300, 0.2)
	_expect(unit.shield_hp == 50 and unit.control.frozen_timer == 0.1 and unit.control.stun_timer == 0.1 and unit.control.slow_timer > 0, "接管只替换位移，保留护盾、冻结、眩晕和减速")
	for i in 6:
		unit.sim_tick(0.05)
		_main._movement.tick(0.05)
	_expect(unit.position.x >= unit.body_radius and _main.is_ground_position_walkable(unit.position, unit.body_radius, unit), "接管后的强制位移仍受场地和结构约束")
	_main._combat.begin_batch(500, "subsequence")
	unit.apply_knockback(Vector2(200, 800), 5, 0.1, 1.4, [42, 1, 0])
	unit.apply_knockback(Vector2(0, 800), 5, 0.1, 1.4, [42, 1, 1])
	_main._combat.commit_batch()
	_expect(unit._knockback_velocity.x > 0, "改变权威效果子序号会改变最后接管方向")
	var position_before := unit.position
	unit.take_damage(100000)
	_main._movement.tick(0.05)
	_expect(unit.position == position_before, "死亡后不再执行剩余强制位移")
	unit.free()
