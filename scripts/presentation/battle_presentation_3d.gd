class_name BattlePresentation3D
extends Node
## 战场的 3D 表现容器。模拟、碰撞与联机仍在 Node2D 中运行；
## 本节点只把单位、塔与基地水晶镜像到透明 3D 视口。

var _viewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D

func setup(field_size: Vector2, tile_size: float) -> void:
	_viewport = SubViewport.new()
	_viewport.name = "UnitViewport3D"
	_viewport.size = Vector2i(roundi(field_size.x), roundi(field_size.y))
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_world_root = Node3D.new()
	_world_root.name = "UnitWorld3D"
	_viewport.add_child(_world_root)

	_create_environment()
	_create_camera(field_size.y / tile_size)

	# 透明视口作为普通 2D 画布叠在灰盒地图之上；后添加的单位血条仍会画在它上面。
	var overlay := Sprite2D.new()
	overlay.name = "UnitOverlay3D"
	overlay.centered = false
	overlay.texture = _viewport.get_texture()
	add_child(overlay)

func attach_unit(unit: Unit, stats: Dictionary) -> bool:
	var visual_stats := _unit_visual_stats_for_form(stats, unit.get_form_index())
	var scene_path: String = visual_stats.get("visual_scene_path", "")
	# 水晶兵线等阵营单位共用玩法数据，但 order/chaos 使用各自模型包装场景。
	var scene_paths: Array = visual_stats.get("visual_scene_paths", [])
	if unit.team >= 0 and unit.team < scene_paths.size():
		scene_path = String(scene_paths[unit.team])
	if scene_path.is_empty():
		return false
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("无法加载单位 3D 表现：%s" % scene_path)
		return false
	var view := UnitModel3D.new()
	_world_root.add_child(view)
	var animations: Dictionary = visual_stats.get("visual_animations", {})
	var forward_yaw: float = visual_stats.get("visual_forward_yaw", 0.0)
	if not view.setup(unit, packed, _camera, animations, forward_yaw):
		view.queue_free()
		return false
	unit.has_model_art = true
	unit.queue_redraw()
	unit.form_changed.connect(_on_unit_form_changed.bind(unit, view, stats))
	return true

func _unit_visual_stats_for_form(base_stats: Dictionary, form_index: int) -> Dictionary:
	if form_index == 1:
		var transformed: Dictionary = base_stats.get("transformed_stats", {})
		if not transformed.is_empty():
			return transformed
	return base_stats

func _on_unit_form_changed(form_index: int, unit: Unit, view: UnitModel3D, base_stats: Dictionary) -> void:
	if unit == null or not is_instance_valid(unit) or view == null or not is_instance_valid(view):
		return
	var visual_stats := _unit_visual_stats_for_form(base_stats, form_index)
	var scene_path := String(visual_stats.get("visual_scene_path", ""))
	if scene_path.is_empty():
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("无法加载单位形态 3D 表现：%s" % scene_path)
		return
	view.replace_visual(
		packed,
		visual_stats.get("visual_animations", {}),
		float(visual_stats.get("visual_forward_yaw", 0.0))
	)

func attach_tower(tower: Tower, config: Dictionary) -> bool:
	var scene_paths: Array = config.get("scene_paths", [])
	if tower.team < 0 or tower.team >= scene_paths.size():
		return false
	var scene_path := String(scene_paths[tower.team])
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("无法加载塔的 3D 表现：%s" % scene_path)
		return false
	var view := TowerModel3D.new()
	_world_root.add_child(view)
	if not view.setup(tower, packed, _camera, config):
		view.queue_free()
		return false
	tower.has_model_art = true
	tower.queue_redraw()
	return true

func _create_camera(field_rows: float) -> void:
	_camera = Camera3D.new()
	_camera.name = "UnitCamera3D"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = field_rows
	_camera.near = 0.1
	_camera.far = 100.0
	_camera.position = Vector3(0.0, 24.0, 24.0)
	_world_root.add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_camera.current = true

func _create_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.86)
	environment.ambient_light_energy = 1.1

	var world_environment := WorldEnvironment.new()
	world_environment.name = "UnitEnvironment3D"
	world_environment.environment = environment
	_world_root.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.name = "UnitKeyLight3D"
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_color = Color(1.0, 0.93, 0.82)
	light.light_energy = 1.35
	light.shadow_enabled = false
	_world_root.add_child(light)
