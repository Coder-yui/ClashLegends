extends SceneTree
## 有界表现夹具：生产 Unit._draw / UnitModel3D，仅四个模型，不启动比赛或全库预热。
## 由 safe_probe.run_guarded 启动，--output=素材库内新目录；输出三张原始截图与输入/锚点。
class DisplayContext extends BattleContext:
	var viewer := 0
	func _init() -> void: super(null, null)
	func has_presentation() -> bool: return true
	func is_net_client() -> bool: return true
	func local_player_team() -> int: return viewer
	func has_carried_skill_visual(_unit: Unit) -> bool: return false

var heartbeat: RefCounted
var output := ""
var canvas: Node2D
var context := DisplayContext.new()
var units: Array[Unit] = []
var models: Array[UnitModel3D] = []
var samples: Array[Dictionary] = []
var camera: Camera3D
var stage: Node3D
var title: Label
var labels: CanvasLayer
var captions: Array[Dictionary] = []
var reference: SubViewport
var render_camera: Camera3D
var canvas_origin := 0.0

func _initialize() -> void:
	heartbeat = preload("res://tools/performance/safe_probe_heartbeat.gd").new(self)
	_run.call_deferred()

func _run() -> void:
	if not heartbeat.enabled:
		push_error("血条渲染检查须通过监督器启动")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty():
		quit(2)
		return
	root.size = Vector2i(1000, 1040)
	root.content_scale_size = Vector2i(1000, 1040)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.set_default_clear_color(Color(0.07, 0.09, 0.12))
	canvas = Node2D.new()
	canvas_origin = 520.0 * (1.0 - BattleGroundProjection.Q)
	root.canvas_transform = Transform2D(0, Vector2(1, BattleGroundProjection.Q), 0, Vector2(0, canvas_origin))
	labels = CanvasLayer.new()
	root.add_child(labels)
	root.add_child(canvas)
	title = _label(Vector2(24, 12), "Production Unit bars / W=60 examples / blue observer", 21)
	var cases := [
		[300, 300, 150, "full + small shield", 3.0],
		[300, 300, 900, "full + huge shield", 3.0],
		[450, 300, 150, "real overflow + shield", 3.0],
		[150, 300, 100, "partial HP + shield", 0.0],
		[3, 300, 2997, "low HP + huge shield", 0.0],
		[300, 300, 0, "full HP / ZERO stacks", 0.0],
		[300, 300, 0, "stasis sample", 3.0],
		[0, 300, 0, "Sion recovery (real HP=0)", 0.0],
		[150, 300, 0, "partial HP / continuous resource", 1.5],
	]
	for index in cases.size():
		var c: Array = cases[index]
		var pos := Vector2(160 + (index % 3) * 330, 170 + (index / 3) * 220)
		var stats := CardDB.get_unit_stats("sion" if index == 7 else "gnar").duplicate(true)
		stats.visual_radius = 30.0
		var u := _unit(stats, index % 2, pos)
		u.hp = c[0]
		u.max_hp = c[1]
		u.net_shield_ratio = 1.0 if c[2] > 0 else 0.0
		u.net_shield_capacity_ratio = float(c[2]) / float(c[1])
		u.skill_resource_max = 3.0 if index != 8 else 100.0
		u.net_skill_resource_ratio = float(c[4]) / u.skill_resource_max
		if index == 6: u.control.apply_replica_stasis(true)
		if index == 7: u.death_form.apply_replica([true, 20])
		# 非零横向头顶偏移专门复现旧技能条漏X问题。
		u.set_visual_head_world_position(pos + Vector2(14, -42))
		u.queue_redraw()
		var caption := _label(Vector2.ZERO, c[3], 16)
		var numbers := _label(Vector2.ZERO, "H=%d M=%d S=%d" % [c[0], c[1], c[2]], 15)
		captions.append({"unit": u, "caption": caption, "numbers": numbers})
	heartbeat.set_phase("setup_models", true)
	_setup_3d()
	for index in 4:
		var stats := CardDB.get_unit_stats("garen" if index == 3 else "gnar")
		var u := _unit(stats, index % 2, Vector2(130 + index * 245, 960))
		if index == 1:
			u.growth_body_scale = 1.3
			u.growth_health_bonus = BattleNumbers.quantity(u.max_hp * 0.3)
			u.max_hp += u.growth_health_bonus
			u.visual_radius *= 1.3
		if index == 2: u.sync_network_form(1, 1)
		u.hp = u.max_hp * 1.5
		u.net_shield_ratio = 1.0
		u.net_shield_capacity_ratio = 0.5
		u.net_skill_resource_ratio = 0.5
		u.skill_resource_max = 6
		var visual := PresentationConfig.for_form(stats, u.get_form_index())
		var view := UnitModel3D.new()
		stage.add_child(view)
		var packed: PackedScene = load(PresentationConfig.scene_path(visual, u.team))
		if not view.setup(u, packed, camera, visual.get("visual_animations", {}), float(visual.get("visual_forward_yaw", 0))):
			push_error("模型setup失败")
			quit(1)
			return
		u.has_model_art = true
		view.set_process(false)
		view._process(0)
		models.append(view)
		var caption := _label(Vector2.ZERO, ["small Gnar", "grown small Gnar", "mega Gnar", "Garen"][index], 17)
		var numbers := _label(Vector2.ZERO, "native W=%.1f" % u.presentation_state().base_health_bar_width, 16)
		captions.append({"unit": u, "caption": caption, "numbers": numbers})
		await process_frame
	await _capture("01-blue")
	context.viewer = 1
	# 真实倒转画布；锚点重新投影，标条在屏幕上保持直立。
	root.canvas_transform = Transform2D(PI, Vector2(1.0, BattleGroundProjection.Q), 0, Vector2(1000, 1040 - canvas_origin))
	camera.rotate_object_local(Vector3.BACK, PI)
	camera.set_meta("canvas_flipped", true)
	for u in units:
		u.set_visual_head_world_position(u.position + Vector2(14, 42))
		u.queue_redraw()
	title.text = "Production Unit bars / red observer / flipped canvas"
	await _capture("02-red-flipped")
	root.canvas_transform = Transform2D(0, Vector2(1, BattleGroundProjection.Q), 0, Vector2(0, canvas_origin))
	camera.rotate_object_local(Vector3.BACK, PI)
	camera.set_meta("canvas_flipped", false)
	context.viewer = 0
	for u in units:
		u.net_shield_ratio = 0
		u.net_shield_capacity_ratio = 0
		u.hp = minf(u.hp, u.max_hp)
		u.control.apply_replica_stasis(false)
		u.set_visual_head_world_position(u.position + Vector2(14, -42))
		u.queue_redraw()
	for view in models: view._process(0)
	title.text = "Shield broken / overflow consumed / stasis restored"
	await _capture("03-restored")
	FileAccess.open(output.path_join("render-inputs.json"), FileAccess.WRITE).store_string(JSON.stringify(samples, "\t"))
	for view in models: view.free()
	for u in units: u.free()
	stage.free()
	reference.free()
	labels.free()
	canvas.free()
	print("[UNIT_BAR_RENDER] completed 3 screenshots; 9 synthetic inputs + 4 production models")
	quit(0)

func _unit(stats: Dictionary, team: int, pos: Vector2) -> Unit:
	var u := Unit.new()
	u.setup(team, stats, "bar-review")
	u.set_battle_context(context)
	u._deploy_timer = 0
	u.position = pos
	canvas.add_child(u)
	u.set_process(false)
	u.net_skill_resource_enabled = true
	units.append(u)
	return u

func _label(pos: Vector2, text: String, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	labels.add_child(label)
	return label

func _setup_3d() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	reference = SubViewport.new()
	reference.size = Vector2i(1000, 1040)
	reference.own_world_3d = true
	reference.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(reference)
	camera = Camera3D.new()
	reference.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.position = Vector3(0, 16.18, 11.76)
	camera.look_at(Vector3.ZERO)
	camera.set_meta("uniform_ground", true)
	camera.current = true
	render_camera = Camera3D.new()
	stage.add_child(render_camera)
	render_camera.projection = camera.projection
	render_camera.size = camera.size
	render_camera.transform = camera.transform
	render_camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.3
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	stage.add_child(environment)

func _capture(name: String) -> void:
	heartbeat.set_phase(name, true)
	for view in models:
		view._stable_head_offset = NAN
		view._process(0)
	for entry in captions:
		var screen: Vector2 = root.canvas_transform * entry.unit.position
		entry.caption.position = screen + Vector2(-110, 43)
		entry.numbers.position = screen + Vector2(-110, 65)
		if entry.unit in units.slice(0, 9):
			entry.numbers.text = "H=%d M=%d S=%d" % [entry.unit.hp, entry.unit.max_hp, roundi(entry.unit.get_shield_health_ratio() * entry.unit.max_hp)]
	for u in units: u.queue_redraw()
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	var img := root.get_texture().get_image()
	var result := img.save_png(output.path_join(name + ".png"))
	if result != OK: push_error("截图保存失败")
	for u in units:
		samples.append({"capture": name, "team": u.team, "form": u.get_form_index(), "hp": u.hp, "max_hp": u.max_hp,
			"shield_ratio": u.get_shield_health_ratio(), "width": u.presentation_state().base_health_bar_width,
			"layout": u.presentation_state().health_bar_layout, "visible": u.presentation_state().health_bar_visible,
			"head": str(u.get_visual_head_screen_position()), "bar": str(u.get_health_bar_screen_center())})
