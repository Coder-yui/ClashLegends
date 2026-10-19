class_name WorkbenchModelPreview
extends SubViewportContainer
## 独立素材观察器。没有 Unit、命中回调或战斗状态；逐帧查看仅作用于该预览实例。
signal camera_changed

## 工具摄影棚开启后使用交互相机、三点灯光和竖幅画布；普通工作台保持原来的静态观察器行为。
var studio_mode := false
var player: AnimationPlayer
var model: Node3D
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _environment: Environment
var _key_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _rim_light: DirectionalLight3D
var _floor: MeshInstance3D
var _floor_material: StandardMaterial3D
var _model_roots: Array[Node3D] = []
var _models: Array[Node3D] = []
var _players: Array[AnimationPlayer] = []
var _fit_size := 3.0
var _target := Vector3.ZERO
var _floor_y := 0.0
var _camera_yaw := -90.0
var _camera_pitch := 8.0
var _camera_distance := 6.0
var _camera_aim_yaw := 0.0
var _camera_aim_pitch := 0.0
var _camera_roll := 0.0
var _target_height := 0.0
var _fov := 34.0
var _ortho_size := 3.0
var _projection := "perspective"
var _model_yaw := 0.0
var _background_color := Color("111c2a")
var _transparent_background := false
var _dragging := false
var _last_pointer := Vector2.ZERO

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP if studio_mode else Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	# 摄影棚使用卡面常见的竖幅画布；普通工作台继续使用原来的横向预览画布。
	_viewport.size = Vector2i(308, 560) if studio_mode else Vector2i(680, 720)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.01
	_camera.far = 10000.0
	if studio_mode:
		_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_viewport.add_child(_camera)
	_camera.current = true
	var environment := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = _background_color
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("c6d5ef")
	_environment.ambient_light_energy = 0.7 if studio_mode else 0.85
	environment.environment = _environment
	_viewport.add_child(environment)
	if studio_mode:
		_key_light = _make_light(Color("fff1dc"), 1.55, Vector3(-42, -32, 0))
		_fill_light = _make_light(Color("b8d6ff"), 0.55, Vector3(-20, 145, 0))
		_rim_light = _make_light(Color("9ec7ff"), 0.95, Vector3(-25, 155, 0))
		_viewport.add_child(_key_light)
		_viewport.add_child(_fill_light)
		_viewport.add_child(_rim_light)
		_floor = MeshInstance3D.new()
		var floor_mesh := PlaneMesh.new()
		floor_mesh.size = Vector2(20, 20)
		_floor.mesh = floor_mesh
		_floor_material = StandardMaterial3D.new()
		_floor_material.albedo_color = Color("172337")
		_floor_material.roughness = 0.78
		_floor.material_override = _floor_material
		_floor.visible = true
		_viewport.add_child(_floor)
		_apply_camera()
	else:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, -30, 0)
		light.light_energy = 1.5
		_viewport.add_child(light)

func _make_light(color: Color, energy: float, rotation: Vector3) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	# 卡面摄影默认是无影棚；主体轮廓靠三点光和环境光塑形。
	light.shadow_enabled = false
	light.rotation_degrees = rotation
	return light

func show_definition(stats: Dictionary, team: int) -> PackedStringArray:
	var path := PresentationConfig.scene_path(stats, team)
	var packed: PackedScene
	if not path.is_empty() and ResourceLoader.exists(path):
		packed = load(path) as PackedScene
	return show_packed_scene(packed)

## 工具展台也使用同一套灯光、实例隔离、动作播放与包围盒取景。
func show_packed_scene(packed: PackedScene) -> PackedStringArray:
	_clear_preview_models()
	player = null
	if packed == null:
		return PackedStringArray()
	model = packed.instantiate() as Node3D
	if model == null:
		return PackedStringArray()
	_pivot.add_child(model)
	_pivot.rotation = Vector3.ZERO
	_find_player(model)
	if player != null:
		for library_name in player.get_animation_library_list():
			var library := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
			player.remove_animation_library(library_name)
			player.add_animation_library(library_name, library)
		player.stop()
	var bounds: Array[AABB] = []
	_collect_bounds(model, bounds)
	var box := AABB(Vector3.ZERO, Vector3.ONE)
	if not bounds.is_empty():
		box = bounds[0]
		for next in bounds.slice(1):
			box = box.merge(next)
	_target = box.get_center()
	if not studio_mode and is_instance_valid(model) and model.has_method("get_preview_focus"):
		_target = model.call("get_preview_focus", _target)
	_fit_size = maxf(maxf(box.size.y, box.size.x), box.size.z) * (2.25 if studio_mode else 1.55)
	_fit_size = maxf(_fit_size, 0.1)
	if studio_mode:
		_floor_y = box.position.y
		_floor.position.y = _floor_y
		_reset_studio_camera()
	else:
		set_zoom(1.0)
	return player.get_animation_list() if player != null else PackedStringArray()

## 摄影棚组合入口。每个 entry 至少包含 packed，可选 position(Vector3)、yaw(float)、scale(float)。
## 返回值保留了 wrapper、model、player 和动画列表，供工具面板调整每个成员。
func show_packed_scenes(entries: Array) -> Array:
	_clear_preview_models()
	var result: Array = []
	for entry in entries:
		if not entry is Dictionary:
			continue
		var packed := entry.get("packed") as PackedScene
		if packed == null:
			continue
		var wrapper := Node3D.new()
		var position_variant: Variant = entry.get("position", Vector3.ZERO)
		wrapper.position = position_variant if position_variant is Vector3 else Vector3.ZERO
		wrapper.rotation_degrees.y = float(entry.get("yaw", 0.0))
		var uniform_scale := maxf(float(entry.get("scale", 1.0)), 0.05)
		wrapper.scale = Vector3.ONE * uniform_scale
		_pivot.add_child(wrapper)
		var instance := packed.instantiate() as Node3D
		if instance == null:
			wrapper.free()
			continue
		wrapper.add_child(instance)
		var instance_player := _find_player_in(instance)
		if instance_player != null:
			_duplicate_animation_libraries(instance_player)
			instance_player.stop()
		_model_roots.append(wrapper)
		_models.append(instance)
		_players.append(instance_player)
		result.append({"root": wrapper, "model": instance, "player": instance_player, "clips": instance_player.get_animation_list() if instance_player != null else PackedStringArray()})
	if not _models.is_empty():
		model = _models[0]
		player = _players[0]
	_recalculate_bounds(true)
	return result

func recalculate_group_bounds() -> void:
	if not _model_roots.is_empty():
		_recalculate_bounds(false)

func group_root(index: int) -> Node3D:
	return _model_roots[index] if index >= 0 and index < _model_roots.size() else null

func group_player(index: int) -> AnimationPlayer:
	return _players[index] if index >= 0 and index < _players.size() else null

func _clear_preview_models() -> void:
	for wrapper in _model_roots:
		if is_instance_valid(wrapper):
			wrapper.free()
	_model_roots.clear()
	_models.clear()
	_players.clear()
	if is_instance_valid(model):
		model.free()
	model = null
	player = null

func _duplicate_animation_libraries(target_player: AnimationPlayer) -> void:
	for library_name in target_player.get_animation_library_list():
		var library := target_player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		target_player.remove_animation_library(library_name)
		target_player.add_animation_library(library_name, library)

func _find_player_in(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_player_in(child)
		if found != null:
			return found
	return null

func _recalculate_bounds(reset_camera: bool) -> void:
	var bounds: Array[AABB] = []
	if not _model_roots.is_empty():
		for wrapper in _model_roots:
			_collect_bounds(wrapper, bounds)
	elif is_instance_valid(model):
		_collect_bounds(model, bounds)
	if bounds.is_empty():
		return
	var box := bounds[0]
	for next in bounds.slice(1):
		box = box.merge(next)
	_target = box.get_center()
	if not studio_mode and is_instance_valid(model) and model.has_method("get_preview_focus"):
		_target = model.call("get_preview_focus", _target)
	_fit_size = maxf(maxf(box.size.y, box.size.x), box.size.z) * (2.25 if studio_mode else 1.55)
	_fit_size = maxf(_fit_size, 0.1)
	if studio_mode:
		_floor_y = box.position.y
		if _floor != null:
			_floor.position.y = _floor_y
		if reset_camera:
			_reset_studio_camera()
		else:
			_apply_camera()
	else:
		set_zoom(1.0)

func _find_player(node: Node) -> void:
	if node is AnimationPlayer and player == null:
		player = node
	for child in node.get_children():
		_find_player(child)

func _collect_bounds(node: Node, output: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		output.append(node.global_transform * node.get_aabb())
	for child in node.get_children():
		_collect_bounds(child, output)

func set_zoom(value: float) -> void:
	var zoom := maxf(value, 0.2)
	if not studio_mode:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = _fit_size / zoom
		_camera.position = _target + Vector3(0, _fit_size * 0.22, _fit_size * 2)
		_camera.look_at(_target)
		return
	_camera_distance = _fit_size * 2.15 / zoom
	_ortho_size = _fit_size / zoom
	_apply_camera()
	camera_changed.emit()

func set_model_yaw(value: float) -> void:
	_model_yaw = value
	_pivot.rotation.y = deg_to_rad(value)
	camera_changed.emit()

func set_camera_orbit(yaw: float, pitch: float, distance: float) -> void:
	_camera_yaw = yaw
	_camera_pitch = clampf(pitch, -75.0, 75.0)
	_camera_distance = maxf(distance, _fit_size * 0.25)
	_apply_camera()
	camera_changed.emit()

## 默认先朝向主体；这些偏移允许镜头在主体基础上改变朝向和滚转。
func set_camera_aim_offsets(yaw: float, pitch: float, roll: float) -> void:
	_camera_aim_yaw = clampf(yaw, -180.0, 180.0)
	_camera_aim_pitch = clampf(pitch, -85.0, 85.0)
	_camera_roll = clampf(roll, -180.0, 180.0)
	_apply_camera()
	camera_changed.emit()

func set_camera_target_height(value: float) -> void:
	_target_height = value
	_apply_camera()
	camera_changed.emit()

func set_projection(mode: String) -> void:
	_projection = "orthographic" if mode == "orthographic" else "perspective"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if _projection == "orthographic" else Camera3D.PROJECTION_PERSPECTIVE
	_apply_camera()
	camera_changed.emit()

func set_fov(value: float) -> void:
	_fov = clampf(value, 20.0, 80.0)
	_camera.fov = _fov
	camera_changed.emit()

func set_ortho_size(value: float) -> void:
	_ortho_size = maxf(value, 0.05)
	_apply_camera()
	camera_changed.emit()

func set_light_energy(kind: String, value: float) -> void:
	var light: DirectionalLight3D = _light_for(kind)
	if light != null:
		light.light_energy = maxf(value, 0.0)
	camera_changed.emit()

func set_ambient_energy(value: float) -> void:
	if _environment != null:
		_environment.ambient_light_energy = maxf(value, 0.0)
	camera_changed.emit()

func set_background(color: Color, transparent: bool = false) -> void:
	_background_color = color
	_transparent_background = transparent
	if _environment != null:
		_environment.background_color = color
	if _viewport != null:
		_viewport.transparent_bg = transparent
	if _floor_material != null:
		_floor_material.albedo_color = color.darkened(0.42)
	camera_changed.emit()

func set_floor_visible(value: bool) -> void:
	if _floor != null:
		_floor.visible = value
	camera_changed.emit()

func studio_state() -> Dictionary:
	return {
		"camera_yaw": _camera_yaw,
		"camera_pitch": _camera_pitch,
		"camera_distance": _camera_distance,
		"distance_factor": _camera_distance / maxf(_fit_size, 0.001),
		"aim_yaw": _camera_aim_yaw,
		"aim_pitch": _camera_aim_pitch,
		"camera_roll": _camera_roll,
		"target_height": _target_height,
		"projection": _projection,
		"fov": _fov,
		"ortho_size": _ortho_size,
		"model_yaw": _model_yaw,
		"key_energy": _key_light.light_energy if _key_light != null else 1.55,
		"fill_energy": _fill_light.light_energy if _fill_light != null else 0.55,
		"rim_energy": _rim_light.light_energy if _rim_light != null else 0.95,
		"ambient_energy": _environment.ambient_light_energy if _environment != null else 0.7,
		"background_color": _background_color.to_html(true),
		"transparent_background": _transparent_background,
		"floor_visible": _floor.visible if _floor != null else false,
	}

func apply_studio_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_camera_yaw = float(state.get("camera_yaw", _camera_yaw))
	_camera_pitch = clampf(float(state.get("camera_pitch", _camera_pitch)), -75.0, 75.0)
	if state.has("distance_factor"):
		_camera_distance = maxf(float(state.get("distance_factor", 2.8)) * _fit_size, _fit_size * 0.25)
	else:
		_camera_distance = maxf(float(state.get("camera_distance", _camera_distance)), _fit_size * 0.25)
	_camera_aim_yaw = clampf(float(state.get("aim_yaw", _camera_aim_yaw)), -180.0, 180.0)
	_camera_aim_pitch = clampf(float(state.get("aim_pitch", _camera_aim_pitch)), -85.0, 85.0)
	_camera_roll = clampf(float(state.get("camera_roll", _camera_roll)), -180.0, 180.0)
	_target_height = float(state.get("target_height", _target_height))
	_projection = "orthographic" if String(state.get("projection", _projection)) == "orthographic" else "perspective"
	_fov = clampf(float(state.get("fov", _fov)), 20.0, 80.0)
	_ortho_size = maxf(float(state.get("ortho_size", _ortho_size)), 0.05)
	_model_yaw = float(state.get("model_yaw", _model_yaw))
	if state.has("background_color"):
		var parsed_color := Color(String(state["background_color"]))
		_background_color = parsed_color
	_transparent_background = bool(state.get("transparent_background", _transparent_background))
	if _key_light != null: _key_light.light_energy = maxf(float(state.get("key_energy", _key_light.light_energy)), 0.0)
	if _fill_light != null: _fill_light.light_energy = maxf(float(state.get("fill_energy", _fill_light.light_energy)), 0.0)
	if _rim_light != null: _rim_light.light_energy = maxf(float(state.get("rim_energy", _rim_light.light_energy)), 0.0)
	if _environment != null:
		_environment.ambient_light_energy = maxf(float(state.get("ambient_energy", _environment.ambient_light_energy)), 0.0)
	if _floor != null: _floor.visible = bool(state.get("floor_visible", _floor.visible))
	_pivot.rotation.y = deg_to_rad(_model_yaw)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if _projection == "orthographic" else Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = _fov
	if _environment != null: _environment.background_color = _background_color
	if _viewport != null: _viewport.transparent_bg = _transparent_background
	_apply_camera()
	camera_changed.emit()

func _reset_studio_camera() -> void:
	_camera_yaw = -90.0
	_camera_pitch = 8.0
	_camera_distance = _fit_size * 2.8
	_camera_aim_yaw = 0.0
	_camera_aim_pitch = 0.0
	_camera_roll = 0.0
	_target_height = 0.0
	_projection = "orthographic"
	_fov = 34.0
	_ortho_size = _fit_size
	_model_yaw = 0.0
	_pivot.rotation = Vector3.ZERO
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.fov = _fov
	_apply_camera()

func reset_studio_camera() -> void:
	_reset_studio_camera()
	camera_changed.emit()

func _apply_camera() -> void:
	if _camera == null:
		return
	var look_target := _target + Vector3(0.0, _target_height, 0.0)
	var yaw := deg_to_rad(_camera_yaw)
	var pitch := deg_to_rad(_camera_pitch)
	var planar := cos(pitch)
	var offset := Vector3(sin(yaw) * planar, sin(pitch), cos(yaw) * planar) * _camera_distance
	_camera.position = look_target + offset
	_camera.look_at(look_target)
	_camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(_camera_aim_pitch))
	_camera.rotate_object_local(Vector3.UP, deg_to_rad(_camera_aim_yaw))
	_camera.rotate_object_local(Vector3.BACK, deg_to_rad(_camera_roll))
	_camera.fov = _fov
	_camera.size = _ortho_size

func _light_for(kind: String) -> DirectionalLight3D:
	match kind:
		"key": return _key_light
		"fill": return _fill_light
		"rim": return _rim_light
	return null

func capture_png(path: String) -> void:
	# 等待一帧，确保刚刚拖动的相机和材质已完成绘制。
	await RenderingServer.frame_post_draw
	if _viewport == null:
		return
	var image := _viewport.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("[CameraStudio] 无法保存截图：%s (%s)" % [path, error])

func _gui_input(event: InputEvent) -> void:
	if not studio_mode:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			_last_pointer = button.position
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			set_camera_orbit(_camera_yaw, _camera_pitch, _camera_distance * 0.9)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			set_camera_orbit(_camera_yaw, _camera_pitch, _camera_distance * 1.1)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		set_camera_orbit(_camera_yaw - motion.relative.x * 0.35, _camera_pitch + motion.relative.y * 0.25, _camera_distance)
		accept_event()

func play_clip(clip: String) -> void:
	if player != null and player.has_animation(clip):
		player.play(clip)
		player.seek(0, true)

func set_playing(value: bool) -> void:
	if player == null or player.assigned_animation.is_empty():
		return
	if value:
		player.play()
	else:
		player.pause()

func seek_seconds(value: float) -> void:
	if player != null and not player.assigned_animation.is_empty():
		player.pause()
		player.seek(value, true)

func set_preview_active(active: bool) -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active:
		set_playing(false)
