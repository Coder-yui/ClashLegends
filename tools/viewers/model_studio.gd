extends SceneTree
## 共用模型预览器的独立展台与摄影入口；无战斗模拟。
const PREVIEW := preload("res://scripts/ui/workbench/model_preview.gd")
var _options := {}
var _preview: WorkbenchModelPreview
var _time_slider: HSlider
var _label: Label
var _updating := false

func _initialize() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	push_error(message)
	quit(2)

func _parse() -> bool:
	var args := OS.get_cmdline_user_args()
	var allowed := ["card", "scene", "team", "form", "animation", "time", "yaw", "zoom", "capture", "size", "list", "help", "install-missing-art"]
	var index := 0
	while index < args.size():
		var token := args[index]
		if not token.begins_with("--"):
			_fail("Expected --option: " + token)
			return false
		var key := token.trim_prefix("--").get_slice("=", 0)
		if key not in allowed:
			_fail("Unknown option: " + key)
			return false
		if key in ["list", "help", "install-missing-art"]:
			_options[key] = true
		elif "=" in token:
			_options[key] = token.substr(token.find("=") + 1)
		else:
			index += 1
			if index >= args.size():
				_fail("Missing value for " + key)
				return false
			_options[key] = args[index]
		index += 1
	return true

func _run() -> void:
	if not _parse(): return
	if _options.has("help"):
		print("Model studio: --card ID | --scene PATH(.tscn/.glb); --team 0|1 --form 0|1 --animation NAME --time SECONDS --yaw DEGREES --zoom SCALE --list --capture OUTPUT.png --size 308x560 --install-missing-art")
		quit()
		return
	if _options.has("card") == _options.has("scene"):
		_fail("Specify exactly one of --card or --scene")
		return
	for key in ["time", "yaw", "zoom"]:
		if _options.has(key) and (not String(_options[key]).is_valid_float() or not is_finite(float(_options[key]))):
			_fail("Invalid numeric value: " + key)
			return
	for key in ["team", "form"]:
		if _options.has(key) and String(_options[key]) not in ["0", "1"]:
			_fail(key + " must be 0 or 1")
			return
	if float(_options.get("time", "0")) < 0 or float(_options.get("zoom", "1")) < 0.25 or float(_options.get("zoom", "1")) > 3:
		_fail("Time must be nonnegative; zoom must be 0.25..3")
		return
	var packed: PackedScene
	if _options.has("card"):
		var id := String(_options.card)
		var team := int(_options.get("team", "0"))
		var form := int(_options.get("form", "0"))
		if team not in [0, 1] or form not in [0, 1]:
			_fail("team and form must be 0 or 1")
			return
		var stats: Dictionary
		if id in ["princess_tower", "nexus"]:
			var config: Dictionary = CardDB.PRINCESS_TOWER_VISUAL_CONFIG if id == "princess_tower" else CardDB.NEXUS_VISUAL_CONFIG
			packed = load(String(config.scene_paths[team])) as PackedScene
		else:
			if not CardDB.has_card(id):
				_fail("Unknown card: " + id)
				return
			stats = CardDB.get_card(id)
			if form == 1 and stats.get("transformed_stats", {}).is_empty():
				_fail("This card has no alternate form")
				return
			stats = PresentationConfig.for_form(stats, form)
			var scene := PresentationConfig.scene_path(stats, team)
			if scene.is_empty():
				_fail("This object has no model; use the battle workbench for spells")
				return
			packed = load(scene) as PackedScene
	else:
		var path := String(_options.scene)
		if path.ends_with(".glb") or path.ends_with(".gltf"):
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			if document.append_from_file(path, state) != OK:
				_fail("Cannot load glTF: " + path)
				return
			var scene := document.generate_scene(state)
			if scene == null:
				_fail("glTF generated no scene")
				return
			packed = PackedScene.new()
			var error := packed.pack(scene)
			scene.free()
			if error != OK:
				_fail("Cannot prepare preview scene")
				return
		else:
			packed = load(path) as PackedScene
	if packed == null:
		_fail("Cannot load model scene")
		return
	root.title = "模型动作展台"
	root.size = Vector2i(1000, 900)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(layout)
	_preview = PREVIEW.new()
	_preview.custom_minimum_size = Vector2(400, 550)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_preview)
	await process_frame
	var clips := _preview.show_packed_scene(packed)
	if _preview.model == null:
		_fail("The scene root must be Node3D")
		return
	if _preview.model.has_method("prepare_visual_animations"):
		_preview.model.call("prepare_visual_animations")
		if _preview.player != null: clips = _preview.player.get_animation_list()
	if _options.has("list"):
		for clip in clips:
			print("%s\t%.6f seconds" % [clip, _preview.player.get_animation(clip).length])
		quit()
		return
	var selected := String(_options.get("animation", ""))
	if not selected.is_empty() and (not selected in clips):
		_fail("Animation not found: " + selected)
		return
	var row := HBoxContainer.new()
	layout.add_child(row)
	var selector := OptionButton.new()
	selector.add_item("暂停当前姿态")
	for clip in clips: selector.add_item(clip)
	row.add_child(selector)
	selector.item_selected.connect(func(index: int):
		if index > 0:
			_preview.play_clip(selector.get_item_text(index))
			_time_slider.max_value = _preview.player.current_animation_length
		else:
			_preview.set_playing(false)
	)
	_button(row, "播放", func(): _preview.set_playing(true))
	_button(row, "暂停", func(): _preview.set_playing(false))
	_button(row, "+1/30 秒", func():
		if _preview.player != null: _preview.seek_seconds(_preview.player.current_animation_position + 1.0 / 30.0)
	)
	_label = Label.new()
	layout.add_child(_label)
	_time_slider = HSlider.new()
	_time_slider.step = 0.001
	_time_slider.max_value = 1.0
	layout.add_child(_time_slider)
	_time_slider.value_changed.connect(func(value: float):
		if not _updating: _preview.seek_seconds(value)
	)
	var controls := HBoxContainer.new()
	layout.add_child(controls)
	_slider(controls, "朝向", -180, 180, float(_options.get("yaw", "0")), _preview.set_model_yaw)
	_slider(controls, "缩放", 0.25, 3, float(_options.get("zoom", "1")), _preview.set_zoom)
	_preview.set_model_yaw(float(_options.get("yaw", "0")))
	_preview.set_zoom(float(_options.get("zoom", "1")))
	if not selected.is_empty():
		selector.select(clips.find(selected) + 1)
		_preview.play_clip(selected)
		_time_slider.max_value = _preview.player.current_animation_length
		if _options.has("time") or _options.has("capture") or _options.has("install-missing-art"):
			_preview.seek_seconds(float(_options.get("time", "0")))
	process_frame.connect(_update_time)
	if _options.has("capture") or _options.has("install-missing-art"):
		await _capture()

func _button(row: Node, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	row.add_child(button)
	button.pressed.connect(callback)

func _slider(row: Node, title: String, low: float, high: float, value: float, callback: Callable) -> void:
	var label := Label.new()
	label.text = title
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size.x = 240
	row.add_child(slider)
	slider.value_changed.connect(callback)

func _update_time() -> void:
	if _preview.player == null or _preview.player.assigned_animation.is_empty(): return
	_updating = true
	_time_slider.value = _preview.player.current_animation_position
	_label.text = "%.3f / %.3f 秒" % [_time_slider.value, _time_slider.max_value]
	_updating = false

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Capture needs a real renderer; do not use --headless")
		return
	var dimensions := String(_options.get("size", "308x560")).split("x")
	if dimensions.size() != 2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():
		_fail("--size must be WIDTHxHEIGHT")
		return
	var size := Vector2i(int(dimensions[0]), int(dimensions[1]))
	if size.x < 32 or size.y < 32 or size.x > 2048 or size.y > 2048:
		_fail("Capture dimensions must be 32..2048")
		return
	var output := String(_options.get("capture", ""))
	if _options.has("install-missing-art"):
		if not _options.has("card") or not output.is_empty():
			_fail("--install-missing-art requires --card and cannot combine with --capture")
			return
		var id := String(_options.card)
		for extension in ["png", "jpg", "jpeg", "webp"]:
			if FileAccess.file_exists("res://assets/cards/%s_loading.%s" % [id, extension]):
				_fail("Existing card art is protected; capture a candidate to builds/ instead")
				return
		output = "res://assets/cards/%s_loading.png" % id
	elif not output.is_absolute_path():
		output = ProjectSettings.globalize_path("res://" + output)
	output = ProjectSettings.globalize_path(output).simplify_path()
	if not output.ends_with(".png") or FileAccess.file_exists(output):
		_fail("Choose a new .png output; existing files are never overwritten")
		return
	if not _options.has("install-missing-art"):
		for folder in ["assets", "scripts", "scenes", "docs", "tests", "tools", ".godot", ".git"]:
			if output.begins_with(ProjectSettings.globalize_path("res://" + folder + "/")):
				_fail("Capture candidates to builds/ or a temporary directory")
				return
		if output.begins_with("/Users/czh/Downloads/LOL_Asset_Source/"):
			_fail("The source library is read-only")
			return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	_preview._viewport.transparent_bg = true
	for child in _preview._viewport.get_children():
		if child is WorldEnvironment:
			child.environment.background_mode = Environment.BG_CLEAR_COLOR
	_preview.stretch = false
	_preview._viewport.size = size * 2
	_preview._camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var aspect := float(size.x) / size.y
	_preview._camera.size = _preview._fit_size * 1.8 / minf(aspect, 1.0) / maxf(float(_options.get("zoom", "1")), 0.2)
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	var result := _preview._viewport.get_texture().get_image()
	var used := result.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		var subject := result.get_region(used)
		var scale_factor := minf(float(size.x) / used.size.x, float(size.y) / used.size.y) * 0.86
		subject.resize(maxi(1, int(used.size.x * scale_factor)), maxi(1, int(used.size.y * scale_factor)), Image.INTERPOLATE_LANCZOS)
		result = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		result.fill(Color.TRANSPARENT)
		result.blit_rect(subject, Rect2i(Vector2i.ZERO, subject.get_size()), (size - subject.get_size()) / 2)
	else:
		_fail("Capture contains no visible model")
		return
	var error := result.save_png(output)
	if error != OK:
		_fail("Cannot save capture: " + error_string(error))
		return
	print("Saved model capture: ", output)
	quit()
