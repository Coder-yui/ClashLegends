class_name PresentationSuite
extends RefCounted
## 表现层领域：建筑/单位 3D 代理、体型档位、血条、受击闪白与渲染插值契约。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_structure_art_integration()
	_check_unit_size_tiers()
	_check_visual_state_contract()
	_check_hit_flash_presentation()
	_check_health_bar_team_anchor()
	_check_shared_render_interpolation()
	_check_garen_death_animation()
	_check_masteryi_art_integration()
	_check_ashe_art_integration()
	_check_sett_art_integration()
	_check_teemo_art_integration()

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

func _check_masteryi_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("masteryi").duplicate(true)
	stats["deploy_time"] = 0.0
	var packed := load(stats.visual_scene_path) as PackedScene
	_expect(packed != null, "剑圣包装场景可加载")
	if packed == null:
		return
	var anim_names: Dictionary = stats.visual_animations
	var sample := packed.instantiate() as Node3D
	var anim_player := SuiteUtils.find_anim_player(sample)
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
	var anim_player := SuiteUtils.find_anim_player(sample)
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
	var anim_player := SuiteUtils.find_anim_player(sample)
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
	var anim_player := SuiteUtils.find_anim_player(sample)
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
