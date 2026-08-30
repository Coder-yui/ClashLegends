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
	CardDBValidationSuite.new().run(self)
	await _check_deck_builder_ui()
	_main._start_local()
	_main.set_process(false)
	_main._ai.set_process(false)
	# 常规机制用例手动推进大量固定 tick，关闭自动兵线避免跨用例污染；兵线有独立回归。
	_main._minion_waves_enabled = false

	_check_official_arena_grid()
	_check_card_deployment_preview()
	_check_large_unit_front_row_exit()
	_check_landing_position_correction()
	_check_structure_art_integration()
	_check_tombstone_art_integration()
	_check_minion_line_mechanism()
	_check_death_animation_durations()
	_check_lane_weight_field()
	_check_bridge_path()
	_check_left_spawn_crosses_without_backtracking()
	_check_bridge_corner_slides_into_entrance()
	_check_king_back_spawn_never_retreats()
	_check_unit_routes_around_friendly_tower()
	_check_right_corner_keeps_outer_side()
	_check_weighted_lane_march()
	_check_destroyed_lane_targets_king()
	_check_dense_group_keeps_moving()
	_check_tower_ingress_guards()
	_check_tombstone_footprint()
	_check_tombstone_spawn_cycle()
	_check_card_play_delay()
	_check_deploy_delay()
	_check_active_skill_suite()
	_check_building_pulls_tower_target()
	_check_nearest_unit_or_building_target()
	_check_crystal_target_and_nearest_attack_target()
	_check_per_card_sight()
	_check_unit_size_tiers()
	_check_imp_tower_damage()
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
	_check_gnar_mechanic()
	_check_gnar_art_integration()
	_check_aurelionsol_art_integration()
	_check_aurelionsol_direct_retarget()
	_check_attack_target_lock()
	_check_attack_hit_recovery_commitment()
	_check_basic_attack_has_no_knockback()
	_check_freed_target_cleanup()
	_check_projectile_travel()
	_check_tower_projectile_visual()
	_check_splash_and_knockback()
	_check_xin_deploy_sweep()
	_check_xin_art_integration()
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
	var result := _failed
	_main.free()
	_main = null
	await process_frame
	quit(result)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[通过] ", message)
	else:
		_failed += 1
		push_error("[失败] " + message)

func _check_deck_builder_ui() -> void:
	await DeckBuilderSuite.new().run(self, _main)

func _check_active_skill_suite() -> void:
	ActiveSkillSuite.new().run(self, _main)

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
	var stage_views := 0
	var stage_surfaces_ok := true
	var stage_animations_ok := true
	var nexus_surfaces_ok := true
	var nexus_animations_ok := true
	for view in views:
		views_ok = views_ok and view._source.has_model_art and view._ground_clip_material_count >= 2
		var expected_yaw := PI if view._source.team == 0 else 0.0
		orientation_ok = orientation_ok and is_equal_approx(view.rotation.y, expected_yaw)
		if view._stage_mode:
			# 公主塔阶段模式：满血只显示 Base，其余阶段/碎块/废墟表面全部隐藏待用。
			stage_views += 1
			stage_surfaces_ok = stage_surfaces_ok and _surfaces_visible(view, ["Base"], true)
			stage_surfaces_ok = stage_surfaces_ok and _surfaces_visible(view, ["Stage1", "Stage2", "Stage3", "Broken1", "Broken2", "Broken3", "Rubble"], false)
			stage_animations_ok = stage_animations_ok and view._animation_player.has_animation(String(view._animations.get("destroy", "")))
			for i in range(3):
				stage_animations_ok = stage_animations_ok and view._animation_player.has_animation(StringName("debris/debris%d" % (i + 1)))
		else:
			var alive_names: Array = view._animations.get("alive_materials", [])
			var destroyed_names: Array = view._animations.get("destroyed_materials", [])
			for material_name in alive_names:
				for material in view._surface_materials_by_name.get(String(material_name), []):
					nexus_surfaces_ok = nexus_surfaces_ok and is_equal_approx(float(material.get_shader_parameter("surface_visible")), 1.0)
			for material_name in destroyed_names:
				for material in view._surface_materials_by_name.get(String(material_name), []):
					nexus_surfaces_ok = nexus_surfaces_ok and is_equal_approx(float(material.get_shader_parameter("surface_visible")), 0.0)
			for animation_key in ["spawn", "idle", "destroy"]:
				nexus_animations_ok = nexus_animations_ok and view._animation_player.has_animation(String(view._animations[animation_key]))
	_expect(views_ok, "六座建筑都使用独立 3D 表现代理，并为地上/地下表面启用动态地面裁切")
	_expect(orientation_ok, "蓝方塔朝向红方、红方塔朝向蓝方")
	_expect(stage_views == 4 and stage_surfaces_ok, "公主塔满血仅显示 Base 表面，八个阶段/碎块/废墟材质全部按名接入")
	_expect(stage_animations_ok, "公主塔摧毁动画与三段碎块片段均已注册到专用动画库")
	_expect(nexus_surfaces_ok, "水晶存活时仅显示 startup 部件，隐藏 Rubble/Destroyed 部件")
	_expect(nexus_animations_ok, "水晶的出生、待机和摧毁动画映射均存在")

	# 阶段推进回归：破 2/3 换 Stage1+Broken1 坠毁；破 1/3 换 Stage2+Broken2；
	# 摧毁换 Stage3+Broken3，掉块演完隐藏残核并定格 Rubble。
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
	var stage_flow_ok := attached and temp_view != null and temp_view._stage_mode
	if temp_view != null:
		# 破 2/3：Base 换 Stage1，Broken1 从附着位坠入地下。
		temp_tower.take_damage(temp_tower.max_hp * 0.4)
		temp_view._update_stage_flow(0.016)
		stage_flow_ok = stage_flow_ok and temp_view._visual_stage == 1
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Base"], false)
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Stage1", "Broken1"], true)
		stage_flow_ok = stage_flow_ok and temp_view._animation_player.current_animation == "debris/debris1"
		stage_flow_ok = stage_flow_ok and temp_view._animation_player.is_playing()
		# 掉块演完（2 秒）：碎块隐藏，塔体保持 Stage1。
		temp_view._update_stage_flow(2.2)
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Broken1"], false)
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Stage1"], true)
		# 破 1/3：Stage1 换 Stage2，Broken2 坠毁。
		temp_tower.take_damage(temp_tower.max_hp * 0.3)
		temp_view._update_stage_flow(0.016)
		stage_flow_ok = stage_flow_ok and temp_view._visual_stage == 2
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Stage1"], false)
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Stage2", "Broken2"], true)
		stage_flow_ok = stage_flow_ok and temp_view._animation_player.current_animation == "debris/debris2"
		stage_flow_ok = stage_flow_ok and temp_view._animation_player.is_playing()
		temp_view._update_stage_flow(2.2)
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Broken2"], false)
		# 摧毁：Stage2 换 Stage3+Broken3，掉块演完定格 Rubble；表现事件只触发一次。
		var destroyed_events := [0]
		temp_tower.destroyed.connect(func() -> void: destroyed_events[0] += 1)
		temp_tower.take_damage(temp_tower.max_hp + 1.0)
		temp_tower.notify_visual_destroyed()
		stage_flow_ok = stage_flow_ok and destroyed_events[0] == 1 and temp_view._destroyed
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Stage2", "Rubble"], false)
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Stage3", "Broken3"], true)
		stage_flow_ok = stage_flow_ok and temp_view._animation_player.current_animation == "debris/debris3"
		stage_flow_ok = stage_flow_ok and temp_view._animation_player.is_playing()
		temp_view._update_stage_flow(2.2)
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Stage3", "Broken3"], false)
		stage_flow_ok = stage_flow_ok and _surfaces_visible(temp_view, ["Rubble"], true)
	_expect(stage_flow_ok, "公主塔按血量切换阶段表面，碎块坠毁，摧毁后定格 Rubble 废墟")
	if temp_view != null:
		temp_view.free()
	temp_tower.free()

	# 跳阶段直播回归：满血一击掉到 1/4（跨两阶段），直接跳 Stage2 播 Broken2，
	# 不补演 Broken1。
	var burst_tower := Tower.new()
	burst_tower.setup(0, _main.PRINCESS_STATS, false)
	burst_tower.position = Vector2(360.0, 700.0)
	_main.add_child(burst_tower)
	_main._battle_presentation.attach_tower(burst_tower, _main.PRINCESS_VISUAL_CONFIG)
	var burst_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == burst_tower:
			burst_view = child as TowerModel3D
			break
	var burst_ok := burst_view != null and burst_view._stage_mode
	if burst_view != null:
		burst_tower.take_damage(burst_tower.max_hp * 0.75)
		burst_view._update_stage_flow(0.016)
		burst_ok = burst_ok and burst_view._visual_stage == 2
		burst_ok = burst_ok and burst_view._active_debris_surface == "Broken2"
		burst_ok = burst_ok and _surfaces_visible(burst_view, ["Stage2", "Broken2"], true)
		burst_ok = burst_ok and _surfaces_visible(burst_view, ["Base", "Stage1", "Broken1"], false)
		burst_ok = burst_ok and burst_view._animation_player.current_animation == "debris/debris2"
		burst_ok = burst_ok and burst_view._animation_player.is_playing()
		burst_view._update_stage_flow(2.2)
		burst_ok = burst_ok and burst_view._active_debris_surface.is_empty()
		burst_ok = burst_ok and _surfaces_visible(burst_view, ["Stage2"], true)
		burst_ok = burst_ok and _surfaces_visible(burst_view, ["Broken1", "Broken2"], false)
	_expect(burst_ok, "一击跨两个阶段时直接跳播第二块碎块动画，不补演第一块")
	if burst_view != null:
		burst_view.free()
	burst_tower.free()

	# 途中打断回归：Broken1 播到一半跌破下一阶段，直接切 Stage2 从头播 Broken2，
	# Broken1 立即隐藏（不管它放没放完）。
	var mid_tower := Tower.new()
	mid_tower.setup(0, _main.PRINCESS_STATS, false)
	mid_tower.position = Vector2(360.0, 600.0)
	_main.add_child(mid_tower)
	_main._battle_presentation.attach_tower(mid_tower, _main.PRINCESS_VISUAL_CONFIG)
	var mid_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == mid_tower:
			mid_view = child as TowerModel3D
			break
	var mid_ok := mid_view != null and mid_view._stage_mode
	if mid_view != null:
		mid_tower.take_damage(mid_tower.max_hp * 0.4)
		mid_view._update_stage_flow(0.016)
		mid_view._update_stage_flow(1.0)
		mid_ok = mid_ok and mid_view._active_debris_surface == "Broken1"
		mid_tower.take_damage(mid_tower.max_hp * 0.3)
		mid_view._update_stage_flow(0.016)
		mid_ok = mid_ok and mid_view._visual_stage == 2
		mid_ok = mid_ok and mid_view._active_debris_surface == "Broken2"
		mid_ok = mid_ok and _surfaces_visible(mid_view, ["Stage2", "Broken2"], true)
		mid_ok = mid_ok and _surfaces_visible(mid_view, ["Stage1", "Broken1"], false)
		mid_ok = mid_ok and mid_view._animation_player.current_animation == "debris/debris2"
		mid_ok = mid_ok and mid_view._animation_player.is_playing()
		mid_ok = mid_ok and mid_view._animation_player.current_animation_position < 0.2
		mid_view._update_stage_flow(2.2)
		mid_ok = mid_ok and mid_view._active_debris_surface.is_empty()
		mid_ok = mid_ok and _surfaces_visible(mid_view, ["Stage2"], true)
	_expect(mid_ok, "掉落途中跌破下一阶段时直接切第二块动画并隐藏第一块，不等待旧动画播完")
	if mid_view != null:
		mid_view.free()
	mid_tower.free()

	# 途中摧毁回归：Broken1 播到一半塔被摧毁，直接切 Stage3 播 Broken3，
	# 演完定格 Rubble。
	var death_tower := Tower.new()
	death_tower.setup(0, _main.PRINCESS_STATS, false)
	death_tower.position = Vector2(360.0, 500.0)
	_main.add_child(death_tower)
	_main._battle_presentation.attach_tower(death_tower, _main.PRINCESS_VISUAL_CONFIG)
	var death_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == death_tower:
			death_view = child as TowerModel3D
			break
	var death_ok := death_view != null and death_view._stage_mode
	if death_view != null:
		death_tower.take_damage(death_tower.max_hp * 0.4)
		death_view._update_stage_flow(0.016)
		death_view._update_stage_flow(1.0)
		death_tower.take_damage(death_tower.max_hp + 1.0)
		death_tower.notify_visual_destroyed()
		death_view._update_stage_flow(0.016)
		death_ok = death_ok and death_view._destroyed and death_view._visual_stage == 3
		death_ok = death_ok and death_view._active_debris_surface == "Broken3"
		death_ok = death_ok and _surfaces_visible(death_view, ["Stage3", "Broken3"], true)
		death_ok = death_ok and _surfaces_visible(death_view, ["Stage1", "Stage2", "Broken1", "Broken2", "Rubble"], false)
		death_ok = death_ok and death_view._animation_player.current_animation == "debris/debris3"
		death_view._update_stage_flow(2.2)
		death_ok = death_ok and death_view._active_debris_surface.is_empty()
		death_ok = death_ok and _surfaces_visible(death_view, ["Stage3", "Broken3"], false)
		death_ok = death_ok and _surfaces_visible(death_view, ["Rubble"], true)
	_expect(death_ok, "掉落途中被摧毁时直接切第三块动画，演完定格 Rubble")
	if death_view != null:
		death_view.free()
	death_tower.free()

	# 满血秒杀回归：直接 Stage3+Broken3，演完定格 Rubble。
	var instant_tower := Tower.new()
	instant_tower.setup(0, _main.PRINCESS_STATS, false)
	instant_tower.position = Vector2(360.0, 400.0)
	_main.add_child(instant_tower)
	_main._battle_presentation.attach_tower(instant_tower, _main.PRINCESS_VISUAL_CONFIG)
	var instant_view: TowerModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is TowerModel3D and child._source == instant_tower:
			instant_view = child as TowerModel3D
			break
	var instant_ok := instant_view != null and instant_view._stage_mode
	if instant_view != null:
		instant_tower.take_damage(instant_tower.max_hp + 1.0)
		instant_tower.notify_visual_destroyed()
		instant_view._update_stage_flow(0.016)
		instant_ok = instant_ok and instant_view._active_debris_surface == "Broken3"
		instant_ok = instant_ok and _surfaces_visible(instant_view, ["Stage3", "Broken3"], true)
		instant_ok = instant_ok and _surfaces_visible(instant_view, ["Base", "Broken1", "Broken2", "Rubble"], false)
		instant_view._update_stage_flow(2.2)
		instant_ok = instant_ok and instant_view._active_debris_surface.is_empty()
		instant_ok = instant_ok and _surfaces_visible(instant_view, ["Stage3", "Broken3"], false)
		instant_ok = instant_ok and _surfaces_visible(instant_view, ["Rubble"], true)
	_expect(instant_ok, "满血秒杀时直接播第三块碎块动画，演完定格 Rubble")
	if instant_view != null:
		instant_view.free()
	instant_tower.free()

func _check_tombstone_art_integration() -> void:
	var cards := CardDB.all()
	var tombstone_stats: Dictionary = cards["tombstone"]
	var imp_stats: Dictionary = CardDB.imp_stats()
	var tombstone_packed := load(tombstone_stats.visual_scene_path) as PackedScene
	var imp_packed := load(imp_stats.visual_scene_path) as PackedScene
	var tombstone_sample := tombstone_packed.instantiate() as Node3D if tombstone_packed != null else null
	var imp_sample := imp_packed.instantiate() as Node3D if imp_packed != null else null
	if tombstone_sample != null:
		_main.add_child(tombstone_sample)
	if imp_sample != null:
		_main.add_child(imp_sample)
	var tombstone_player := _find_anim_player(tombstone_sample) if tombstone_sample != null else null
	var imp_player := _find_anim_player(imp_sample) if imp_sample != null else null
	var tombstone_animations_ok := tombstone_player != null
	for key in ["deploy", "idle", "death"]:
		var animation_name := String(tombstone_stats.visual_animations.get(key, ""))
		tombstone_animations_ok = tombstone_animations_ok and tombstone_player.has_animation(animation_name)
	var fog_layers: Array[Node] = tombstone_sample.find_children("BlackFog*", "MeshInstance3D", true, false) if tombstone_sample != null else []
	var fog_ok := fog_layers.size() >= 5
	var fog_material_ids := {}
	for fog_node in fog_layers:
		var fog := fog_node as MeshInstance3D
		var fog_material := fog.material_override as ShaderMaterial
		fog_ok = fog_ok and fog.mesh is QuadMesh and fog_material != null
		fog_ok = fog_ok and fog.is_in_group("tombstone_fog") and fog.is_in_group("presentation_fx")
		if fog_material != null:
			fog_material_ids[fog_material.get_instance_id()] = true
	fog_ok = fog_ok and fog_material_ids.size() == fog_layers.size()
	var fog_death_ok := tombstone_sample != null and tombstone_sample.has_method("begin_visual_death")
	var health_anchor_ok := tombstone_sample != null and tombstone_sample.has_method("get_health_bar_anchor_local")
	if fog_death_ok:
		tombstone_sample.call("begin_visual_death", 0.8)
		tombstone_sample.call("_process", 0.4)
		for fog_node in fog_layers:
			var fog_material := (fog_node as MeshInstance3D).material_override as ShaderMaterial
			var visibility := float(fog_material.get_shader_parameter("fog_visibility")) if fog_material != null else 1.0
			fog_death_ok = fog_death_ok and visibility > 0.0 and visibility < 1.0
	if health_anchor_ok:
		var anchor = tombstone_sample.call("get_health_bar_anchor_local")
		health_anchor_ok = anchor is Vector3 and (anchor as Vector3).y > 1.0
	var imp_animations_ok := imp_player != null
	for key in ["deploy", "idle", "move", "death"]:
		var animation_name := String(imp_stats.visual_animations.get(key, ""))
		imp_animations_ok = imp_animations_ok and imp_player.has_animation(animation_name)
	for animation_name in imp_stats.visual_animations.attack:
		imp_animations_ok = imp_animations_ok and imp_player.has_animation(String(animation_name))
	imp_animations_ok = imp_animations_ok and String(imp_stats.visual_animations.move) == "Run1"
	imp_animations_ok = imp_animations_ok and imp_stats.visual_animations.attack == ["Yorick_ghoul_leapWindup_anm"]
	_expect(tombstone_packed != null and tombstone_animations_ok and fog_ok, "墓碑包装场景接入 Spawn/Idle1/Death，并用五层独立流动黑雾覆盖地面与模型内部")
	_expect(fog_death_ok, "墓碑死亡时每座墓碑的黑雾独立随 Death 动画扩散并淡出")
	_expect(health_anchor_ok, "墓碑使用稳定的模型顶部锚点定位血条")
	_expect(imp_packed != null and imp_animations_ok, "小鬼移动循环 Run1，攻击使用 leapWindup，Spawn/Idle/Death 保持原动画")
	if tombstone_sample != null:
		tombstone_sample.free()
	if imp_sample != null:
		imp_sample.free()

## 校验表面组内所有裁切材质的可见参数，且表面名必须真实存在（防止配置名写错）。
func _surfaces_visible(view: TowerModel3D, surface_names: Array, expected: bool) -> bool:
	var target := 1.0 if expected else 0.0
	for surface_name in surface_names:
		var materials: Array = view._surface_materials_by_name.get(String(surface_name), [])
		if materials.is_empty():
			return false
		for material in materials:
			if not is_equal_approx(float(material.get_shader_parameter("surface_visible")), target):
				return false
	return true

func _check_minion_line_mechanism() -> void:
	var cards := CardDB.all()
	var minion_ids := ["melee_minion", "ranged_minion", "siege_minion", "super_minion"]
	var data_ok := true
	var expected_costs := {"melee_minion": 1, "ranged_minion": 1, "siege_minion": 3, "super_minion": 4}
	for card_id in minion_ids:
		data_ok = data_ok and cards.has(card_id) and bool(cards[card_id].get("selectable", true))
		data_ok = data_ok and CardDB.selectable_ids().has(card_id)
		data_ok = data_ok and int(cards[card_id].cost) == int(expected_costs[card_id])
	_expect(data_ok, "四类兵线单位进入玩家/AI 卡池，费用为近战1、远程1、炮车3、超级兵4")
	_expect(
		cards.melee_minion.size_tier == CardDB.SIZE_SMALL
		and cards.ranged_minion.size_tier == CardDB.SIZE_SMALL
		and cards.siege_minion.size_tier == CardDB.SIZE_SLIGHTLY_SMALL
		and cards.super_minion.size_tier == CardDB.SIZE_MEDIUM
		and is_equal_approx(cards.melee_minion.speed, CardDB.SPEED_MEDIUM)
		and is_equal_approx(cards.ranged_minion.speed, CardDB.SPEED_MEDIUM)
		and is_equal_approx(cards.siege_minion.speed, CardDB.SPEED_MEDIUM)
		and is_equal_approx(cards.super_minion.speed, CardDB.SPEED_MEDIUM)
		and cards.ranged_minion.can_attack_air
		and cards.siege_minion.can_attack_air,
		"四类小兵的权威体型统一下调一档，速度与对空能力保持原定义"
	)

	var art_ok := true
	for card_id in minion_ids:
		var stats: Dictionary = cards[card_id]
		var scene_paths: Array = stats.visual_scene_paths
		art_ok = art_ok and scene_paths.size() == 2
		for scene_path in scene_paths:
			var packed := load(String(scene_path)) as PackedScene
			var sample := packed.instantiate() as Node3D if packed != null else null
			var anim_player := _find_anim_player(sample) if sample != null else null
			for key in ["deploy", "idle", "move", "death"]:
				var animation_name := String(stats.visual_animations[key])
				art_ok = art_ok and anim_player != null and anim_player.has_animation(animation_name)
			for attack_name in stats.visual_animations.attack:
				art_ok = art_ok and anim_player != null and anim_player.has_animation(String(attack_name))
			if sample != null:
				sample.free()
	_expect(art_ok, "四类兵线的 order/chaos 包装场景均可加载，Idle/Run/Attack/Death 映射真实存在")

	var ranged_blue := Unit.new()
	var ranged_red := Unit.new()
	var siege_blue := Unit.new()
	ranged_blue.setup(0, cards.ranged_minion, cards.ranged_minion.name)
	ranged_red.setup(1, cards.ranged_minion, cards.ranged_minion.name)
	siege_blue.setup(0, cards.siege_minion, cards.siege_minion.name)
	_expect(
		ranged_blue.projectile_visual == &"orb"
		and ranged_blue.projectile_color.b > ranged_blue.projectile_color.r
		and ranged_red.projectile_color.r > ranged_red.projectile_color.b
		and siege_blue.projectile_color.r < 0.1
		and ranged_blue.projectile_visual_forward_offset > 0.0
		and siege_blue.projectile_visual_forward_offset > ranged_blue.projectile_visual_forward_offset,
		"远程兵按阵营发射蓝/红小光球，炮车发射黑球，权杖与炮口均配置纯表现起点"
	)
	ranged_blue.free()
	ranged_red.free()
	siege_blue.free()

	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	_main._battle_elapsed = 4.95
	_main._next_minion_wave_time = 5.0
	_main._tick_minion_waves(0.05)
	var first_spawn := _minion_test_units()
	var first_wave_ok := first_spawn.size() == 4
	var first_wave_ready_ok := true
	for minion in first_spawn:
		first_wave_ok = first_wave_ok and minion.card_id == "melee_minion"
		first_wave_ready_ok = first_wave_ready_ok and minion.is_deployed() and is_equal_approx(minion._deploy_timer, 0.0)
	_expect(first_wave_ok and first_wave_ready_ok, "开局第 5 秒双方左右两路各生成一个近战兵，生成后立即可行动")
	_main._tick_minion_waves(0.45)
	_expect(_minion_test_units().size() == 4, "首波经过 0.45 秒尚未生成后排")
	_main._tick_minion_waves(0.05)
	var normal_wave := _minion_test_units()
	var ranged_count := 0
	var ranged_ready_ok := true
	for minion in normal_wave:
		if minion.card_id == "ranged_minion":
			ranged_count += 1
			ranged_ready_ok = ranged_ready_ok and minion.is_deployed() and is_equal_approx(minion._deploy_timer, 0.0)
	_expect(normal_wave.size() == 8 and ranged_count == 4 and ranged_ready_ok, "首波 0.5 秒后双方左右两路各补一个远程兵，生成后立即可行动")

	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	_main._battle_elapsed = 124.95
	_main._next_minion_wave_time = 125.0
	_main._tick_minion_waves(0.05)
	_main._tick_minion_waves(0.5)
	var double_wave := _minion_test_units()
	var siege_count := 0
	for minion in double_wave:
		if minion.card_id == "siege_minion":
			siege_count += 1
	_expect(double_wave.size() == 8 and siege_count == 4, "进入双倍金币后每路编成为近战兵加炮车兵")

	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	var enemy_left_hp: float = _main._towers[2].hp
	_main._towers[2].hp = 0.0
	_main._battle_elapsed = 0.0
	_main._spawn_minion_wave()
	var upgraded_front_ok := false
	var untouched_front_ok := false
	for minion in _minion_test_units():
		if minion.team == 0 and minion.position.x < _main.FIELD_W * 0.5:
			upgraded_front_ok = minion.card_id == "super_minion"
		elif minion.team == 0 and minion.position.x > _main.FIELD_W * 0.5:
			untouched_front_ok = minion.card_id == "melee_minion"
	_expect(upgraded_front_ok and untouched_front_ok, "推掉敌方左塔后，仅己方左路后续近战兵替换为超级兵")
	_main._towers[2].hp = enemy_left_hp
	_clear_minion_test_units()
	_main._pending_lane_minions.clear()
	_main._battle_elapsed = 0.0
	_main._next_minion_wave_time = _main.FIRST_MINION_WAVE_TIME

func _check_death_animation_durations() -> void:
	var cards := CardDB.all()
	var hero_ids := ["garen", "xin", "ashe", "teemo", "masteryi", "gwen", "sett", "aurelionsol"]
	var minion_ids := ["melee_minion", "ranged_minion", "siege_minion", "super_minion"]
	var durations_ok := true
	for card_id in hero_ids:
		durations_ok = durations_ok and is_equal_approx(float(cards[card_id].visual_animations.get("death_duration", 0.0)), 0.8)
	for card_id in minion_ids:
		durations_ok = durations_ok and is_equal_approx(float(cards[card_id].visual_animations.get("death_duration", 0.0)), 0.5)
	_expect(durations_ok, "全部英雄死亡动画统一为 0.8 秒，四类小兵统一为 0.5 秒")
	_expect(
		_runtime_death_speed_matches("garen", 0.8)
		and _runtime_death_speed_matches("melee_minion", 0.5),
		"通用 3D 表现层按配置时长缩放英雄与小兵的死亡动画"
	)

func _runtime_death_speed_matches(card_id: String, expected_duration: float) -> bool:
	var stats: Dictionary = CardDB.get_card(card_id).duplicate(true)
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	unit.card_id = card_id
	unit.setup(0, stats, stats.name)
	_main.add_child(unit)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	unit.take_damage(unit.max_hp + 1.0)
	var playback_ok := false
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			var view := child as UnitModel3D
			var animation := view._animation_player.get_animation(view._death_animation) if view._animation_player != null else null
			if animation != null and animation.length > 0.0:
				var expected_speed: float = animation.length / expected_duration
				playback_ok = is_equal_approx(view._animation_player.get_playing_speed(), expected_speed)
			view.free()
			break
	if is_instance_valid(unit):
		unit.free()
	return attached and playback_ok

func _minion_test_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for combatant in _main.get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and ["melee_minion", "ranged_minion", "siege_minion", "super_minion"].has(combatant.card_id):
			result.append(combatant as Unit)
	return result

func _clear_minion_test_units() -> void:
	for minion in _minion_test_units():
		minion.free()

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

func _check_destroyed_lane_targets_king() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
	stats["deploy_time"] = 0.0
	var blue_left := Unit.new()
	blue_left.position = Vector2(204.0, 520.0)
	blue_left.setup(0, stats, stats.name)
	_main.add_child(blue_left)
	var red_left_hp: float = _main._towers[2].hp
	_main._towers[2].hp = 0.0
	blue_left._update_target()
	_expect(blue_left._target == _main._king_enemy, "左路敌方公主塔摧毁后，同路单位转推敌方水晶而不是跨向右塔")
	_main._towers[2].hp = red_left_hp
	blue_left.free()

	var red_right := Unit.new()
	red_right.position = Vector2(516.0, 760.0)
	red_right.setup(1, stats, stats.name)
	_main.add_child(red_right)
	var blue_right_hp: float = _main._towers[1].hp
	_main._towers[1].hp = 0.0
	red_right._update_target()
	_expect(red_right._target == _main._king_player, "右路我方公主塔摧毁后，敌方单位镜像转推我方水晶而不是跨向左塔")
	_main._towers[1].hp = blue_right_hp
	red_right.free()

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

func _check_tombstone_spawn_cycle() -> void:
	var stats: Dictionary = CardDB.get_card("tombstone").duplicate(true)
	stats["deploy_time"] = 0.0
	var left := Unit.new()
	left.position = Vector2(240.0, 900.0)
	left.setup(0, stats, stats.name)
	_main.add_child(left)
	var before_left := _imp_units()
	left.sim_tick(_main.SIM_DT)
	var after_initial := _imp_units()
	var initial_count := after_initial.size() - before_left.size()
	var initial_left_side := true
	for imp in after_initial:
		if not before_left.has(imp):
			initial_left_side = initial_left_side and imp.position.x < left.position.x
	var initial_ready := true
	for imp in after_initial:
		if not before_left.has(imp):
			initial_ready = initial_ready and imp.is_deployed() and is_equal_approx(imp._deploy_timer, 0.0)
	_expect(initial_count == 2 and initial_left_side and initial_ready, "墓碑完成部署后立即在地图左侧连续生成两个无需部署读条的小鬼")
	left.sim_tick(4.95)
	var after_periodic := _imp_units()
	_expect(after_periodic.size() - after_initial.size() == 2, "墓碑每 5 秒额外生成两个小鬼")

	var right := Unit.new()
	right.position = Vector2(480.0, 900.0)
	right.setup(1, stats, stats.name)
	_main.add_child(right)
	var before_right := _imp_units()
	right.sim_tick(_main.SIM_DT)
	var after_right := _imp_units()
	var right_count := after_right.size() - before_right.size()
	var initial_right_side := true
	for imp in after_right:
		if not before_right.has(imp):
			initial_right_side = initial_right_side and imp.position.x > right.position.x
	_expect(right_count == 2 and initial_right_side, "墓碑完成部署后立即在地图右侧生成两个小鬼")

	var diagonal_corner := left.position + Vector2(40.0, 40.0)
	var direct_overlap := left.position + Vector2(30.0, 0.0)
	_expect(
		_main.is_ground_position_walkable(diagonal_corner, CardDB.RADIUS_EXTREMELY_SMALL)
		and not _main.is_ground_position_walkable(direct_overlap, CardDB.RADIUS_EXTREMELY_SMALL),
		"墓碑 2x2 格占地的实际碰撞为内切圆，圆角外可通行而边缘内不可穿过"
	)
	for imp in _imp_units():
		imp.free()
	left.free()
	right.free()

func _imp_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for combatant in get_nodes_in_group("combatants"):
		if combatant is Unit and (combatant as Unit).card_id == "imp":
			result.append(combatant as Unit)
	return result

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

func _check_card_play_delay() -> void:
	var target_stats: Dictionary = CardDB.get_card("garen").duplicate()
	target_stats["deploy_time"] = 0.0
	var target := Unit.new()
	target.position = Vector2(360.0, 920.0)
	target.setup(1, target_stats, target_stats.name)
	_main.add_child(target)
	var combatants_before := get_nodes_in_group("combatants").size()
	_main._deploy_card(0, "ashe", Vector2(280.0, 980.0))
	_main._deploy_card(0, "tombstone", Vector2(480.0, 1000.0))
	_main._deploy_card(0, "freeze", target.position)
	for _i in 9:
		_main._tick_pending_card_deployments(_main.SIM_DT)
	_expect(
		get_nodes_in_group("combatants").size() == combatants_before
		and target.frozen_timer <= 0.0,
		"兵种、建筑和法术在出牌后 0.45 秒仍未生成或生效"
	)
	_main._tick_pending_card_deployments(_main.SIM_DT)
	var spawned: Array[Unit] = []
	for c in get_nodes_in_group("combatants"):
		if c is Unit and c != target and c.global_position in [Vector2(300.0, 980.0), Vector2(480.0, 1000.0)]:
			spawned.append(c as Unit)
	_expect(
		get_nodes_in_group("combatants").size() == combatants_before + 2
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

func _check_building_pulls_tower_target() -> void:
	var attacker_stats: Dictionary = CardDB.get_card("garen").duplicate()
	attacker_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	attacker.position = Vector2(204.0, 760.0)
	attacker.setup(0, attacker_stats, attacker_stats.name)
	_main.add_child(attacker)
	attacker._update_target()
	var started_for_tower: bool = attacker._target is Tower
	var building_stats: Dictionary = CardDB.get_card("tombstone").duplicate()
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
	var attacker_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var troop_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var building_stats: Dictionary = CardDB.get_card("tombstone").duplicate()
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

func _check_crystal_target_and_nearest_attack_target() -> void:
	# 普通单位在攻击范围内应优先锁定最近的合法敌方单位；测试位置都在赵信的攻击距离内。
	var attacker_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var target_stats: Dictionary = CardDB.get_card("xin").duplicate()
	attacker_stats["deploy_time"] = 0.0
	target_stats["deploy_time"] = 0.0
	var attacker := Unit.new()
	var nearer := Unit.new()
	var farther := Unit.new()
	attacker.position = Vector2(300.0, 800.0)
	nearer.position = Vector2(300.0, 755.0)
	farther.position = Vector2(300.0, 980.0)
	attacker.setup(0, attacker_stats, attacker_stats.name)
	nearer.setup(1, target_stats, target_stats.name)
	farther.setup(1, target_stats, target_stats.name)
	_main.add_child(attacker)
	_main.add_child(nearer)
	_main.add_child(farther)
	attacker._update_target()
	var nearest_unit_ok: bool = (
		attacker._target == nearer
		and attacker._target_gap(nearer) <= attacker.attack_range
		and attacker._target_gap(farther) > attacker.attack_range
		and attacker._target_gap(farther) <= attacker.sight_range
	)
	_expect(nearest_unit_ok, "攻击范围内优先攻击最近单位，只有视野内的较远单位则继续追击最近目标")
	attacker.free()
	nearer.free()
	farther.free()

	# 两座敌方公主塔都还存活时，贴近水晶的单位也应能把水晶作为合法目标。
	var crystal_attacker := Unit.new()
	crystal_attacker.position = _main._king_enemy.position + Vector2.DOWN * 100.0
	crystal_attacker.setup(0, attacker_stats, attacker_stats.name)
	_main.add_child(crystal_attacker)
	crystal_attacker._target = _main._towers[3]
	crystal_attacker._update_target()
	var princesses_alive: bool = _main._towers[2].hp > 0.0 and _main._towers[3].hp > 0.0
	_expect(princesses_alive and crystal_attacker._target == _main._king_enemy, "公主塔未被摧毁时，进入攻击范围的单位也能选择敌方水晶")
	crystal_attacker.free()

func _check_per_card_sight() -> void:
	var melee_stats: Dictionary = CardDB.get_card("masteryi").duplicate()
	var ranged_stats: Dictionary = CardDB.get_card("ashe").duplicate()
	var enemy_stats: Dictionary = CardDB.get_card("xin").duplicate()
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
		"gnar": [CardDB.SIZE_SMALL, CardDB.RADIUS_SMALL],
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
	_expect(tiers_ok, "盖伦/剑圣/瑟提/寒冰/提莫/小纳尔/赵信/龙王/小鬼/格温使用指定的七档体型")

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
		"aurelionsol": 0.006,
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
	var stats: Dictionary = CardDB.get_card("garen").duplicate()
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
	var air_stats: Dictionary = CardDB.get_card("aurelionsol").duplicate()
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
	var stats: Dictionary = CardDB.get_card("garen").duplicate(true)
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
	var stats: Dictionary = CardDB.get_card("garen").duplicate(true)
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
	var stats: Dictionary = CardDB.get_card("masteryi").duplicate(true)
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
	var stats: Dictionary = CardDB.get_card("garen").duplicate(true)
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
	var stats: Dictionary = CardDB.get_card("garen").duplicate(true)
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
	var stats: Dictionary = CardDB.get_card("masteryi").duplicate(true)
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
	_expect(attached and death_view_found, "剑圣死亡时由独立 3D 代理播放 Death")
	_expect(process_order_ok, "客户端 3D 代理在 Unit 快照插值完成后读取最终位置")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

func _check_ashe_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("ashe").duplicate(true)
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
	_expect(attached and death_view_found, "寒冰死亡时由独立 3D 代理播放 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

func _check_gwen_mechanic() -> void:
	var gwen_stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	var enemy_stats: Dictionary = CardDB.get_card("xin").duplicate(true)
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
	var gwen_stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
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
	_expect(not king.activated, "水晶受到攻击后仍不激活攻击能力")
	_expect(is_equal_approx(attacker.hp, attacker_hp), "水晶不索敌、不发射弹体也不造成伤害")
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
	var stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
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
	_expect(attached and death_view_found, "格温死亡时由独立 3D 代理播放 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

## 腕豪连招节奏：快速两拳(0.28)→停顿(1.05)→快速两拳(0.28)→停顿(1.05) 循环。
func _check_sett_attack_rhythm() -> void:
	var stats: Dictionary = CardDB.get_card("sett").duplicate(true)
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
	var damage_multipliers: Array = stats.get("attack_damage_multipliers", [])
	var damage_ok := damage_multipliers == [1.0, 1.5, 1.0, 1.5]
	for i in range(4):
		damage_ok = damage_ok and is_equal_approx(unit._attack_damage_multiplier(i), float(damage_multipliers[i]))
	_expect(damage_ok, "腕豪右拳伤害为左拳的1.5倍，并按左右拳循环")
	unit.free()

## 腕豪美术集成：包装场景可加载，模型落到地面，动画名在源模型中存在，死亡由 3D 代理播放。
func _check_sett_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("sett").duplicate(true)
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
	_expect(attached and death_view_found, "腕豪死亡时由独立 3D 代理播放 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

## 提莫美术集成：远程射节约一处弹体发射（不命中前不结算伤害），毒针走独立 needle 表现。
func _check_teemo_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("teemo").duplicate(true)
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
	_expect(attached and death_view_found, "提莫死亡时由独立 3D 代理播放 Death")
	if is_instance_valid(unit):
		unit.free()
	if sample != null:
		sample.free()

## 纳尔循环双形态：小形态第6次命中变大，大形态第4次命中变小；变形期间可移动但不能攻击。
func _check_gnar_mechanic() -> void:
	var stats: Dictionary = CardDB.get_card("gnar").duplicate(true)
	stats["deploy_time"] = 0.0
	var dummy_stats := _sweep_dummy_stats(CardDB.get_card("garen"))
	var gnar := Unit.new()
	var dummy := Unit.new()
	gnar.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 780.0)
	gnar.setup(0, stats, stats.name)
	dummy.setup(1, dummy_stats, "纳尔被动木桩")
	_main.add_child(gnar)
	_main.add_child(dummy)
	var small_contract := (
		gnar.form_index == 0
		and gnar.can_attack_air
		and gnar.projectile_speed > 0.0
		and gnar.body_radius == CardDB.RADIUS_SMALL
	)
	dummy.hp = 5000.0
	dummy.max_hp = 5000.0
	var dummy_hp_before := dummy.hp
	_main.launch_attack(gnar, dummy, gnar.damage, gnar.projectile_speed, 0.0, 0.0, gnar.color)
	var delayed_projectile_ok: bool = dummy.hp == dummy_hp_before and gnar.transform_hit_count == 0 and not _main._projectiles.is_empty()
	for _tick in 10:
		_main._tick_projectiles(_main.SIM_DT)
	for _hit_index in range(4):
		gnar.on_attack_landed()
	var five_hits_still_small := gnar.form_index == 0 and gnar.transform_hit_count == 5
	gnar.hp = 300.0
	# 同一时刻在途的两枚小纳尔回旋镖只有第一枚完成第6层；第二枚不会误算为大纳尔命中。
	_main.launch_attack(gnar, dummy, gnar.damage, gnar.projectile_speed, 0.0, 0.0, gnar.color)
	_main.launch_attack(gnar, dummy, gnar.damage, gnar.projectile_speed, 0.0, 0.0, gnar.color)
	for _tick in 10:
		_main._tick_projectiles(_main.SIM_DT)
	var transformed_contract := (
		gnar.form_index == 1
		and not gnar.can_attack_air
		and is_zero_approx(gnar.projectile_speed)
		and gnar.body_radius == CardDB.RADIUS_EXTREMELY_LARGE
		and is_equal_approx(gnar.max_hp, float(stats.transformed_stats.hp))
		and is_equal_approx(gnar.hp, 300.0 + float(stats.transformed_stats.hp) - float(stats.hp))
		and gnar.transform_hit_count == 0
		and is_equal_approx(gnar.form_transition_timer, float(stats.transform_duration))
	)
	var largest_other_unit_radius := 0.0
	for card_id in CardDB.all():
		if card_id == "gnar":
			continue
		var other_stats: Dictionary = CardDB.get_card(card_id)
		if other_stats.get("type", "unit") == "unit":
			largest_other_unit_radius = maxf(largest_other_unit_radius, float(other_stats.get("radius", 0.0)))
	_expect(small_contract and delayed_projectile_ok and five_hits_still_small, "小纳尔为小体型远程单位，回旋镖抵达才造成伤害/计层且前5次命中不会提前变身")
	_expect(transformed_contract, "小纳尔第6次真实命中立即切换大形态数值，当前生命增加两形态上限差值且在途回旋镖不串层")
	_expect(gnar.body_radius > largest_other_unit_radius, "大纳尔使用当前可移动单位唯一且最大的极大体型档位")

	# 变大演出期间先用大纳尔视野/射程决定追击或待攻；移动不被锁，攻击必须等固定演出结束。
	dummy.position = gnar.position + Vector2(0.0, -120.0)
	gnar.sim_tick(_main.SIM_DT)
	var transition_moves := gnar.form_transition_timer > 0.0 and not gnar._attacking and gnar._move_intent.length_squared() > 0.01
	dummy.position = gnar.position + Vector2(0.0, -65.0)
	gnar.sim_tick(_main.SIM_DT)
	var transition_waits_in_range := not gnar._attacking and gnar._move_intent.is_zero_approx() and gnar._attack_load > 0.0
	var attack_serial_before := gnar.get_attack_visual_serial()
	while gnar.form_transition_timer > 0.0:
		gnar.sim_tick(_main.SIM_DT)
	var attacks_immediately_after_transition := gnar._attacking and gnar.get_attack_visual_serial() > attack_serial_before
	_expect(transition_moves and transition_waits_in_range, "变形期间按新形态射程决定继续移动或原地待攻，但始终不发动攻击")
	_expect(attacks_immediately_after_transition, "变形动画锁结束后，射程内目标会立即衔接新形态攻击")

	gnar.hp = 200.0
	for _hit_index in range(3):
		gnar.on_attack_landed(1)
	var three_mega_hits_still_big := gnar.form_index == 1 and gnar.transform_hit_count == 3
	gnar.on_attack_landed(1)
	var reverted_contract := (
		gnar.form_index == 0
		and is_equal_approx(gnar.max_hp, float(stats.hp))
		and is_equal_approx(gnar.hp, 200.0)
		and gnar.transform_hit_count == 0
		and gnar.get_visual_action_name() == &"revert"
		and is_equal_approx(gnar.form_transition_timer, float(stats.revert_duration))
	)
	gnar.transform_to_mega()
	gnar.hp = 700.0
	gnar.transform_to_small()
	var revert_clamps_overflow := is_equal_approx(gnar.hp, float(stats.hp))
	_expect(three_mega_hits_still_big and reverted_contract, "大纳尔前3次命中保持大形态，第4次命中立即变小并保留未超上限的剩余生命")
	_expect(revert_clamps_overflow, "大纳尔变小时剩余生命会被小纳尔最大生命上限截断")

	# 小半径合法但大半径压入河岸的位置，变大后应被确定性修正到新体积合法点。
	var resize_gnar := Unit.new()
	resize_gnar.position = Vector2(360.0, _main.RIVER_Y + _main.RIVER_HALF + CardDB.RADIUS_SMALL)
	resize_gnar.setup(0, stats, stats.name)
	_main.add_child(resize_gnar)
	var resize_origin := resize_gnar.position
	resize_gnar.transform_to_mega()
	var resize_safe: bool = resize_gnar.position != resize_origin and _main.is_ground_position_walkable(resize_gnar.position, resize_gnar.body_radius, resize_gnar)
	_expect(resize_safe, "小纳尔在河岸/桥角变大时会按新半径移到最近安全点，不会因瞬时体积增大卡住")

	# 周围单位使用统一圆柱推挤处理，不做伤害或击退；即使纳尔贴场地边缘，另一侧单位也应被推出。
	var crowded_gnar := Unit.new()
	crowded_gnar.position = Vector2(540.0, 860.0)
	crowded_gnar.setup(0, stats, stats.name)
	_main.add_child(crowded_gnar)
	crowded_gnar._just_deployed = false
	var crowded_neighbors: Array[Unit] = []
	var old_contact_distance := CardDB.RADIUS_SMALL + float(dummy_stats.radius) - 0.5
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var neighbor := Unit.new()
		neighbor.position = crowded_gnar.position + direction * old_contact_distance
		neighbor.setup(1, dummy_stats, "纳尔变大推挤木桩")
		_main.add_child(neighbor)
		neighbor._just_deployed = false
		crowded_neighbors.append(neighbor)
	var crowded_origins: Array[Vector2] = []
	for neighbor in crowded_neighbors:
		crowded_origins.append(neighbor.position)
	crowded_gnar.transform_to_mega()
	_main._resolve_unit_collisions(_main.SIM_DT)
	var pushed_on_resize_tick := false
	for neighbor_index in crowded_neighbors.size():
		pushed_on_resize_tick = pushed_on_resize_tick or crowded_neighbors[neighbor_index].position != crowded_origins[neighbor_index]
	for _tick in 40:
		_main._resolve_unit_collisions(_main.SIM_DT)
	var crowd_separated := true
	for neighbor in crowded_neighbors:
		var required_gap: float = crowded_gnar.body_radius + neighbor.body_radius - _main.COLLISION_SLOP - 0.1
		crowd_separated = (
			crowd_separated
			and crowded_gnar.position.distance_to(neighbor.position) >= required_gap
			and _main.is_ground_position_walkable(neighbor.position, neighbor.body_radius, neighbor)
		)
	var edge_gnar := Unit.new()
	var edge_neighbor := Unit.new()
	edge_gnar.position = Vector2(CardDB.RADIUS_EXTREMELY_LARGE, 760.0)
	edge_neighbor.position = edge_gnar.position + Vector2.RIGHT * old_contact_distance
	edge_gnar.setup(0, stats, stats.name)
	edge_neighbor.setup(1, dummy_stats, "贴边推挤木桩")
	_main.add_child(edge_gnar)
	_main.add_child(edge_neighbor)
	edge_gnar._just_deployed = false
	edge_neighbor._just_deployed = false
	edge_gnar.transform_to_mega()
	for _tick in 40:
		_main._resolve_unit_collisions(_main.SIM_DT)
	var edge_separated: bool = (
		edge_gnar.position.distance_to(edge_neighbor.position) >= edge_gnar.body_radius + edge_neighbor.body_radius - _main.COLLISION_SLOP - 0.1
		and _main.is_ground_position_walkable(edge_gnar.position, edge_gnar.body_radius, edge_gnar)
		and _main.is_ground_position_walkable(edge_neighbor.position, edge_neighbor.body_radius, edge_neighbor)
	)
	_expect(pushed_on_resize_tick and crowd_separated and edge_separated, "纳尔变大当帧开始按质量挤开周围单位，密集包围与贴边场景最终都无重叠、无单位被卡进地形")

	var active_small := Unit.new()
	active_small.card_id = "gnar"
	active_small.position = Vector2(200.0, 900.0)
	active_small.setup(0, stats, stats.name)
	_main.add_child(active_small)
	var skill: Dictionary = stats.active_skill
	# team0 默认朝上。前方目标在 -Y，后方目标在 +Y，空中目标即使在前方也应免疫。
	var front := Unit.new()
	var back := Unit.new()
	var air := Unit.new()
	front.position = active_small.position + Vector2(20.0, -100.0)
	back.position = active_small.position + Vector2(0.0, 100.0)
	air.position = active_small.position + Vector2(-20.0, -90.0)
	front.setup(1, dummy_stats, "前方木桩")
	back.setup(1, dummy_stats, "后方木桩")
	var air_stats := dummy_stats.duplicate(true)
	air_stats["is_air"] = true
	air.setup(1, air_stats, "空中木桩")
	_main.add_child(front)
	_main.add_child(back)
	_main.add_child(air)
	var front_hp := front.hp
	var back_hp := back.hp
	var air_hp := air.hp
	var cast_facing := active_small.get_visual_facing_direction()
	_main._activate_dual_form_skill(active_small, skill)
	var active_small_contract := (
		active_small.form_index == 1
		and active_small.get_visual_action_name() == &"transform_active"
		and is_equal_approx(active_small.form_transition_timer, float(stats.active_transform_duration))
		and is_equal_approx(active_small.active_skill_cast_timer, float(skill.transform_cast_duration))
	)
	var attack_serial_before_cast_tick := active_small.get_attack_visual_serial()
	active_small._target = back
	active_small._attacking = true
	active_small.sim_tick(_main.SIM_DT)
	var cast_lock_ok := (
		not active_small._attacking
		and active_small._move_intent.is_zero_approx()
		and active_small.get_attack_visual_serial() == attack_serial_before_cast_tick
		and active_small.get_visual_facing_direction().is_equal_approx(cast_facing)
	)
	var telegraph_queued: bool = (
		front.hp == front_hp
		and is_zero_approx(front.stun_timer)
		and _main._pending_frontal_stun_skills.size() == 1
		and _main._frontal_skill_effects.size() == 1
	)
	_main._tick_pending_frontal_stun_skills(float(skill.transform_impact_delay) - 0.05)
	var waits_for_hand_impact := front.hp == front_hp and is_zero_approx(front.stun_timer)
	_main._tick_pending_frontal_stun_skills(0.05)
	var frontal_hit_ok := front.hp == front_hp - float(skill.damage) and is_equal_approx(front.stun_timer, 1.0)
	var filtering_ok := back.hp == back_hp and is_zero_approx(back.stun_timer) and air.hp == air_hp and is_zero_approx(air.stun_timer)
	var frozen_position := front.position
	front._move_intent = Vector2.DOWN * front.move_speed
	front.sim_tick(_main.SIM_DT)
	_expect(active_small_contract and cast_lock_ok and telegraph_queued and waits_for_hand_impact and frontal_hit_ok, "小纳尔主动锁定发动方向且不能移动/普攻，合成变身 Spell2 手掌触地才造成伤害和 1 秒眩晕")
	_expect(filtering_ok and front.position == frozen_position, "大纳尔 Spell2 不命中后方或空中单位，眩晕期间目标不能自主行动")
	active_small.form_transition_timer = 0.0
	active_small.active_skill_cast_timer = 0.0
	active_small.active_skill_cast_facing = Vector2.ZERO
	_main._activate_dual_form_skill(active_small, skill)
	var mega_waits_for_impact: bool = (
		active_small.get_visual_action_name() == &"active"
		and _main._pending_frontal_stun_skills.size() == 1
		and is_equal_approx(active_small.active_skill_cast_timer, float(skill.cast_duration))
	)
	_expect(mega_waits_for_impact, "大纳尔主动固定方向并锁定行动，直接播放 Spell2 后延迟到 0.8 秒手掌触地时结算")
	_main._pending_frontal_stun_skills.clear()
	_main._frontal_skill_effects.clear()
	active_small.active_skill_cast_timer = 0.0
	active_small.active_skill_cast_facing = Vector2.ZERO
	for unit in [gnar, dummy, resize_gnar, crowded_gnar, edge_gnar, edge_neighbor, active_small, front, back, air] + crowded_neighbors:
		if is_instance_valid(unit):
			unit.free()

func _check_gnar_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("gnar").duplicate(true)
	var mega_stats: Dictionary = stats.transformed_stats
	var small_packed := load(stats.visual_scene_path) as PackedScene
	var mega_packed := load(mega_stats.visual_scene_path) as PackedScene
	_expect(small_packed != null and mega_packed != null, "纳尔小/大双形态包装场景均可加载")
	if small_packed == null or mega_packed == null:
		return
	_expect(stats.visual_animations.attack == ["Gnar_Attack1_anm", "Gnar_Attack2_anm"], "小纳尔普通攻击使用非 Fast 版 Attack1/Attack2")
	var art_panel := ArtDevPanel.new()
	_main.add_child(art_panel)
	art_panel.setup(CardDB.all())
	art_panel._select_item("gnar")
	_expect(not art_panel._skill_button.disabled, "美术开发面板选择纳尔后可用主动技能按钮")
	art_panel.free()
	var deck_builder := DeckBuilder.new()
	var mega_attributes: Array[Dictionary] = deck_builder._card_attributes(mega_stats)
	deck_builder.free()
	var mega_hp_shown := false
	var mega_damage_shown := false
	for attribute in mega_attributes:
		if String(attribute.get("name", "")) == "生命" and String(attribute.get("value", "")) == "820":
			mega_hp_shown = true
		if String(attribute.get("name", "")) == "单次伤害" and String(attribute.get("value", "")) == "85":
			mega_damage_shown = true
	_expect(mega_hp_shown and mega_damage_shown, "纳尔信息面板可读取大纳尔变形后的生命与伤害")
	var visuals_valid := true
	for form_stats in [stats, mega_stats]:
		var sample := (load(form_stats.visual_scene_path) as PackedScene).instantiate() as Node3D
		if sample.has_method("prepare_visual_animations"):
			sample.call("prepare_visual_animations")
		var player := _find_anim_player(sample)
		var animations: Dictionary = form_stats.visual_animations
		for key in ["deploy", "idle", "move", "death"]:
			var animation_name := String(animations.get(key, ""))
			visuals_valid = visuals_valid and player != null and player.has_animation(animation_name)
		for attack_key in ["attack", "attack_structure"]:
			for animation_name in animations.get(attack_key, []):
				visuals_valid = visuals_valid and player != null and player.has_animation(String(animation_name))
		var move_enter_name := String(animations.get("move_enter", ""))
		if not move_enter_name.is_empty():
			visuals_valid = visuals_valid and player != null and player.has_animation(move_enter_name)
		for configured_action in (animations.get("visual_actions", {}) as Dictionary).values():
			var action_names: Array = configured_action if configured_action is Array else [configured_action]
			for animation_name in action_names:
				visuals_valid = visuals_valid and player != null and player.has_animation(String(animation_name))
		var followup_scene_path := String(animations.get("death_followup_scene_path", ""))
		if not followup_scene_path.is_empty():
			var followup_sample := (load(followup_scene_path) as PackedScene).instantiate() as Node3D
			var followup_player := _find_anim_player(followup_sample)
			visuals_valid = visuals_valid and followup_player != null and followup_player.has_animation(String(animations.get("death_followup_animation", "")))
			followup_sample.free()
		sample.free()
	_expect(visuals_valid, "纳尔双形态 Idle/Run/Attack/Death 与变身/Spell2 动画名均在源模型中存在")
	var small_sample := small_packed.instantiate() as Node3D
	var mega_sample := mega_packed.instantiate() as Node3D
	var small_model := small_sample.get_node_or_null("Model") as Node3D
	var mega_model := mega_sample.get_node_or_null("Model") as Node3D
	_expect(
		small_model != null and mega_model != null
		and is_equal_approx(small_model.scale.x, 0.0105)
		and is_equal_approx(mega_model.scale.x, 0.00825)
		and is_equal_approx(small_model.position.y, 0.5)
		and mega_model.position.y < small_model.position.y,
		"纳尔双模型分别按小/极大体型校准缩放与脚底偏移",
	)
	small_sample.free()
	mega_sample.free()

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
	var small_standard_attack_playing := false
	if view != null:
		unit._target = unit
		unit._attacking = true
		view._play_attack(1)
		small_standard_attack_playing = view._animation_player.current_animation == "Gnar_Attack1_anm"
		unit._attacking = false
	unit.transform_to_mega()
	if view != null:
		view._sync_visual(false, 0.05)
	var swapped_and_playing := (
		view != null
		and view._model_root.name == "GnarMegaView"
		and view._animation_player.current_animation == "gnar_runtime/Rage_Transform"
	)
	var rage_transform_filtered := false
	var rage_transform_duration_ok := false
	var rage_transform_has_body_motion := false
	var rage_endpoint_scale_ok := false
	var attack_waited_for_transform := false
	var mega_run_in_then_loop := false
	var mega_run_in_filtered := false
	var revert_transform_started := false
	var revert_transform_filtered := false
	var revert_transform_duration_ok := false
	var revert_transform_has_body_motion := false
	var revert_endpoint_scale_ok := false
	var small_run_in_then_loop := false
	var small_run_in_filtered := false
	var active_transform_chain := false
	var turret_attack_playing := false
	var unit_attack_playing := false
	if view != null:
		var rage_transform_animation := view._animation_player.get_animation(&"gnar_runtime/Rage_Transform")
		rage_transform_filtered = (
			view._model_root.call("is_filtered_clip_active")
			and int(view._model_root.call("get_filtered_triangle_count")) < int(view._model_root.call("get_original_triangle_count"))
		)
		rage_transform_duration_ok = absf(rage_transform_animation.length - 1.5) < 0.001
		for track_index in rage_transform_animation.get_track_count():
			if rage_transform_animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D and rage_transform_animation.track_get_key_count(track_index) > 1:
				rage_transform_has_body_motion = true
			if (
				rage_transform_animation.track_get_type(track_index) == Animation.TYPE_SCALE_3D
				and String(rage_transform_animation.track_get_path(track_index)) == "Skeleton/Skeleton3D:Root"
			):
				var first_scale: Vector3 = rage_transform_animation.track_get_key_value(track_index, 0)
				var last_scale: Vector3 = rage_transform_animation.track_get_key_value(track_index, rage_transform_animation.track_get_key_count(track_index) - 1)
				rage_endpoint_scale_ok = absf(first_scale.x - 0.68) < 0.001 and last_scale.is_equal_approx(Vector3.ONE)
		unit._target = unit
		unit._attacking = true
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		var transform_not_interrupted := view._animation_player.current_animation == "gnar_runtime/Rage_Transform"
		view._on_animation_finished(&"gnar_runtime/Rage_Transform")
		attack_waited_for_transform = transform_not_interrupted and view._animation_player.current_animation == "GnarBig_Attack1_anm"
		unit._move_intent = Vector2.UP * unit.move_speed
		unit._attacking = false
		view._sync_visual(false, 0.05)
		var entered_run := view._animation_player.current_animation == "Run_In"
		mega_run_in_filtered = view._model_root.call("is_filtered_clip_active")
		view._on_animation_finished(&"Run_In")
		mega_run_in_then_loop = entered_run and view._animation_player.current_animation == "Run_Base" and not view._model_root.call("is_filtered_clip_active")
		unit._move_intent = Vector2.ZERO
		unit.transform_to_small()
		view._sync_visual(false, 0.05)
		revert_transform_started = view._animation_player.current_animation == "gnar_runtime/Revert_Transform"
		var revert_transform_animation := view._animation_player.get_animation(&"gnar_runtime/Revert_Transform")
		revert_transform_filtered = (
			view._model_root.call("is_filtered_clip_active")
			and int(view._model_root.call("get_filtered_triangle_count")) < int(view._model_root.call("get_original_triangle_count"))
		)
		revert_transform_duration_ok = absf(revert_transform_animation.length - 1.333333) < 0.001
		for track_index in revert_transform_animation.get_track_count():
			if revert_transform_animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D and revert_transform_animation.track_get_key_count(track_index) > 1:
				revert_transform_has_body_motion = true
			if (
				revert_transform_animation.track_get_type(track_index) == Animation.TYPE_SCALE_3D
				and String(revert_transform_animation.track_get_path(track_index)) == "Skeleton/Skeleton3D:Root_Upper"
			):
				var first_scale: Vector3 = revert_transform_animation.track_get_key_value(track_index, 0)
				var last_scale: Vector3 = revert_transform_animation.track_get_key_value(track_index, revert_transform_animation.track_get_key_count(track_index) - 1)
				revert_endpoint_scale_ok = absf(first_scale.x - 2.45) < 0.001 and last_scale.is_equal_approx(Vector3.ONE)
		view._on_animation_finished(&"gnar_runtime/Revert_Transform")
		unit._move_intent = Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.05)
		var small_entered_run := view._animation_player.current_animation == "Run1_In"
		small_run_in_filtered = view._model_root.call("is_filtered_clip_active")
		view._on_animation_finished(&"Run1_In")
		small_run_in_then_loop = small_entered_run and view._animation_player.current_animation == "Run_Base" and not view._model_root.call("is_filtered_clip_active")
		unit._move_intent = Vector2.ZERO
		unit.transform_to_mega(true)
		view._sync_visual(false, 0.05)
		var active_rage_started := view._animation_player.current_animation == "gnar_runtime/Rage_Spell2_Transform"
		var active_transform_animation := view._animation_player.get_animation(&"gnar_runtime/Rage_Spell2_Transform")
		active_transform_chain = (
			active_rage_started
			and view._model_root.call("is_filtered_clip_active")
			and absf(active_transform_animation.length - 1.2) < 0.001
		)
		view._on_animation_finished(&"gnar_runtime/Rage_Spell2_Transform")
		unit._move_intent = Vector2.ZERO
		unit._target = _main._towers[0]
		unit._attacking = true
		view._play_attack(1)
		turret_attack_playing = view._animation_player.current_animation == "GnarBig_Turret_Attack01_anm"
		unit._target = unit
		view._play_attack(2)
		unit_attack_playing = view._animation_player.current_animation == "GnarBig_Attack2_anm"
	_main._activate_frontal_stun_skill(unit, stats.active_skill)
	if view != null:
		view._sync_visual(false, 0.05)
	var spell2_playing := view != null and view._animation_player.current_animation == "GnarBig_Spell2_anm"
	var death_chain := false
	if view != null:
		view._on_animation_finished(&"GnarBig_Spell2_anm")
		var mega_death_root := view._model_root
		unit.notify_visual_death()
		var big_death_started := view._animation_player.current_animation == "GnarBig_Death_anm"
		view._on_animation_finished(&"GnarBig_Death_anm")
		death_chain = big_death_started and view._model_root != mega_death_root and view._animation_player.current_animation == "Death"
	_expect(attached and swapped_and_playing, "普通变大使用 Rage_Scale 相对 Base 叠加到 Rage_Move 的单段合成动画，权威形态已先切换")
	_expect(small_standard_attack_playing, "小纳尔实战表现代理播放非 Fast 版 Gnar_Attack1")
	_expect(rage_transform_filtered and rage_transform_duration_ok and rage_transform_has_body_motion, "变大合成动画保留 1.5 秒完整动作与多帧身体旋转，并隐藏石头")
	_expect(rage_endpoint_scale_ok and revert_endpoint_scale_ok, "变大/变小合成动画重映射根缩放首值并在末帧回到各自包装尺寸")
	_expect(attack_waited_for_transform, "变形期间已经决定攻击时不打断变形，序列结束后立即播放攻击动画")
	_expect(mega_run_in_then_loop and small_run_in_then_loop and mega_run_in_filtered and small_run_in_filtered, "大、小纳尔 Run_In 隐藏石头/额外回旋镖，完成后衔接完整模型 Run")
	_expect(revert_transform_started and revert_transform_filtered and revert_transform_duration_ok and revert_transform_has_body_motion, "变小使用 Revert_Scale 相对 Base 叠加到 Gnar_Revert 的 1.33 秒完整合成动画，并隐藏额外回旋镖")
	_expect(active_transform_chain, "小纳尔主动使用 Rage_Scale 与 Spell2_Tran 同步合成的 1.2 秒变身施法动画")
	_expect(turret_attack_playing and unit_attack_playing, "大纳尔攻击建筑使用 Turret_Attack，攻击单位仍使用普通 Attack")
	_expect(spell2_playing, "大纳尔前方主动使用源模型 Spell2 动画，效果时刻仍由固定模拟决定")
	_expect(death_chain, "大纳尔死亡先播放极短 BigGnar Death，再换小纳尔模型播放 Death")
	if view != null:
		view.free()
	if is_instance_valid(unit):
		unit.free()

## 龙王是首个空中 3D 单位：模型悬空，移动四段循环，吐息进入/循环与退出衔接均由表现状态驱动。
func _check_aurelionsol_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("aurelionsol").duplicate(true)
	stats["deploy_time"] = 0.0
	var packed := load(stats.visual_scene_path) as PackedScene
	_expect(packed != null, "龙王包装场景可加载")
	if packed == null:
		return
	var sample := packed.instantiate() as Node3D
	var model_node := sample.get_node_or_null("Model") as Node3D
	_expect(
		model_node != null and model_node.position.y > 2.0 and is_equal_approx(model_node.scale.x, 0.006),
		"龙王模型以独立表现高度悬在地面上方，权威空中坐标仍留在 2D 地面",
	)
	var anim_names: Dictionary = stats.visual_animations
	var anim_player := _find_anim_player(sample)
	_expect(anim_names.deploy == "Respawn" and is_equal_approx(anim_names.deploy_clip_ratio, 0.5), "龙王部署使用 Respawn 前半段翻滚动画")
	var names_found := anim_player != null
	for key in ["deploy", "idle", "move", "move_enter", "attack_enter", "attack_retarget_enter", "attack_loop", "attack_to_move", "death"]:
		var animation_name := String(anim_names.get(key, ""))
		names_found = names_found and animation_name != "" and anim_player.has_animation(animation_name)
	for animation_name in anim_names.move_cycle:
		names_found = names_found and anim_player.has_animation(String(animation_name))
	_expect(names_found, "龙王 Idle/RunIn/Run1A~D/吐息进入与循环/吐息转移动/Death 动画名均存在")
	_expect(
		anim_names.move_cycle == ["Run1B", "Run1C", "Run1D", "Run1A"]
		and anim_names.attack_enter == "AurelionSol_Spell1_newtst_anm"
		and anim_names.attack_retarget_enter == "AurelionSol_Spell1_new_looptoin_anm"
		and anim_names.attack_loop == "AurelionSol_Spell1_loop_anm"
		and anim_names.attack_to_move == "Spell1_2Run"
		and anim_names.move_enter_after_attack == false,
		"龙王区分移动后 newtst 与原地换目标 new_looptoin，并保留吐息转移动链路",
	)
	var beam_color: Color = stats.continuous_beam_color
	_expect(
		is_equal_approx(beam_color.a, 0.7)
		and stats.continuous_beam_start_width < stats.continuous_beam_end_width,
		"龙王临时吐息为 70% 不透明度、嘴部窄目标端宽的浅蓝梯形光柱",
	)
	var unit := Unit.new()
	var dummy := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 780.0)
	unit.setup(0, stats, stats.name)
	dummy.setup(1, _sweep_dummy_stats(CardDB.get_card("ashe")), "龙息木桩")
	_main.add_child(unit)
	_main.add_child(dummy)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	var view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			view = child as UnitModel3D
			break
	var attack_transition_ok := false
	var retarget_transition_ok := false
	var move_transition_ok := false
	var move_cycle_ok := false
	var immediate_stop_ok := false
	if view != null:
		unit._target = dummy
		unit._attacking = true
		view._sync_visual(false, 0.05)
		var entered_attack := (
			view._animation_player.current_animation == "AurelionSol_Spell1_newtst_anm"
			and not unit.continuous_beam_visible
		)
		view._on_animation_finished(&"AurelionSol_Spell1_newtst_anm")
		attack_transition_ok = (
			entered_attack
			and view._animation_player.current_animation == "AurelionSol_Spell1_loop_anm"
			and unit.continuous_beam_visible
		)
		# 攻击状态未退出但目标序号推进：表示原目标被击败后在范围内直接换目标。
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		var entered_retarget := (
			view._animation_player.current_animation == "AurelionSol_Spell1_new_looptoin_anm"
			and not unit.continuous_beam_visible
		)
		view._on_animation_finished(&"AurelionSol_Spell1_new_looptoin_anm")
		retarget_transition_ok = (
			entered_retarget
			and view._animation_player.current_animation == "AurelionSol_Spell1_loop_anm"
			and unit.continuous_beam_visible
		)
		unit._attacking = false
		unit._move_intent = Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.05)
		var attack_to_run := view._animation_player.current_animation == "Spell1_2Run"
		view._on_animation_finished(&"Spell1_2Run")
		var run_b := view._animation_player.current_animation == "Run1B"
		view._on_animation_finished(&"Run1B")
		var run_c := view._animation_player.current_animation == "Run1C"
		view._on_animation_finished(&"Run1C")
		var run_d := view._animation_player.current_animation == "Run1D"
		view._on_animation_finished(&"Run1D")
		var run_a := view._animation_player.current_animation == "Run1A"
		view._on_animation_finished(&"Run1A")
		var looped_to_b := view._animation_player.current_animation == "Run1B"
		move_transition_ok = attack_to_run and run_b and not unit.continuous_beam_visible
		move_cycle_ok = run_b and run_c and run_d and run_a and looped_to_b
		unit._move_intent = Vector2.ZERO
		unit._attacking = true
		view._sync_visual(false, 0.05)
		view._on_animation_finished(&"AurelionSol_Spell1_newtst_anm")
		unit._attacking = false
		view._sync_visual(false, 0.05)
		immediate_stop_ok = (
			view._animation_player.current_animation == "Idle1_Base"
			and not unit.continuous_beam_visible
		)
	_expect(attached and attack_transition_ok, "龙王吐息进入段不显示光柱，进入循环吐息后才显示")
	_expect(retarget_transition_ok, "龙王原地击败目标并直接换目标时播放 new_looptoin→loop")
	_expect(move_transition_ok, "龙王吐息后按 Spell1_2Run→Run1B 直接接入移动循环")
	_expect(move_cycle_ok, "龙王移动按 Run1B→Run1C→Run1D→Run1A 循环")
	_expect(immediate_stop_ok, "龙王退出攻击时立即打断吐息循环，不等待循环动画播完")
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := view != null and view._dying and view._animation_player.current_animation == "Death"
	_expect(death_view_found, "龙王死亡时由独立 3D 代理播放 Death")
	if view != null:
		view.free()
	if is_instance_valid(unit):
		unit.free()
	if is_instance_valid(dummy):
		dummy.free()
	if sample != null:
		sample.free()

## 持续吐息的真实换目标：两个目标都在射程内时，击败其一后不移动，直接推进表现序号攻击另一个。
func _check_aurelionsol_direct_retarget() -> void:
	var dragon_stats: Dictionary = CardDB.get_card("aurelionsol").duplicate(true)
	dragon_stats["deploy_time"] = 0.0
	var dummy_stats: Dictionary = CardDB.training_dummy_stats().duplicate(true)
	dummy_stats["deploy_time"] = 0.0
	dummy_stats["hp"] = 30.0
	var dragon := Unit.new()
	var first_dummy := Unit.new()
	var second_dummy := Unit.new()
	dragon.position = Vector2(360.0, 1100.0)
	first_dummy.position = Vector2(360.0, 990.0)
	# 与第一目标相距超过吐息溅射判定，同时仍在龙王攻击范围内。
	second_dummy.position = Vector2(430.0, 980.0)
	dragon.setup(0, dragon_stats, dragon_stats.name)
	first_dummy.setup(1, dummy_stats, "换目标木桩一")
	second_dummy.setup(1, dummy_stats, "换目标木桩二")
	_main.add_child(dragon)
	_main.add_child(first_dummy)
	_main.add_child(second_dummy)
	var start_position := dragon.global_position
	var retargeted_without_move := false
	for _tick in 80:
		dragon.sim_tick(_main.SIM_DT)
		if dragon.get_attack_visual_serial() >= 2 and dragon._target == second_dummy and dragon._attacking:
			retargeted_without_move = true
			break
	_expect(
		first_dummy.hp <= 0.0
		and second_dummy.hp > 0.0
		and retargeted_without_move
		and dragon.global_position.is_equal_approx(start_position),
		"龙王击败射程内第一个目标后不移动，直接推进目标序号并攻击第二个目标",
	)
	for unit in [dragon, first_dummy, second_dummy]:
		if is_instance_valid(unit):
			unit.free()

func _check_attack_target_lock() -> void:
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
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
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
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
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
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
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
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
	var stats: Dictionary = CardDB.get_card("xin").duplicate()
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
	var enemy_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var defender_stats: Dictionary = CardDB.get_card("garen").duplicate()
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
	ProjectileSuite.new(self, _main)._check_projectile_travel()

func _check_tower_projectile_visual() -> void:
	ProjectileSuite.new(self, _main)._check_tower_projectile_visual()

func _check_imp_tower_damage() -> void:
	ProjectileSuite.new(self, _main)._check_imp_tower_damage()

func _check_splash_and_knockback() -> void:
	ProjectileSuite.new(self, _main)._check_splash_and_knockback()

func _check_xin_deploy_sweep() -> void:
	# 横扫千军：赵信生成当帧挥击并击退，Spell4 → Spell4_To_Idle 整段就是 1.5 秒部署。
	var xin_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var light_stats := _sweep_dummy_stats(CardDB.imp_stats())            # 质量 1
	var heavy_stats := _sweep_dummy_stats(CardDB.get_card("garen"))         # 质量 8
	var far_stats := _sweep_dummy_stats(CardDB.get_card("ashe"))            # 圈外
	var air_stats := _sweep_dummy_stats(CardDB.get_card("aurelionsol"))     # 空中
	var xin := Unit.new()
	var light := Unit.new()
	var heavy := Unit.new()
	var far := Unit.new()
	var air := Unit.new()
	xin.position = Vector2(360.0, 900.0)
	light.position = Vector2(360.0, 840.0)
	heavy.position = Vector2(420.0, 900.0)
	far.position = Vector2(360.0, 720.0)
	air.position = Vector2(300.0, 900.0)
	xin.setup(0, xin_stats, xin_stats.name)
	light.setup(1, light_stats, light_stats.name)
	heavy.setup(1, heavy_stats, heavy_stats.name)
	far.setup(1, far_stats, far_stats.name)
	air.setup(1, air_stats, air_stats.name)
	# 敌人先进入战场；赵信加入 combatants 的同一帧就应命中它们。
	for u in [light, heavy, far, air]:
		_main.add_child(u)
	var light_start := light.global_position
	var heavy_start := heavy.global_position
	var far_start := far.global_position
	var air_start := air.global_position
	_main.add_child(xin)
	_expect(not xin.is_deployed() and is_equal_approx(xin._deploy_timer, 1.5), "赵信生成后进入 1.5 秒特殊部署阶段")
	_expect(light._knockback_timer > 0.0 and heavy._knockback_timer > 0.0, "赵信生成当帧立即结算横扫击退")
	_expect(xin._sweep_fx_timer > 0.0, "横扫击退触发短暂扇形冲击特效")
	var xin_start := xin.global_position
	# 跑完整段部署；赵信自身不行动，受击单位的权威击退照常推进。
	for _i in 30:
		for u in [xin, light, heavy, far, air]:
			u.sim_tick(_main.SIM_DT)
		_main._apply_unit_movement(_main.SIM_DT)
	_expect(xin.is_deployed(), "Spell4 → Spell4_To_Idle 的 1.5 秒演出结束后赵信解锁行动")
	_expect(xin.global_position.distance_to(xin_start) < 0.01, "赵信在出场演出期间没有自主移动")
	_expect(light.hp == 99999.0 and heavy.hp == 99999.0, "横扫千军只击退不造成伤害")
	var light_push := light.global_position.distance_to(light_start)
	var heavy_push := heavy.global_position.distance_to(heavy_start)
	var far_push := far.global_position.distance_to(far_start)
	var air_push := air.global_position.distance_to(air_start)
	_expect(light_push > 90.0, "圈内轻单位（质量1）被大幅击退出圈（推移 %.1fpx）" % light_push)
	_expect(heavy_push > 10.0 and heavy_push < light_push, "圈内重单位（质量8）被顶开但幅度小于轻单位（推移 %.1fpx < %.1fpx）" % [heavy_push, light_push])
	_expect(far_push < 0.5, "圈外地面单位不受横扫影响（位移 %.2fpx）" % far_push)
	_expect(air_push < 0.5, "空中单位扫不到（位移 %.2fpx）" % air_push)
	for u in [xin, light, heavy, far, air]:
		u.free()

## 静止木桩属性：不索敌、不移动、不还手，但保留质量与体型，专测横扫本身。
func _sweep_dummy_stats(base: Dictionary) -> Dictionary:
	var stats: Dictionary = base.duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 99999.0
	stats["damage"] = 0.0
	stats["speed"] = 0.0
	stats["sight"] = 0.0
	return stats

func _check_xin_art_integration() -> void:
	# 赵信素材接入：三段普攻循环、出场技能序列与第三击回血。
	var stats: Dictionary = CardDB.get_card("xin").duplicate(true)
	var packed := load(stats.visual_scene_path) as PackedScene
	_expect(packed != null, "赵信包装场景可加载")
	if packed == null:
		return
	var anim_names: Dictionary = stats.visual_animations
	var sample := packed.instantiate() as Node3D
	var anim_player := _find_anim_player(sample)
	var names_found := true
	for key in ["idle", "move", "death"]:
		var animation_name: String = anim_names.get(key, "")
		names_found = names_found and animation_name != "" and anim_player != null and anim_player.has_animation(animation_name)
	for key in ["attack", "attack_hit", "deploy"]:
		for value in anim_names.get(key, []):
			names_found = names_found and String(value) != "" and anim_player != null and anim_player.has_animation(String(value))
	_expect(names_found, "赵信 Idle/Run/Death、三段普攻与出场技能动画名在源模型中都存在")
	_expect(anim_names.deploy == ["Spell4", "Spell4_To_Idle"], "赵信出场技能按 Spell4 → Spell4_To_Idle 序列播放")
	_expect(anim_names.deploy_durations == [1.0, 0.5], "赵信出场技能分段时长为 Spell4 1 秒、Spell4_To_Idle 0.5 秒")
	_expect(anim_names.attack.size() == 3 and anim_names.attack_hit.size() == 3, "赵信三段普攻 Start/收势映射一一对应")
	if sample != null:
		sample.free()
	# 第三击回血：站桩木桩不还手，赵信只应在第 3/6/9…次命中时回复 heal_amount。
	var combat_stats: Dictionary = stats.duplicate()
	combat_stats["deploy_time"] = 0.0
	var xin := Unit.new()
	var dummy := Unit.new()
	xin.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 870.0)
	xin.setup(0, combat_stats, combat_stats.name)
	dummy.setup(1, _sweep_dummy_stats(stats), stats.name)
	_main.add_child(xin)
	_main.add_child(dummy)
	xin.take_damage(xin.max_hp - 300.0)
	var hits := 0
	var heals := 0
	var heal_at_third := false
	var heal_at_sixth := false
	var third_checked := false
	var sixth_checked := false
	var last_self_hp := xin.hp
	var last_dummy_hp := dummy.hp
	# 部署锁定已由上一项独立验证；这里关闭部署时间，只验证三段攻击与回血循环。
	for _i in 280:
		xin.sim_tick(_main.SIM_DT)
		if not is_equal_approx(dummy.hp, last_dummy_hp):
			hits += 1
			last_dummy_hp = dummy.hp
		if xin.hp > last_self_hp + 0.01:
			heals += 1
			last_self_hp = xin.hp
		# 里程碑在 tick 末检查：命中与回血在同一 tick 同步结算。
		if hits >= 3 and not third_checked:
			third_checked = true
			heal_at_third = heals == 1
		if hits >= 6 and not sixth_checked:
			sixth_checked = true
			heal_at_sixth = heals == 2
	_expect(hits >= 7, "赵信在模拟窗口内完成多轮普攻循环（命中 %d 次）" % hits)
	_expect(heal_at_third, "三段循环第三击命中时回复生命")
	_expect(heal_at_sixth, "第六击命中时再次回复，循环持续生效")
	_expect(is_equal_approx(xin.hp, 300.0 + heals * stats.heal_amount), "回血总量与 heal_amount × 触发次数一致（300→%.0f，回复 %d 次）" % [xin.hp, heals])
	xin.free()
	dummy.free()

func _check_king_activation() -> void:
	var king: Tower = _main._king_player
	_main._towers[0].hp = 0.0
	_main._sim_step(_main.SIM_DT)
	_expect(not king.activated and not king.can_attack, "任一公主塔被摧毁后水晶仍不具备攻击能力")

func _check_pocket_deployment() -> void:
	_main._towers[2].hp = 0.0
	_main._sim_step(_main.SIM_DT)
	var left_pocket := Vector2(204.0, 520.0)
	var right_pocket := Vector2(516.0, 520.0)
	_expect(_main._pos_in_deploy_zone(left_pocket, 0, false), "破坏左路公主塔后解锁对应 pocket 部署区")
	_expect(not _main._pos_in_deploy_zone(right_pocket, 0, false), "未破坏的另一路不会提前解锁部署区")

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

func _check_lane_stress() -> void:
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
