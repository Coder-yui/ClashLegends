extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in main._towers: tower.can_attack = false
	_check_continuous_takeover()
	_check_authoritative_launch_order()
	_check_terrain_and_independent_state()
	_check_swept_obstacles()
	_check_swept_unit_contacts()
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

func _locked_unit(pos: Vector2) -> Unit:
	var unit: Unit = _main._spawn_unit(0, "masteryi", pos, 0)
	unit.freeze(3.0)
	return unit

func _advance_knockback(units: Array, count: int = 1) -> void:
	for i in count:
		for unit in units: unit.sim_tick(0.05)
		_main._movement.tick(0.05)

func _check_swept_obstacles() -> void:
	var unlocked: Unit = _main._spawn_unit(0, "masteryi", Vector2(360, 750), 0)
	unlocked.apply_knockback(Vector2(360, 850), 800, 0.2)
	_advance_knockback([unlocked])
	var action_mask := ControlState.MOVE | ControlState.BASIC_ATTACK | ControlState.START_SKILL
	_expect((unlocked.action_permissions() & action_mask) == 0, "无其他控制时，撞停仍锁自主移动、普攻和新技能")
	_advance_knockback([unlocked], 4)
	_expect((unlocked.action_permissions() & action_mask) == action_mask, "原定击退时间结束后恢复行动权限")
	unlocked.free()
	# 单 Tick 的终点已经在对岸合法地面，仍不能越过中间的河道。
	var unit := _locked_unit(Vector2(360, 750))
	unit.apply_knockback(Vector2(360, 850), 800, 0.2)
	_advance_knockback([unit])
	var stopped := unit.position
	_expect(stopped.y >= ArenaRules.RIVER_Y + ArenaRules.RIVER_HALF + unit.body_radius and stopped.y < 751, "普通击退扫掠河道：合法对岸终点不能穿过河流")
	_expect(unit.knockback.end_reason == &"blocked" and unit._knockback_velocity == Vector2.ZERO and is_equal_approx(unit._knockback_timer, 0.15), "撞停速度归零，保留原定剩余锁定")
	_advance_knockback([unit], 2)
	_expect(unit.position.is_equal_approx(stopped) and unit._knockback_timer > 0.0, "撞停后的剩余时间不补走、不滑向桥口")
	_advance_knockback([unit], 2)
	_expect(unit._knockback_timer == 0.0 and unit.knockback.end_reason == &"blocked", "撞停锁定按时结束，保留终止原因")
	unit.apply_knockback(unit.position + Vector2.UP * 100, 10, 0.1)
	_advance_knockback([unit])
	_expect(unit.position.y > stopped.y and unit.knockback.end_reason == &"running", "新合法击退能从撞停位置接管")
	unit.free()
	unit = _locked_unit(Vector2(280, 730))
	unit.apply_knockback(Vector2(180, 830), 400, 0.2)
	_advance_knockback([unit], 2)
	_expect(absf((unit.position.x - 280) - (730 - unit.position.y)) < 0.01, "斜向撞岸在原轨迹截停，不沿河岸滑动")
	unit.free()
	var building: Unit = _main._spawn_unit(0, "tombstone", Vector2(360, 800), 0)
	var obstacles: Array = [building]
	obstacles.append_array(_main._towers)
	for obstacle in obstacles:
		unit = _locked_unit(obstacle.position - Vector2(110, 0))
		unit.apply_knockback(unit.position - Vector2(100, 0), 880, 0.2)
		_advance_knockback([unit])
		_expect(unit.position.x < obstacle.position.x and unit.is_walkable_at(unit.position), "高速普通击退不能穿过建筑、防御塔或水晶")
		_expect(unit.knockback.end_reason == &"blocked", "结构阻拦终止击退轨迹")
		unit.free()
	building.free()
	for pos in [Vector2(80, 800), Vector2(640, 800), Vector2(280, 80), Vector2(280, 1200)]:
		unit = _locked_unit(pos)
		var center := Vector2(360, 640)
		unit.apply_knockback(center, 1200, 0.2)
		_advance_knockback([unit])
		_expect(unit.position.x >= unit.body_radius and unit.position.x <= ArenaRules.FIELD_W - unit.body_radius and unit.position.y >= unit.body_radius and unit.position.y <= ArenaRules.FIELD_H - unit.body_radius, "四周场界以完整碰撞圆截停，不能推出地图")
		_expect(unit.knockback.end_reason == &"blocked" and unit._knockback_timer > 0.0, "场界撞停保留锁定")
		unit.free()

func _check_swept_unit_contacts() -> void:
	var ground := _locked_unit(Vector2(360, 750))
	var air: Unit = _main._spawn_unit(0, "aurelionsol", Vector2(360, 750), 0)
	air.freeze(3.0)
	air.mass = 4.0
	air.apply_knockback(Vector2(360, 850), 800, 0.2)
	_advance_knockback([ground, air])
	_expect(air.position.y < ArenaRules.RIVER_Y - ArenaRules.RIVER_HALF and ground.position == Vector2(360, 750), "空军保留原地形通行能力，与地面单位不发生同层碰撞")
	air.free()
	ground.free()
	for reverse in [false, true]:
		var a := _locked_unit(Vector2(260, 800))
		var b := _locked_unit(Vector2(360, 800))
		if reverse: _main.move_child(b, a.get_index())
		a.apply_knockback(Vector2(160, 800), 800, 0.2)
		_advance_knockback([a, b])
		_expect(a.position.x < b.position.x and b.position.x - a.position.x >= a.body_radius + b.body_radius - ArenaRules.COLLISION_SLOP - 0.01, "高速击退真实碰到单位，不从身体另一侧穿出")
		var b_before := b.position.x
		_advance_knockback([a, b])
		_expect(b.position.x > b_before, "被撞单位受到既有质量接触推挤，不被瞬间挪出路径")
		_expect(a.knockback.end_reason == &"running", "单位接触不被误判为地形永久撞停")
		a.free()
		b.free()
		var left := _locked_unit(Vector2(260, 800))
		var right := _locked_unit(Vector2(460, 800))
		if reverse: _main.move_child(right, left.get_index())
		left.apply_knockback(Vector2(160, 800), 800, 0.2)
		right.apply_knockback(Vector2(560, 800), 800, 0.2)
		_advance_knockback([left, right])
		_expect(left.position.x < right.position.x and right.position.x - left.position.x >= left.body_radius + right.body_radius - ArenaRules.COLLISION_SLOP - 0.01, "双方同时高速击退使用相对扫掠，不能交换位置穿体")
		left.free()
		right.free()

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
	_expect(is_equal_approx(unit.position.x, reached.x - 5) and is_equal_approx(unit._knockback_timer, 0.05), "冻结姿势时外部轨迹继续前进")
	unit.stun(0.05)
	unit.sim_tick(0.05)
	_main._movement.tick(0.05)
	_expect(is_equal_approx(unit.position.x, reached.x - 10) and unit._knockback_timer == 0, "眩晕不延长击退轨迹")
	unit.stun(0.2)
	for i in 2:
		unit.sim_tick(0.05)
		_main._movement.tick(0.05)
	_expect(is_equal_approx(unit.position.x, reached.x - 10) and unit._knockback_timer == 0, "击退已到终点，后续控制不补走旧距离")
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
	_expect(unit.position.x >= unit.body_radius and _main.is_ground_position_walkable(unit.position, unit.body_radius, unit), "接管后的普通击退仍受场地和结构约束")
	_main._combat.begin_batch(500, "subsequence")
	unit.apply_knockback(Vector2(200, 800), 5, 0.1, 1.4, [42, 1, 0])
	unit.apply_knockback(Vector2(0, 800), 5, 0.1, 1.4, [42, 1, 1])
	_main._combat.commit_batch()
	_expect(unit._knockback_velocity.x > 0, "改变权威效果子序号会改变最后接管方向")
	var position_before := unit.position
	unit.take_damage(100000)
	_main._movement.tick(0.05)
	_expect(unit.position == position_before, "死亡后不再执行剩余击退")
	unit.free()
