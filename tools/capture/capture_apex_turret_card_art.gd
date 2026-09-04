extends SceneTree
## 使用 H-28Q 尖端炮台正式 3D 包装场景拍摄卡面。
## 运行：Godot --path . --script tools/capture/capture_apex_turret_card_art.gd

const RENDER_SIZE := Vector2i(616, 1120)
const OUTPUT_SIZE := Vector2i(308, 560)
const TURRET_SCENE := preload("res://assets/units/apex_turret/apex_turret_view.tscn")


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

	var turret := TURRET_SCENE.instantiate() as Node3D
	turret.position = Vector3(-0.10, 0.0, 0.0)
	turret.rotation_degrees.y = 18.0
	turret.scale = Vector3.ONE * 1.12
	stage.add_child(turret)
	_play_pose(turret, &"Idle1", 0.45)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 31.0
	camera.near = 0.05
	camera.far = 30.0
	camera.position = Vector3(0.15, 2.30, 6.45)
	stage.add_child(camera)
	camera.look_at(Vector3(0.06, 0.76, 0.10), Vector3.UP)
	camera.current = true

	for _frame in range(14):
		await process_frame
	var image := viewport.get_texture().get_image()
	image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path := ProjectSettings.globalize_path("res://assets/cards/apex_turret_loading.png")
	var error := image.save_png(output_path)
	if error == OK:
		print("[卡面摄影] 已保存 res://assets/cards/apex_turret_loading.png")
	else:
		push_error("H-28Q 尖端炮台卡面保存失败：%s" % output_path)
	quit(0 if error == OK else 1)


func _build_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.86
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.006, 0.018, 0.052)
	sky_material.sky_horizon_color = Color(0.015, 0.18, 0.25)
	sky_material.ground_horizon_color = Color(0.045, 0.11, 0.14)
	sky_material.ground_bottom_color = Color(0.004, 0.012, 0.025)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 1.55
	platform_mesh.bottom_radius = 1.78
	platform_mesh.height = 0.18
	platform_mesh.radial_segments = 64
	platform.mesh = platform_mesh
	platform.position.y = -0.11
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color(0.018, 0.055, 0.070)
	platform_material.metallic = 0.72
	platform_material.roughness = 0.34
	platform.material_override = platform_material
	stage.add_child(platform)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46.0, -34.0, 0.0)
	key.light_color = Color(0.72, 0.92, 1.0)
	key.light_energy = 2.05
	key.shadow_enabled = true
	stage.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.55, 1.45, -0.55)
	rim.light_color = Color(0.05, 0.62, 1.0)
	rim.light_energy = 7.0
	rim.omni_range = 5.0
	stage.add_child(rim)

	var warm_fill := OmniLight3D.new()
	warm_fill.position = Vector3(1.55, 0.82, 1.8)
	warm_fill.light_color = Color(1.0, 0.38, 0.13)
	warm_fill.light_energy = 3.1
	warm_fill.omni_range = 4.0
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
