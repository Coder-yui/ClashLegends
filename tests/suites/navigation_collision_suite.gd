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
	_check_dense_group_keeps_moving()
	_check_bridge_queue()
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
	_expect(absf(rear_velocity.x) < absf(rear_velocity.y), "局部侧移用于找空隙，但不会取代主要推进方向")
	front.free()
	rear.free()

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
	var light_stats: Dictionary = CardDB.imp_stats().duplicate()
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
