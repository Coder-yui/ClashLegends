class_name ArenaDeploymentSuite
extends RefCounted
## 竞技场与部署领域：场地网格、部署规则、出牌/部署延迟与 pocket 解锁回归。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_official_arena_grid()
	_check_card_deployment_preview()
	_check_large_unit_front_row_exit()
	_check_landing_position_correction()
	_check_tower_ingress_guards()
	_check_card_play_delay()
	_check_deploy_delay()
	_check_pocket_deployment()

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
		and is_equal_approx(_main._towers[0].attack_range, 240.0)
		and is_equal_approx(_main._towers[0].max_hp, 2100.0)
		and is_equal_approx(_main._king_player.body_radius, 72.0)
		and is_equal_approx(_main._king_player.visual_radius, 80.0)
		and is_equal_approx(_main._king_player.deployment_radius, 72.0)
		and is_equal_approx(_main._king_player.attack_range, 0.0)
		and is_equal_approx(_main._king_player.max_hp, 3600.0)
		and not _main._king_player.can_attack
		and is_equal_approx(Tower.PRINCESS_HEALTH_BAR_WIDTH, 120.0)
		and is_equal_approx(Tower.KING_HEALTH_BAR_WIDTH, 160.0)
		and Tower.HEALTH_BAR_HEIGHT >= float(Tower.HEALTH_TEXT_SIZE)
		and _main._towers[0]._health_text() == "2100"
	)
	_expect(tower_sizes_ok, "塔/水晶生命提升 50%，血条保持原宽度且只显示当前生命，水晶不具备攻击能力")
	_expect(_main.is_card_deploy_position_valid(0, "xin", Vector2(20.0, 700.0)), "我方靠河左上角可部署")
	_expect(_main.is_card_deploy_position_valid(0, "xin", Vector2(700.0, 700.0)), "我方靠河右上角可部署")
	var same_front_row: bool = (
		_main.is_card_deploy_position_valid(0, "xin", Vector2(300.0, 700.0))
		and _main.is_card_deploy_position_valid(0, "garen", Vector2(300.0, 700.0))
		and _main.is_card_deploy_position_valid(0, "ashe", Vector2(300.0, 700.0))
	)
	_expect(same_front_row, "不同体型兵种在同一部署格拥有相同的可部署资格")
	_expect(_main.is_card_deploy_position_valid(1, "xin", Vector2(20.0, 580.0)), "敌方视角对应靠河角格同样可部署")
	var princess_footprint_locked: bool = (
		not _main.is_card_deploy_position_valid(0, "garen", Vector2(100.0, 980.0))
		and _main.is_card_deploy_position_valid(0, "garen", Vector2(60.0, 1020.0))
	)
	_expect(princess_footprint_locked, "存活公主塔只封锁精确 3x3 格，塔外相邻格不受体型半径额外影响")
	var nexus_footprint_locked: bool = (
		not _main.is_card_deploy_position_valid(0, "garen", Vector2(300.0, 1100.0))
		and _main.is_card_deploy_position_valid(0, "garen", Vector2(260.0, 1100.0))
	)
	_expect(nexus_footprint_locked, "存活水晶只封锁精确 4x4 格，水晶外相邻格仍按网格规则处理")
	_expect(_main._pos_in_deploy_zone(Vector2(260.0, 1260.0), 0, false), "国王塔正后方中央格可部署")
	_expect(_main._pos_in_deploy_zone(Vector2(20.0, 1260.0), 0, false) == false, "国王塔后方两侧不可部署")
	var full_back_row := true
	for column in range(6, 12):
		full_back_row = full_back_row and _main.is_card_deploy_position_valid(0, "xin", Vector2(column * 40.0 + 20.0, 1260.0))
	_expect(full_back_row, "国王塔后方中央 6 格组成完整可部署行")
	_expect(int(ProjectSettings.get_setting("display/window/size/viewport_height")) > int(_main.FIELD_H), "手牌区位于战场之外，不遮挡最后一行")

func _check_card_deployment_preview() -> void:
	# 鼠标落在格子内部任意位置时，兵种预览和最终部署坐标都必须是该格格心。
	_main._on_card_selected("xin")
	_main._update_deployment_preview(Vector2(63.0, 742.0))
	var expected_tile := Vector2i(1, 18)
	var expected_center: Vector2 = _main._arena_tile_center(expected_tile)
	var valid_preview: bool = (
		_main._deployment_preview_visible
		and _main._deployment_preview_tile == expected_tile
		and _main._deployment_preview_pos.is_equal_approx(expected_center)
		and _main._deployment_preview_valid
	)
	_expect(valid_preview, "选卡后鼠标移动会预览当前格，兵种落点严格吸附格心")

	# 非己方部署区也要显示当前格，但变红并拒绝点击，不能自动跳到相邻合法格。
	_main._update_deployment_preview(Vector2(63.0, 102.0))
	var invalid_preview: bool = (
		_main._deployment_preview_visible
		and _main._deployment_preview_tile == Vector2i(1, 2)
		and _main._deployment_preview_pos.is_equal_approx(Vector2(60.0, 100.0))
		and not _main._deployment_preview_valid
	)
	_expect(invalid_preview, "非法部署格保留红色预览并拒绝部署，不会悄悄改落点")
	_main._on_card_selected("")

func _check_large_unit_front_row_exit() -> void:
	var stats: Dictionary = CardDB.get_card("garen").duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 100000.0
	var unit := Unit.new()
	unit.setup(0, stats, stats.name)
	unit.position = _main._snap_card_position("garen", Vector2(300.0, 700.0), 0)
	_main.add_child(unit)
	var start := unit.position
	for _tick in 100:
		_main._sim_step(_main.SIM_DT)
	var exited: bool = unit.position.y < start.y - 10.0 or unit.position.x != start.x
	_expect(exited, "大体型兵种在靠河第一排落地后仍能离开部署格继续推进")
	unit.free()

func _check_landing_position_correction() -> void:
	var cases := [
		["河岸", Vector2(300.0, 700.0)],
		["桥边", Vector2(180.0, 700.0)],
		["公主塔", Vector2(100.0, 1060.0)],
		["水晶", Vector2(300.0, 1220.0)],
	]
	var all_corrected := true
	for landing_case in cases:
		var desired: Vector2 = landing_case[1]
		var unit: Unit = _main._spawn_unit(0, "garen", desired)
		var corrected: bool = not unit.position.is_equal_approx(desired)
		var physically_valid: bool = _main.is_ground_position_walkable(unit.position, unit.body_radius, unit)
		all_corrected = all_corrected and corrected and physically_valid
		unit.free()
	_expect(all_corrected, "盖伦落在河岸、桥边、塔体或水晶重叠格时会被修正到最近合法位置")

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

func _check_card_play_delay() -> void:
	var target_stats: Dictionary = CardDB.get_card("garen").duplicate()
	target_stats["deploy_time"] = 0.0
	var target := Unit.new()
	target.position = Vector2(360.0, 920.0)
	target.setup(1, target_stats, target_stats.name)
	_main.add_child(target)
	var combatants_before := _main.get_tree().get_nodes_in_group("combatants").size()
	_main._deploy_card(0, "ashe", Vector2(280.0, 980.0))
	_main._deploy_card(0, "tombstone", Vector2(480.0, 1000.0))
	_main._deploy_card(0, "freeze", target.position)
	for _i in 9:
		_main._tick_pending_card_deployments(_main.SIM_DT)
	_expect(
		_main.get_tree().get_nodes_in_group("combatants").size() == combatants_before
		and target.frozen_timer <= 0.0,
		"兵种、建筑和法术在出牌后 0.45 秒仍未生成或生效"
	)
	_main._tick_pending_card_deployments(_main.SIM_DT)
	var spawned: Array[Unit] = []
	for c in _main.get_tree().get_nodes_in_group("combatants"):
		if c is Unit and c != target and c.global_position in [Vector2(300.0, 980.0), Vector2(480.0, 1000.0)]:
			spawned.append(c as Unit)
	_expect(
		_main.get_tree().get_nodes_in_group("combatants").size() == combatants_before + 2
		and target.frozen_timer > 0.0,
		"兵种、建筑和法术在主机权威 0.5 秒节点统一生效"
	)
	var spawned_with_default_deploy := false
	for unit in spawned:
		if not unit.is_building and is_equal_approx(unit._deploy_timer, 1.0):
			spawned_with_default_deploy = true
	_expect(spawned_with_default_deploy, "兵种在 0.5 秒卡牌延迟结束时生成，并另行开始 1 秒部署")
	for unit in spawned:
		unit._die()
	target.free()
	_main._freeze_effects.clear()

func _check_deploy_delay() -> void:
	var stats: Dictionary = CardDB.get_card("garen").duplicate()
	var unit := Unit.new()
	unit.position = Vector2(204.0, 820.0)
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var before := unit.position
	unit.sim_tick(0.5)
	_expect(
		is_equal_approx(unit.deploy_time, 1.0)
		and unit.position.is_equal_approx(before)
		and not unit.is_deployed(),
		"普通单位默认部署 1 秒，期间没有自主移动或攻击"
	)
	var attacker_stats: Dictionary = CardDB.get_card("ashe").duplicate()
	attacker_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	attacker.position = unit.position
	attacker.setup(1, attacker_stats, attacker_stats.name)
	_main.add_child(attacker)
	attacker._update_target()
	var hp_before := unit.hp
	unit.take_damage(25.0, attacker)
	var overlap_before := attacker.position.distance_to(unit.position)
	_main._resolve_unit_collisions(_main.SIM_DT)
	_expect(attacker._target == unit and unit.hp < hp_before, "部署中的单位可以被敌方索敌并命中")
	_expect(attacker.position.distance_to(unit.position) > overlap_before, "部署中的单位拥有实体碰撞并参与推挤")
	attacker.free()
	unit.free()

func _check_pocket_deployment() -> void:
	var princess: Tower = _main._towers[2]
	var saved_hp: float = princess.hp
	var saved_nav_cells: Array = princess.nav_cells.duplicate()
	princess.hp = 0.0
	_main._sim_step(_main.SIM_DT)
	var left_pocket := Vector2(204.0, 520.0)
	var right_pocket := Vector2(516.0, 520.0)
	_expect(_main._pos_in_deploy_zone(left_pocket, 0, false), "破坏左路公主塔后解锁对应 pocket 部署区")
	_expect(not _main._pos_in_deploy_zone(right_pocket, 0, false), "未破坏的另一路不会提前解锁部署区")
	# 还原现场：本用例只验证部署区解锁，恢复血量与导航占用，不向其他领域 suite 泄露“公主塔已摧毁”。
	princess.hp = saved_hp
	if princess.nav_cells.is_empty() and not saved_nav_cells.is_empty():
		princess.nav_cells = saved_nav_cells.duplicate()
		_main.nav.set_cells_blocked(princess.nav_cells, true)
