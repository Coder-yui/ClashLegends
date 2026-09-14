extends SceneTree
## 使用冰晶凤凰正式模型拍摄艾尼维亚卡面。
## 运行：Godot --path . --script tools/capture/capture_anivia_card_art.gd

const RENDER_SIZE := Vector2i(616, 1120)
const OUTPUT_SIZE := Vector2i(308, 560)
const ANIVIA_SCENE := preload("res://assets/units/anivia/anivia_view.tscn")

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

	var phoenix := ANIVIA_SCENE.instantiate() as Node3D
	phoenix.position = Vector3(0.0, 0.0, 0.05)
	phoenix.rotation_degrees.y = -8.0
	phoenix.scale = Vector3.ONE * 0.82
	stage.add_child(phoenix)
	_play_pose(phoenix, &"Idle1", 0.8)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 30.0
	camera.near = 0.05
	camera.far = 30.0
	camera.position = Vector3(0.0, 0.52, 2.25)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.50, 0.0), Vector3.UP)
	camera.current = true

	for _frame in range(14):
		await process_frame
	var image := viewport.get_texture().get_image()
	image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path := ProjectSettings.globalize_path(preload("res://tools/lib/development_paths.gd").output("card_art/anivia_loading.png"))
	var error := image.save_png(output_path)
	if error == OK:
		print("[卡面摄影] 已保存 res://assets/cards/anivia_loading.png")
	else:
		push_error("艾尼维亚卡面保存失败：%s" % output_path)
	quit(0)

func _build_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.95
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.008, 0.045, 0.16)
	sky_material.sky_horizon_color = Color(0.16, 0.48, 0.72)
	sky_material.ground_horizon_color = Color(0.045, 0.16, 0.28)
	sky_material.ground_bottom_color = Color(0.006, 0.018, 0.06)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 2.1
	platform_mesh.bottom_radius = 2.35
	platform_mesh.height = 0.16
	platform_mesh.radial_segments = 48
	platform.mesh = platform_mesh
	platform.position.y = -0.10
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color(0.035, 0.13, 0.22)
	platform_material.roughness = 0.78
	platform_material.metallic = 0.18
	platform.material_override = platform_material
	stage.add_child(platform)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key.light_color = Color(0.72, 0.92, 1.0)
	key.light_energy = 2.25
	key.shadow_enabled = true
	stage.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.45, 1.15, -0.65)
	rim.light_color = Color(0.15, 0.62, 1.0)
	rim.light_energy = 5.4
	rim.omni_range = 4.5
	stage.add_child(rim)

	var accent := OmniLight3D.new()
	accent.position = Vector3(1.4, 0.8, 1.0)
	accent.light_color = Color(0.36, 0.48, 1.0)
	accent.light_energy = 3.2
	accent.omni_range = 4.0
	stage.add_child(accent)

func _play_pose(node: Node, animation_name: StringName, time: float) -> void:
	var player := _find_animation_player(node)
	if player == null or not player.has_animation(animation_name):
		return
	player.play(animation_name)
	player.seek(time, true)
	player.pause()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
