extends SceneTree
## Candidate-only rendering QA. F5 and the production 2D background are unchanged.
## Godot --path . --script tools/capture/capture_rift_arena_v2.gd [-- --hold|--inspect]
## Captures are actual Godot frames, including the existing six tower proxies.

const CANDIDATE_PATH := "res://assets/arena/rift_arena/rift_arena.tscn"
var OUTPUT_PATH := preload("res://tools/lib/development_paths.gd").output("arena_preview_v2")
const STUDIO_BACKGROUND := Color("173c42")

# Override only this instantiated preview's background draw. Inherited gameplay,
# input, deployment validation and the actual hint methods remain unchanged.
class CandidatePreviewMain extends "res://scripts/main.gd":
	func _draw() -> void:
		if not _selected_card.is_empty():
			var stats: Dictionary = CardDB.get_card(_selected_card)
			if String(stats.get("deploy_zone", "own_side")) == "global":
				draw_rect(Rect2(0, 0, ArenaRules.FIELD_W, ArenaRules.FIELD_H), Color(0.40, 0.70, 1.00, 0.08))
			else:
				for row in ArenaRules.ARENA_ROWS:
					for column in ArenaRules.ARENA_COLUMNS:
						var tile := Vector2i(column, row)
						if _tile_in_ground_deploy_zone(tile, 0):
							draw_rect(Rect2(Vector2(tile) * ArenaRules.TILE_SIZE,
								Vector2.ONE * ArenaRules.TILE_SIZE), Color(0.40, 0.70, 1.00, 0.15))
			_draw_deployment_preview(stats)
		for deployment in _commands.pre_deployments:
			_draw_card_pre_deploy_indicator(deployment)

class InspectionControls extends Node:
	var handler: Callable

	func _input(event: InputEvent) -> void:
		if handler.is_valid():
			handler.call(event)

var _main: Node2D
var _presentation: BattlePresentation3D
var _candidate: Node3D
var _output: String
var _proxy_process_states: Dictionary = {}
var _gameplay_transform: Transform3D
var _gameplay_camera_size: float
var _inspection_panel: Control
var _inspection_label: Label
var _inspection_mode := ""
var _orbit_center := Vector3.ZERO


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Arena v2 capture needs the graphics renderer; omit --headless.")
		quit(1)
		return
	root.size = Vector2i(720, 1400)
	root.title = "Clash Legends — Rift Arena v2 candidate"
	RenderingServer.set_default_clear_color(STUDIO_BACKGROUND)
	_output = ProjectSettings.globalize_path(OUTPUT_PATH)
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		push_error("Unable to create capture directory: " + _output)
		quit(1)
		return
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_main.set_script(CandidatePreviewMain)
	root.add_child(_main)
	current_scene = _main
	await process_frame
	_main._start_local()
	_main.set_process(false)
	_main._ai.enabled = false
	_main._minion_waves_enabled = false
	_presentation = _main._battle_presentation
	_candidate = (load(CANDIDATE_PATH) as PackedScene).instantiate()
	if _candidate.get_script() == null or not _candidate.get_script().can_instantiate():
		push_error("Arena v2 materials did not load. Import current arena assets before capture.")
		_candidate.free()
		quit(1)
		return
	_presentation._world_root.add_child(_candidate)
	_set_background()
	# Main's preview-only _draw retains the existing hint renderer above the
	# candidate viewport. Runtime files and authority rules are unchanged.
	var overlay := _presentation.get_node("UnitOverlay3D") as Sprite2D
	overlay.show_behind_parent = true
	overlay.z_index = -1
	_main.queue_redraw()
	# Let both Nexus spawn animations finish before evaluating their silhouettes.
	await create_timer(2.8).timeout
	await _settle_frames(12)
	if not _save_viewport(_presentation._viewport, "rift_arena_clean.png"):
		return
	# All four units use the shared authoritative play_card entry point with its
	# normal position validation. The immediate option is the existing dev flow.
	for spec in [[0, "garen", Vector2(140, 760)], [1, "garen", Vector2(140, 520)],
		[0, "ashe", Vector2(580, 840)], [1, "ashe", Vector2(580, 440)]]:
		if not _main.play_card(spec[0], spec[1], spec[2], {"immediate": true}):
			push_error("Arena v2 capture could not play card: " + str(spec))
			quit(1)
			return
	for _i in range(40):
		_main._sim_step(0.05)
		await process_frame
	_main._selected_card = "garen"
	_main._update_deployment_preview(Vector2(340, 820))
	await _settle_frames(12)
	if not _save_viewport(root, "rift_arena_gameplay.png"):
		return
	# Proxies project authority pixels through the camera every frame. Freeze their
	# positions before inspecting the model with a different local preview camera.
	_gameplay_transform = _presentation._camera.transform
	_gameplay_camera_size = _presentation._camera.size
	_freeze_proxy_positions()
	_presentation._viewport.size = Vector2i(1680, 1500)
	_fit_overview()
	await _settle_frames(12)
	if not _save_viewport(_presentation._viewport, "rift_arena_overview.png"):
		return
	_presentation._viewport.size = Vector2i(1600, 1000)
	_presentation._camera.position = Vector3(3.5, 20.0, 19.0)
	_presentation._camera.look_at(Vector3(0.0, -0.1, 0.0), Vector3.UP)
	_presentation._camera.size = 15.7
	await _settle_frames(12)
	if not _save_viewport(_presentation._viewport, "rift_arena_river_detail.png"):
		return
	print("[Arena v2 render] draw calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("[Arena v2 capture] ", _output)
	if OS.get_cmdline_user_args().has("--inspect"):
		_start_inspector()
		await _settle_frames(4)
		print("[Arena v2 capture] Inspector ready: 1 gameplay, 2 overview, 3 river; overview arrows orbit and wheel zoom.")
		return
	# --hold returns to the authority-aligned gameplay view and leaves water and
	# visual animations running. The manually advanced match remains paused.
	_restore_gameplay_camera()
	await _settle_frames(4)
	if OS.get_cmdline_user_args().has("--hold"):
		print("[Arena v2 capture] Holding candidate gameplay view; close the window to exit.")
		return
	quit()


func _set_background() -> void:
	_presentation._viewport.transparent_bg = false
	for child in _presentation._world_root.get_children():
		if child is WorldEnvironment:
			# Duplicating keeps this preview's studio background instance-local.
			child.environment = child.environment.duplicate()
			child.environment.background_mode = Environment.BG_COLOR
			child.environment.background_color = STUDIO_BACKGROUND
			child.environment.ambient_light_energy = 0.95
		elif child is DirectionalLight3D:
			# Instance-local contact shadows help seat the scenery on the ground.
			# The production presentation light retains its original settings.
			child.light_energy = 0.90
			child.shadow_enabled = true
			child.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			child.directional_shadow_max_distance = 100.0
			child.directional_shadow_blend_splits = true
			child.shadow_bias = 0.03
			child.shadow_normal_bias = 0.5
			child.shadow_opacity = 0.70


func _freeze_proxy_positions() -> void:
	for child in _presentation._world_root.get_children():
		if child is UnitModel3D or child is TowerModel3D:
			if not _proxy_process_states.has(child):
				_proxy_process_states[child] = child.is_processing()
			child.set_process(false)


func _restore_gameplay_camera() -> void:
	_presentation._viewport.size = Vector2i(720, 1280)
	_presentation._camera.transform = _gameplay_transform
	_presentation._camera.size = _gameplay_camera_size
	_presentation._camera.far = 100.0
	for child in _proxy_process_states:
		if is_instance_valid(child):
			child.set_process(_proxy_process_states[child])


func _start_inspector() -> void:
	_main.set_process_unhandled_input(false)
	var layer := CanvasLayer.new()
	layer.name = "ArenaInspectionLayer"
	layer.layer = 100
	root.add_child(layer)
	_inspection_panel = Control.new()
	_inspection_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_inspection_panel)
	var backdrop := ColorRect.new()
	backdrop.color = STUDIO_BACKGROUND
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspection_panel.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var picture := TextureRect.new()
	picture.texture = _presentation._viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspection_panel.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 18.0
	picture.offset_top = 50.0
	picture.offset_right = -18.0
	picture.offset_bottom = -18.0
	_inspection_label = Label.new()
	_inspection_label.position = Vector2(22.0, 16.0)
	_inspection_label.add_theme_font_size_override("font_size", 17)
	_inspection_label.add_theme_color_override("font_color", Color("e0ebe7"))
	_inspection_panel.add_child(_inspection_label)
	var controls := InspectionControls.new()
	controls.name = "ArenaInspectionControls"
	controls.handler = _inspect_input
	root.add_child(controls)
	_switch_inspection_view("overview")
	root.grab_focus()


func _switch_inspection_view(mode: String) -> void:
	# Always freeze before changing camera or resolution; never project authority
	# coordinates through a free camera, including during keyboard view changes.
	_freeze_proxy_positions()
	_inspection_mode = mode
	if mode == "gameplay":
		root.size = Vector2i(720, 1400)
		root.content_scale_size = Vector2i(720, 1400)
		_inspection_panel.hide()
		_restore_gameplay_camera()
		root.title = "Rift Arena v2 — 1 Gameplay | 2 Overview | 3 River"
		return
	root.size = Vector2i(1200, 900)
	root.content_scale_size = Vector2i(1200, 900)
	_inspection_panel.show()
	_inspection_label.text = "1 实战正交    2 全景    3 河道     |     全景：← → 旋转，滚轮缩放"
	if mode == "overview":
		_presentation._viewport.size = Vector2i(1680, 1500)
		_fit_overview()
		root.title = "Rift Arena v2 — Overview / 全景检查"
	else:
		_presentation._viewport.size = Vector2i(1600, 1000)
		_presentation._camera.position = Vector3(3.5, 20.0, 19.0)
		_presentation._camera.look_at(Vector3(0.0, -0.1, 0.0), Vector3.UP)
		_presentation._camera.size = 15.7
		root.title = "Rift Arena v2 — River / 河道检查"


func _inspect_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_switch_inspection_view("gameplay")
			KEY_2, KEY_KP_2:
				_switch_inspection_view("overview")
			KEY_3, KEY_KP_3:
				_switch_inspection_view("river")
			KEY_LEFT, KEY_RIGHT:
				if _inspection_mode == "overview":
					var angle := -0.10 if event.keycode == KEY_LEFT else 0.10
					var offset := _presentation._camera.position - _orbit_center
					_presentation._camera.position = _orbit_center + offset.rotated(Vector3.UP, angle)
					_presentation._camera.look_at(_orbit_center, Vector3.UP)
			_:
				return
		root.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and _inspection_mode == "overview":
		var zoom := 1.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = 0.91
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = 1.10
		else:
			return
		_presentation._camera.size = clampf(_presentation._camera.size * zoom, 12.0, 120.0)
		root.set_input_as_handled()


func _fit_overview() -> void:
	var bounds_points: Array[Vector3] = []
	_collect_mesh_bounds(_candidate, bounds_points)
	# Tower positions are real proxies; add room for their standing silhouettes.
	for child in _presentation._world_root.get_children():
		if child is TowerModel3D:
			bounds_points.append(child.global_position + Vector3(0.0, 5.0, 0.0))
	if bounds_points.is_empty():
		bounds_points = [Vector3(-14.0, -3.0, -27.0), Vector3(14.0, 5.0, 27.0)]
	var bounds := AABB(bounds_points[0], Vector3.ZERO)
	for point in bounds_points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	var camera := _presentation._camera
	camera.position = center + Vector3(28.0, 39.0, 41.0)
	camera.look_at(center, Vector3.UP)
	camera.far = 160.0
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in bounds_points:
		var local := camera.to_local(point)
		minimum = minimum.min(Vector2(local.x, local.y))
		maximum = maximum.max(Vector2(local.x, local.y))
	var projected_center := (minimum + maximum) * 0.5
	var framing_offset := camera.global_basis.x * projected_center.x + camera.global_basis.y * projected_center.y
	camera.position += framing_offset
	_orbit_center = center + framing_offset
	var extents := maximum - minimum
	var aspect := float(_presentation._viewport.size.x) / float(_presentation._viewport.size.y)
	camera.size = maxf(extents.y, extents.x / aspect) * 1.12


func _collect_mesh_bounds(node: Node, points: Array[Vector3]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh_bounds: AABB = node.get_aabb()
		for index in range(8):
			points.append(node.global_transform * mesh_bounds.get_endpoint(index))
	for child in node.get_children():
		_collect_mesh_bounds(child, points)


func _settle_frames(count: int) -> void:
	for _i in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _save_viewport(viewport: Viewport, filename: String) -> bool:
	var frame := viewport.get_texture().get_image()
	var save_result := frame.save_png(_output.path_join(filename))
	if save_result != OK:
		push_error("Arena v2 capture failed to save " + filename + ": " + str(save_result))
		quit(1)
		return false
	print("[Arena v2 capture] ", filename, " ", frame.get_width(), "×", frame.get_height())
	return true
