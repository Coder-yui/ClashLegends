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
	_check_structure_art_integration()
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
	_check_unit_size_tiers()
	_check_visual_state_contract()
	_check_hit_flash_presentation()
	_check_health_bar_team_anchor()
	_check_shared_render_interpolation()
	_check_unit_reaches_and_damages_tower()
	_check_garen_death_animation()
	_check_masteryi_art_integration()
	_check_ashe_art_integration()
	_check_gwen_mechanic()
	_check_gwen_tower_combat()
	_check_gwen_art_integration()
	_check_sett_attack_rhythm()
	_check_sett_art_integration()
	_check_teemo_art_integration()
	_check_attack_target_lock()
	_check_attack_hit_recovery_commitment()
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
	var tower_sizes_ok: bool = (
		is_equal_approx(_main._towers[0].body_radius, 54.0)
		and is_equal_approx(_main._towers[0].visual_radius, 60.0)
		and is_equal_approx(_main._towers[0].deployment_radius, 54.0)
		and is_equal_approx(_main._king_player.body_radius, 72.0)
		and is_equal_approx(_main._king_player.visual_radius, 80.0)
		and is_equal_approx(_main._king_player.deployment_radius, 72.0)
	)
	_expect(tower_sizes_ok, "塔与水晶保持原视觉尺寸，同时缩小物理和部署碰撞圆")
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

func _check_structure_art_integration() -> void:
	var wrapper_paths := [
		"res://assets/towers/princess/princess_tower_blue_view.tscn",
		"res://assets/towers/princess/princess_tower_red_view.tscn",
		"res://assets/towers/nexus/nexus_blue_view.tscn",
		"res://assets/towers/nexus/nexus_red_view.tscn",
	]
	var wrappers_load := true
	for wrapper_path in wrapper_paths:
		wrappers_load = wrappers_load and load(wrapper_path) is PackedScene
	_expect(wrappers_load, "蓝红双方防御塔与基地水晶包装场景均可加载")

	var views: Array[TowerModel3D] = []
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D:
			views.append(child as TowerModel3D)
	var views_ok := views.size() == 6
	var orientation_ok := true
	var surfaces_ok := true
	var animations_ok := true
	for view in views:
		views_ok = views_ok and view._source.has_model_art and view._ground_clip_material_count >= 2
		var expected_yaw := PI if view._source.team == 0 else 0.0
		orientation_ok = orientation_ok and is_equal_approx(view.rotation.y, expected_yaw)
		var alive_names: Array = view._animations.get("alive_materials", [])
		var destroyed_names: Array = view._animations.get("destroyed_materials", [])
		for material_name in alive_names:
			for material in view._surface_materials_by_name.get(String(material_name), []):
				surfaces_ok = surfaces_ok and is_equal_approx(float(material.get_shader_parameter("surface_visible")), 1.0)
		for material_name in destroyed_names:
			for material in view._surface_materials_by_name.get(String(material_name), []):
				surfaces_ok = surfaces_ok and is_equal_approx(float(material.get_shader_parameter("surface_visible")), 0.0)
		for animation_key in ["spawn", "idle", "destroy"]:
			animations_ok = animations_ok and view._animation_player.has_animation(String(view._animations[animation_key]))
	_expect(views_ok, "六座建筑都使用独立 3D 表现代理，并为地上/地下表面启用动态地面裁切")
	_expect(orientation_ok, "蓝方塔朝向红方、红方塔朝向蓝方")
	_expect(surfaces_ok, "存活时仅显示塔体/水晶 startup 部件，隐藏 Rubble/Destroyed 部件")
	_expect(animations_ok, "防御塔与水晶的出生、待机和摧毁动画映射均存在")

	var temp_tower := Tower.new()
	temp_tower.setup(0, _main.PRINCESS_STATS, false)
	temp_tower.position = Vector2(360.0, 800.0)
	_main.add_child(temp_tower)
	var attached: bool = _main._battle_presentation.attach_tower(temp_tower, _main.PRINCESS_VISUAL_CONFIG)
	var temp_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == temp_tower:
			temp_view = child as TowerModel3D
			break
	var destroyed_events := [0]
	temp_tower.destroyed.connect(func() -> void: destroyed_events[0] += 1)
	temp_tower.take_damage(temp_tower.max_hp + 1.0)
	temp_tower.notify_visual_destroyed()
	var destroy_state_ok := attached and temp_view != null and temp_view._destroyed
	if temp_view != null:
		destroy_state_ok = destroy_state_ok and temp_view._animation_player.current_animation == "Destroyed"
		for material in temp_view._surface_materials_by_name.get("Base", []):
			destroy_state_ok = destroy_state_ok and is_equal_approx(float(material.get_shader_parameter("surface_visible")), 0.0)
		for material in temp_view._surface_materials_by_name.get("Rubble", []):
			destroy_state_ok = destroy_state_ok and is_equal_approx(float(material.get_shader_parameter("surface_visible")), 1.0)
	_expect(destroyed_events[0] == 1 and destroy_state_ok, "塔被摧毁时只触发一次表现事件，并切换到 Destroyed 动画与 Rubble 废墟")
	if temp_view != null:
		temp_view.free()
	temp_tower.free()

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
	var bridge_centers: Array[float] = [_main.BRIDGE_X_LEFT, _main.BRIDGE_X_RIGHT]
	var all_crossed := true
	var worst_stall := 0
	# 覆盖两座桥的左右四个桥—水交角，并使用当前最大的实际人物（盖伦）验证圆柱净空。
	for bridge_x in bridge_centers:
		for side_sign in [-1.0, 1.0]:
			var stats: Dictionary = CardDB.all()["garen"].duplicate()
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
	var stats: Dictionary = CardDB.all()["garen"].duplicate()
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
	enemy.position = Vector2(510.0, 800.0)
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

func _check_unit_size_tiers() -> void:
	var cards := CardDB.all()
	var expected := {
		"garen": [CardDB.SIZE_LARGE, CardDB.RADIUS_LARGE],
		"masteryi": [CardDB.SIZE_MEDIUM, CardDB.RADIUS_MEDIUM],
		"sett": [CardDB.SIZE_SLIGHTLY_LARGE, CardDB.RADIUS_SLIGHTLY_LARGE],
		"ashe": [CardDB.SIZE_MEDIUM, CardDB.RADIUS_MEDIUM],
		"teemo": [CardDB.SIZE_SMALL, CardDB.RADIUS_SMALL],
		"xin": [CardDB.SIZE_MEDIUM, CardDB.RADIUS_MEDIUM],
		"aurelionsol": [CardDB.SIZE_SLIGHTLY_LARGE, CardDB.RADIUS_SLIGHTLY_LARGE],
		"gwen": [CardDB.SIZE_MEDIUM, CardDB.RADIUS_MEDIUM],
	}
	var tiers_ok := true
	for card_id in expected:
		var stats: Dictionary = cards[card_id]
		var spec: Array = expected[card_id]
		tiers_ok = tiers_ok and stats.size_tier == spec[0] and is_equal_approx(stats.radius, spec[1])
	var imp := CardDB.imp_stats()
	tiers_ok = tiers_ok and imp.size_tier == CardDB.SIZE_EXTREMELY_SMALL
	tiers_ok = tiers_ok and is_equal_approx(imp.radius, CardDB.RADIUS_EXTREMELY_SMALL)
	tiers_ok = tiers_ok and [
		CardDB.RADIUS_EXTREMELY_SMALL,
		CardDB.RADIUS_SMALL,
		CardDB.RADIUS_SLIGHTLY_SMALL,
		CardDB.RADIUS_MEDIUM,
		CardDB.RADIUS_SLIGHTLY_LARGE,
		CardDB.RADIUS_LARGE,
		CardDB.RADIUS_EXTREMELY_LARGE,
	] == [9.0, 12.0, 15.0, 18.0, 21.0, 24.0, 27.0]
	_expect(tiers_ok, "盖伦/剑圣/瑟提/寒冰/提莫/赵信/龙王/小鬼/格温使用指定的七档体型")

	var large := Unit.new()
	var tiny := Unit.new()
	large.setup(0, cards.garen, cards.garen.name)
	tiny.setup(0, imp, imp.name)
	_expect(
		is_equal_approx(large.body_radius, CardDB.RADIUS_LARGE)
		and is_equal_approx(tiny.body_radius, CardDB.RADIUS_EXTREMELY_SMALL)
		and large.body_radius > tiny.body_radius
		and is_equal_approx(CardDB.CHARACTER_SCALE_MULTIPLIER, 1.5)
		and Unit.COLLISION_SHAPE == &"cylinder",
		"人物整体放大 1.5 倍，体型档位直接写入权威圆柱碰撞半径"
	)
	large.free()
	tiny.free()

	var model_scales := {
		"garen": 0.015,
		"masteryi": 0.01815,
		"sett": 0.013125,
		"ashe": 0.012,
		"teemo": 0.01185,
		"gwen": 0.00945,
	}
	var models_scaled := true
	for card_id in model_scales:
		var packed := load(cards[card_id].visual_scene_path) as PackedScene
		var sample := packed.instantiate() as Node3D if packed != null else null
		var model := sample.get_node_or_null("Model") as Node3D if sample != null else null
		models_scaled = models_scaled and model != null and is_equal_approx(model.scale.x, model_scales[card_id])
		if sample != null:
			sample.free()
	_expect(models_scaled, "所有已接入人物模型的包装场景均在当前尺寸基础上放大 1.5 倍")

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
	# 单位 2D 层（血条/状态圈）必须整体盖在塔/水晶 2D 层之上，贴身攻塔时血条才不会被建筑血条挡住。
	var air_stats: Dictionary = CardDB.all()["aurelionsol"].duplicate()
	var air_unit := Unit.new()
	air_unit.position = Vector2(300.0, 900.0)
	air_unit.setup(0, air_stats, air_stats.name)
	_main.add_child(air_unit)
	var z_layers_ok: bool = (
		_main._towers[0].z_index == 10
		and _main._king_player.z_index == 10
		and unit.z_index > _main._towers[0].z_index
		and air_unit.z_index > unit.z_index
	)
	_expect(z_layers_ok, "单位血条 2D 层位于塔/水晶层之上，空中单位再高于地面单位")
	air_unit.free()
	unit.free()

func _check_hit_flash_presentation() -> void:
	var stats: Dictionary = CardDB.all()["garen"].duplicate(true)
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	var view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			view = child as UnitModel3D
			break
	unit.take_damage(1.0)
	var flashed := attached and view != null and view._hit_flash_timer > 0.0 and not view._flash_meshes.is_empty()
	var health_bar_above_head := view != null and unit._health_bar_y < -unit.visual_radius - Unit.HEALTH_BAR_HEAD_GAP
	var flash_is_subtle := flashed and view._hit_flash_timer <= 0.051 and is_equal_approx(view._hit_flash_material.albedo_color.a, 0.22)
	if flashed:
		for mesh_instance in view._flash_meshes:
			flashed = flashed and mesh_instance.material_overlay == view._hit_flash_material
	view._update_hit_flash(0.05)
	unit.take_damage(1.0)
	var continuous_damage_throttled := view != null and view._hit_flash_timer <= 0.05
	view._update_hit_flash(0.1)
	var restored := view != null and view._hit_flash_timer <= 0.0
	if restored:
		for i in range(view._flash_meshes.size()):
			restored = restored and view._flash_meshes[i].material_overlay == view._original_overlays[i]
	_expect(flashed and flash_is_subtle and restored and continuous_damage_throttled and _main.has_method("_rpc_unit_hit"), "单位受击短暂轻微泛白后恢复，持续伤害限频且联机使用可靠表现事件")
	_expect(health_bar_above_head, "3D 单位血条按模型投影顶部定位在人物头顶上方")
	if view != null:
		view.free()
	unit.free()

func _check_health_bar_team_anchor() -> void:
	var stats: Dictionary = CardDB.all()["garen"].duplicate(true)
	stats["deploy_time"] = 0.0
	var blue := Unit.new()
	var red := Unit.new()
	blue.position = Vector2(260.0, 880.0)
	red.position = Vector2(460.0, 320.0)
	blue.setup(0, stats, stats.name)
	red.setup(1, stats, stats.name)
	_main.add_child(blue)
	_main.add_child(red)
	var blue_attached: bool = _main._battle_presentation.attach_unit(blue, stats)
	var red_attached: bool = _main._battle_presentation.attach_unit(red, stats)
	var blue_view: UnitModel3D = null
	var red_view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == blue:
			blue_view = child as UnitModel3D
		elif child is UnitModel3D and child._source == red:
			red_view = child as UnitModel3D
	if blue_view != null:
		blue_view._update_health_bar_anchor()
	if red_view != null:
		red_view._update_health_bar_anchor()
	var bar_gap := Unit.HEALTH_BAR_HEAD_GAP + Unit.HEALTH_BAR_HEIGHT * 0.5
	var blue_head := blue.get_visual_head_screen_position()
	var red_head := red.get_visual_head_screen_position()
	var blue_bar := blue.get_health_bar_screen_center()
	var red_bar := red.get_health_bar_screen_center()
	var blue_ok: bool = blue_attached and blue_view != null and is_equal_approx(blue_head.y - blue_bar.y, bar_gap)
	var red_ok: bool = red_attached and red_view != null and is_equal_approx(red_head.y - red_bar.y, bar_gap)
	var flip_camera := Camera2D.new()
	flip_camera.position = Vector2(_main.FIELD_W * 0.5, _main.FIELD_H * 0.5)
	flip_camera.rotation = PI
	_main.add_child(flip_camera)
	flip_camera.make_current()
	if blue_view != null:
		blue_view._update_health_bar_anchor()
	if red_view != null:
		red_view._update_health_bar_anchor()
	var flipped_blue_head := blue.get_visual_head_screen_position()
	var flipped_red_head := red.get_visual_head_screen_position()
	var flipped_blue_bar := blue.get_health_bar_screen_center()
	var flipped_red_bar := red.get_health_bar_screen_center()
	var flipped_ok: bool = (
		is_equal_approx(flipped_blue_head.y - flipped_blue_bar.y, bar_gap)
		and is_equal_approx(flipped_red_head.y - flipped_red_bar.y, bar_gap)
	)
	var colors_ok: bool = blue.get_health_bar_fill_color() == Color(0.2, 0.9, 0.2) and red.get_health_bar_fill_color() == Color(0.95, 0.25, 0.25)
	_expect(blue_ok and red_ok and flipped_ok and colors_ok, "红蓝双方血条统一贴在头顶上方，敌方血条显示为红色")
	flip_camera.free()
	if blue_view != null:
		blue_view.free()
	if red_view != null:
		red_view.free()
	blue.free()
	red.free()

func _check_shared_render_interpolation() -> void:
	var stats: Dictionary = CardDB.all()["masteryi"].duplicate(true)
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = Vector2(300.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	unit._prev_pos = Vector2(300.0, 900.0)
	unit.position = Vector2(300.0, 903.9)
	var saved_accumulator: float = _main._sim_acc
	_main._sim_acc = 0.0
	var at_start := unit.get_visual_screen_position()
	_main._sim_acc = _main.SIM_DT * 0.5
	var at_half := unit.get_visual_screen_position()
	_main._sim_acc = _main.SIM_DT
	var at_end := unit.get_visual_screen_position()
	_main._sim_acc = saved_accumulator
	var monotonic := at_start.y < at_half.y and at_half.y < at_end.y
	var exact := is_equal_approx(at_start.y, 900.0) and is_equal_approx(at_half.y, 901.95) and is_equal_approx(at_end.y, 903.9)
	_expect(monotonic and exact, "高速单位使用主模拟器统一 alpha 在前后状态间单调插值")
	unit.free()

func _check_unit_reaches_and_damages_tower() -> void:
	var stats: Dictionary = CardDB.all()["garen"].duplicate(true)
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var tower: Tower = _main._towers[3]
	var unit := Unit.new()
	var stop_distance: float = tower.body_radius + stats.radius + stats.range
	unit.position = tower.position + Vector2.DOWN * (stop_distance + 12.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	unit._target = tower
	var hp_before := tower.hp
	tower.frozen_timer = 5.0
	for _tick in 60:
		_main._sim_step(_main.SIM_DT)
	_expect(tower.hp < hp_before, "攻城单位会补齐 A* 末端距离并对塔造成伤害")
	var hit_ratio := unit.first_hit_time / unit.attack_interval
	_expect(hit_ratio > 0.3 and hit_ratio < 0.4, "盖伦权威命中点提前到完整攻击周期约 35%")
	_expect(unit.get_attack_visual_serial() >= 2, "连续真实攻击会产生递增的独立表现序号")
	var attack_animations: Array = stats.visual_animations.attack
	_expect(attack_animations == ["Attack1", "Attack2"], "盖伦两套攻击动作按表现序号交替选择")
	tower.hp = hp_before
	tower.frozen_timer = 0.0
	if is_instance_valid(unit):
		unit.free()

func _check_garen_death_animation() -> void:
	var stats: Dictionary = CardDB.all()["garen"].duplicate(true)
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	var death_signal_count := [0]
	unit.died.connect(func() -> void: death_signal_count[0] += 1)
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var view := child as UnitModel3D
			death_view_found = view._dying and view._animation_player.current_animation == "Death"
			view.free()
			break
	_expect(attached and death_signal_count[0] == 1 and death_view_found, "盖伦死亡时立即退出战斗并由独立 3D 代理播放 Death")
	if is_instance_valid(unit):
		unit.free()

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null

func _check_masteryi_art_integration() -> void:
	var stats: Dictionary = CardDB.all()["masteryi"].duplicate(true)
	stats["deploy_time"] = 0.0
	var packed := load(stats.visual_scene_path) as PackedScene
	_expect(packed != null, "剑圣包装场景可加载")
	if packed == null:
		return
	var anim_names: Dictionary = stats.visual_animations
	var sample := packed.instantiate() as Node3D
	var anim_player := _find_anim_player(sample)
	var names_found := true
	for key in ["deploy", "idle", "move", "death"]:
		var animation_name: String = anim_names.get(key, "")
		names_found = names_found and animation_name != "" and anim_player != null and anim_player.has_animation(animation_name)
	_expect(names_found, "剑圣 Idle/Run/A 两套普攻/Death/Deploy 动画名在源模型中都存在")
	var attacks: Array = anim_names.attack
	_expect(attacks == ["masteryi_2013_attack1_anm", "masteryi_2013_attack2_anm"], "剑圣两套攻击动作按表现序号交替选择")
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := false
	var process_order_ok := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var view := child as UnitModel3D
			death_view_found = view._dying and view._animation_player.current_animation == "Death"
			process_order_ok = view.process_priority > unit.process_priority
			view.free()
			break
	_expect(attached and death_view_found, "剑圣死亡时由独立 3D 代理播放完整 Death")
	_expect(process_order_ok, "客户端 3D 代理在 Unit 快照插值完成后读取最终位置")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

func _check_ashe_art_integration() -> void:
	var stats: Dictionary = CardDB.all()["ashe"].duplicate(true)
	stats["deploy_time"] = 0.0
	var packed := load(stats.visual_scene_path) as PackedScene
	_expect(packed != null, "寒冰包装场景可加载")
	if packed == null:
		return
	var anim_names: Dictionary = stats.visual_animations
	var sample := packed.instantiate() as Node3D
	var anim_player := _find_anim_player(sample)
	var names_found := true
	for key in ["deploy", "idle", "move", "death"]:
		var animation_name: String = anim_names.get(key, "")
		names_found = names_found and animation_name != "" and anim_player != null and anim_player.has_animation(animation_name)
	for attack in anim_names.attack:
		names_found = names_found and anim_player != null and anim_player.has_animation(String(attack))
	_expect(names_found, "寒冰 Idle/Run/两套普攻/Death 动画名在源模型中都存在")
	_expect(anim_names.attack == ["Attack1", "Attack2"], "寒冰两套射箭动作按表现序号交替选择")
	_expect(stats.projectile_visual == "arrow" and is_equal_approx(stats.first_hit / stats.interval, 0.45), "寒冰在攻击动画约 45% 的离弦姿态生成蓝色箭矢")
	_expect(is_equal_approx(stats.projectile_visual_height, 45.0), "寒冰放大后箭矢绘制点同步抬到新的弓部高度")
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var view := child as UnitModel3D
			death_view_found = view._dying and view._animation_player.current_animation == "Death"
			view.free()
			break
	_expect(attached and death_view_found, "寒冰死亡时由独立 3D 代理播放完整 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

func _check_gwen_mechanic() -> void:
	var gwen_stats: Dictionary = CardDB.all()["gwen"].duplicate(true)
	var enemy_stats: Dictionary = CardDB.all()["xin"].duplicate(true)
	gwen_stats["deploy_time"] = 0.0
	gwen_stats["hp"] = 1000.0
	enemy_stats["deploy_time"] = 0.0
	var gwen := Unit.new()
	var foe := Unit.new()
	gwen.position = Vector2(300.0, 800.0)
	foe.position = Vector2(300.0, 760.0)
	gwen.setup(0, gwen_stats, gwen_stats.name)
	foe.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(gwen)
	_main.add_child(foe)
	_expect(is_equal_approx(gwen.shroud_radius, 120.0), "格温缠流半径读取为 3 格（120px）")
	# 未开启时：圈外敌方能看到她，攻击造成完整伤害
	var far := Unit.new()
	far.position = Vector2(300.0, 660.0)   # 距 gwen 140px > 120，属圈外
	far.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(far)
	_expect(not gwen.is_hidden_from(far), "未开启时，圈外敌方能看到格温")
	_expect(far._target_is_attackable(gwen), "未开启时，圈外敌方能把格温锁定为目标")
	far.free()
	# 首次普攻命中 → 开启丝缕缠流
	var activated := false
	for _i in 60:
		_main._sim_step(_main.SIM_DT)
		if gwen._shroud_active:
			activated = true
			break
	_expect(activated, "格温首次普攻命中后开启丝缕缠流")
	_expect(gwen._shroud_active, "锁定在攻中时，缠流处于开启状态")
	# 开启后：圈外敌方/塔看不到她，无法锁定、不会攻击
	far = Unit.new()
	far.position = Vector2(300.0, 660.0)
	far.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(far)
	_expect(gwen.is_hidden_from(far), "开启后，圈外敌方看不到格温")
	_expect(not far._target_is_attackable(gwen), "开启后，圈外敌方不会把格温锁定为目标")
	far._target = gwen
	far._attacking = false
	far._update_target()
	_expect(far._target != gwen, "正在圈外追击的敌方会立即丢失格温并重新行动")
	var tower := Tower.new()
	tower.team = 1
	tower.position = Vector2(300.0, 620.0)
	_main.add_child(tower)
	_expect(gwen.is_hidden_from(tower), "开启后，圈外塔也看不到格温")
	tower.free()
	# 圈内的敌方仍能看到并攻击
	var near := Unit.new()
	near.position = Vector2(300.0, 760.0)   # 距 40px < 100，属圈内
	near.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(near)
	_expect(not gwen.is_hidden_from(near), "圈内敌方能看到格温")
	var in_hp := gwen.hp
	_main.launch_attack(near, gwen, 30.0, 0.0, 0.0, 0.0, near.color)
	_expect(gwen.hp == in_hp - 30.0, "圈内敌方的攻击仍然生效")
	# 弹体已在空中、格温随后开启缠流 → 圈外弹体立即失去目标并消散。
	# 隔离：清掉圈内目标保证飞行期间 hp 只受这支弹体影响；foe 保留存活以维持格温攻击态。
	near.free()
	foe.damage = 0.0   # foe 只在圈内站桩，确保攻击态持续但不产生正常伤害
	gwen._shroud_active = false
	var inb_hp := gwen.hp
	var shooter := Unit.new()
	shooter.position = Vector2(300.0, 600.0)   # 距 200px，圈外射手
	shooter.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(shooter)
	_main.launch_attack(shooter, gwen, 50.0, 600.0, 0.0, 0.0, shooter.color)
	var launched_before_shroud: bool = not _main._projectiles.is_empty()
	gwen.on_attack_landed()
	_main._tick_projectiles(_main.SIM_DT)
	_expect(launched_before_shroud and _main._projectiles.is_empty() and gwen.hp == inb_hp, "弹体飞行中开启缠流时，圈外弹体立即消散且不造成伤害")
	# 攻击者在弹体飞行途中死亡，仍使用其最后位置判断，不能因来源节点释放而穿透缠流。
	gwen._shroud_active = false
	_main.launch_attack(shooter, gwen, 50.0, 600.0, 0.0, 0.0, shooter.color)
	var launched_before_source_freed: bool = not _main._projectiles.is_empty()
	shooter.free()
	gwen.on_attack_landed()
	_main._tick_projectiles(_main.SIM_DT)
	_expect(launched_before_source_freed and _main._projectiles.is_empty() and gwen.hp == inb_hp, "攻击者死亡后，弹体仍按最后来源位置被缠流拦截")
	# 缠流已经开启时，圈外来源不能创建新的弹体。
	var blocked_shooter := Unit.new()
	blocked_shooter.position = Vector2(300.0, 600.0)
	blocked_shooter.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(blocked_shooter)
	_main.launch_attack(blocked_shooter, gwen, 50.0, 600.0, 0.0, 0.0, blocked_shooter.color)
	_expect(_main._projectiles.is_empty(), "缠流开启后，圈外攻击者无法继续向格温发射弹体")
	blocked_shooter.free()
	# 目标死亡 → 退出攻击状态 → 关闭缠流，敌方又能看到并攻击
	far.free()
	foe.hp = 0.0
	foe.queue_free()
	for _i in 20:
		_main._sim_step(_main.SIM_DT)
	_expect(not gwen._shroud_active, "目标死亡、格温退出攻击状态后缠流关闭")
	var observer := Unit.new()
	observer.position = Vector2(300.0, 660.0)
	observer.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(observer)
	_expect(not gwen.is_hidden_from(observer), "缠流关闭后，圈外敌方又能看到格温")
	observer.free()
	gwen.free()

## 缠流扩大到 3 格后的推塔回归：格温贴身攻击时，公主塔心距她 ≤ 54+18+30=102px、
## 水晶心距她 ≤ 72+18+30=120px，都落在 120px 缠流圈内 → 塔和水晶能看见她并反击，
## 修复旧版 100px 半径下"圈外塔心看不到格温"导致的无伤推塔。
func _check_gwen_tower_combat() -> void:
	var gwen_stats: Dictionary = CardDB.all()["gwen"].duplicate(true)
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
	_expect(gwen._shroud_active, "格温攻击公主塔首次命中后开启丝缕缠流")
	_expect(tower.hp < tower_hp, "格温对公主塔持续输出")
	_expect(gwen.hp < gwen_hp, "缠流开启后，贴身的公主塔仍在圈内，能看见并反击格温")
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
	_expect(attacker._shroud_active, "格温攻击水晶首次命中后开启丝缕缠流")
	_expect(king.hp < king_hp, "格温对水晶持续输出")
	_expect(king.activated, "水晶受到攻击后激活")
	_expect(attacker.hp < attacker_hp, "缠流开启后，贴身的水晶仍在圈内，能看见并反击格温")
	# 水晶同样接入受击闪白表现。
	var king_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == king:
			king_view = child as TowerModel3D
			break
	_expect(king_view != null and king_view._hit_flash_timer > 0.0, "水晶受击后 3D 模型同步轻微闪白")
	attacker.free()
	# 还原现场：公主塔解冻、水晶回到初始血量与休眠状态，不影响后续测试。
	left_princess.frozen_timer = 0.0
	tower.frozen_timer = 0.0
	king.hp = king_hp
	king.activated = king_was_active

func _check_gwen_art_integration() -> void:
	var stats: Dictionary = CardDB.all()["gwen"].duplicate(true)
	stats["deploy_time"] = 0.0
	var packed := load(stats.visual_scene_path) as PackedScene
	_expect(packed != null, "格温包装场景可加载")
	if packed == null:
		return
	var anim_names: Dictionary = stats.visual_animations
	var sample := packed.instantiate() as Node3D
	var model_node := sample.get_node_or_null("Model") as Node3D
	_expect(model_node != null and is_equal_approx(model_node.position.y, -0.045), "格温放大后脚底校正同步缩放，模型仍落在地面")
	var anim_player := _find_anim_player(sample)
	var names_found := true
	for key in ["deploy", "idle", "move", "death"]:
		var animation_name: String = anim_names.get(key, "")
		names_found = names_found and animation_name != "" and anim_player != null and anim_player.has_animation(animation_name)
	for attack in anim_names.attack:
		names_found = names_found and anim_player != null and anim_player.has_animation(String(attack))
	_expect(names_found, "格温 Idle/Run/三套普攻/Death/Deploy 动画名在源模型中都存在")
	var attacks: Array = anim_names.attack
	_expect(attacks == ["Attack1", "Attack2", "Attack3"], "格温三套攻击动作按表现序号交替选择")
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var view := child as UnitModel3D
			death_view_found = view._dying and view._animation_player.current_animation == "Death"
			view.free()
			break
	_expect(attached and death_view_found, "格温死亡时由独立 3D 代理播放完整 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

## 腕豪连招节奏：快速两拳(0.28)→停顿(1.05)→快速两拳(0.28)→停顿(1.05) 循环。
func _check_sett_attack_rhythm() -> void:
	var stats: Dictionary = CardDB.all()["sett"].duplicate(true)
	stats["deploy_time"] = 0.0
	_expect(stats.attack_pattern == [0.28, 1.05, 0.28, 1.05], "腕豪配置了 两拳→停顿→两拳→停顿 的连招节奏")
	var unit := Unit.new()
	unit.setup(0, stats, stats.name)
	# 逐个取出连招间距，验证节奏确实按数组循环
	var expected: Array = [0.28, 1.05, 0.28, 1.05]
	var rhythm_ok := true
	for i in range(8):
		var gap: float = unit._next_attack_gap()
		rhythm_ok = rhythm_ok and is_equal_approx(gap, float(expected[i % expected.size()]))
	_expect(rhythm_ok, "腕豪连招间距按 两拳→停顿→两拳→停顿 依次循环")
	unit.free()

## 腕豪美术集成：包装场景可加载，模型落到地面，动画名在源模型中存在，死亡由 3D 代理播放。
func _check_sett_art_integration() -> void:
	var stats: Dictionary = CardDB.all()["sett"].duplicate(true)
	stats["deploy_time"] = 0.0
	var packed := load(stats.visual_scene_path) as PackedScene
	_expect(packed != null, "腕豪包装场景可加载")
	if packed == null:
		return
	var anim_names: Dictionary = stats.visual_animations
	var sample := packed.instantiate() as Node3D
	var anim_player := _find_anim_player(sample)
	var names_found := true
	for key in ["deploy", "idle", "move", "death"]:
		var animation_name: String = anim_names.get(key, "")
		names_found = names_found and animation_name != "" and anim_player != null and anim_player.has_animation(animation_name)
	for key in ["attack", "attack_hit", "attack_recover"]:
		for animation_value in anim_names.get(key, []):
			if String(animation_value).is_empty():
				continue
			names_found = names_found and anim_player != null and anim_player.has_animation(String(animation_value))
	_expect(names_found, "腕豪 Idle/Run/四段普攻/两段收势/Death/Deploy 动画名在源模型中都存在")
	var starts_ok: bool = anim_names.attack == ["Attack1_Start", "Attack1_Passive_Start", "Attack2_Start", "Attack2_Passive_Start"]
	var hits_ok: bool = anim_names.attack_hit == ["Attack1_Hit", "Sett_Attack1_Passive_anm", "Attack2_Hit", "Sett_Attack2_Passive_anm"]
	var recovers_ok: bool = anim_names.attack_recover == ["", "Attack1_Passive_Into_Idle", "", "Attack2_Passive_Into_Idle"]
	_expect(starts_ok and hits_ok and recovers_ok, "腕豪按第一套左/右拳、收势、第二套左/右拳、收势循环，不再使用 Q 技能动画")
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	var staged_attacks_ok := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var staged_view := child as UnitModel3D
			staged_view._play_attack(1)
			var left_start_ok: bool = staged_view._animation_player.current_animation == "Attack1_Start"
			staged_view._update_attack_stages(unit.first_hit_time + 0.01)
			var left_hit_ok: bool = staged_view._animation_player.current_animation == "Attack1_Hit"
			staged_view._play_attack(2)
			staged_view._update_attack_stages(unit.first_hit_time + 0.01)
			var right_hit_ok: bool = staged_view._animation_player.current_animation == "Sett_Attack1_Passive_anm"
			staged_view._update_attack_stages(float(anim_names.attack_recover_delay) + 0.01)
			var recover_ok: bool = staged_view._animation_player.current_animation == "Attack1_Passive_Into_Idle"
			staged_attacks_ok = left_start_ok and left_hit_ok and right_hit_ok and recover_ok
			break
	_expect(staged_attacks_ok, "腕豪分段普攻按 Start→Hit，并在右拳后播放 Passive_Into_Idle 停顿")
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var view := child as UnitModel3D
			death_view_found = view._dying and view._animation_player.current_animation == "Death"
			view.free()
			break
	_expect(attached and death_view_found, "腕豪死亡时由独立 3D 代理播放完整 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

## 提莫美术集成：远程射节约一处弹体发射（不命中前不结算伤害），毒针走独立 needle 表现。
func _check_teemo_art_integration() -> void:
	var stats: Dictionary = CardDB.all()["teemo"].duplicate(true)
	stats["deploy_time"] = 0.0
	_expect(stats.projectile_visual == "needle" and stats.projectile_speed > 0.0, "提莫射的是绿色短针弹体，且配有独立飞行速度")
	_expect(is_equal_approx(stats.projectile_visual_height, 42.0), "提莫放大后绿色短针同步从新的吹管口高度出现")
	_expect(is_equal_approx(stats.interval, 1.0) and is_equal_approx(stats.range, 160.0), "提莫降低攻速并保持 4 格攻击距离")
	_expect(is_equal_approx(stats.visual_animations.attack_hit_duration, stats.interval - stats.first_hit), "提莫两段攻击后摇与降低后的攻速周期对齐")
	var packed := load(stats.visual_scene_path) as PackedScene
	_expect(packed != null, "提莫包装场景可加载")
	if packed == null:
		return
	var anim_names: Dictionary = stats.visual_animations
	var sample := packed.instantiate() as Node3D
	var anim_player := _find_anim_player(sample)
	var names_found := true
	for key in ["deploy", "idle", "move", "death"]:
		var animation_name: String = anim_names.get(key, "")
		names_found = names_found and animation_name != "" and anim_player != null and anim_player.has_animation(animation_name)
	for attack in anim_names.attack:
		names_found = names_found and anim_player != null and anim_player.has_animation(String(attack))
	_expect(names_found, "提莫 Idle/Run/普攻/Death/Deploy 动画名在源模型中都存在")
	var unit := Unit.new()
	unit.position = Vector2(260.0, 900.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var view := child as UnitModel3D
			death_view_found = view._dying and view._animation_player.current_animation == "Death"
			view.free()
			break
	_expect(attached and death_view_found, "提莫死亡时由独立 3D 代理播放完整 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

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

func _check_attack_hit_recovery_commitment() -> void:
	var stats: Dictionary = CardDB.all()["xin"].duplicate()
	stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var target := Unit.new()
	attacker.setup(0, stats, stats.name)
	target.setup(1, stats, stats.name)
	attacker.position = Vector2(300.0, 760.0)
	target.position = Vector2(300.0, 760.0 - attacker.body_radius - target.body_radius - float(stats.range) - 8.0)
	_main.add_child(attacker)
	_main.add_child(target)
	# 目标在命中节点所在的固定 tick 刚越出射程：本次挥击依然成立。
	attacker._target = target
	attacker._attacking = true
	attacker._attack_windup = _main.SIM_DT
	attacker._attack_visual_pending = false
	var hp_before := target.hp
	attacker.sim_tick(_main.SIM_DT)
	var recovery_after_hit := attacker._attack_recovery_timer
	_expect(target.hp < hp_before, "目标在命中节点刚越出射程时，本次攻击仍然命中")
	_expect(attacker._attacking and recovery_after_hit > 0.0 and attacker._move_intent.is_zero_approx(), "攻击命中后进入后摇锁定，不会立刻追击")
	# 后摇中目标保持在射程外：不能补第二次伤害，也不能切到 Move。
	attacker.sim_tick(recovery_after_hit * 0.5)
	_expect(target.hp < hp_before and attacker._attacking and attacker._move_intent.is_zero_approx(), "后摇期间保持 Attack 状态且不重复结算伤害")
	# 收招完成后才解除锁定，重新追向仍然存活的移动目标。
	attacker.sim_tick(recovery_after_hit)
	_expect(not attacker._attacking and attacker._attack_recovery_timer <= 0.0 and not attacker._move_intent.is_zero_approx(), "完整播放后摇后才恢复追击")
	# 尚未到命中节点就提前脱离射程，仍可取消前摇，避免整段攻击无条件锁定。
	attacker._move_intent = Vector2.ZERO
	attacker._target = target
	attacker._attacking = true
	attacker._attack_windup = _main.SIM_DT * 2.0
	attacker._attack_recovery_timer = 0.0
	attacker._attack_visual_pending = false
	var hp_before_cancel := target.hp
	attacker.sim_tick(_main.SIM_DT)
	_expect(is_equal_approx(target.hp, hp_before_cancel) and not attacker._attacking and not attacker._move_intent.is_zero_approx(), "目标在命中节点前脱离射程时仍会取消前摇并追击")
	attacker.free()
	target.free()

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
	# 放在攻塔射程的外沿内侧，确保落地体积推挤后会真正越出扩大后的塔碰撞圈。
	var initial_tower_distance := tower.body_radius + float(enemy_stats.radius) + float(enemy_stats.range) - 2.0
	var landing_pos := tower.position + Vector2(0.0, -initial_tower_distance)
	enemy.position = landing_pos
	defender.position = landing_pos
	enemy.setup(1, enemy_stats, enemy_stats.name)
	defender.setup(0, defender_stats, defender_stats.name)
	_main.add_child(enemy)
	_main.add_child(defender)
	enemy._target = tower
	enemy._attacking = true
	# 仍处于命中节点之前；若已经命中则新规则要求先完整播放后摇，不能立即转火。
	enemy._attack_windup = _main.SIM_DT * 3.0
	enemy._attack_visual_pending = true
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
	var projectile: Dictionary = _main._projectiles.values()[0]
	var raised_from_bow: bool = is_equal_approx(projectile.visual_height, 45.0) and is_equal_approx(_main._projectile_visual_position(projectile).y, attacker.position.y - 45.0)
	_expect(projectile.visual == &"arrow" and projectile.direction.x > 0.9 and is_equal_approx(projectile.radius, 3.0) and raised_from_bow, "寒冰弹体使用朝向目标、从弓部高度出现的蓝色小箭表现")
	for _i in 12:
		_main._tick_projectiles(_main.SIM_DT)
	_expect(target.hp < hp_before and _main._projectiles.is_empty(), "弹道抵达目标碰撞圆后才结算伤害")
	attacker.free()
	target.free()
	var teemo_stats: Dictionary = CardDB.all()["teemo"].duplicate()
	teemo_stats["deploy_time"] = 0.0
	var teemo := Unit.new()
	var teemo_target := Unit.new()
	teemo.position = Vector2(200.0, 800.0)
	teemo_target.position = Vector2(300.0, 800.0)
	teemo.setup(0, teemo_stats, teemo_stats.name)
	teemo_target.setup(1, target_stats, target_stats.name)
	_main.add_child(teemo)
	_main.add_child(teemo_target)
	_main.launch_attack(teemo, teemo_target, 10.0, teemo.projectile_speed, 0.0, 0.0, teemo.color)
	var needle: Dictionary = _main._projectiles.values()[0]
	_expect(needle.visual == &"needle" and needle.color.g > needle.color.r and is_equal_approx(needle.visual_height, 42.0), "提莫生成从放大后吹管口高度飞出的短绿色线条弹体")
	_main._projectiles.clear()
	teemo.free()
	teemo_target.free()

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
