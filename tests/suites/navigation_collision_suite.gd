class_name NavigationCollisionSuite
extends "res://tests/suites/battle_suite.gd"
## 导航与碰撞领域：路线场、桥梁通行、绕塔寻路与单位推挤。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_direct_approach_after_bridge()
	_check_lane_weight_field()
	_check_bridge_path()
	_check_bridge_contact_stays_on_land()
	_check_left_spawn_crosses_without_backtracking()
	_check_bridge_corner_slides_into_entrance()
	_check_king_back_spawn_never_retreats()
	_check_formal_back_row_spawn()
	_check_unit_routes_around_friendly_tower()
	_check_right_corner_keeps_outer_side()
	_check_weighted_lane_march()
	_check_melee_minimum_range()
	_check_dense_group_keeps_moving()
	_check_bridge_queue()
	_check_tower_follower_splits_quickly()
	_check_rear_contact_push()
	_check_pair_collision()
	_check_mass_weighting()
	_check_lane_stress()

func _check_lane_weight_field() -> void:
	_check_native_path_search()
	var lane_weight: float = _main.nav.get_lane_weight_at(Vector2(ArenaRules.BRIDGE_X_LEFT, 800.0))
	var center_weight: float = _main.nav.get_lane_weight_at(Vector2(ArenaRules.FIELD_W * 0.5, 800.0))
	_expect(lane_weight < center_weight, "半格路线场使左右推进区成本低于场地中央")

func _check_native_path_search() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native_path_search.json"))
	var search := preload("res://scripts/battle/battle_path_search.gd").new()
	var matched := 0
	for example in fixture.cases:
		var size := Vector2i(example.grid[0].size(), example.grid.size())
		var costs := PackedInt32Array()
		for row in example.grid:
			for value in row:
				costs.append(int(value))
		var actual := search.find_cells(size, costs, Vector2i(example.start[0], example.start[1]), Vector2i(example.goal[0], example.goal[1]))
		var expected: Array[Vector2i] = []
		for cell in example.path:
			expected.append(Vector2i(cell[0], cell[1]))
		if actual == expected:
			matched += 1
		else:
			_expect(false, "原始指令路线对比失败：%s，实际=%s，预期=%s" % [example.name, actual, expected])
	_expect(matched == fixture.cases.size(), "搜索核心逐格匹配 %d/%d 组原始 ARM64 路线（含等价路线的堆顺序）" % [matched, fixture.cases.size()])

func _check_bridge_path() -> void:
	var path: PackedVector2Array = _main.nav.find_path(Vector2(360.0, 820.0), Vector2(360.0, 460.0))
	var crosses_bridge := false
	var crosses_river_elsewhere := false
	for i in range(1, path.size()):
		var length := path[i - 1].distance_to(path[i])
		var samples := maxi(1, ceili(length / 8.0))
		for sample in range(samples + 1):
			var point := path[i - 1].lerp(path[i], float(sample) / float(samples))
			if absf(point.y - ArenaRules.RIVER_Y) <= ArenaRules.RIVER_HALF + ArenaRules.NAV_CLEARANCE:
				var at_left: bool = absf(point.x - ArenaRules.BRIDGE_X_LEFT) <= ArenaRules.BRIDGE_HALF
				var at_right: bool = absf(point.x - ArenaRules.BRIDGE_X_RIGHT) <= ArenaRules.BRIDGE_HALF
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
		if unit.position.y < ArenaRules.RIVER_Y - ArenaRules.RIVER_HALF - ArenaRules.NAV_CLEARANCE:
			crossed = true
			break
		if absf(unit.position.y - ArenaRules.RIVER_Y) < 150.0 and unit.position.y > previous_y + 0.25:
			backward_steps += 1
		previous_y = unit.position.y
	_expect(crossed, "左下角出兵可持续通过左桥")
	_expect(backward_steps <= 1, "桥头周期性重寻路不会再把单位拉回入口")
	unit.free()

func _check_bridge_corner_slides_into_entrance() -> void:
	var bridge_centers: Array[float] = [ArenaRules.BRIDGE_X_LEFT, ArenaRules.BRIDGE_X_RIGHT]
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
			var safe_half: float = ArenaRules.BRIDGE_HALF - unit.body_radius - ArenaRules.BRIDGE_EDGE_MARGIN
			unit.position = Vector2(
				bridge_x + side_sign * (safe_half + 8.0),
				ArenaRules.RIVER_Y + ArenaRules.RIVER_HALF + unit.body_radius + 0.5
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
				if unit.position.y < ArenaRules.RIVER_Y - ArenaRules.RIVER_HALF - unit.body_radius:
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
		max_side_offset = maxf(max_side_offset, absf(unit.position.x - ArenaRules.BRIDGE_X_LEFT))
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
	unit.position = Vector2(ArenaRules.FIELD_W - unit.body_radius, 1220.0)
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
	unit.position = Vector2(ArenaRules.FIELD_W * 0.5, 820.0)
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
	var rear_velocity: Vector2 = _main._movement._adjust_unit_velocity(rear, units, _main.SIM_DT)
	_expect(rear_velocity.is_equal_approx(rear._move_intent), "同向桥区纵队保留自主步幅，重叠由接触位移处理")
	front._move_intent = Vector2.ZERO
	rear_velocity = _main._movement._adjust_unit_velocity(rear, units, _main.SIM_DT)
	_expect(is_equal_approx(rear_velocity.length(), rear.move_speed) and absf(rear_velocity.x) > 0.1, "前排停下时后排保持步幅偏转绕行")
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

func _check_rear_contact_push() -> void:
	var equal := _measure_rear_contact_push(4.0, 4.0)
	var light_rear := _measure_rear_contact_push(8.0, 2.0)
	var heavy_rear := _measure_rear_contact_push(2.0, 8.0)
	_expect(equal.x > CardDB.SPEED_SLOW + 1.0 and equal.y < CardDB.SPEED_FAST - 1.0,
		"持续追尾使慢前排超过自主移速、快后排减速（前=%.2f，后=%.2f）" % [equal.x, equal.y])
	_expect(heavy_rear.x > equal.x and equal.x > light_rear.x,
		"重后排推动轻前排更明显；推行不要求动量守恒（轻后=%.2f，等重=%.2f，重后=%.2f）" % [light_rear.x, equal.x, heavy_rear.x])
	_check_contact_boundaries()
	_check_dense_contact_limit()

func _measure_rear_contact_push(front_mass: float, rear_mass: float) -> Vector2:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var front := Unit.new()
	var rear := Unit.new()
	front.setup(0, stats, stats.name)
	rear.setup(0, stats, stats.name)
	front.mass = front_mass
	rear.mass = rear_mass
	front.move_speed = CardDB.SPEED_SLOW
	rear.move_speed = CardDB.SPEED_FAST
	front.position = Vector2(230.0, 850.0)
	rear.position = front.position + Vector2.LEFT * (front.body_radius + rear.body_radius + 1.0)
	_main.add_child(front)
	_main.add_child(rear)
	var units: Array[Unit] = [front, rear]
	front._move_intent = Vector2.RIGHT * front.move_speed
	rear._move_intent = Vector2.RIGHT * rear.move_speed
	var start := Vector2.ZERO
	var valid_positions := true
	for tick in 80:
		if tick == 20:
			start = Vector2(front.position.x, rear.position.x)
		_main._movement._apply_unit_movement(_main.SIM_DT, units)
		valid_positions = valid_positions and front.position.x > rear.position.x
		valid_positions = valid_positions and front.is_walkable_at(front.position) and rear.is_walkable_at(rear.position)
	var speeds: Vector2 = (Vector2(front.position.x, rear.position.x) - start) / (60.0 * _main.SIM_DT)
	_expect(valid_positions, "持续追尾不穿过前排或进入地形")
	rear.position = Vector2(100.0, 100.0)
	var before := front.position
	_main._movement._apply_unit_movement(_main.SIM_DT, units)
	_expect(is_equal_approx(front.position.distance_to(before) / _main.SIM_DT, front.move_speed),
		"移走推手后的下一 Tick 恢复自主速度，没有残留动量")
	front.free()
	rear.free()
	return speeds

func _check_contact_boundaries() -> void:
	var stats: Dictionary = CardDB.get_card("garen").duplicate()
	stats["deploy_time"] = 0.0
	var a := Unit.new()
	var b := Unit.new()
	a.setup(0, stats, stats.name)
	b.setup(0, stats, stats.name)
	_main.add_child(a)
	_main.add_child(b)
	var units: Array[Unit] = [a, b]
	a.position = Vector2(320.0, 850.0)
	b.position = a.position + Vector2.LEFT * (a.body_radius + b.body_radius + 0.5)
	a._move_intent = Vector2.RIGHT * CardDB.SPEED_SLOW
	b._move_intent = Vector2.RIGHT * CardDB.SPEED_FAST
	var before := a.position
	_main._movement._apply_unit_movement(_main.SIM_DT, units)
	_expect(is_equal_approx(a.position.distance_to(before) / _main.SIM_DT, CardDB.SPEED_SLOW), "未接触前不会隔空传递速度")
	# 站定单位可以被挤开，但不产生自主行走的冲锋充能。
	a._move_intent = Vector2.ZERO
	b._move_intent = Vector2.ZERO
	a.charge_time = 1.0
	a._charge_timer = 0.0
	a._just_deployed = false
	b._just_deployed = false
	b.position = a.position + Vector2.LEFT * (a.body_radius + b.body_radius - 2.0)
	before = a.position
	_main._movement._apply_unit_movement(_main.SIM_DT, units)
	_expect(a.position.x > before.x and a._charge_timer == 0.0,
		"站定单位可被接触挤开，纯被动位移不积攒冲锋")
	b.is_air = true
	b.position = a.position
	before = a.position
	_main._movement._apply_unit_movement(_main.SIM_DT, units)
	_expect(a.position == before and b.position == before, "空地不同层完全重叠也不互推")
	b.is_air = false
	b.team = 1
	b.position = a.position + Vector2.LEFT * (a.body_radius + b.body_radius - 2.0)
	before = a.position
	_main._movement._apply_unit_movement(_main.SIM_DT, units)
	_expect(a.position.x > before.x, "接触分离也作用于同层敌军，不限于友军追尾")
	# 同一时刻收集全部贡献：反转遍历顺序也不改变结果。
	b.position = a.position + Vector2.LEFT * (a.body_radius + b.body_radius - 2.0)
	var forward: Dictionary = _main._movement._collect_unit_contacts(units)
	units.reverse()
	var reversed: Dictionary = _main._movement._collect_unit_contacts(units)
	_expect(forward == reversed, "接触贡献使用同一位置快照，不受候选遍历顺序影响")
	a._just_deployed = true
	b._just_deployed = true
	b.position = a.position
	forward = _main._movement._collect_unit_contacts(units)
	units.reverse()
	reversed = _main._movement._collect_unit_contacts(units)
	_expect(forward == reversed, "双方同 Tick 完全重叠部署时也以稳定 id 决定挤开方向")
	a.free()
	b.free()

func _check_dense_contact_limit() -> void:
	var stats: Dictionary = CardDB.get_card("garen").duplicate()
	stats["deploy_time"] = 0.0
	var units: Array[Unit] = []
	for index in 9:
		var unit := Unit.new()
		unit.setup(0, stats, stats.name)
		unit.position = Vector2(360.0, 850.0) + Vector2.LEFT * float(index)
		_main.add_child(unit)
		unit._just_deployed = false
		units.append(unit)
	var starts: Array[Vector2] = []
	for unit in units:
		starts.append(unit.position)
	# 经真正 Tick 验证没有再追加第二轮成对修正。
	_main._movement.tick(_main.SIM_DT)
	var bounded := true
	for index in units.size():
		bounded = bounded and units[index].position.distance_to(starts[index]) <= ArenaRules.CONTACT_STEP_LIMIT + 0.001
	_expect(bounded, "九单位单侧密集重叠每 Tick 仍有统一接触位移上限，不按邻居数量累加或重复修正")
	var center := units[0]
	center.position = Vector2(360.0, 850.0)
	for index in range(1, units.size()):
		var angle := TAU * float(index - 1) / 8.0
		units[index].position = center.position + Vector2.from_angle(angle) * (center.body_radius * 2.0 - 5.0)
	var before := center.position
	_main._movement.tick(_main.SIM_DT)
	_expect(center.position.distance_to(before) < 0.001, "对称包围的接触贡献相互抵消，不凭遍历顺序把中心单位挤向一侧")
	for unit in units:
		unit.free()

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
	_main._movement._resolve_unit_collisions(_main.SIM_DT, _main._movement._active_mobile_units())
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
	_main._movement._resolve_unit_collisions(_main.SIM_DT, _main._movement._active_mobile_units())
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
			crossed = crossed or unit.position.y < ArenaRules.RIVER_Y - ArenaRules.RIVER_HALF
			if absf(unit.position.y - ArenaRules.RIVER_Y) <= ArenaRules.RIVER_HALF:
				var on_left: bool = absf(unit.position.x - ArenaRules.BRIDGE_X_LEFT) <= ArenaRules.BRIDGE_HALF
				var on_right: bool = absf(unit.position.x - ArenaRules.BRIDGE_X_RIGHT) <= ArenaRules.BRIDGE_HALF
				invalid_river_position = invalid_river_position or not (on_left or on_right)
	_expect(crossed, "多单位拥挤情况下仍能排队通过桥梁")
	_expect(not invalid_river_position, "长时间模拟中地面单位不会被碰撞挤入河道")
	for unit in spawned:
		if is_instance_valid(unit):
			unit.free()
	_restore_towers(towers_snapshot)

func _check_bridge_contact_stays_on_land() -> void:
	var stats: Dictionary = CardDB.get_card("melee_minion").duplicate()
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var stayed_legal := true
	for bridge_x in [ArenaRules.BRIDGE_X_LEFT, ArenaRules.BRIDGE_X_RIGHT]:
		for side in [-1.0, 1.0]:
			for bank in [-1.0, 1.0]:
				unit.position = Vector2(bridge_x + side * (ArenaRules.BRIDGE_HALF - unit.body_radius - 0.5), ArenaRules.RIVER_Y + bank * 10.0)
				_main._movement._apply_contact_displacement(unit, Vector2(side * 4.0, bank * 2.0), _main.SIM_DT)
				stayed_legal = stayed_legal and unit.is_walkable_at(unit.position)
	_expect(stayed_legal, "桥上单位受到朝岸斜向推挤时不能越过桥侧进入河道")
	# 靠河格心出生的大单位仍能逐步退出出生时的河岸重叠。
	unit.position = Vector2(360.0, ArenaRules.RIVER_Y + ArenaRules.RIVER_HALF + unit.body_radius - 2.0)
	var previous_y := unit.position.y
	_main._movement._try_apply_velocity(unit, Vector2(0.0, 20.0), _main.SIM_DT)
	_expect(unit.position.y > previous_y, "已处于河岸重叠的单位仍可向岸上脱离")
	unit.free()

func _check_formal_back_row_spawn() -> void:
	var all_escaped := true
	for team in [0, 1]:
		for x in [340.0, 380.0]:
			var requested := Vector2(x, 1260.0 if team == 0 else 20.0)
			var accepted: bool = _main.play_card(team, "garen", requested, {"immediate": true})
			var unit: Unit
			for c in _main.get_tree().get_nodes_in_group("combatants"):
				if c is Unit and c.card_id == "garen" and c.team == team:
					unit = c
			if not accepted or unit == null:
				all_escaped = false
				continue
			var start := unit.position
			var movers: Array[Unit] = [unit]
			for tick in 160:
				unit.sim_tick(_main.SIM_DT)
				_main._movement._apply_unit_movement(_main.SIM_DT, movers)
			all_escaped = all_escaped and absf(unit.position.y - start.y) > 100.0 and unit.is_walkable_at(unit.position)
			unit.free()
	_expect(all_escaped, "正式下卡在双方水晶后方两格均能绕出，出生钳制不再引向不可达边界格心")

func _check_direct_approach_after_bridge() -> void:
	for team in [0, 1]:
		for right_lane in [false, true]:
			var x := 553.0 if right_lane else 167.0
			var pos := Vector2(x, 580.0 if team == 0 else 700.0)
			var unit: Unit = _main._spawn_unit(team, "ashe", pos, 0.0)
			unit._target = unit._find_nearest_tower()
			unit._path = PackedVector2Array([pos, Vector2(530.0 if right_lane else 190.0, 490.0 if team == 0 else 790.0)])
			unit._path_index = 1
			unit._move_direction = Vector2.ZERO
			unit._chase(0.05)
			var expected: Vector2 = pos.direction_to(unit._target.position)
			_expect(unit._move_intent.normalized().dot(expected) > 0.999 and unit._path.is_empty(), "双方左右桥出口直接朝塔接近，不追赶旧攻击站位")
			unit.position = Vector2(300.0 if not right_lane else 420.0, 760.0 if team == 0 else 520.0)
			_expect(not unit._try_direct_approach(0.05), "直接接近段穿过河岸时仍保留寻路")
			unit.free()
