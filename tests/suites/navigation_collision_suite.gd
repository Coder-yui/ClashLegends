class_name NavigationCollisionSuite
extends RefCounted
## 导航与碰撞领域：路线场、桥梁通行、绕塔寻路与单位推挤。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_lane_weight_field()
	_check_bridge_path()
	_check_left_spawn_crosses_without_backtracking()
	_check_bridge_corner_slides_into_entrance()
	_check_king_back_spawn_never_retreats()
	_check_unit_routes_around_friendly_tower()
	_check_right_corner_keeps_outer_side()
	_check_weighted_lane_march()
	_check_melee_minimum_range()
	_check_dense_group_keeps_moving()
	_check_bridge_queue()
	_check_tower_follower_splits_quickly()
	_check_rear_momentum_push()
	_check_pair_collision()
	_check_mass_weighting()
	_check_lane_stress()

func _check_lane_weight_field() -> void:
	var lane_weight: float = _main.nav.get_lane_weight_at(Vector2(_main.BRIDGE_X_LEFT, 800.0))
	var center_weight: float = _main.nav.get_lane_weight_at(Vector2(_main.FIELD_W * 0.5, 800.0))
	_expect(lane_weight < center_weight, "半格路线场使左右推进区成本低于场地中央")

func _check_bridge_path() -> void:
	var path: PackedVector2Array = _main.nav.find_path(Vector2(360.0, 820.0), Vector2(360.0, 460.0))
	var crosses_bridge := false
	var crosses_river_elsewhere := false
	for i in range(1, path.size()):
		var length := path[i - 1].distance_to(path[i])
		var samples := maxi(1, ceili(length / 8.0))
		for sample in range(samples + 1):
			var point := path[i - 1].lerp(path[i], float(sample) / float(samples))
			if absf(point.y - _main.RIVER_Y) <= _main.RIVER_HALF + _main.NAV_CLEARANCE:
				var at_left: bool = absf(point.x - _main.BRIDGE_X_LEFT) <= _main.BRIDGE_HALF
				var at_right: bool = absf(point.x - _main.BRIDGE_X_RIGHT) <= _main.BRIDGE_HALF
				crosses_bridge = crosses_bridge or at_left or at_right
				crosses_river_elsewhere = crosses_river_elsewhere or not (at_left or at_right)
	_expect(not path.is_empty() and crosses_bridge and not crosses_river_elsewhere, "地面路径只通过桥梁跨河")

func _check_left_spawn_crosses_without_backtracking() -> void:
	var stats: Dictionary = CardDB.get_card("garen").duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	stats["speed"] = 72.0
	var unit := Unit.new()
	unit.position = Vector2(60.0, 1140.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var crossed := false
	var backward_steps := 0
	var previous_y := unit.position.y
	for _tick in 420:
		_main._sim_step(_main.SIM_DT)
		if unit.position.y < _main.RIVER_Y - _main.RIVER_HALF - _main.NAV_CLEARANCE:
			crossed = true
			break
		if absf(unit.position.y - _main.RIVER_Y) < 150.0 and unit.position.y > previous_y + 0.25:
			backward_steps += 1
		previous_y = unit.position.y
	_expect(crossed, "左下角出兵可持续通过左桥")
	_expect(backward_steps <= 1, "桥头周期性重寻路不会再把单位拉回入口")
	unit.free()

func _check_bridge_corner_slides_into_entrance() -> void:
	var bridge_centers: Array[float] = [_main.BRIDGE_X_LEFT, _main.BRIDGE_X_RIGHT]
	var all_crossed := true
	var worst_stall := 0
	# 覆盖两座桥的左右四个桥—水交角，并使用当前最大的实际人物（盖伦）验证圆柱净空。
	for bridge_x in bridge_centers:
		for side_sign in [-1.0, 1.0]:
			var stats: Dictionary = CardDB.get_card("garen").duplicate()
			stats["deploy_time"] = 0.0
			stats["hp"] = 100000.0
			stats["speed"] = 72.0
			var unit := Unit.new()
			unit.setup(0, stats, stats.name)
			var safe_half: float = _main.BRIDGE_HALF - unit.body_radius - _main.BRIDGE_EDGE_MARGIN
			unit.position = Vector2(
				bridge_x + side_sign * (safe_half + 8.0),
				_main.RIVER_Y + _main.RIVER_HALF + unit.body_radius + 0.5
			)
			_main.add_child(unit)
			var longest_stall := 0
			var stall_ticks := 0
			var previous := unit.position
			var crossed := false
			for _tick in 300:
				_main._sim_step(_main.SIM_DT)
				if unit.position.distance_to(previous) < 0.02 and unit._move_intent.length_squared() > 0.1:
					stall_ticks += 1
					longest_stall = maxi(longest_stall, stall_ticks)
				else:
					stall_ticks = 0
				previous = unit.position
				if unit.position.y < _main.RIVER_Y - _main.RIVER_HALF - unit.body_radius:
					crossed = true
					break
			all_crossed = all_crossed and crossed
			worst_stall = maxi(worst_stall, longest_stall)
			unit.free()
	_expect(all_crossed and worst_stall <= 1, "放大后的圆柱单位经过两座桥四个水边交角时连续切线入桥，不再短暂停顿")

func _check_king_back_spawn_never_retreats() -> void:
	var stats: Dictionary = CardDB.get_card("garen").duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var unit := Unit.new()
	unit.setup(0, stats, stats.name)
	unit.position = _main._snap_card_position("garen", Vector2(340.0, 1260.0), 0)
	var deploy_valid: bool = _main.is_card_deploy_position_valid(0, "garen", Vector2(340.0, 1260.0))
	_main.add_child(unit)
	var start_y := unit.position.y
	var previous_y := unit.position.y
	var never_retreated := true
	for _tick in 50:
		_main._sim_step(_main.SIM_DT)
		never_retreated = never_retreated and unit.position.y <= previous_y + 0.05
		previous_y = unit.position.y
	_expect(deploy_valid and never_retreated and unit.position.y < start_y - 10.0, "盖伦可部署在水晶底部，并能连续绕出而不会卡住或先后退")
	unit.free()

func _check_unit_routes_around_friendly_tower() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var unit := Unit.new()
	# 从己方左塔正后方出发：先沿圆形塔体侧绕，再汇入左路向前推进。
	unit.position = Vector2(140.0, 1100.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var crossed_tower := false
	var longest_stall := 0
	var stall_ticks := 0
	var max_side_offset := 0.0
	var previous := unit.position
	for _tick in 180:
		_main._sim_step(_main.SIM_DT)
		if unit.position.y < 940.0:
			crossed_tower = true
			break
		max_side_offset = maxf(max_side_offset, absf(unit.position.x - _main.BRIDGE_X_LEFT))
		if unit.position.distance_to(previous) < 0.05 and unit._move_intent.length_squared() > 0.1:
			stall_ticks += 1
			longest_stall = maxi(longest_stall, stall_ticks)
		else:
			stall_ticks = 0
		previous = unit.position
	_expect(crossed_tower, "单位会寻路绕过己方存活塔继续推进")
	_expect(longest_stall < 8, "单位不会在塔的边角持续卡住")
	_expect(max_side_offset > unit.body_radius, "塔正后方单位会先贴圆周侧绕，再回到推进路线")
	unit.free()

func _check_right_corner_keeps_outer_side() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var unit := Unit.new()
	unit.setup(0, stats, stats.name)
	unit.position = Vector2(_main.FIELD_W - unit.body_radius, 1220.0)
	_main.add_child(unit)
	var right_tower: Tower = _main._towers[1]
	var min_x_behind_tower := unit.position.x
	var passed_tower := false
	for _tick in 220:
		_main._sim_step(_main.SIM_DT)
		if unit.position.y >= right_tower.position.y:
			min_x_behind_tower = minf(min_x_behind_tower, unit.position.x)
		if unit.position.y < right_tower.position.y - right_tower.body_radius - unit.body_radius:
			passed_tower = true
			break
	_expect(passed_tower and min_x_behind_tower > right_tower.position.x + right_tower.body_radius, "右下角单位会从己方右塔外侧绕行，不再穿到塔左边")
	unit.free()

func _check_weighted_lane_march() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = Vector2(_main.FIELD_W * 0.5, 820.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	unit._target = _main._towers[2]
	unit._chase(_main.SIM_DT)
	var enters_lane := false
	for point in unit._path:
		enters_lane = enters_lane or _main.nav.get_lane_weight_at(point) <= 1.0
	_expect(not unit._path.is_empty() and enters_lane and unit._move_intent.y < 0.0, "无仇恨单位会从非主路自然汇入带权左右路")
	var first_path: PackedVector2Array = unit._path.duplicate()
	unit._chase(_main.SIM_DT)
	_expect(unit._path == first_path, "推进路径生成后会复用，不会每个模拟帧重跑 A*")
	unit.free()

func _check_melee_minimum_range() -> void:
	var melee_ranges: Array[float] = []
	for card_id in ["garen", "xin", "melee_minion", "super_minion", "masteryi", "gwen", "sett"]:
		melee_ranges.append(float(CardDB.get_card(card_id).range))
	melee_ranges.append(float(CardDB.get_card("gnar").transformed_stats.range))
	melee_ranges.append(float(CardDB.get_unit_stats("imp").range))
	var all_reach_minimum := true
	for attack_range in melee_ranges:
		all_reach_minimum = all_reach_minimum and attack_range >= CardDB.MELEE_RANGE_MIN
	_expect(all_reach_minimum, "所有近战单位的表面攻击距离至少为 0.8 格")

func _check_dense_group_keeps_moving() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var units: Array[Unit] = []
	var starts: Array[Vector2] = []
	for offset in [Vector2.ZERO, Vector2(12.0, 0.0), Vector2(-12.0, 0.0), Vector2(0.0, 12.0), Vector2(0.0, -12.0)]:
		var unit := Unit.new()
		unit.position = Vector2(300.0, 820.0) + offset
		unit.setup(0, stats, stats.name)
		_main.add_child(unit)
		units.append(unit)
		starts.append(unit.position)
	var start_center_y := 0.0
	for start in starts:
		start_center_y += start.y
	start_center_y /= starts.size()
	for _tick in 80:
		_main._sim_step(_main.SIM_DT)
	var end_center_y := 0.0
	var moved_count := 0
	for i in units.size():
		end_center_y += units[i].position.y
		if units[i].position.distance_to(starts[i]) > 20.0:
			moved_count += 1
	end_center_y /= units.size()
	_expect(moved_count == units.size() and end_center_y < start_center_y - 30.0, "五单位密集团簇会自然散开并继续推进，不会互相等待卡死")
	for unit in units:
		unit.free()

func _check_bridge_queue() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var front := Unit.new()
	var rear := Unit.new()
	front.position = Vector2(204.0, 655.0)
	rear.position = Vector2(204.0, 682.0)
	front.setup(0, stats, stats.name)
	rear.setup(0, stats, stats.name)
	_main.add_child(front)
	_main.add_child(rear)
	front._move_intent = Vector2.UP * front.move_speed
	rear._move_intent = Vector2.UP * rear.move_speed
	var units: Array[Unit] = [front, rear]
	var rear_velocity: Vector2 = _main._adjust_unit_velocity(rear, units, _main.SIM_DT)
	_expect(rear_velocity.length() > rear.move_speed * 0.2 and rear_velocity.length() < rear.move_speed, "桥区后排会减速避让但不会完全停住")
	_expect(-rear_velocity.y >= rear.move_speed * _main.AVOID_MIN_FORWARD_RATIO - 0.01, "加快侧移时仍保留最低向前推进速度")
	front.free()
	rear.free()

func _check_tower_follower_splits_quickly() -> void:
	var tower: Tower = _main._towers[2]
	var tower_hp := tower.hp
	tower.hp = 100000.0
	var stats: Dictionary = CardDB.get_card("sett").duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var front := Unit.new()
	var rear := Unit.new()
	front.setup(0, stats, stats.name)
	rear.setup(0, stats, stats.name)
	var stop_distance: float = tower.body_radius + front.body_radius + front.attack_range
	front.position = tower.position + Vector2.DOWN * (stop_distance - 1.0)
	# 后排已经追到接触 skin 外，专门测量“发现被堵”到侧向错开所需时间，
	# 不把正常赶路耗时混进避让响应指标。
	rear.position = front.position + Vector2.DOWN * (front.body_radius + rear.body_radius + 4.0)
	_main.add_child(front)
	_main.add_child(rear)
	front._target = tower
	rear._target = tower
	var enter_tick := -1
	var side_separation := 0.0
	var max_side_separation := 0.0
	for tick in 40:
		_main._sim_step(_main.SIM_DT)
		max_side_separation = maxf(max_side_separation, absf(rear.position.x - front.position.x))
		if rear._target_gap(tower) <= rear.attack_range:
			enter_tick = tick + 1
			side_separation = absf(rear.position.x - front.position.x)
			break
	_expect(
		enter_tick > 0 and enter_tick <= 36 and side_separation > front.body_radius,
		"塔前有横向空间时，后排近战会在 1.8 秒内错开友军并进入攻击圈（tick=%d，横向差=%.1f，最大横移=%.1f，末端gap=%.1f）" % [enter_tick, side_separation, max_side_separation, rear._target_gap(tower)]
	)
	front.free()
	rear.free()
	tower.hp = tower_hp

func _check_rear_momentum_push() -> void:
	var equal_mass_speeds := _measure_rear_momentum_push(4.0, 4.0)
	var expected_equal_speed := (4.0 * CardDB.SPEED_SLOW + 4.0 * CardDB.SPEED_FAST) / 8.0
	_expect(
		is_equal_approx(equal_mass_speeds.x, expected_equal_speed)
		and is_equal_approx(equal_mass_speeds.y, expected_equal_speed),
		"等质量快慢单位追尾后按完全非弹性碰撞共享质量加权速度"
	)
	var momentum_before := 4.0 * CardDB.SPEED_SLOW + 4.0 * CardDB.SPEED_FAST
	var momentum_after := 4.0 * equal_mass_speeds.x + 4.0 * equal_mass_speeds.y
	_expect(is_equal_approx(momentum_before, momentum_after), "追尾接触前后的质量×速度总动量守恒")
	var light_rear_speeds := _measure_rear_momentum_push(8.0, 2.0)
	var heavy_rear_speeds := _measure_rear_momentum_push(2.0, 8.0)
	_expect(
		heavy_rear_speeds.x > equal_mass_speeds.x and equal_mass_speeds.x > light_rear_speeds.x,
		"相同速度差下，重后排推动轻前排的加速大于轻后排推动重前排"
	)
	var probe_stats: Dictionary = CardDB.get_card("xin").duplicate()
	probe_stats["deploy_time"] = 0.0
	var probe_front := Unit.new()
	var probe_rear := Unit.new()
	probe_front.setup(0, probe_stats, probe_stats.name)
	probe_rear.setup(0, probe_stats, probe_stats.name)
	probe_front.position = Vector2(360.0, 800.0)
	probe_rear.position = probe_front.position + Vector2.DOWN * (probe_front.body_radius + probe_rear.body_radius + 1.0)
	probe_front._move_intent = Vector2.UP * CardDB.SPEED_MEDIUM
	probe_rear._move_intent = Vector2.UP * CardDB.SPEED_MEDIUM
	var same_speed_contact: bool = _main._is_unit_momentum_contact(probe_front, probe_rear)
	probe_rear._move_intent = Vector2.UP * CardDB.SPEED_FAST
	probe_rear.position = probe_front.position + Vector2.RIGHT * (probe_front.body_radius + probe_rear.body_radius + 1.0)
	var side_contact: bool = _main._is_unit_momentum_contact(probe_front, probe_rear)
	_expect(not same_speed_contact and not side_contact, "同速纵队与并排行军均不会产生追尾冲量")
	probe_front.free()
	probe_rear.free()

func _measure_rear_momentum_push(front_mass: float, rear_mass: float) -> Vector2:
	var front_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var rear_stats: Dictionary = front_stats.duplicate()
	front_stats["deploy_time"] = 0.0
	rear_stats["deploy_time"] = 0.0
	front_stats["speed"] = CardDB.SPEED_SLOW
	rear_stats["speed"] = CardDB.SPEED_FAST
	front_stats["mass"] = front_mass
	rear_stats["mass"] = rear_mass
	var front := Unit.new()
	var rear := Unit.new()
	front.setup(0, front_stats, front_stats.name)
	rear.setup(0, rear_stats, rear_stats.name)
	front.position = Vector2(360.0, 800.0)
	rear.position = front.position + Vector2.DOWN * (front.body_radius + rear.body_radius + _main.MOMENTUM_CONTACT_PADDING * 0.25)
	_main.add_child(front)
	_main.add_child(rear)
	front._move_intent = Vector2.UP * front.move_speed
	rear._move_intent = Vector2.UP * rear.move_speed
	var front_start := front.position
	var rear_start := rear.position
	_main._apply_unit_movement(_main.SIM_DT)
	var front_tick_speed: float = front_start.distance_to(front.position) / float(_main.SIM_DT)
	var rear_tick_speed: float = rear_start.distance_to(rear.position) / float(_main.SIM_DT)
	front.free()
	rear.free()
	return Vector2(front_tick_speed, rear_tick_speed)

func _check_pair_collision() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var a := Unit.new()
	var b := Unit.new()
	a.position = Vector2(204.0, 760.0)
	b.position = a.position
	a.setup(0, stats, stats.name)
	b.setup(0, stats, stats.name)
	_main.add_child(a)
	_main.add_child(b)
	_main._resolve_unit_collisions(_main.SIM_DT)
	_expect(a.position.distance_to(b.position) > 0.1, "完全重叠的单位按稳定方向拆分")
	_expect(a.is_walkable_at(a.position) and b.is_walkable_at(b.position), "轻量重叠修正不会把地面单位推进障碍")
	a.free()
	b.free()

func _check_mass_weighting() -> void:
	var heavy_stats: Dictionary = CardDB.get_card("garen").duplicate()
	var light_stats: Dictionary = CardDB.get_unit_stats("imp").duplicate()
	heavy_stats["deploy_time"] = 0.0
	light_stats["deploy_time"] = 0.0
	var heavy := Unit.new()
	var light := Unit.new()
	heavy.position = Vector2(300.0, 800.0)
	light.position = Vector2(320.0, 800.0)
	heavy.setup(0, heavy_stats, heavy_stats.name)
	light.setup(0, light_stats, light_stats.name)
	_main.add_child(heavy)
	_main.add_child(light)
	var heavy_before := heavy.position
	var light_before := light.position
	_main._resolve_unit_collisions(_main.SIM_DT)
	var heavy_move := heavy.position.distance_to(heavy_before)
	var light_move := light.position.distance_to(light_before)
	_expect(light_move > heavy_move, "重叠修正按质量分配，大单位移动得更少")
	heavy.free()
	light.free()

## 长时间自由行军用例会真实交战并可能摧毁敌方公主塔；原文件中 lane_stress 排在最后，
## 拆分后先于索敌/pocket 用例执行，必须在用例结束时还原塔的血量与导航占地。
func _snapshot_towers() -> Array:
	var snapshot := []
	for tower: Tower in _main._towers:
		snapshot.append({"tower": tower, "hp": tower.hp, "nav_cells": tower.nav_cells.duplicate()})
	for king: Tower in [_main._king_player, _main._king_enemy]:
		snapshot.append({"tower": king, "hp": king.hp, "nav_cells": king.nav_cells.duplicate()})
	return snapshot

func _restore_towers(snapshot: Array) -> void:
	for entry in snapshot:
		var tower: Tower = entry["tower"]
		tower.hp = entry["hp"]
		if tower.nav_cells.is_empty() and not entry["nav_cells"].is_empty():
			tower.nav_cells = entry["nav_cells"].duplicate()
			_main.nav.set_cells_blocked(tower.nav_cells, true)

func _check_lane_stress() -> void:
	var towers_snapshot := _snapshot_towers()
	var spawned: Array[Unit] = []
	for i in 6:
		var card_id := "garen" if i % 3 == 0 else ("xin" if i % 3 == 1 else "masteryi")
		var stats: Dictionary = CardDB.get_card(card_id).duplicate()
		stats["deploy_time"] = 0.0
		var unit := Unit.new()
		unit.position = Vector2(180.0 + float(i % 3) * 20.0, 800.0 + float(i / 3) * 28.0)
		unit.setup(0, stats, stats.name)
		_main.add_child(unit)
		spawned.append(unit)
	var crossed := false
	var invalid_river_position := false
	for _tick in 320:
		_main._sim_step(_main.SIM_DT)
		for unit in spawned:
			if not is_instance_valid(unit) or unit.hp <= 0.0:
				continue
			crossed = crossed or unit.position.y < _main.RIVER_Y - _main.RIVER_HALF
			if absf(unit.position.y - _main.RIVER_Y) <= _main.RIVER_HALF:
				var on_left: bool = absf(unit.position.x - _main.BRIDGE_X_LEFT) <= _main.BRIDGE_HALF
				var on_right: bool = absf(unit.position.x - _main.BRIDGE_X_RIGHT) <= _main.BRIDGE_HALF
				invalid_river_position = invalid_river_position or not (on_left or on_right)
	_expect(crossed, "多单位拥挤情况下仍能排队通过桥梁")
	_expect(not invalid_river_position, "长时间模拟中地面单位不会被碰撞挤入河道")
	for unit in spawned:
		if is_instance_valid(unit):
			unit.free()
	_restore_towers(towers_snapshot)
