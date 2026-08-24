extends SceneTree
## 使用正式墓碑黑雾与小鬼模型拍摄墓碑卡面。
## 运行：Godot --path . --script tools/capture_tombstone_card_art.gd

const RENDER_SIZE := Vector2i(616, 1120)
const OUTPUT_SIZE := Vector2i(308, 560)
const TOMBSTONE_SCENE := preload("res://assets/units/tombstone/tombstone_view.tscn")
const IMP_SCENE := preload("res://assets/units/imp/imp_view.tscn")

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = RENDER_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var stage := Node3D.new()
	viewport.add_child(stage)
	_build_environment(stage)

	var tombstone := TOMBSTONE_SCENE.instantiate() as Node3D
	tombstone.position = Vector3(0.0, 0.0, -0.58)
	tombstone.scale = Vector3.ONE * 1.12
	stage.add_child(tombstone)
	_play_pose(tombstone, &"Idle1", 0.8)
	# 摄影棚不运行权威单位；直接推进纯表现控制器，让正式黑雾达到完整密度。
	tombstone.call("_process", 1.0)

	var imp_left := IMP_SCENE.instantiate() as Node3D
	imp_left.position = Vector3(-0.54, 0.0, 1.24)
	imp_left.rotation.y = -0.18
	imp_left.scale = Vector3.ONE * 0.92
	stage.add_child(imp_left)
	_play_pose(imp_left, &"Run1", 0.18)

	var imp_right := IMP_SCENE.instantiate() as Node3D
	imp_right.position = Vector3(0.58, 0.0, 1.02)
	imp_right.rotation.y = 0.22
	imp_right.scale = Vector3.ONE * 0.96
	stage.add_child(imp_right)
	_play_pose(imp_right, &"Run1", 0.43)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 32.0
	camera.near = 0.05
	camera.far = 30.0
	camera.position = Vector3(0.0, 2.42, 7.6)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.62, 0.18), Vector3.UP)
	camera.current = true

	for i in range(14):
		await process_frame
	var image := viewport.get_texture().get_image()
	image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path := ProjectSettings.globalize_path("res://assets/cards/tombstone_loading.png")
	var error := image.save_png(output_path)
	if error == OK:
		print("[卡面摄影] 已保存 res://assets/cards/tombstone_loading.png")
	else:
		push_error("墓碑卡面保存失败：%s" % output_path)
	quit(0)

func _build_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.003, 0.008, 0.025)
	sky_material.sky_horizon_color = Color(0.025, 0.11, 0.13)
	sky_material.ground_horizon_color = Color(0.018, 0.065, 0.075)
	sky_material.ground_bottom_color = Color(0.004, 0.01, 0.022)
	sky_material.sky_curve = 0.25
	sky_material.ground_curve = 0.30
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 2.3
	platform_mesh.bottom_radius = 2.5
	platform_mesh.height = 0.16
	platform_mesh.radial_segments = 48
	platform.mesh = platform_mesh
	platform.position.y = -0.10
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color(0.035, 0.055, 0.065)
	platform_material.roughness = 0.84
	platform_material.metallic = 0.12
	platform.material_override = platform_material
	stage.add_child(platform)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_color = Color(0.60, 0.82, 0.92)
	key.light_energy = 1.85
	key.shadow_enabled = true
	stage.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.7, 1.6, -0.7)
	rim.light_color = Color(0.08, 0.58, 0.62)
	rim.light_energy = 5.8
	rim.omni_range = 5.0
	stage.add_child(rim)

	var accent := OmniLight3D.new()
	accent.position = Vector3(1.8, 1.0, 1.5)
	accent.light_color = Color(0.42, 0.24, 0.65)
	accent.light_energy = 3.2
	accent.omni_range = 4.5
	stage.add_child(accent)

func _play_pose(node: Node, animation_name: StringName, time: float) -> void:
	var player := _find_animation_player(node)
	if player == null or not player.has_animation(animation_name):
		return
	player.play(animation_name)
	player.advance(time)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
