extends SceneTree
## 从皮克斯 3D 包装场景拍摄多单位卡面。
## 运行：Godot --path . --script tools/capture/capture_pix_card_art.gd
## 动作选片：追加 -- --inspect-attacks，输出 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/pix_attack_contact_sheet.png。

const PIX_SCENE := "res://assets/units/pix/pix_view.tscn"
const RENDER_SIZE := Vector2i(616, 1120)
const OUTPUT_SIZE := Vector2i(308, 560)
const INSPECT_CELL := Vector2i(300, 300)
const INSPECT_TIMES := [0.0, 0.25, 0.50, 0.75, 1.0]

var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_studio()
	if "--inspect-attacks" in OS.get_cmdline_user_args():
		await _capture_attack_contact_sheet()
	else:
		await _capture_card_art()
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
	environment.ambient_light_energy = 1.05
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.055, 0.012, 0.15)
	sky_material.sky_horizon_color = Color(0.30, 0.06, 0.42)
	sky_material.ground_horizon_color = Color(0.16, 0.025, 0.28)
	sky_material.ground_bottom_color = Color(0.025, 0.008, 0.09)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_stage.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_color = Color(0.92, 0.82, 1.0)
	key_light.light_energy = 2.2
	key_light.shadow_enabled = true
	_stage.add_child(key_light)

	var purple_rim := OmniLight3D.new()
	purple_rim.position = Vector3(-1.2, 1.2, -0.5)
	purple_rim.light_color = Color(0.72, 0.28, 1.0)
	purple_rim.light_energy = 5.0
	purple_rim.omni_range = 4.0
	_stage.add_child(purple_rim)

	var pink_fill := OmniLight3D.new()
	pink_fill.position = Vector3(1.3, 0.7, 1.0)
	pink_fill.light_color = Color(1.0, 0.32, 0.72)
	pink_fill.light_energy = 2.2
	pink_fill.omni_range = 3.5
	_stage.add_child(pink_fill)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 28.0
	_camera.near = 0.05
	_camera.far = 30.0
	_stage.add_child(_camera)
	_camera.current = true


func _capture_card_art() -> void:
	_viewport.size = RENDER_SIZE
	_camera.position = Vector3(0.0, 0.50, 2.25)
	_camera.look_at(Vector3(0.0, 0.34, 0.0), Vector3.UP)
	var arrangements := [
		{"position": Vector3(0.0, 0.0, 0.12), "rotation": -8.0, "animation": "Attack1", "time": 0.55, "scale": 1.22},
		{"position": Vector3(-0.43, 0.13, -0.18), "rotation": 18.0, "animation": "Attack2", "time": 0.48, "scale": 0.83},
		{"position": Vector3(0.43, 0.18, -0.25), "rotation": -28.0, "animation": "Idle1", "time": 0.55, "scale": 0.76},
	]
	for arrangement: Dictionary in arrangements:
		var model := _instantiate_pix()
		model.position = arrangement.position
		model.rotation_degrees.y = float(arrangement.rotation)
		model.scale = Vector3.ONE * float(arrangement.scale)
		_stage.add_child(model)
		_pose(model, StringName(arrangement.animation), float(arrangement.time))
	for _frame in range(10):
		await process_frame
	var image := _viewport.get_texture().get_image()
	image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path := preload("res://tools/lib/development_paths.gd").output("card_art/pix_loading.png")
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error == OK:
		print("[卡面摄影] 已保存 ", output_path)
	else:
		push_error("卡面保存失败：%s" % output_path)


func _capture_attack_contact_sheet() -> void:
	_viewport.size = INSPECT_CELL
	_camera.position = Vector3(0.0, 0.42, 1.65)
	_camera.look_at(Vector3(0.0, 0.31, 0.0), Vector3.UP)
	var sheet := Image.create(INSPECT_CELL.x * INSPECT_TIMES.size(), INSPECT_CELL.y * 2, false, Image.FORMAT_RGBA8)
	for row in range(2):
		var animation_name := StringName("Attack%d" % (row + 1))
		for column in range(INSPECT_TIMES.size()):
			var model := _instantiate_pix()
			model.rotation_degrees.y = -12.0
			_stage.add_child(model)
			_pose(model, animation_name, float(INSPECT_TIMES[column]))
			for _frame in range(3):
				await process_frame
			var frame := _viewport.get_texture().get_image()
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, INSPECT_CELL), Vector2i(column * INSPECT_CELL.x, row * INSPECT_CELL.y))
			model.free()
	var output_path := preload("res://tools/lib/development_paths.gd").output("pix_attack_contact_sheet.png")
	var error := sheet.save_png(output_path)
	if error == OK:
		print("[动作选片] 已保存 ", output_path)
	else:
		push_error("动作选片保存失败：%s" % output_path)


func _instantiate_pix() -> Node3D:
	var packed := load(PIX_SCENE) as PackedScene
	return packed.instantiate() as Node3D


func _pose(model: Node, animation_name: StringName, time: float) -> void:
	var player := _find_animation_player(model)
	if player == null or not player.has_animation(animation_name):
		push_error("皮克斯模型缺少动画：%s" % animation_name)
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
