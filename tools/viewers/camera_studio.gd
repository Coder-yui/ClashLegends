extends SceneTree
## 可复用的 3D 卡面摄影棚：只加载模型表现，不启动战斗或工作台。
##
## 交互模式：
##   python3 tools/dev.py studio --card garen
##   python3 tools/dev.py studio --scene /absolute/path/model.glb
##
## 预览区左键拖拽环绕相机，滚轮推拉；右侧面板可细调相机、灯光、背景、动作、预设和拍摄。

const PREVIEW := preload("res://scripts/ui/workbench/model_preview.gd")
const PRESETS_PATH := "res://ClashLegends-开发素材库/04-中间产物/3D摄影棚/camera_studio_presets.json"
const SHOTS_DIR := "res://ClashLegends-开发素材库/04-中间产物/3D摄影棚/shots"
const CARD_IMAGE_SIZE := Vector2i(308, 560)
const PREVIEW_SIZE := Vector2(440, 800)

var _options: Dictionary = {}
var _preview: WorkbenchModelPreview
var _preview_host: Control
var _clip_option: OptionButton
var _time_slider: HSlider
var _time_label: Label
var _card_option: OptionButton
var _team_option: OptionButton
var _form_option: OptionButton
var _member_option: OptionButton
var _card_ids: Array[String] = []
var _selected_card := ""
var _selected_team := 0
var _selected_form := 0
var _stats: Dictionary = {}
var _subject_title := "模型"
var _members: Array[Dictionary] = []
var _selected_member_index := -1
var _scene_mode := false
var _status: Label
var _capture_name: LineEdit
var _preset_name: LineEdit
var _preset_option: OptionButton
var _yaw: HSlider
var _pitch: HSlider
var _distance: HSlider
var _aim_yaw: HSlider
var _aim_pitch: HSlider
var _camera_roll: HSlider
var _target_height: HSlider
var _model_yaw: HSlider
var _fov: HSlider
var _ortho_size: HSlider
var _key_energy: HSlider
var _fill_energy: HSlider
var _rim_energy: HSlider
var _ambient_energy: HSlider
var _member_x: HSlider
var _member_y: HSlider
var _member_z: HSlider
var _member_yaw: HSlider
var _member_scale: HSlider
var _formation_spacing: HSlider
var _active_formation := "line"
var _projection: OptionButton
var _background: ColorPickerButton
var _transparent: CheckButton
var _floor: CheckButton
var _time_updating := false
var _state_updating := false
var _member_updating := false
var _presets: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	push_error("[CameraStudio] " + message)
	quit(2)

func _parse() -> bool:
	var args := OS.get_cmdline_user_args()
	var allowed := ["card", "cards", "scene", "team", "form", "animation", "time", "capture", "size", "preset", "formation", "help"]
	var index := 0
	while index < args.size():
		var token := String(args[index])
		if not token.begins_with("--"):
			_fail("Expected --option: " + token)
			return false
		var key := token.trim_prefix("--").get_slice("=", 0)
		if key not in allowed:
			_fail("Unknown option: " + key)
			return false
		if key == "help":
			_options[key] = true
			index += 1
			continue
		if "=" in token:
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
	if not _parse():
		return
	if _options.has("help"):
		print("3D Camera Studio: --card ID | --cards ID1,ID2,... | --scene PATH(.tscn/.glb) [--team 0|1] [--form 0|1]")
		print("  交互模式可拖拽预览区调相机；卡面 PNG 固定输出 308x560。")
		print("  多单位可用 --cards ID1,ID2 --formation line|triangle|ring。")
		quit()
		return
	if (_options.has("card") or _options.has("cards")) and _options.has("scene"):
		_fail("Specify only one of --card/--cards or --scene")
		return
	if _options.has("card") and _options.has("cards"):
		_fail("Specify only one of --card or --cards")
		return
	if _options.has("team") and String(_options.team) not in ["0", "1"]:
		_fail("team must be 0 or 1")
		return
	if _options.has("form") and String(_options.form) not in ["0", "1"]:
		_fail("form must be 0 or 1")
		return
	_selected_team = int(_options.get("team", "0"))
	_selected_form = int(_options.get("form", "0"))
	_scene_mode = _options.has("scene")
	root.title = "Clash Legends · 3D 卡面摄影棚"
	root.size = Vector2i(1280, 900)
	# 项目主窗口是 720×1400 竖屏；摄影棚是独立横向工具，必须同步内容画布，否则 Godot 会在两侧加黑边。
	root.content_scale_size = Vector2i(1280, 900)
	root.min_size = Vector2i(1080, 720)
	_load_presets()
	_build_ui()
	process_frame.connect(_update_time)
	await process_frame
	if _scene_mode:
		var packed := _load_scene(String(_options.scene))
		if packed == null:
			return
		await _show_scene(packed, "外部模型")
	else:
		var requested_cards := String(_options.get("cards", _options.get("card", "garen"))).split(",", false)
		if requested_cards.is_empty():
			_fail("cards must contain at least one card ID")
			return
		_selected_card = requested_cards[0].strip_edges()
		_populate_card_option()
		await _load_card(_selected_card, _selected_team, _selected_form)
		for requested_card in requested_cards.slice(1):
			_selected_card = String(requested_card).strip_edges()
			_add_source_member()
		if _options.has("formation"):
			var formation := String(_options.formation)
			if formation not in ["line", "triangle", "ring"]:
				_fail("formation must be line, triangle or ring")
				return
			_apply_formation(formation)
	if _preview == null or _members.is_empty() or _preview.model == null:
		_fail("模型没有可渲染的 Node3D 根节点")
		return
	if _options.has("preset"):
		_apply_preset_name(String(_options.preset))
	if _options.has("animation"):
		_select_animation(String(_options.animation))
	if _options.has("time"):
		if not String(_options.time).is_valid_float() or float(_options.time) < 0.0:
			_fail("time must be a nonnegative number")
			return
		_seek_selected(float(_options.time))
	_sync_controls()
	if _options.has("capture"):
		await _capture_to_path(String(_options.capture), String(_options.get("size", "308x560")), true)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1320")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	background.add_child(margin)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(main)
	_preview_host = PanelContainer.new()
	_preview_host.custom_minimum_size = PREVIEW_SIZE
	_preview_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.add_child(_preview_host)
	_preview = PREVIEW.new()
	_preview.studio_mode = true
	_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview.custom_minimum_size = PREVIEW_SIZE
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview_host.add_child(_preview)
	_preview.camera_changed.connect(_sync_controls)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 450
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	main.add_child(right)
	var title := Label.new()
	title.text = "3D 卡面摄影棚"
	title.add_theme_font_size_override("font_size", 26)
	right.add_child(title)
	var hint := Label.new()
	hint.text = "拖拽预览区环绕相机 · 滚轮推拉\n右侧参数可保存为方案，拍摄只输出到开发素材库"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("9badc4"))
	right.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 8)
	scroll.add_child(controls)
	_build_subject_controls(controls)
	_build_camera_controls(controls)
	_build_light_controls(controls)
	_build_preset_controls(controls)
	_build_capture_controls(controls)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("8fd4b2"))
	controls.add_child(_status)

func _section(parent: Node, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 9)
	panel.add_child(margin)
	margin.add_child(box)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	return box

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_subject_controls(parent: Node) -> void:
	var box := _section(parent, "对象与动作")
	var row := _row(box)
	_card_option = OptionButton.new()
	_card_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_option.item_selected.connect(func(index: int):
		if not _scene_mode and index >= 0 and index < _card_ids.size():
			_selected_card = _card_ids[index]
			_status.text = "已选择来源：%s；点击“替换当前成员”或“添加成员”应用" % _selected_card
	)
	row.add_child(_card_option)
	_team_option = OptionButton.new()
	_team_option.add_item("蓝方")
	_team_option.add_item("红方")
	_team_option.select(_selected_team)
	_team_option.item_selected.connect(func(index: int):
		_selected_team = index
		_status.text = "来源阵营已改为 %s；点击“替换当前成员”或“添加成员”应用" % ("红方" if index == 1 else "蓝方")
	)
	row.add_child(_team_option)
	_form_option = OptionButton.new()
	_form_option.add_item("基础形态")
	_form_option.add_item("变形形态")
	_form_option.select(_selected_form)
	_form_option.item_selected.connect(func(index: int):
		_selected_form = index
		_status.text = "来源形态已改为 %s；点击“替换当前成员”或“添加成员”应用" % ("变形" if index == 1 else "基础")
	)
	row.add_child(_form_option)
	if _scene_mode:
		_card_option.disabled = true
		_team_option.disabled = true
		_form_option.disabled = true
	var source_actions := _row(box)
	_button(source_actions, "替换当前成员", _replace_source_member)
	_button(source_actions, "添加成员", _add_source_member)
	var source_actions_more := _row(box)
	_button(source_actions_more, "删除成员", _remove_selected_member)
	_button(source_actions_more, "清空组合", _clear_members)
	var member_row := _row(box)
	_member_option = OptionButton.new()
	_member_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_member_option.item_selected.connect(_select_member)
	member_row.add_child(_member_option)
	_member_x = _add_slider(box, "成员横向 X", -6.0, 6.0, 0.0, func(value): _update_selected_member_transform())
	_member_y = _add_slider(box, "成员高度 Y", -3.0, 3.0, 0.0, func(value): _update_selected_member_transform())
	_member_z = _add_slider(box, "成员纵深 Z", -6.0, 6.0, 0.0, func(value): _update_selected_member_transform())
	_member_yaw = _add_slider(box, "成员朝向", -180.0, 180.0, 0.0, func(value): _update_selected_member_transform())
	_member_scale = _add_slider(box, "成员缩放", 0.2, 2.5, 1.0, func(value): _update_selected_member_transform())
	_formation_spacing = _add_slider(box, "编队间距", 0.2, 4.0, 1.45, func(value): _set_formation_spacing(value))
	var formation := _row(box)
	_button(formation, "横排", func(): _apply_formation("line"))
	_button(formation, "三角", func(): _apply_formation("triangle"))
	_button(formation, "环绕", func(): _apply_formation("ring"))
	_clip_option = OptionButton.new()
	_clip_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_option.item_selected.connect(func(index: int): _select_animation(_clip_option.get_item_text(index)))
	box.add_child(_clip_option)
	var transport := _row(box)
	_button(transport, "播放", func(): _set_selected_playing(true))
	_button(transport, "暂停", func(): _set_selected_playing(false))
	_button(transport, "+1/30 秒", func():
		var selected_player := _selected_player()
		if selected_player != null: _seek_selected(selected_player.current_animation_position + 1.0 / 30.0))
	_time_slider = HSlider.new()
	_time_slider.step = 0.001
	_time_slider.value_changed.connect(func(value: float):
		if not _time_updating: _seek_selected(value))
	box.add_child(_time_slider)
	_time_label = Label.new()
	_time_label.text = "0.000 秒"
	box.add_child(_time_label)

func _build_camera_controls(parent: Node) -> void:
	var box := _section(parent, "相机")
	_projection = OptionButton.new()
	_projection.add_item("透视投影")
	_projection.add_item("正交投影")
	_projection.item_selected.connect(func(index: int): _preview.set_projection("orthographic" if index == 1 else "perspective"))
	box.add_child(_projection)
	_yaw = _add_slider(box, "相机水平环绕", -180.0, 180.0, -90.0, func(value): _preview.set_camera_orbit(value, _pitch.value, _distance.value))
	_pitch = _add_slider(box, "相机俯仰", -65.0, 65.0, 8.0, func(value): _preview.set_camera_orbit(_yaw.value, value, _distance.value))
	_distance = _add_slider(box, "相机距离", 0.1, 20.0, 6.0, func(value): _preview.set_camera_orbit(_yaw.value, _pitch.value, value))
	_aim_yaw = _add_slider(box, "相机朝向水平偏移", -180.0, 180.0, 0.0, func(value): _set_camera_aim_from_controls())
	_aim_pitch = _add_slider(box, "相机朝向垂直偏移", -85.0, 85.0, 0.0, func(value): _set_camera_aim_from_controls())
	_camera_roll = _add_slider(box, "相机朝向滚转", -180.0, 180.0, 0.0, func(value): _set_camera_aim_from_controls())
	_target_height = _add_slider(box, "目标高度", -3.0, 3.0, 0.0, func(value): _preview.set_camera_target_height(value))
	_model_yaw = _add_slider(box, "模型朝向", -180.0, 180.0, 0.0, func(value): _preview.set_model_yaw(value))
	_fov = _add_slider(box, "视野角 FOV", 20.0, 80.0, 34.0, func(value): _preview.set_fov(value))
	_ortho_size = _add_slider(box, "正交画幅", 0.1, 20.0, 3.0, func(value): _preview.set_ortho_size(value))
	var row := _row(box)
	_button(row, "复位相机", func(): _preview.reset_studio_camera())
	_button(row, "正面卡面", func(): _apply_preset(_builtin_preset("正面卡面")))
	_button(row, "侧身英雄", func(): _apply_preset(_builtin_preset("侧身英雄")))

func _build_light_controls(parent: Node) -> void:
	var box := _section(parent, "灯光与背景")
	var presets := _row(box)
	_button(presets, "三点柔光", func(): _apply_preset(_builtin_preset("三点柔光")))
	_button(presets, "冷色轮廓", func(): _apply_preset(_builtin_preset("冷色轮廓")))
	_key_energy = _add_slider(box, "主光", 0.0, 4.0, 1.55, func(value): _preview.set_light_energy("key", value))
	_fill_energy = _add_slider(box, "辅光", 0.0, 4.0, 0.55, func(value): _preview.set_light_energy("fill", value))
	_rim_energy = _add_slider(box, "轮廓光", 0.0, 4.0, 0.95, func(value): _preview.set_light_energy("rim", value))
	_ambient_energy = _add_slider(box, "环境光", 0.0, 3.0, 0.7, func(value): _preview.set_ambient_energy(value))
	var bg_row := _row(box)
	_background = ColorPickerButton.new()
	_background.text = "背景颜色"
	_background.color = Color("111c2a")
	_background.color_changed.connect(func(value: Color): _preview.set_background(value, _transparent.button_pressed if _transparent != null else false))
	bg_row.add_child(_background)
	_transparent = CheckButton.new()
	_transparent.text = "透明背景"
	_transparent.toggled.connect(func(value: bool): _preview.set_background(_background.color, value))
	bg_row.add_child(_transparent)
	_floor = CheckButton.new()
	_floor.text = "地面（无影）"
	_floor.button_pressed = true
	_floor.toggled.connect(func(value: bool): _preview.set_floor_visible(value))
	bg_row.add_child(_floor)

func _build_preset_controls(parent: Node) -> void:
	var box := _section(parent, "方案")
	_preset_option = OptionButton.new()
	_preset_option.item_selected.connect(func(index: int):
		if index >= 0 and index < _preset_option.item_count:
			_apply_preset_name(_preset_option.get_item_text(index)))
	box.add_child(_preset_option)
	var row := _row(box)
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = "方案名称"
	_preset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_preset_name)
	_button(row, "保存当前方案", _save_current_preset)
	_refresh_preset_option()

func _build_capture_controls(parent: Node) -> void:
	var box := _section(parent, "拍摄")
	_capture_name = LineEdit.new()
	_capture_name.placeholder_text = "文件名（留空使用当前对象名）"
	box.add_child(_capture_name)
	var row := _row(box)
	_button(row, "拍摄卡面 PNG 308×560", func(): _capture_interactive(CARD_IMAGE_SIZE))

func _add_slider(parent: Node, title: String, low: float, high: float, value: float, callback: Callable) -> HSlider:
	var row := _row(parent)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 100
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return slider

func _populate_card_option() -> void:
	if _card_option == null or _scene_mode:
		return
	_card_option.clear()
	_card_ids.clear()
	for id in CardDB.selectable_ids():
		var stats: Dictionary = CardDB.get_card(id)
		var base := PresentationConfig.for_form(stats, 0)
		var has_own_model := not String(PresentationConfig.scene_path(base, 0)).is_empty()
		var has_deployment_members: bool = not stats.get("deployment_member_ids", []).is_empty()
		if has_own_model or has_deployment_members:
			_card_ids.append(id)
	_card_ids.sort()
	for id in _card_ids:
		_card_option.add_item(id)
		_card_option.set_item_tooltip(_card_option.item_count - 1, String(PresentationConfig.for_form(CardDB.get_card(id), 0).get("name", id)))
	_card_option.select(maxi(_card_ids.find(_selected_card), 0))

func _load_card(id: String, team: int, form: int) -> void:
	if _scene_mode or id.is_empty() or not CardDB.has_card(id):
		return
	var card_stats: Dictionary = CardDB.get_card(id)
	var deployment_member_ids: Array = card_stats.get("deployment_member_ids", [])
	if not deployment_member_ids.is_empty():
		_load_composite_card(id, team, form, deployment_member_ids, card_stats)
		return
	var source := _resolve_card_source(id, team, form)
	if source.is_empty():
		return
	_selected_card = id
	_selected_team = int(source.get("team", team))
	_selected_form = int(source.get("form", form))
	_stats = source.get("stats", {})
	var member := _make_member(source)
	if _members.is_empty():
		_members.append(member)
		_selected_member_index = 0
	else:
		if _selected_member_index < 0 or _selected_member_index >= _members.size():
			_selected_member_index = 0
		_members[_selected_member_index] = member
	var keep_camera := _preview.model != null
	await _rebuild_group_preview(keep_camera)
	_subject_title = String(source.get("title", id))
	_sync_member_controls()

func _load_composite_card(id: String, team: int, form: int, member_ids: Array, stats: Dictionary) -> void:
	var prepared: Array[Dictionary] = []
	for index in member_ids.size():
		var source := _resolve_card_source(String(member_ids[index]), team, 0)
		if source.is_empty():
			return
		prepared.append(_make_member(source))
	_members = prepared
	_selected_member_index = 0
	_selected_card = id
	_selected_team = team
	_selected_form = form
	_stats = stats
	_subject_title = String(stats.get("name", id))
	_rebuild_group_preview(false)
	_apply_formation("line")
	if _card_option != null:
		_card_option.select(maxi(_card_ids.find(_selected_card), 0))
	if _team_option != null:
		_team_option.select(_selected_team)
	if _form_option != null:
		_form_option.select(_selected_form)
	_status.text = "已加载组合卡：可用横排、三角、环绕和编队间距重新布局"

func _resolve_card_source(id: String, team: int, form: int) -> Dictionary:
	if id.is_empty() or not CardDB.has_card(id):
		return {}
	var raw: Dictionary = CardDB.get_card(id)
	if form == 1 and raw.get("transformed_stats", {}).is_empty():
		form = 0
	var stats: Dictionary = PresentationConfig.for_form(raw, form)
	var path := PresentationConfig.scene_path(stats, team)
	if path.is_empty() or not ResourceLoader.exists(path):
		_status.text = "%s 没有 %s 方 3D 模型" % [id, "红" if team == 1 else "蓝"]
		return {}
	var packed := load(path) as PackedScene
	if packed == null:
		_status.text = "%s 的模型无法加载" % id
		return {}
	return {"packed": packed, "title": String(stats.get("name", id)), "card_id": id, "team": team, "form": form, "stats": stats}

func _make_member(source: Dictionary) -> Dictionary:
	return {
		"packed": source.get("packed") as PackedScene,
		"title": String(source.get("title", "模型")),
		"card_id": String(source.get("card_id", "")),
		"team": int(source.get("team", 0)),
		"form": int(source.get("form", 0)),
		"position": source.get("position", Vector3.ZERO),
		"yaw": float(source.get("yaw", 0.0)),
		"scale": maxf(float(source.get("scale", 1.0)), 0.05),
		"clip": String(source.get("clip", "")),
		"time": maxf(float(source.get("time", 0.0)), 0.0),
	}

func _replace_source_member() -> void:
	if _scene_mode:
		return
	_load_card(_selected_card, _selected_team, _selected_form)

func _add_source_member() -> void:
	if _scene_mode:
		return
	if CardDB.has_card(_selected_card):
		var selected_stats: Dictionary = CardDB.get_card(_selected_card)
		var deployment_member_ids: Array = selected_stats.get("deployment_member_ids", [])
		if not deployment_member_ids.is_empty():
			_load_composite_card(_selected_card, _selected_team, _selected_form, deployment_member_ids, selected_stats)
			return
	var source := _resolve_card_source(_selected_card, _selected_team, _selected_form)
	if source.is_empty():
		return
	_members.append(_make_member(source))
	_selected_member_index = _members.size() - 1
	_rebuild_group_preview(true)
	_subject_title = _group_title()
	_status.text = "已添加成员：%s；可在列表中逐个调整位置" % String(source.get("title", _selected_card))

func _show_scene(packed: PackedScene, title: String) -> void:
	if packed == null:
		return
	_members.clear()
	_members.append(_make_member({"packed": packed, "title": title}))
	_selected_member_index = 0
	_subject_title = title
	_rebuild_group_preview(false)
	_status.text = "%s · 可继续添加卡牌成员" % title

func _rebuild_group_preview(keep_camera: bool) -> void:
	if _preview == null:
		return
	var saved_camera := _preview.studio_state() if keep_camera and not _members.is_empty() else {}
	var entries: Array = []
	for member in _members:
		entries.append({
			"packed": member.get("packed"),
			"position": member.get("position", Vector3.ZERO),
			"yaw": member.get("yaw", 0.0),
			"scale": member.get("scale", 1.0),
		})
	var rendered: Array = _preview.show_packed_scenes(entries)
	var rebuilt: Array[Dictionary] = []
	for index in rendered.size():
		if index >= _members.size():
			break
		var member: Dictionary = _members[index]
		var rendered_entry: Dictionary = rendered[index]
		var rendered_model := rendered_entry.get("model") as Node3D
		if rendered_model != null and rendered_model.has_method("prepare_visual_animations"):
			rendered_model.call("prepare_visual_animations")
		var rendered_player := rendered_entry.get("player") as AnimationPlayer
		var clips: PackedStringArray = rendered_player.get_animation_list() if rendered_player != null else PackedStringArray()
		member["root"] = rendered_entry.get("root")
		member["model"] = rendered_model
		member["player"] = rendered_player
		member["clips"] = clips
		var clip := String(member.get("clip", ""))
		if clip.is_empty() or not clip in clips:
			clip = _preferred_idle_clip(clips) if not clips.is_empty() else ""
		member["clip"] = clip
		var position := maxf(float(member.get("time", 0.0)), 0.0)
		member["time"] = position
		_apply_member_animation(member, clip, position)
		rebuilt.append(member)
	_members = rebuilt
	if _members.is_empty():
		_selected_member_index = -1
	else:
		_selected_member_index = clampi(_selected_member_index, 0, _members.size() - 1)
	if not saved_camera.is_empty():
		_preview.apply_studio_state(saved_camera)
	_select_member(_selected_member_index)

func _apply_member_animation(member: Dictionary, clip: String, time: float) -> void:
	var target_player := member.get("player") as AnimationPlayer
	if target_player == null or clip.is_empty() or not target_player.has_animation(clip):
		return
	target_player.play(clip)
	target_player.seek(clampf(time, 0.0, target_player.get_animation(clip).length), true)
	target_player.pause()

func _select_member(index: int) -> void:
	if index < 0 or index >= _members.size():
		return
	_selected_member_index = index
	var member: Dictionary = _members[index]
	var card_id := String(member.get("card_id", ""))
	if not card_id.is_empty():
		_selected_card = card_id
		_selected_team = int(member.get("team", 0))
		_selected_form = int(member.get("form", 0))
		if _card_option != null:
			_card_option.select(maxi(_card_ids.find(_selected_card), 0))
		if _team_option != null:
			_team_option.select(_selected_team)
		if _form_option != null:
			_form_option.select(_selected_form)
	_refresh_animation_option(member)
	_sync_member_controls()

func _refresh_animation_option(member: Dictionary) -> void:
	if _clip_option == null:
		return
	_clip_option.clear()
	var clips: PackedStringArray = member.get("clips", PackedStringArray())
	for clip in clips:
		_clip_option.add_item(clip)
	_clip_option.disabled = clips.is_empty()
	var selected_clip := String(member.get("clip", ""))
	for index in _clip_option.item_count:
		if _clip_option.get_item_text(index) == selected_clip:
			_clip_option.select(index)
	var target_player := member.get("player") as AnimationPlayer
	var duration := target_player.get_animation(selected_clip).length if target_player != null and not selected_clip.is_empty() and target_player.has_animation(selected_clip) else 0.0
	_time_slider.max_value = maxf(duration, 0.001)
	_time_slider.set_value_no_signal(clampf(float(member.get("time", 0.0)), 0.0, _time_slider.max_value))
	_time_label.text = "%.3f / %.3f 秒" % [_time_slider.value, _time_slider.max_value]

func _selected_player() -> AnimationPlayer:
	if _selected_member_index < 0 or _selected_member_index >= _members.size():
		return null
	return _members[_selected_member_index].get("player") as AnimationPlayer

func _select_animation(clip: String) -> void:
	var target_player := _selected_player()
	if target_player == null or not target_player.has_animation(clip):
		return
	var member: Dictionary = _members[_selected_member_index]
	member["clip"] = clip
	member["time"] = 0.0
	_members[_selected_member_index] = member
	target_player.play(clip)
	target_player.seek(0.0, true)
	target_player.pause()
	_refresh_animation_option(member)

func _set_selected_playing(playing: bool) -> void:
	var target_player := _selected_player()
	if target_player == null or target_player.assigned_animation.is_empty():
		return
	if playing:
		target_player.play()
	else:
		target_player.pause()

func _seek_selected(value: float) -> void:
	var target_player := _selected_player()
	if target_player == null or target_player.assigned_animation.is_empty():
		return
	var member: Dictionary = _members[_selected_member_index]
	var clamped := clampf(value, 0.0, target_player.current_animation_length)
	member["time"] = clamped
	_members[_selected_member_index] = member
	target_player.pause()
	target_player.seek(clamped, true)

func _update_selected_member_transform() -> void:
	if _member_updating or _selected_member_index < 0 or _selected_member_index >= _members.size():
		return
	var root_node := _preview.group_root(_selected_member_index)
	if root_node == null:
		return
	var member: Dictionary = _members[_selected_member_index]
	var position := Vector3(_member_x.value, _member_y.value, _member_z.value)
	var yaw := _member_yaw.value
	var uniform_scale := _member_scale.value
	root_node.position = position
	root_node.rotation_degrees.y = yaw
	root_node.scale = Vector3.ONE * uniform_scale
	member["position"] = position
	member["yaw"] = yaw
	member["scale"] = uniform_scale
	_members[_selected_member_index] = member
	var camera_state := _preview.studio_state()
	_preview.recalculate_group_bounds()
	_preview.apply_studio_state(camera_state)
	_subject_title = _group_title()

func _set_formation_spacing(_value: float) -> void:
	if not _members.is_empty():
		_apply_formation(_active_formation)

func _apply_formation(kind: String) -> void:
	if _members.is_empty():
		return
	_active_formation = kind
	var spacing := _formation_spacing.value if _formation_spacing != null else 1.45
	var camera_state := _preview.studio_state()
	for index in _members.size():
		var member: Dictionary = _members[index]
		var position := Vector3.ZERO
		match kind:
			"line":
				position = Vector3((float(index) - float(_members.size() - 1) * 0.5) * spacing, 0.0, 0.0)
			"triangle":
				if index == 0:
					position = Vector3(-0.55 * spacing, 0.0, 0.31 * spacing)
				elif index == 1:
					position = Vector3(0.55 * spacing, 0.0, 0.31 * spacing)
				else:
					var tail_index := index - 2
					position = Vector3((float(tail_index) - float(maxi(_members.size() - 3, 0)) * 0.5) * spacing, 0.0, -0.45 * spacing)
			"ring":
				var angle := TAU * float(index) / float(_members.size())
				var ring_radius := spacing * 0.5 if _members.size() < 3 else spacing / (2.0 * sin(PI / float(_members.size())))
				position = Vector3(cos(angle) * ring_radius, 0.0, sin(angle) * ring_radius)
		var root_node := _preview.group_root(index)
		if root_node != null:
			root_node.position = position
		member["position"] = position
		_members[index] = member
	_preview.recalculate_group_bounds()
	_preview.apply_studio_state(camera_state)
	_sync_member_controls()
	_status.text = "已应用%s编队；仍可逐个拖动参数微调" % ("横排" if kind == "line" else "三角" if kind == "triangle" else "环绕")

func _sync_member_controls() -> void:
	if _member_option == null:
		return
	_member_option.clear()
	for index in _members.size():
		var member: Dictionary = _members[index]
		var card_id := String(member.get("card_id", ""))
		var label := String(member.get("title", "模型"))
		if not card_id.is_empty():
			label = "%02d · %s" % [index + 1, card_id]
		else:
			label = "%02d · %s" % [index + 1, label]
		_member_option.add_item(label)
	if _selected_member_index >= 0 and _selected_member_index < _member_option.item_count:
		_member_option.select(_selected_member_index)
	if _selected_member_index < 0 or _selected_member_index >= _members.size():
		return
	var member: Dictionary = _members[_selected_member_index]
	var position: Vector3 = member.get("position", Vector3.ZERO)
	_member_updating = true
	_set_slider(_member_x, position.x)
	_set_slider(_member_y, position.y)
	_set_slider(_member_z, position.z)
	_set_slider(_member_yaw, float(member.get("yaw", 0.0)))
	_set_slider(_member_scale, float(member.get("scale", 1.0)))
	_member_updating = false

func _remove_selected_member() -> void:
	if _selected_member_index < 0 or _selected_member_index >= _members.size():
		return
	if _members.size() <= 1:
		_status.text = "至少保留一个成员；如需换对象请使用“替换当前成员”"
		return
	_members.remove_at(_selected_member_index)
	_selected_member_index = clampi(_selected_member_index, 0, _members.size() - 1)
	_rebuild_group_preview(true)
	_subject_title = _group_title()

func _clear_members() -> void:
	_members.clear()
	_selected_member_index = -1
	_preview.show_packed_scenes([])
	_sync_member_controls()
	_clip_option.clear()
	_clip_option.disabled = true
	_status.text = "组合已清空；请选择来源后点击“添加成员”"

func _group_title() -> String:
	if _members.is_empty():
		return "模型"
	if _members.size() == 1:
		return String(_members[0].get("title", "模型"))
	return "%s_%d单位" % [String(_members[0].get("title", "组合")), _members.size()]

func _load_scene(path: String) -> PackedScene:
	var packed: PackedScene
	if path.ends_with(".glb") or path.ends_with(".gltf"):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path, state) != OK:
			_fail("Cannot load glTF: " + path)
			return null
		var scene := document.generate_scene(state)
		if scene == null:
			_fail("glTF generated no scene")
			return null
		packed = PackedScene.new()
		var error := packed.pack(scene)
		scene.free()
		if error != OK:
			_fail("Cannot prepare preview scene")
			return null
	else:
		packed = load(path) as PackedScene
	if packed == null:
		_fail("Cannot load model scene: " + path)
	return packed

func _preferred_idle_clip(clips: PackedStringArray) -> String:
	for clip in clips:
		if String(clip).to_lower().contains("idle"):
			return String(clip)
	return String(clips[0])

func _builtin_preset(name: String) -> Dictionary:
	match name:
		"正面卡面":
			return {"camera_yaw": -90.0, "camera_pitch": 5.0, "distance_factor": 2.8, "target_height": 0.15, "projection": "orthographic", "fov": 32.0, "model_yaw": 0.0, "key_energy": 1.5, "fill_energy": 0.6, "rim_energy": 0.8, "ambient_energy": 0.7, "background_color": "182235", "transparent_background": false, "floor_visible": true}
		"侧身英雄":
			return {"camera_yaw": -118.0, "camera_pitch": 10.0, "distance_factor": 2.8, "target_height": 0.2, "projection": "perspective", "fov": 38.0, "model_yaw": 18.0, "key_energy": 1.7, "fill_energy": 0.35, "rim_energy": 1.25, "ambient_energy": 0.55, "background_color": "10182a", "transparent_background": false, "floor_visible": true}
		"俯拍展示":
			return {"camera_yaw": 18.0, "camera_pitch": 24.0, "distance_factor": 3.2, "target_height": 0.0, "projection": "perspective", "fov": 42.0, "model_yaw": -8.0, "key_energy": 1.25, "fill_energy": 0.8, "rim_energy": 1.1, "ambient_energy": 0.8, "background_color": "253044", "transparent_background": false, "floor_visible": true}
		"三点柔光":
			return {"key_energy": 1.55, "fill_energy": 0.55, "rim_energy": 0.95, "ambient_energy": 0.7, "background_color": "111c2a", "transparent_background": false, "floor_visible": true}
		"冷色轮廓":
			return {"key_energy": 1.2, "fill_energy": 0.25, "rim_energy": 1.7, "ambient_energy": 0.5, "background_color": "0b1630", "transparent_background": false, "floor_visible": true}
	return {}

func _apply_preset(state: Dictionary) -> void:
	if state.is_empty() or _preview == null:
		return
	_preview.apply_studio_state(state)
	_sync_controls()

func _load_presets() -> void:
	_presets.clear()
	if not FileAccess.file_exists(PRESETS_PATH):
		return
	var file := FileAccess.open(PRESETS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_presets = parsed

func _refresh_preset_option() -> void:
	if _preset_option == null:
		return
	_preset_option.clear()
	for name in _presets.keys():
		_preset_option.add_item(String(name))

func _save_current_preset() -> void:
	var name := _preset_name.text.strip_edges()
	if name.is_empty():
		name = "方案_%d" % (_presets.size() + 1)
	_presets[name] = {"studio": _preview.studio_state(), "members": _serialize_members()}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRESETS_PATH).get_base_dir())
	var file := FileAccess.open(PRESETS_PATH, FileAccess.WRITE)
	if file == null:
		_status.text = "无法写入方案：" + PRESETS_PATH
		return
	file.store_string(JSON.stringify(_presets, "  "))
	_refresh_preset_option()
	_status.text = "已保存摄影方案：%s" % name

func _apply_preset_name(name: String) -> void:
	if _presets.has(name):
		var payload = _presets[name]
		if payload is Dictionary and payload.has("studio"):
			_restore_members(payload.get("members", []))
			_apply_preset(payload.get("studio", {}))
		else:
			_apply_preset(payload)
		_status.text = "已加载方案：%s" % name

func _serialize_members() -> Array:
	var result: Array = []
	for member in _members:
		var position: Vector3 = member.get("position", Vector3.ZERO)
		result.append({
			"card_id": String(member.get("card_id", "")),
			"team": int(member.get("team", 0)),
			"form": int(member.get("form", 0)),
			"title": String(member.get("title", "模型")),
			"position": [position.x, position.y, position.z],
			"yaw": float(member.get("yaw", 0.0)),
			"scale": float(member.get("scale", 1.0)),
			"clip": String(member.get("clip", "")),
			"time": float(member.get("time", 0.0)),
		})
	return result

func _restore_members(serialized) -> void:
	if not serialized is Array or serialized.is_empty() or _scene_mode:
		return
	var restored: Array[Dictionary] = []
	for entry in serialized:
		if not entry is Dictionary:
			return
		var card_id := String(entry.get("card_id", ""))
		var source: Dictionary
		if not card_id.is_empty():
			source = _resolve_card_source(card_id, int(entry.get("team", 0)), int(entry.get("form", 0)))
		elif restored.size() < _members.size():
			var current: Dictionary = _members[restored.size()]
			source = {"packed": current.get("packed"), "title": String(entry.get("title", current.get("title", "模型")))}
		if source.is_empty():
			return
		var position_variant = entry.get("position", [0.0, 0.0, 0.0])
		var position := Vector3.ZERO
		if position_variant is Array and position_variant.size() >= 3:
			position = Vector3(float(position_variant[0]), float(position_variant[1]), float(position_variant[2]))
		source["position"] = position
		source["yaw"] = float(entry.get("yaw", 0.0))
		source["scale"] = float(entry.get("scale", 1.0))
		source["clip"] = String(entry.get("clip", ""))
		source["time"] = float(entry.get("time", 0.0))
		if not card_id.is_empty():
			source["team"] = int(entry.get("team", 0))
			source["form"] = int(entry.get("form", 0))
		restored.append(_make_member(source))
	if restored.is_empty():
		return
	_members = restored
	_selected_member_index = clampi(_selected_member_index, 0, _members.size() - 1)
	_rebuild_group_preview(false)

func _sync_controls() -> void:
	if _preview == null or _state_updating:
		return
	_state_updating = true
	var state := _preview.studio_state()
	_set_slider(_yaw, float(state.get("camera_yaw", 0.0)))
	_set_slider(_pitch, float(state.get("camera_pitch", 8.0)))
	_set_slider(_distance, float(state.get("camera_distance", 5.8)))
	_set_slider(_aim_yaw, float(state.get("aim_yaw", 0.0)))
	_set_slider(_aim_pitch, float(state.get("aim_pitch", 0.0)))
	_set_slider(_camera_roll, float(state.get("camera_roll", 0.0)))
	_set_slider(_target_height, float(state.get("target_height", 0.0)))
	_set_slider(_model_yaw, float(state.get("model_yaw", 0.0)))
	_set_slider(_fov, float(state.get("fov", 34.0)))
	_set_slider(_ortho_size, float(state.get("ortho_size", 3.0)))
	_set_slider(_key_energy, float(state.get("key_energy", 1.55)))
	_set_slider(_fill_energy, float(state.get("fill_energy", 0.55)))
	_set_slider(_rim_energy, float(state.get("rim_energy", 0.95)))
	_set_slider(_ambient_energy, float(state.get("ambient_energy", 0.7)))
	_projection.select(1 if String(state.get("projection", "perspective")) == "orthographic" else 0)
	_background.color = Color(String(state.get("background_color", "111c2a")))
	_transparent.button_pressed = bool(state.get("transparent_background", false))
	_floor.button_pressed = bool(state.get("floor_visible", true))
	_state_updating = false

func _set_slider(slider: HSlider, value: float) -> void:
	if slider == null:
		return
	slider.set_value_no_signal(clampf(value, slider.min_value, slider.max_value))

func _set_camera_aim_from_controls() -> void:
	if _state_updating or _aim_yaw == null or _aim_pitch == null or _camera_roll == null:
		return
	_preview.set_camera_aim_offsets(_aim_yaw.value, _aim_pitch.value, _camera_roll.value)

func _capture_interactive(size: Vector2i) -> void:
	if _members.is_empty() or _preview == null or _preview.model == null:
		_status.text = "请先添加至少一个可渲染成员"
		return
	var stem := _capture_name.text.strip_edges()
	if stem.is_empty():
		stem = _group_title() if not _members.is_empty() else (_selected_card if not _selected_card.is_empty() else "model")
	stem = stem.replace("/", "_").replace("\\", "_").replace(" ", "_")
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var path := ProjectSettings.globalize_path(SHOTS_DIR + "/" + stem + "_" + stamp + ".png")
	_capture_to_path(path, "%dx%d" % [size.x, size.y], false)

func _capture_to_path(raw_path: String, size_text: String, quit_after: bool) -> void:
	if DisplayServer.get_name() == "headless":
		_fail("拍摄需要实际渲染，请不要使用 --headless")
		return
	var dimensions := size_text.split("x")
	if dimensions.size() != 2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():
		_fail("size must be WIDTHxHEIGHT")
		return
	var size := Vector2i(int(dimensions[0]), int(dimensions[1]))
	if size != CARD_IMAGE_SIZE:
		_fail("卡面摄影输出固定为 308x560，请不要修改 --size")
		return
	var output := raw_path
	if not output.is_absolute_path():
		output = ProjectSettings.globalize_path("res://" + output)
	output = ProjectSettings.globalize_path(output).simplify_path()
	if not output.ends_with(".png"):
		_fail("拍摄输出必须是 .png")
		return
	if FileAccess.file_exists(output):
		_fail("不会覆盖已有文件，请换一个输出路径：" + output)
		return
	var library_root := ProjectSettings.globalize_path("res://ClashLegends-开发素材库/")
	if not output.begins_with(library_root):
		_fail("摄影输出必须放在 ClashLegends-开发素材库 内")
		return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	_preview.stretch = false
	await process_frame
	_preview._viewport.size = size * 2
	_preview._camera.keep_aspect = Camera3D.KEEP_HEIGHT
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := _preview._viewport.get_texture().get_image()
	if image.get_width() != size.x or image.get_height() != size.y:
		image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(output)
	if error != OK:
		_fail("保存截图失败：" + error_string(error))
		return
	_preview._viewport.size = CARD_IMAGE_SIZE
	_preview.stretch = true
	_preview.custom_minimum_size = PREVIEW_SIZE
	_status.text = "已拍摄：%s" % output
	print("Saved camera studio capture: ", output)
	if quit_after:
		quit()

func _update_time() -> void:
	var selected_player := _selected_player()
	if selected_player == null or selected_player.assigned_animation.is_empty():
		return
	_time_updating = true
	_time_slider.set_value_no_signal(selected_player.current_animation_position)
	_time_label.text = "%.3f / %.3f 秒" % [selected_player.current_animation_position, _time_slider.max_value]
	if _selected_member_index >= 0 and _selected_member_index < _members.size():
		var member: Dictionary = _members[_selected_member_index]
		member["time"] = selected_player.current_animation_position
		_members[_selected_member_index] = member
	_time_updating = false
