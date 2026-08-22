extends SceneTree
## 阶段 3 核心机制回归检查。运行：
## Godot --headless --path . --script tests/mechanics_check.gd

var _failed := 0
var _main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_main = scene.instantiate()
	root.add_child(_main)
	current_scene = _main
	await process_frame
	_main._start_local()
	_main.set_process(false)
	_main._ai.set_process(false)

	_check_official_arena_grid()
	_check_lane_weight_field()
	_check_bridge_path()
	_check_left_spawn_crosses_without_backtracking()
	_check_bridge_corner_slides_into_entrance()
	_check_king_back_spawn_never_retreats()
	_check_unit_routes_around_friendly_tower()
	_check_right_corner_keeps_outer_side()
	_check_weighted_lane_march()
	_check_dense_group_keeps_moving()
	_check_tower_ingress_guards()
	_check_tombstone_footprint()
	_check_deploy_delay()
	_check_building_pulls_tower_target()
	_check_nearest_unit_or_building_target()
	_check_per_card_sight()
	_check_visual_state_contract()
	_check_attack_target_lock()
	_check_basic_attack_has_no_knockback()
	_check_freed_target_cleanup()
	_check_projectile_travel()
	_check_splash_and_knockback()
	_check_charge()
	_check_tower_loses_out_of_range_target()
	_check_landing_body_push_retargets_attacker()
	_check_king_activation()
	_check_pocket_deployment()
	_check_bridge_queue()
	_check_pair_collision()
	_check_mass_weighting()
	_check_lane_stress()

	if _failed == 0:
		print("[机制检查] 全部通过")
	else:
		push_error("[机制检查] %d 项失败" % _failed)
	quit(_failed)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[通过] ", message)
	else:
		_failed += 1
		push_error("[失败] " + message)

func _check_official_arena_grid() -> void:
	var dimensions_ok: bool = (
		_main.ARENA_COLUMNS == 18
		and _main.ARENA_ROWS == 32
		and is_equal_approx(_main.TILE_SIZE, 40.0)
		and is_equal_approx(_main.RIVER_HALF * 2.0, _main.TILE_SIZE * 2.0)
		and is_equal_approx(_main.BRIDGE_HALF * 2.0, _main.TILE_SIZE * 3.0)
	)
	_expect(dimensions_ok, "竞技场使用 18x32 格、两格河道与三格桥")
	var towers_ok: bool = (
		_main._towers[0].position == Vector2(140.0, 1020.0)
		and _main._towers[1].position == Vector2(580.0, 1020.0)
		and _main._towers[2].position == Vector2(140.0, 260.0)
		and _main._towers[3].position == Vector2(580.0, 260.0)
		and _main._king_player.position == Vector2(360.0, 1160.0)
		and _main._king_enemy.position == Vector2(360.0, 120.0)
	)
	_expect(towers_ok, "公主塔与国王塔落在参考项目的镜像格位")
	var split_sizes_ok: bool = (
		is_equal_approx(_main._towers[0].body_radius, 40.0)
		and is_equal_approx(_main._towers[0].visual_radius, 60.0)
		and is_equal_approx(_main._king_player.body_radius, 56.0)
		and is_equal_approx(_main._king_player.visual_radius, 80.0)
	)
	_expect(split_sizes_ok, "塔的圆形物理半径与 3x3/4x4 视觉占地分离")
	_expect(_main.is_card_deploy_position_valid(0, "xin", Vector2(20.0, 700.0)), "我方靠河左上角可部署")
	_expect(_main.is_card_deploy_position_valid(0, "xin", Vector2(700.0, 700.0)), "我方靠河右上角可部署")
	_expect(_main.is_card_deploy_position_valid(1, "xin", Vector2(20.0, 580.0)), "敌方视角对应靠河角格同样可部署")
	_expect(_main._pos_in_deploy_zone(Vector2(260.0, 1260.0), 0, false), "国王塔正后方中央格可部署")
	_expect(_main._pos_in_deploy_zone(Vector2(20.0, 1260.0), 0, false) == false, "国王塔后方两侧不可部署")
	var full_back_row := true
	for column in range(6, 12):
		full_back_row = full_back_row and _main.is_card_deploy_position_valid(0, "xin", Vector2(column * 40.0 + 20.0, 1260.0))
	_expect(full_back_row, "国王塔后方中央 6 格组成完整可部署行")
	_expect(int(ProjectSettings.get_setting("display/window/size/viewport_height")) > int(_main.FIELD_H), "手牌区位于战场之外，不遮挡最后一行")

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
	var stats: Dictionary = CardDB.all()["garen"].duplicate()
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
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var unit := Unit.new()
	# 直接放在左桥下方的外侧角点，复现斜向速度被河岸拒绝的场景。
	unit.position = Vector2(_main.BRIDGE_X_LEFT - _main.BRIDGE_HALF + 6.0, _main.RIVER_Y + _main.RIVER_HALF + unit.body_radius + 2.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var longest_stall := 0
	var stall_ticks := 0
	var previous := unit.position
	var crossed := false
	for _tick in 260:
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
	_expect(crossed and longest_stall < 8, "单位在桥角受阻时会沿河岸滑入桥口，不会卡在角落")
	unit.free()

func _check_king_back_spawn_never_retreats() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var unit := Unit.new()
	unit.position = Vector2(340.0, 1260.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var start_y := unit.position.y
	var previous_y := unit.position.y
	var never_retreated := true
	for _tick in 50:
		_main._sim_step(_main.SIM_DT)
		never_retreated = never_retreated and unit.position.y <= previous_y + 0.05
		previous_y = unit.position.y
	_expect(never_retreated and unit.position.y < start_y - 10.0, "国王塔后方合法格出兵后直接向前，不会先退一步")
	unit.free()

func _check_unit_routes_around_friendly_tower() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
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
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var unit := Unit.new()
	unit.position = Vector2(700.0, 1220.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var right_tower: Tower = _main._towers[1]
	var min_x_behind_tower := unit.position.x
	var passed_tower := false
	for _tick in 150:
		_main._sim_step(_main.SIM_DT)
		if unit.position.y >= right_tower.position.y:
			min_x_behind_tower = minf(min_x_behind_tower, unit.position.x)
		if unit.position.y < right_tower.position.y - right_tower.body_radius - unit.body_radius:
			passed_tower = true
			break
	_expect(passed_tower and min_x_behind_tower > right_tower.position.x + right_tower.body_radius, "右下角单位会从己方右塔外侧绕行，不再穿到塔左边")
	unit.free()

func _check_weighted_lane_march() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
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
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
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

func _check_tower_ingress_guards() -> void:
	var king: Tower = _main._king_player
	_expect(not _main.is_card_deploy_position_valid(0, "xin", king.position), "玩家与联机请求不能在存活国王塔上部署")
	_expect(not _main.is_card_deploy_position_valid(1, "xin", Vector2(_main.BRIDGE_X_LEFT, 250.0)), "AI 的旧出兵坐标会被统一占位校验拒绝")
	_expect(_main.is_card_deploy_position_valid(1, "xin", Vector2(_main.BRIDGE_X_LEFT, 460.0)), "AI 改用公主塔前方合法格出兵")
	var tombstone: Unit = _main._spawn_unit(0, "tombstone", Vector2(480.0, 1080.0))
	# 召唤偏移位于墓碑占地内时，生成前改到最近合法位置。
	var desired_summon := tombstone.position + Vector2(-24.0, 0.0)
	var imp: Unit = _main.spawn_summoned(0, "imp", desired_summon)
	_expect(not imp.position.is_equal_approx(desired_summon) and imp.is_walkable_at(imp.position), "召唤物生成前修正指向国王塔的非法偏移")
	# 方形绘制角附近只要没有进入塔的碰撞圆，单位就可以自然侧绕。
	var corner := king.position + Vector2(87.0, 87.0)
	var outside_old_circle: bool = corner.distance_to(king.position) > king.body_radius + 14.0
	_expect(outside_old_circle and _main.is_ground_position_walkable(corner, 14.0), "塔使用圆形碰撞，单位可沿塔角外侧通过")
	imp.free()
	tombstone._die()

func _check_tombstone_footprint() -> void:
	var snapped: Vector2 = _main._snap_card_position("tombstone", Vector2(467.0, 1093.0))
	_expect(fmod(snapped.x, _main.TILE_SIZE) == 0.0 and fmod(snapped.y, _main.TILE_SIZE) == 0.0, "2x2 墓碑中心吸附在格线交点")
	var tombstone: Unit = _main._spawn_unit(0, "tombstone", snapped)
	var half_size_ok := is_equal_approx(tombstone.body_radius, _main.TILE_SIZE)
	var first := Vector2(snapped.x - 20.0, snapped.y - 20.0)
	var occupied := true
	for offset in [Vector2.ZERO, Vector2(40.0, 0.0), Vector2(0.0, 40.0), Vector2(40.0, 40.0)]:
		occupied = occupied and not _main.nav.is_walkable(first + offset)
	_expect(half_size_ok and occupied, "墓碑实际占据完整 2x2 格并写入导航障碍")
	tombstone._die()

func _check_deploy_delay() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	var unit := Unit.new()
	unit.position = Vector2(204.0, 820.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var before := unit.position
	unit.sim_tick(0.5)
	_expect(unit.position.is_equal_approx(before) and not unit.is_deployed(), "部署时间内单位不移动、不进入战斗")
	unit.free()

func _check_building_pulls_tower_target() -> void:
	var attacker_stats: Dictionary = CardDB.all()["garen"].duplicate()
	attacker_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	attacker.position = Vector2(204.0, 760.0)
	attacker.setup(0, attacker_stats, attacker_stats.name)
	_main.add_child(attacker)
	attacker._update_target()
	var started_for_tower: bool = attacker._target is Tower
	var building_stats: Dictionary = CardDB.all()["tombstone"].duplicate()
	building_stats["deploy_time"] = 0.0
	var building := Unit.new()
	building.position = Vector2(204.0, 610.0)
	building.setup(1, building_stats, building_stats.name)
	_main.add_child(building)
	attacker._update_target()
	_expect(started_for_tower and attacker._target == building, "视野内建筑可拉走正在向塔行军的攻城单位")
	attacker.free()
	building.free()

func _check_nearest_unit_or_building_target() -> void:
	var attacker_stats: Dictionary = CardDB.all()["xin"].duplicate()
	var troop_stats: Dictionary = CardDB.all()["xin"].duplicate()
	var building_stats: Dictionary = CardDB.all()["tombstone"].duplicate()
	attacker_stats["deploy_time"] = 0.0
	troop_stats["deploy_time"] = 0.0
	building_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var troop := Unit.new()
	var building := Unit.new()
	attacker.position = Vector2(300.0, 800.0)
	troop.position = Vector2(300.0, 650.0)
	building.position = Vector2(300.0, 720.0)
	attacker.setup(0, attacker_stats, attacker_stats.name)
	troop.setup(1, troop_stats, troop_stats.name)
	building.setup(1, building_stats, building_stats.name)
	_main.add_child(attacker)
	_main.add_child(troop)
	_main.add_child(building)
	_expect(attacker._find_nearest_distraction() == building, "普通单位会选择视野内更近的敌方建筑，不固定优先兵种")
	troop.position = Vector2(300.0, 755.0)
	_expect(attacker._find_nearest_distraction() == troop, "敌方兵种更近时则改为追击兵种")
	attacker._target = building
	attacker._attacking = false
	attacker._update_target()
	_expect(attacker._target == troop, "追击期间出现更近的合法目标时会转移仇恨")
	attacker.free()
	troop.free()
	building.free()

func _check_per_card_sight() -> void:
	var melee_stats: Dictionary = CardDB.all()["masteryi"].duplicate()
	var ranged_stats: Dictionary = CardDB.all()["ashe"].duplicate()
	var enemy_stats: Dictionary = CardDB.all()["xin"].duplicate()
	for stats in [melee_stats, ranged_stats, enemy_stats]:
		stats["deploy_time"] = 0.0
	var melee := Unit.new()
	var ranged := Unit.new()
	var enemy := Unit.new()
	melee.position = Vector2(260.0, 800.0)
	ranged.position = Vector2(260.0, 840.0)
	enemy.position = Vector2(490.0, 800.0)
	melee.setup(0, melee_stats, melee_stats.name)
	ranged.setup(0, ranged_stats, ranged_stats.name)
	enemy.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(melee)
	_main.add_child(ranged)
	_main.add_child(enemy)
	_expect(melee.sight_range != ranged.sight_range, "视野已从全局常量下放到每张单位卡")
	_expect(melee._find_nearest_distraction() == null and ranged._find_nearest_distraction() == enemy, "不同单位会按自身视野范围产生仇恨")
	melee.free()
	ranged.free()
	enemy.free()

func _check_visual_state_contract() -> void:
	var stats: Dictionary = CardDB.all()["garen"].duplicate()
	var unit := Unit.new()
	unit.position = Vector2(300.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var deploy_state_ok := unit.get_visual_state_code() == 0
	unit._deploy_timer = 0.0
	unit._move_intent = Vector2.UP * unit.move_speed
	var move_state_ok := unit.get_visual_state_code() == 2
	unit._attacking = true
	var attack_state_ok := unit.get_visual_state_code() == 3
	_expect(deploy_state_ok and move_state_ok and attack_state_ok, "表现层可读取部署/移动/攻击状态，但不驱动战斗逻辑")
	_expect(unit.visual_radius > unit.body_radius and unit._presentation != null, "单位美术尺寸与物理碰撞同样已解耦")
	unit.free()

func _check_attack_target_lock() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var locked_target := Unit.new()
	var closer_target := Unit.new()
	attacker.position = Vector2(300.0, 760.0)
	locked_target.position = Vector2(300.0, 720.0)
	closer_target.position = Vector2(302.0, 750.0)
	attacker.setup(0, stats, stats.name)
	locked_target.setup(1, stats, stats.name)
	closer_target.setup(1, stats, stats.name)
	_main.add_child(attacker)
	_main.add_child(locked_target)
	_main.add_child(closer_target)
	attacker._target = locked_target
	attacker._attacking = true
	attacker._update_target()
	var kept_lock := attacker._target == locked_target
	locked_target.position = Vector2(300.0, 500.0)
	attacker._update_target()
	_expect(kept_lock, "攻击状态下不会因为出现更近目标而转火")
	_expect(attacker._target == closer_target, "原目标脱离攻击范围后才重新寻找目标")
	attacker.free()
	locked_target.free()
	closer_target.free()
func _check_basic_attack_has_no_knockback() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var target := Unit.new()
	attacker.position = Vector2(300.0, 760.0)
	target.position = Vector2(300.0, 720.0)
	attacker.setup(0, stats, stats.name)
	target.setup(1, stats, stats.name)
	_main.add_child(attacker)
	_main.add_child(target)
	attacker._target = target
	var before := target.position
	attacker.sim_tick(attacker.first_hit_time)
	_expect(attacker.attack_knockback == 0.0 and target.position.is_equal_approx(before) and target._knockback_timer == 0.0, "普通单位对打只造成伤害，不会把目标突然撞退")
	attacker.free()
	target.free()

func _check_freed_target_cleanup() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var target := Unit.new()
	attacker.position = Vector2(204.0, 800.0)
	target.position = Vector2(204.0, 700.0)
	attacker.setup(0, stats, stats.name)
	target.setup(1, stats, stats.name)
	_main.add_child(attacker)
	_main.add_child(target)
	attacker._target = target
	attacker._attacking = true
	target.free()
	attacker._update_target()
	_expect(attacker._target == null or is_instance_valid(attacker._target), "攻击中的目标释放后安全清理引用并重新索敌")
	attacker.free()

func _check_tower_loses_out_of_range_target() -> void:
	var tower: Tower = _main._towers[0]
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	var enemy := Unit.new()
	enemy.position = tower.position + Vector2(0.0, -120.0)
	enemy.setup(1, stats, stats.name)
	_main.add_child(enemy)
	tower.sim_tick(0.2)
	tower.sim_tick(0.05)
	for _i in 20:
		_main._tick_projectiles(_main.SIM_DT)
	var hp_after_hit := enemy.hp
	enemy.position = Vector2(700.0, 40.0)
	for _i in 30:
		tower.sim_tick(0.05)
		_main._tick_projectiles(0.05)
	_expect(enemy.hp == hp_after_hit, "防御塔目标离开射程后停止攻击并脱锁")
	enemy.free()

func _check_landing_body_push_retargets_attacker() -> void:
	var tower: Tower = _main._towers[0]
	var enemy_stats: Dictionary = CardDB.all()["xin"].duplicate()
	var defender_stats: Dictionary = CardDB.all()["garen"].duplicate()
	enemy_stats["deploy_time"] = 0.0
	defender_stats["deploy_time"] = _main.SIM_DT
	var enemy := Unit.new()
	var defender := Unit.new()
	var landing_pos := tower.position + Vector2(0.0, -80.0)
	enemy.position = landing_pos
	defender.position = landing_pos
	enemy.setup(1, enemy_stats, enemy_stats.name)
	defender.setup(0, defender_stats, defender_stats.name)
	_main.add_child(enemy)
	_main.add_child(defender)
	enemy._target = tower
	enemy._attacking = true
	var before_distance := enemy.position.distance_to(tower.position)
	var overlap_deploy_allowed: bool = _main.is_card_deploy_position_valid(0, "garen", landing_pos)
	_main._sim_step(_main.SIM_DT)
	var pushed_from_tower := enemy.position.distance_to(tower.position) > before_distance + 1.0
	var no_fake_knockback := enemy._knockback_timer == 0.0 and defender._knockback_timer == 0.0
	_main._sim_step(_main.SIM_DT)
	_expect(overlap_deploy_allowed, "部署校验允许在塔前已有可移动单位下方落兵")
	_expect(pushed_from_tower and no_fake_knockback, "大体积单位落地会通过体积/质量把塔前小单位挤开，不伪造击退状态")
	_expect(enemy._target == defender, "攻塔单位被挤出射程后会解锁塔并改为攻击新落地单位")
	enemy.free()
	defender.free()

func _check_projectile_travel() -> void:
	var attacker_stats: Dictionary = CardDB.all()["ashe"].duplicate()
	attacker_stats["deploy_time"] = 0.0
	var target_stats: Dictionary = CardDB.all()["xin"].duplicate()
	target_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var target := Unit.new()
	attacker.position = Vector2(200.0, 800.0)
	target.position = Vector2(320.0, 800.0)
	attacker.setup(0, attacker_stats, attacker_stats.name)
	target.setup(1, target_stats, target_stats.name)
	_main.add_child(attacker)
	_main.add_child(target)
	var hp_before := target.hp
	_main.launch_attack(attacker, target, 50.0, attacker.projectile_speed, 0.0, 0.0, attacker.color)
	_expect(target.hp == hp_before and not _main._projectiles.is_empty(), "远程攻击先生成弹道，不会瞬时扣血")
	for _i in 12:
		_main._tick_projectiles(_main.SIM_DT)
	_expect(target.hp < hp_before and _main._projectiles.is_empty(), "弹道抵达目标碰撞圆后才结算伤害")
	attacker.free()
	target.free()

func _check_splash_and_knockback() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var primary := Unit.new()
	var secondary := Unit.new()
	attacker.position = Vector2(220.0, 800.0)
	primary.position = Vector2(300.0, 800.0)
	secondary.position = Vector2(340.0, 800.0)
	attacker.setup(0, stats, stats.name)
	primary.setup(1, stats, stats.name)
	secondary.setup(1, stats, stats.name)
	_main.add_child(attacker)
	_main.add_child(primary)
	_main.add_child(secondary)
	var primary_hp := primary.hp
	var secondary_hp := secondary.hp
	_main.launch_attack(attacker, primary, 30.0, 0.0, 34.0, 28.0, attacker.color)
	_expect(primary.hp < primary_hp and secondary.hp < secondary_hp, "范围攻击按命中点和碰撞圆伤害多个目标")
	var before_push := primary.position.x
	primary.sim_tick(_main.SIM_DT)
	_main._apply_unit_movement(_main.SIM_DT)
	_expect(primary.position.x > before_push, "击退方向远离攻击来源并按固定模拟移动")
	attacker.free()
	primary.free()
	secondary.free()

func _check_charge() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = Vector2(204.0, 850.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	for _i in 42:
		unit.sim_tick(_main.SIM_DT)
		_main._apply_unit_movement(_main.SIM_DT)
	_expect(unit.is_charged(), "连续移动达到阈值后进入冲锋状态")
	unit.free()

func _check_king_activation() -> void:
	var king: Tower = _main._king_player
	_main._towers[0].hp = 0.0
	_main._sim_step(_main.SIM_DT)
	_expect(king.activated, "任一公主塔被摧毁后国王塔激活")

func _check_pocket_deployment() -> void:
	_main._towers[2].hp = 0.0
	_main._sim_step(_main.SIM_DT)
	var left_pocket := Vector2(204.0, 520.0)
	var right_pocket := Vector2(516.0, 520.0)
	_expect(_main._pos_in_deploy_zone(left_pocket, 0, false), "破坏左路公主塔后解锁对应 pocket 部署区")
	_expect(not _main._pos_in_deploy_zone(right_pocket, 0, false), "未破坏的另一路不会提前解锁部署区")

func _check_bridge_queue() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
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
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
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
	var heavy_stats: Dictionary = CardDB.all()["garen"].duplicate()
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

func _check_lane_stress() -> void:
	var spawned: Array[Unit] = []
	for i in 6:
		var card_id := "garen" if i % 3 == 0 else ("xin" if i % 3 == 1 else "masteryi")
		var stats: Dictionary = CardDB.all()[card_id].duplicate()
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
