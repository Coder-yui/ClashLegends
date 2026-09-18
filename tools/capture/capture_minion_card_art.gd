extends SceneTree
## 从项目内 Order 阵营 3D 模型拍摄小兵卡面。
## 运行：Godot --path . --script tools/capture/capture_minion_card_art.gd

const RENDER_SIZE := Vector2i(616, 1120)
const OUTPUT_SIZE := Vector2i(308, 560)
const PORTRAITS := [
	{
		"id": "melee_minion",
		"scene": "res://assets/units/melee_minion/melee_minion_order_view.tscn",
		"animation": "Idle1",
		"pose_time": 0.35,
		"camera": Vector3(0.0, 1.05, 3.2),
		"target": Vector3(0.0, 0.62, 0.0),
	},
	{
		"id": "ranged_minion",
		"scene": "res://assets/units/ranged_minion/ranged_minion_order_view.tscn",
		"animation": "Idle1",
		"pose_time": 0.35,
		"camera": Vector3(0.0, 1.12, 3.15),
		"target": Vector3(0.0, 0.68, 0.0),
	},
	{
		"id": "siege_minion",
		"scene": "res://assets/units/siege_minion/siege_minion_order_view.tscn",
		"animation": "Idle1",
		"pose_time": 0.35,
		"camera": Vector3(0.0, 1.15, 4.3),
		"target": Vector3(0.0, 0.62, 0.0),
	},
	{
		"id": "super_minion",
		"scene": "res://assets/units/super_minion/super_minion_order_view.tscn",
		"animation": "Idle1",
		"pose_time": 0.35,
		"camera": Vector3(0.0, 1.35, 4.0),
		"target": Vector3(0.0, 0.92, 0.0),
	},
	{
		"id": "minion_squad",
		"squad": true,
		"camera": Vector3(0.0, 1.55, 4.45),
		"target": Vector3(0.0, 0.72, 0.0),
	},
	{
		"id": "melee_minion_squad",
		"squad": true,
		"member_scenes": [
			"res://assets/units/melee_minion/melee_minion_order_view.tscn",
			"res://assets/units/melee_minion/melee_minion_order_view.tscn",
			"res://assets/units/melee_minion/melee_minion_order_view.tscn",
			"res://assets/units/melee_minion/melee_minion_order_view.tscn",
		],
		"positions": [
			Vector3(-0.34, 0.0, 0.18), Vector3(0.34, 0.0, 0.18),
			Vector3(-0.34, 0.0, -0.18), Vector3(0.34, 0.0, -0.18),
		],
		"camera": Vector3(0.0, 1.34, 4.35),
		"target": Vector3(0.0, 0.70, 0.0),
	},
	{
		"id": "ranged_minion_squad",
		"squad": true,
		"member_scenes": [
			"res://assets/units/ranged_minion/ranged_minion_order_view.tscn",
			"res://assets/units/ranged_minion/ranged_minion_order_view.tscn",
			"res://assets/units/ranged_minion/ranged_minion_order_view.tscn",
		],
		# 镜头方向对应战场：一只在前，左右两只在后，位置保持紧凑。
		"positions": [
			Vector3(0.0, 0.0, 0.20),
			Vector3(-0.34, 0.0, -0.16), Vector3(0.34, 0.0, -0.16),
		],
		"camera": Vector3(0.0, 1.28, 4.05),
		"target": Vector3(0.0, 0.66, 0.0),
	},
	{
		"id": "super_minion_squad",
		"squad": true,
		"member_scenes": [
			"res://assets/units/super_minion/super_minion_order_view.tscn",
			"res://assets/units/super_minion/super_minion_order_view.tscn",
		],
		# 两只超级兵并排，卡面构图保持现有版本，不因战场间距调整重拍。
		"positions": [Vector3(-0.46, 0.0, 0.0), Vector3(0.46, 0.0, 0.0)],
		"camera": Vector3(0.0, 1.55, 5.80),
		"target": Vector3(0.0, 0.82, 0.0),
	},
	{
		"id": "siege_minion_squad",
		"squad": true,
		"member_scenes": [
			"res://assets/units/siege_minion/siege_minion_order_view.tscn",
			"res://assets/units/siege_minion/siege_minion_order_view.tscn",
			"res://assets/units/siege_minion/siege_minion_order_view.tscn",
		],
		# 三角形卡面构图与战场方向一致：一只在前、两只在后。
		"positions": [
			Vector3(0.0, 0.0, 0.48),
			Vector3(-0.52, 0.0, -0.30), Vector3(0.52, 0.0, -0.30),
		],
		"camera": Vector3(0.0, 1.82, 7.10),
		"target": Vector3(0.0, 0.88, 0.0),
	},
	{
		"id": "heavy_minion_squad",
		"squad": true,
		"member_scenes": [
			"res://assets/units/super_minion/super_minion_order_view.tscn",
			"res://assets/units/siege_minion/siege_minion_order_view.tscn",
		],
		# 首版构图遮住了后排炮车兵；本次补拍用横向错位和更远镜头确保两名成员完整入镜。
		"positions": [
			Vector3(-1.40, 0.0, 0.50), Vector3(1.40, 0.0, -0.50),
		],
		# 从前方右侧约45度斜拍，保留超级兵前置、炮车兵后置的纵深关系。
		"camera": Vector3(11.50, 1.60, 11.50),
		"target": Vector3(0.0, 0.88, 0.0),
	},
]

var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D

func _initialize() -> void:
	_capture_all.call_deferred()

func _capture_all() -> void:
	_build_studio()
	for portrait: Dictionary in PORTRAITS:
		await _capture_portrait(portrait)
	quit(0)

func _build_studio() -> void:
	_viewport = SubViewport.new()
	_viewport.size = RENDER_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	_stage = Node3D.new()
	_viewport.add_child(_stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.85
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.012, 0.045, 0.11)
	sky_material.sky_horizon_color = Color(0.035, 0.24, 0.31)
	sky_material.ground_horizon_color = Color(0.028, 0.18, 0.25)
	sky_material.ground_bottom_color = Color(0.018, 0.065, 0.12)
	sky_material.sky_curve = 0.32
	sky_material.ground_curve = 0.28
	sky_material.sun_angle_max = 8.0
	sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_stage.add_child(world_environment)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 1.4
	platform_mesh.bottom_radius = 1.55
	platform_mesh.height = 0.14
	platform.mesh = platform_mesh
	platform.position.y = -0.09
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color(0.055, 0.095, 0.14)
	platform_material.metallic = 0.25
	platform_material.roughness = 0.58
	platform_material.emission_enabled = true
	platform_material.emission = Color(0.01, 0.12, 0.18)
	platform_material.emission_energy_multiplier = 0.45
	platform.material_override = platform_material
	_stage.add_child(platform)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key_light.light_color = Color(0.88, 0.95, 1.0)
	key_light.light_energy = 2.1
	key_light.shadow_enabled = true
	_stage.add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-1.7, 1.8, -0.7)
	rim_light.light_color = Color(0.16, 0.62, 1.0)
	rim_light.light_energy = 5.0
	rim_light.omni_range = 5.0
	_stage.add_child(rim_light)

	var warm_light := OmniLight3D.new()
	warm_light.position = Vector3(1.6, 1.15, 1.2)
	warm_light.light_color = Color(1.0, 0.62, 0.28)
	warm_light.light_energy = 2.5
	warm_light.omni_range = 4.0
	_stage.add_child(warm_light)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 31.0
	_camera.near = 0.05
	_camera.far = 30.0
	_stage.add_child(_camera)
	_camera.current = true

func _capture_portrait(portrait: Dictionary) -> void:
	if bool(portrait.get("squad", false)):
		await _capture_squad_portrait(portrait)
		return
	var packed := load(String(portrait.scene)) as PackedScene
	if packed == null:
		push_error("无法加载卡面模型：%s" % portrait.scene)
		return
	var model := packed.instantiate() as Node3D
	model.name = "PortraitModel"
	model.rotation_degrees.y = -18.0
	_stage.add_child(model)
	_camera.position = portrait.camera
	_camera.look_at(portrait.target, Vector3.UP)

	var animation_player := _find_animation_player(model)
	var animation_name := StringName(portrait.animation)
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		animation_player.advance(float(portrait.get("pose_time", 0.35)))

	for i in range(8):
		await process_frame
	var image := _viewport.get_texture().get_image()
	image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path := preload("res://tools/lib/development_paths.gd").output("card_art/%s_loading.png") % portrait.id
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error == OK:
		print("[卡面摄影] 已保存 ", output_path)
	else:
		push_error("卡面保存失败：%s" % output_path)
	model.queue_free()
	await process_frame


func _capture_squad_portrait(portrait: Dictionary) -> void:
	var default_member_scenes := [
		"res://assets/units/melee_minion/melee_minion_order_view.tscn",
		"res://assets/units/melee_minion/melee_minion_order_view.tscn",
		"res://assets/units/melee_minion/melee_minion_order_view.tscn",
		"res://assets/units/ranged_minion/ranged_minion_order_view.tscn",
		"res://assets/units/ranged_minion/ranged_minion_order_view.tscn",
		"res://assets/units/ranged_minion/ranged_minion_order_view.tscn",
	]
	var member_scenes: Array = portrait.get("member_scenes", default_member_scenes)
	# 默认构图让近战兵在镜头较近的前排，远程兵在后排；其他编队可提供自己的位置。
	var default_positions := [
		Vector3(-0.72, 0.0, 0.34), Vector3(0.0, 0.0, 0.48), Vector3(0.72, 0.0, 0.34),
		Vector3(-0.72, 0.0, -0.36), Vector3(0.0, 0.0, -0.48), Vector3(0.72, 0.0, -0.36),
	]
	var positions: Array = portrait.get("positions", default_positions)
	var models: Array[Node3D] = []
	for index in member_scenes.size():
		var packed := load(String(member_scenes[index])) as PackedScene
		if packed == null:
			push_error("无法加载小兵分队卡面模型：%s" % member_scenes[index])
			continue
		var model := packed.instantiate() as Node3D
		model.name = "SquadMember%d" % index
		model.position = positions[index]
		model.rotation_degrees.y = -18.0
		_stage.add_child(model)
		var animation_player := _find_animation_player(model)
		if animation_player != null and animation_player.has_animation(&"Idle1"):
			animation_player.play(&"Idle1")
			animation_player.advance(0.35)
		models.append(model)
	_camera.position = portrait.camera
	_camera.look_at(portrait.target, Vector3.UP)
	for i in range(8):
		await process_frame
	var image := _viewport.get_texture().get_image()
	image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path := preload("res://tools/lib/development_paths.gd").output("card_art/%s_loading.png") % portrait.id
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error == OK:
		print("[卡面摄影] 已保存 ", output_path)
	else:
		push_error("卡面保存失败：%s" % output_path)
	for model in models:
		model.queue_free()
	await process_frame

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
