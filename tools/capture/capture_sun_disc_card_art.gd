extends SceneTree
## 使用太阳圆盘正式组合包装场景拍摄卡面。
## 运行：Godot --path . --script tools/capture/capture_sun_disc_card_art.gd

const RENDER_SIZE := Vector2i(616, 1120)
const OUTPUT_SIZE := Vector2i(308, 560)
const SUN_DISC_SCENE := preload("res://assets/units/sun_disc/sun_disc_blue_view.tscn")


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

	var disc := SUN_DISC_SCENE.instantiate() as Node3D
	disc.position = Vector3(0.0, 0.0, 0.0)
	disc.rotation_degrees.y = 18.0
	stage.add_child(disc)
	_play_pose(disc, &"Idle2_Base", 0.45)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 30.0
	camera.near = 0.05
	camera.far = 40.0
	camera.position = Vector3(0.2, 4.7, 12.2)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 2.45, 0.0), Vector3.UP)
	camera.current = true

	for _frame in range(16):
		await process_frame
	var image := viewport.get_texture().get_image()
	image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path := ProjectSettings.globalize_path("res://assets/cards/sun_disc_loading.png")
	var error := image.save_png(output_path)
	if error == OK:
		print("[卡面摄影] 已保存 res://assets/cards/sun_disc_loading.png")
	else:
		push_error("太阳圆盘卡面保存失败：%s" % output_path)
	quit(0 if error == OK else 1)


func _build_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.92
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.055, 0.025, 0.12)
	sky_material.sky_horizon_color = Color(0.44, 0.17, 0.08)
	sky_material.ground_horizon_color = Color(0.23, 0.08, 0.035)
	sky_material.ground_bottom_color = Color(0.012, 0.006, 0.025)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 1.85
	platform_mesh.bottom_radius = 2.05
	platform_mesh.height = 0.16
	platform_mesh.radial_segments = 64
	platform.mesh = platform_mesh
	platform.position.y = -0.10
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color(0.19, 0.075, 0.025)
	platform_material.metallic = 0.32
	platform_material.roughness = 0.68
	platform.material_override = platform_material
	stage.add_child(platform)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	key.light_color = Color(1.0, 0.80, 0.42)
	key.light_energy = 2.2
	key.shadow_enabled = true
	stage.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.6, 2.6, -0.6)
	rim.light_color = Color(0.35, 0.22, 1.0)
	rim.light_energy = 8.0
	rim.omni_range = 6.0
	stage.add_child(rim)

	var warm_fill := OmniLight3D.new()
	warm_fill.position = Vector3(1.5, 1.4, 2.0)
	warm_fill.light_color = Color(1.0, 0.48, 0.10)
	warm_fill.light_energy = 4.4
	warm_fill.omni_range = 5.0
	stage.add_child(warm_fill)


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
