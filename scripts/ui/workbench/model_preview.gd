class_name WorkbenchModelPreview
extends SubViewportContainer
## 独立素材观察器。没有 Unit、命中回调或战斗状态；逐帧查看仅作用于该预览实例。
var player: AnimationPlayer
var model: Node3D
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _fit_size := 3.0
var _target := Vector3.ZERO

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(680, 720)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.01
	_camera.far = 10000.0
	_viewport.add_child(_camera)
	_camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111c2a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c6d5ef")
	environment.environment.ambient_light_energy = 0.85
	_viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.5
	_viewport.add_child(light)

func show_definition(stats: Dictionary, team: int) -> PackedStringArray:
	var path := PresentationConfig.scene_path(stats, team)
	var packed: PackedScene
	if not path.is_empty() and ResourceLoader.exists(path):
		packed = load(path) as PackedScene
	return show_packed_scene(packed)

## 工具展台也使用同一套灯光、实例隔离、动作播放与包围盒取景。
func show_packed_scene(packed: PackedScene) -> PackedStringArray:
	player = null
	if is_instance_valid(model):
		model.free()
	model = null
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
	_fit_size = maxf(maxf(box.size.y, box.size.x), box.size.z) * 1.55
	_fit_size = maxf(_fit_size, 0.1)
	set_zoom(1.0)
	return player.get_animation_list() if player != null else PackedStringArray()

func _find_player(node: Node) -> void:
	if node is AnimationPlayer and player == null:
		player = node
	for child in node.get_children():
		_find_player(child)

func _collect_bounds(node: Node, output: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		output.append(node.global_transform * node.get_aabb())
	for child in node.get_children():
		_collect_bounds(child, output)

func set_zoom(value: float) -> void:
	_camera.size = _fit_size / maxf(value, 0.2)
	_camera.position = _target + Vector3(0, _fit_size * 0.22, _fit_size * 2)
	_camera.look_at(_target)

func set_model_yaw(value: float) -> void:
	_pivot.rotation.y = deg_to_rad(value)

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
