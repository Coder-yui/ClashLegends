extends SceneTree
## 真实峡谷封面摄影台：地图、四座防御塔、双方水晶和可定格的表现对象。
## 只操作表现副本，不创建对局、不驱动伤害或移动规则。

const SceneStore = preload("res://tools/viewers/cover/scene_store.gd")

const DEFAULT_CARD := "pantheon"
const OUTPUT_9X16 := Vector2i(1080, 1920)
const OUTPUT_16X9 := Vector2i(1920, 1080)
const TOWER_SPECS := [
	[0, Vector2(ArenaRules.BRIDGE_X_LEFT, 25.5 * ArenaRules.TILE_SIZE), false],
	[0, Vector2(ArenaRules.BRIDGE_X_RIGHT, 25.5 * ArenaRules.TILE_SIZE), false],
	[1, Vector2(ArenaRules.BRIDGE_X_LEFT, 6.5 * ArenaRules.TILE_SIZE), false],
	[1, Vector2(ArenaRules.BRIDGE_X_RIGHT, 6.5 * ArenaRules.TILE_SIZE), false],
	[0, Vector2(9.0 * ArenaRules.TILE_SIZE, 29.0 * ArenaRules.TILE_SIZE), true],
	[1, Vector2(9.0 * ArenaRules.TILE_SIZE, 3.0 * ArenaRules.TILE_SIZE), true],
]

var _scene_path := SceneStore.PATH
var _scene_enabled := true
var _scene_ready := false
var _last_saved: Dictionary = {}
var _save_label: Label

var _ratio := "9x16"
var _canvas_size := OUTPUT_9X16
var _out_path := ""
var _presentation: BattlePresentation3D
var _world: Node3D
var _camera: Camera3D
var _viewport: SubViewport
var _preview: TextureRect
var _preview_frame: AspectRatioContainer
var _reference_camera: Camera3D
var _reference_viewport: SubViewport
var _shots: Dictionary = {}
var _shot_window: Window
var _camera_frames: Dictionary = {}
var _card_sources: Array[Dictionary] = []
var _effect_team: OptionButton
var _effect_instance_team: OptionButton
var _external_viewport: SubViewport
var _external_camera: Camera3D
var _external_view := false
var _view_label: Label
var _effect_members: OptionButton
var _effect_position: Array[HSlider] = []
var _effect_heading: HSlider
var _effect_updating := false
var _placing_effect := false
var _capture_busy := false
var _root_control: Control
var _status: Label
var _card_option: OptionButton
var _team_option: OptionButton
var _member_option: OptionButton
var _clip_option: OptionButton
var _effect_option: OptionButton
var _ratio_option: OptionButton
var _time_slider: HSlider
var _effect_slider: HSlider
var _time_label: Label
var _effect_label: Label
var _capture_name: LineEdit
var _camera_fov: HSlider
var _camera_position_x: HSlider
var _camera_position_y: HSlider
var _camera_position_z: HSlider
var _camera_rotation_x: HSlider
var _camera_rotation_y: HSlider
var _camera_rotation_z: HSlider
var _camera_position_updating := false
var _camera_rotation_updating := false
var _member_position_x: HSlider
var _member_position_y: HSlider
var _member_position_z: HSlider
var _member_yaw: HSlider
var _member_transform_updating := false
var _selected_member := -1
var _members: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _selected_effect := -1
var _camera_target := Vector3.ZERO
var _time_updating := false
var _drag_place := false
var _smoke := false
var _smoke_capture := false
var _camera_dragging := false
var _pan_dragging := false

func _initialize() -> void:
	# 项目主窗口是 720×1400 竖屏；封面拍摄台需要预览区和右侧控制面板并排显示。
	# 在构建界面前切换到独立横向工具窗口，避免控制面板被挤到窗口外。
	root.title = "Clash Legends · 真实峡谷封面摄影台"
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	root.min_size = Vector2i(1120, 760)
	if "--help" in OS.get_cmdline_user_args():
		print("Cover Studio: --ratio=9x16|16x9 --out=/path/file.png")
		quit()
		return
	_parse_args()
	auto_accept_quit = false
	root.close_requested.connect(_close_studio)
	call_deferred("_build")

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke":
			_smoke = true
			continue
		if arg == "--smoke-capture":
			_smoke = true
			_smoke_capture = true
			continue
		if arg.begins_with("--ratio="):
			_ratio = arg.trim_prefix("--ratio=")
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene-file="):
			_scene_path = arg.trim_prefix("--scene-file=")
		elif arg == "--no-save":
			_scene_enabled = false
	if _smoke: _scene_enabled = false
	_canvas_size = OUTPUT_16X9 if _ratio == "16x9" else OUTPUT_9X16

func _build() -> void:
	# 在 deferred 阶段再次设置，确保覆盖项目默认的 720×1400 竖屏窗口初始化值。
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	root.min_size = Vector2i(1120, 760)
	await _build_scene()
	_build_ui()
	await process_frame
	_populate_cards()

	_status.text = "已载入真实峡谷地图与透视相机；相机模式左键转头、中键平移、滚轮前后移动；添加单位或特效开始布景"
	if _scene_enabled: _restore_scene()
	_scene_ready = true
	if _smoke:
		await process_frame
		if _smoke_capture: await _capture()
		quit()

func _build_scene() -> void:
	_presentation = BattlePresentation3D.new()
	root.add_child(_presentation)
	_presentation.setup(Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H), ArenaRules.TILE_SIZE)
	_world = _presentation._world_root
	_camera = _presentation._camera
	_viewport = _presentation._viewport
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 固定的正式对局投影用于建筑、部署落点及特效采样；永不跟随拍摄相机。
	_reference_viewport = SubViewport.new()
	_reference_viewport.size = Vector2i(720, 1280)
	_reference_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_reference_viewport)
	_reference_camera = _camera.duplicate() as Camera3D
	_reference_viewport.add_child(_reference_camera)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.texture = _viewport.get_texture()
	var overlay := _presentation.get_node_or_null("UnitOverlay3D")
	if overlay != null: overlay.hide()
	_setup_towers()
	await process_frame
	for child in _world.get_children():
		if child is TowerModel3D:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			var animation: AnimationPlayer = child._animation_player
			if child._source.is_king and animation != null and animation.has_animation("Idle1_Base"):
				animation.play("Idle1_Base")
				animation.seek(0.0, true)
				animation.pause()
				child._show_alive_surfaces()
	# 塔的正式屏幕坐标在 720×1280 权威画布上完成投影；塔就位后再切封面输出比例。
	_viewport.size = _canvas_size
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.near = 0.05
	_camera.far = 1000.0
	_camera_target = Vector3.ZERO
	_initialize_camera()
	_external_viewport = SubViewport.new()
	_external_viewport.size = Vector2i(1440, 900)
	_external_viewport.world_3d = _viewport.find_world_3d()
	_external_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_external_viewport)
	_external_camera = Camera3D.new()
	_external_camera.near = 0.05
	_external_camera.far = 1000
	_external_camera.fov = 50
	_external_viewport.add_child(_external_camera)
	_external_camera.current = true
	_reset_external_camera()

func _setup_towers() -> void:
	for spec in TOWER_SPECS:
		var source := Tower.new()
		var is_king: bool = spec[2]
		source.setup(spec[0], CardDB.NEXUS_STATS if is_king else CardDB.PRINCESS_TOWER_STATS, is_king)
		source.position = spec[1]
		root.add_child(source)
		_presentation.attach_tower(source, CardDB.NEXUS_VISUAL_CONFIG if is_king else CardDB.PRINCESS_TOWER_VISUAL_CONFIG)

func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_root_control)
	var background := ColorRect.new()
	background.color = Color("0b1220")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	background.add_child(margin)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(left)
	var toolbar := _row(left)
	_button(toolbar, "竖版 9:16", func(): _set_ratio("9x16"))
	_button(toolbar, "横版 16:9", func(): _set_ratio("16x9"))
	_button(toolbar, "拍摄到桌面", _capture)
	_button(toolbar, "查看已拍成片", _show_shots)
	var save_row := _row(left)
	_button(save_row, "保存布景", func(): _save_scene())
	_save_label = Label.new()
	_save_label.text = "手动保存布景 · 关闭不保存"
	save_row.add_child(_save_label)
	var views := _row(left)
	_button(views, "拍摄视角", func(): _set_external_view(false))
	_button(views, "外部视角 · 布景", func(): _set_external_view(true))
	_button(views, "外部视角复位", _reset_external_camera)
	_view_label = Label.new()
	_view_label.text = "拍摄视角：当前画面用于成片"
	left.add_child(_view_label)
	_preview_frame = AspectRatioContainer.new()
	_preview_frame.ratio = float(_canvas_size.x) / _canvas_size.y
	_preview_frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_preview_frame)
	_preview_frame.add_child(_preview)
	var panel := ScrollContainer.new()
	panel.custom_minimum_size.x = 430
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(panel)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 7)
	panel.add_child(controls)
	var title := Label.new()
	title.text = "真实峡谷 · 封面摄影台"
	title.add_theme_font_size_override("font_size", 24)
	controls.add_child(title)
	var hint := Label.new()
	hint.text = "横版 16:9 / 竖版 9:16 · 透视相机可真实改变远近、机位和角度"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("9badc4"))
	controls.add_child(hint)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(420, 720)
	controls.add_child(tabs)
	for tab_name in ["单位布景", "特效布景", "相机", "输出"]:
		var page := VBoxContainer.new()
		page.name = tab_name
		tabs.add_child(page)
		match tab_name:
			"单位布景": _build_subject_controls(page)
			"特效布景": _build_effect_controls(page)
			"相机": _build_camera_controls(page)
			"输出": _build_capture_controls(page)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("8fd4b2"))
	controls.add_child(_status)

func _section(parent: Node, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	margin.add_child(box)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 17)
	box.add_child(label)
	return box

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	return row

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _slider(parent: Node, title: String, low: float, high: float, value: float, action: Callable) -> HSlider:
	var row := _row(parent)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 106
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.allow_greater = title.contains("位置") or title.contains("高度") or title.contains("朝向")
	slider.allow_lesser = slider.allow_greater
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(action)
	row.add_child(slider)
	var number := SpinBox.new()
	number.min_value = low
	number.max_value = high
	number.allow_greater = slider.allow_greater
	number.allow_lesser = slider.allow_lesser
	number.step = slider.step
	number.custom_minimum_size.x = 86
	number.value = value
	row.add_child(number)
	slider.value_changed.connect(func(v): number.set_value_no_signal(v))
	number.value_changed.connect(func(v): slider.value = v)
	# 同步来自鼠标拖拽与对象切换的无信号更新。
	number.set_meta("slider", slider)
	return slider

func _build_subject_controls(parent: Node) -> void:
	var box := _section(parent, "单位与动作定格")
	var row := _row(box)
	_card_option = OptionButton.new()
	_card_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_option.item_selected.connect(func(index: int):
		if index >= 0 and index < _card_option.item_count: _status.text = "来源：%s；点击添加单位" % _card_option.get_item_text(index))
	row.add_child(_card_option)
	_team_option = OptionButton.new()
	_team_option.add_item("蓝方")
	_team_option.add_item("红方")
	row.add_child(_team_option)
	_button(box, "添加单位", _add_selected_card)
	_member_option = OptionButton.new()
	_member_option.item_selected.connect(_select_member)
	box.add_child(_member_option)
	_member_position_x = _slider(box, "单位位置 X", -50.0, 50.0, 0.0, func(value): _update_selected_member_transform())
	_member_position_y = _slider(box, "单位高度 Y", -4.0, 12.0, 0.0, func(value): _update_selected_member_transform())
	_member_position_z = _slider(box, "单位位置 Z", -50.0, 50.0, 0.0, func(value): _update_selected_member_transform())
	_member_yaw = _slider(box, "单位朝向", -180.0, 180.0, 0.0, func(value): _update_selected_member_transform())
	_button(box, "恢复游戏内地面位置", _reset_selected_member_transform)
	var actions := _row(box)
	_button(actions, "删除单位", _remove_member)
	_button(actions, "放置模式", func(): _drag_place = true; _placing_effect = false; _status.text = "放置模式：左键地图任意位置，拖动中的单位会跟随鼠标")
	_button(actions, "相机模式", func(): _drag_place = false; _status.text = "相机模式：左键转头，中键平移，滚轮前进/后退")
	_clip_option = OptionButton.new()
	_clip_option.item_selected.connect(func(index: int):
		if _selected_member < 0 or index < 0: return
		_select_clip(_clip_option.get_item_text(index)))
	box.add_child(_clip_option)
	var transport := _row(box)
	_button(transport, "播放动作", func(): _set_member_playing(true))
	_button(transport, "暂停动作", func(): _set_member_playing(false))
	_button(transport, "+1/30秒", func(): _seek_member(_member_time() + 1.0 / 30.0))
	_time_slider = _slider(box, "动作时间", 0.0, 1.0, 0.0, func(value):
		if not _time_updating: _seek_member(value))
	_time_label = Label.new()
	box.add_child(_time_label)

func _build_effect_controls(parent: Node) -> void:
	var box := _section(parent, "添加与编辑独立特效")
	_effect_option = OptionButton.new()
	_effect_option.add_item("潘森 · 完整天降 / 滑行冲击波")
	_effect_option.set_item_metadata(0, "pantheon_arrival")
	for system in preload("res://assets/units/pantheon/arrival/particle_player.gd").systems():
		_effect_option.add_item("潘森 · " + {"Spear_Impact": "长矛命中", "update_missile": "天降彗星", "Sliding_Comet": "滑行彗星", "Damage_Mis": "伤害拖尾", "Update_Impact": "滑行冲击", "Ending_Shockwave": "落地收尾冲击波", "Spear_Landing": "长矛落地"}.get(system, system))
		_effect_option.set_item_metadata(_effect_option.item_count - 1, system)
	box.add_child(_effect_option)
	_effect_team = OptionButton.new()
	_effect_team.add_item("新增特效：蓝方")
	_effect_team.add_item("新增特效：红方")
	box.add_child(_effect_team)
	_button(box, "添加特效", func(): _add_effect(_effect_option.get_selected_metadata()))
	_effect_members = OptionButton.new()
	box.add_child(_effect_members)
	_effect_members.item_selected.connect(func(i): _selected_effect = i; _sync_effect_ui())
	_effect_instance_team = OptionButton.new()
	_effect_instance_team.add_item("当前特效：蓝方")
	_effect_instance_team.add_item("当前特效：红方")
	_effect_instance_team.item_selected.connect(_change_effect_team)
	box.add_child(_effect_instance_team)
	var actions := _row(box)
	_button(actions, "删除", _remove_effect)
	_button(actions, "拖动布置", func(): _drag_place = true; _placing_effect = true; _status.text = "左键移动当前特效；Shift + 左键拖动调整朝向")
	var help := Label.new()
	help.text = "左键拖动位置 · Shift + 左键拖动朝向"
	box.add_child(help)
	for axis in ["X", "Y", "Z"]:
		_effect_position.append(_slider(box, "特效位置 " + axis, -50, 50, 0, func(v): _edit_effect_transform()))
	_effect_heading = _slider(box, "特效朝向", -180, 180, 0, func(v): _edit_effect_transform())
	var transport := _row(box)
	_button(transport, "播放", func(): _set_effect_playing(true))
	_button(transport, "定格", func(): _set_effect_playing(false))
	_button(transport, "+1/30秒", func(): _seek_effect(_effect_slider.value + 1.0 / 30.0))
	_effect_slider = _slider(box, "特效时间", 0, 5, 0, _seek_effect)
	_effect_label = Label.new()
	box.add_child(_effect_label)

func _build_camera_controls(parent: Node) -> void:
	var box := _section(parent, "相机角度与位置")
	_ratio_option = OptionButton.new()
	_ratio_option.add_item("竖版 9:16")
	_ratio_option.add_item("横版 16:9")
	_ratio_option.select(1 if _ratio == "16x9" else 0)
	_ratio_option.item_selected.connect(func(index: int): _set_ratio("16x9" if index == 1 else "9x16"))
	box.add_child(_ratio_option)
	_camera_fov = _slider(box, "视野 FOV", 10.0, 120.0, 48.0, func(value): _apply_camera_lens())
	_camera_position_x = _slider(box, "相机位置 X", -100.0, 100.0, 0.0, func(value): _apply_camera_position())
	_camera_position_y = _slider(box, "相机位置 Y", -60.0, 120.0, 24.0, func(value): _apply_camera_position())
	_camera_position_z = _slider(box, "相机位置 Z", -100.0, 100.0, 24.0, func(value): _apply_camera_position())
	_camera_rotation_x = _slider(box, "自由旋转 X", -180.0, 180.0, 0.0, func(value): _apply_camera_rotation())
	_camera_rotation_y = _slider(box, "自由旋转 Y", -180.0, 180.0, 0.0, func(value): _apply_camera_rotation())
	_camera_rotation_z = _slider(box, "自由旋转 Z", -180.0, 180.0, 0.0, func(value): _apply_camera_rotation())
	_sync_camera_position_controls()
	_sync_camera_rotation_controls()
	_button(box, "复位相机", _reset_camera)
	_button(box, "镜头朝向选中单位", _aim_at_member)
	_button(box, "鼠标控制相机", func(): _drag_place = false)

func _build_capture_controls(parent: Node) -> void:
	var box := _section(parent, "输出到桌面")
	_capture_name = LineEdit.new()
	_capture_name.placeholder_text = "文件名前缀（自动附加比例、时间）"
	box.add_child(_capture_name)
	_button(box, "拍摄当前封面 PNG", _capture)

func _populate_cards() -> void:
	_card_option.clear()
	_card_sources.clear()
	for id in CardDB.all():
		var base := CardDB.get_card(id)
		for form in range(2 if base.has("transformed_stats") else 1):
			var stats := PresentationConfig.for_form(base, form)
			if PresentationConfig.scene_path(stats, 0).is_empty(): continue
			_card_sources.append({"id": id, "form": form})
			_card_option.add_item("%s · %s" % [stats.get("name", id), id])
			if id == DEFAULT_CARD: _card_option.select(_card_option.item_count - 1)

func _add_selected_card() -> void:
	if _card_option.selected < 0: return
	var entry: Dictionary = _card_sources[_card_option.selected]
	_add_member(entry.id, _team_option.selected, entry.form, false)

func _resolve_scene(card_id: String, team: int, form: int) -> PackedScene:
	if not CardDB.has_card(card_id): return null
	var stats := PresentationConfig.for_form(CardDB.get_card(card_id), form)
	var path := PresentationConfig.scene_path(stats, team)
	return load(path) as PackedScene if not path.is_empty() and ResourceLoader.exists(path) else null

func _add_member(card_id: String, team: int, form: int, first: bool) -> void:
	var packed := _resolve_scene(card_id, team, form)
	if packed == null:
		_status.text = "没有可用的 3D 模型：%s" % card_id
		return
	var model := packed.instantiate() as Node3D
	if model == null: return
	var staging := Node3D.new()
	_world.add_child(staging)
	staging.add_child(model)
	var stats := PresentationConfig.for_form(CardDB.get_card(card_id), form)
	if model.has_method("set_visual_form"): model.call("set_visual_form", form)
	if bool(stats.get("is_air", false)):
		var bottom := INF
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var bounds := mesh.get_aabb()
			for corner in 8:
				var p := bounds.position + bounds.size * Vector3(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1)
				bottom = minf(bottom, staging.to_local(mesh.to_global(p)).y)
		if is_finite(bottom): model.position.y += CardDB.AIR_VISUAL_ELEVATION - bottom
	if model.has_method("prepare_visual_animations"): model.call("prepare_visual_animations")
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := player.get_animation_list() if player != null else PackedStringArray()
	var member := {"model": staging, "player": player, "card_id": card_id, "team": team, "form": form, "clips": clips, "clip": "", "time": 0.0}
	var idle = stats.get("visual_animations", {}).get("idle", "")
	if idle is Array: idle = idle[0] if not idle.is_empty() else ""
	member["clip"] = String(idle) if String(idle) in clips else _preferred_clip(clips)
	_members.append(member)
	_selected_member = _members.size() - 1
	var member_slot := _members.size() - 1
	staging.position = _map_screen_to_world(Vector2(300 + (member_slot % 3) * 60, 840 if team == 0 else 440))
	staging.rotation.y = (PI if team == 0 else 0.0) + float(stats.get("visual_forward_yaw", 0.0))
	member["default_position"] = staging.position
	member["default_yaw"] = staging.rotation.y
	_apply_member_clip(member, String(member["clip"]), 0.0)
	_refresh_member_ui()
	if not first: _status.text = "已添加 %s；可放置到地图任意位置" % card_id

func _preferred_clip(clips: PackedStringArray) -> String:
	for clip in clips:
		if String(clip).to_lower().contains("idle"): return String(clip)
	return String(clips[0]) if not clips.is_empty() else ""

func _refresh_member_ui() -> void:
	_member_option.clear()
	for index in _members.size(): _member_option.add_item("%02d · %s" % [index + 1, _members[index].card_id])
	if _selected_member >= 0 and _selected_member < _member_option.item_count: _member_option.select(_selected_member)
	_clip_option.clear()
	if _selected_member < 0 or _selected_member >= _members.size():
		_time_label.text = "尚未选择单位"
		return
	var member: Dictionary = _members[_selected_member]
	for clip in member.clips: _clip_option.add_item(String(clip))
	for index in _clip_option.item_count:
		if _clip_option.get_item_text(index) == member.clip: _clip_option.select(index)
	var player: AnimationPlayer = member.player
	var duration := player.get_animation(member.clip).length if player != null and player.has_animation(member.clip) else 0.001
	_time_slider.max_value = maxf(duration, 0.001)
	_time_slider.set_value_no_signal(clampf(float(member.time), 0.0, _time_slider.max_value))
	_time_label.text = "动作：%.3f / %.3f 秒" % [float(member.time), _time_slider.max_value]
	_sync_member_transform_controls()

func _select_member(index: int) -> void:
	if index < 0 or index >= _members.size(): return
	_selected_member = index
	_refresh_member_ui()

func _remove_member() -> void:
	if _selected_member < 0 or _selected_member >= _members.size(): return
	var model: Node3D = _members[_selected_member].model
	if is_instance_valid(model): model.queue_free()
	_members.remove_at(_selected_member)
	_selected_member = clampi(_selected_member, 0, _members.size() - 1)
	_refresh_member_ui()

func _map_screen_to_world(point: Vector2) -> Vector3:
	var origin := _reference_camera.project_ray_origin(point)
	var direction := _reference_camera.project_ray_normal(point)
	return origin + direction * (-origin.y / direction.y)

func _sync_member_transform_controls() -> void:
	if _member_position_x == null or _selected_member < 0 or _selected_member >= _members.size(): return
	var model: Node3D = _members[_selected_member].model
	if model == null or not is_instance_valid(model): return
	_member_transform_updating = true
	_member_position_x.set_value_no_signal(model.position.x)
	_member_position_y.set_value_no_signal(model.position.y)
	_member_position_z.set_value_no_signal(model.position.z)
	_member_yaw.set_value_no_signal(rad_to_deg(model.rotation.y))
	_member_transform_updating = false

func _update_selected_member_transform() -> void:
	if _member_transform_updating or _selected_member < 0 or _selected_member >= _members.size(): return
	var model: Node3D = _members[_selected_member].model
	if model == null or not is_instance_valid(model): return
	model.position = Vector3(_member_position_x.value, _member_position_y.value, _member_position_z.value)
	model.rotation.y = deg_to_rad(_member_yaw.value)
	_status.text = "已调整 %s 的三维位置 / 朝向" % _members[_selected_member].card_id

func _reset_selected_member_transform() -> void:
	if _selected_member < 0 or _selected_member >= _members.size(): return
	var model: Node3D = _members[_selected_member].model
	if model == null or not is_instance_valid(model): return
	model.position = _members[_selected_member].default_position
	model.rotation.y = _members[_selected_member].default_yaw
	_sync_member_transform_controls()
	_status.text = "已恢复游戏内地面放置位置：%s" % _members[_selected_member].card_id

func _apply_member_clip(member: Dictionary, clip: String, time: float) -> void:
	var player: AnimationPlayer = member.player
	if player == null or clip.is_empty() or not player.has_animation(clip): return
	member.clip = clip
	member.time = clampf(time, 0.0, player.get_animation(clip).length)
	player.play(clip)
	player.seek(member.time, true)
	player.pause()

func _select_clip(clip: String) -> void:
	if _selected_member < 0 or _selected_member >= _members.size(): return
	var member: Dictionary = _members[_selected_member]
	_apply_member_clip(member, clip, 0.0)
	_refresh_member_ui()

func _member_time() -> float:
	return float(_members[_selected_member].time) if _selected_member >= 0 and _selected_member < _members.size() else 0.0

func _seek_member(value: float) -> void:
	if _selected_member < 0 or _selected_member >= _members.size(): return
	var member: Dictionary = _members[_selected_member]
	var player: AnimationPlayer = member.player
	if player == null or not player.has_animation(member.clip): return
	member.time = clampf(value, 0.0, player.get_animation(member.clip).length)
	player.pause()
	player.seek(member.time, true)
	_refresh_member_ui()

func _set_member_playing(playing: bool) -> void:
	if _selected_member < 0 or _selected_member >= _members.size(): return
	var player: AnimationPlayer = _members[_selected_member].player
	if player == null: return
	if playing: player.play(String(_members[_selected_member].clip))
	else: player.pause()

func _add_effect(kind: String) -> void:
	var team := _effect_team.selected
	var position := _map_screen_to_world(Vector2(360, 840 if team == 0 else 440))
	if _selected_member >= 0: position = _members[_selected_member].model.position
	_effects.append({"team": team, "kind": kind, "time": 0.78 if kind == "pantheon_arrival" else 0.3, "duration": 1.3 if kind == "pantheon_arrival" else 5.0, "playing": false, "position": position, "yaw": 0.0, "node": null})
	_selected_effect = _effects.size() - 1
	_sample_effect(_effects.back())
	_sync_effect_ui()

func _remove_effect() -> void:
	if _selected_effect < 0: return
	_effects[_selected_effect].node.free()
	_effects.remove_at(_selected_effect)
	_selected_effect = mini(_selected_effect, _effects.size() - 1)
	_sync_effect_ui()

func _sample_effect(entry: Dictionary) -> void:
	if is_instance_valid(entry.node): entry.node.free()
	var placement := Transform3D(Basis(Vector3.UP, deg_to_rad(entry.yaw)), entry.position)
	var node: Node3D
	if entry.kind == "pantheon_arrival":
		node = preload("res://tools/viewers/cover/arrival.gd").new()
		_world.add_child(node)
		node.staging_transform = placement
		node.setup(_reference_camera, Vector2(360, 640), entry.team)
		node.advance_visual(entry.time / entry.duration)
	else:
		node = preload("res://assets/units/pantheon/arrival/particle_player.gd").new()
		_world.add_child(node)
		node.transform = placement
		if entry.team == 1: node.rotate_y(PI)
		node.setup(entry.kind, 0.0075)
		for tick in range(floori(entry.time * 60)): node.advance(1.0 / 60.0)
		node.advance(fposmod(entry.time, 1.0 / 60.0))
	node.set_process(false)
	node.set_physics_process(false)
	entry.node = node

func _sync_effect_ui() -> void:
	_effect_updating = true
	_effect_members.clear()
	for i in _effects.size(): _effect_members.add_item("%02d · %s · %s" % [i + 1, "蓝方" if _effects[i].team == 0 else "红方", _effects[i].kind])
	if _selected_effect >= 0:
		_effect_members.select(_selected_effect)
		var entry: Dictionary = _effects[_selected_effect]
		_effect_instance_team.select(entry.team)
		for axis in 3: _effect_position[axis].set_value_no_signal(entry.position[axis])
		_effect_heading.set_value_no_signal(entry.yaw)
		_effect_slider.max_value = entry.duration
		_effect_slider.set_value_no_signal(entry.time)
		_effect_label.text = "定格时间 %.3f / %.2f 秒" % [entry.time, entry.duration]
	_effect_updating = false

func _change_effect_team(team: int) -> void:
	if _effect_updating or _selected_effect < 0: return
	_effects[_selected_effect].team = team
	_sample_effect(_effects[_selected_effect])
	_sync_effect_ui()

func _edit_effect_transform() -> void:
	if _effect_updating or _selected_effect < 0: return
	var entry: Dictionary = _effects[_selected_effect]
	entry.position = Vector3(_effect_position[0].value, _effect_position[1].value, _effect_position[2].value)
	entry.yaw = _effect_heading.value
	_sample_effect(entry)

func _seek_effect(value: float) -> void:
	if _effect_updating or _selected_effect < 0: return
	var entry: Dictionary = _effects[_selected_effect]
	entry.time = clampf(value, 0, entry.duration)
	entry.playing = false
	_sample_effect(entry)
	_sync_effect_ui()

func _set_effect_playing(value: bool) -> void:
	if _selected_effect < 0: return
	var entry: Dictionary = _effects[_selected_effect]
	if value and entry.time >= entry.duration: entry.time = 0.0
	entry.playing = value

func _set_ratio(value: String) -> void:
	_camera_frames[_ratio] = {"transform": _camera.transform, "fov": _camera.fov}
	_ratio = value
	_canvas_size = OUTPUT_16X9 if value == "16x9" else OUTPUT_9X16
	_viewport.size = _canvas_size
	if not _external_view: _preview_frame.ratio = float(_canvas_size.x) / _canvas_size.y
	_ratio_option.select(1 if value == "16x9" else 0)
	if _camera_frames.has(value):
		_camera.transform = _camera_frames[value].transform
		_camera.fov = _camera_frames[value].fov
	_camera_fov.set_value_no_signal(_camera.fov)
	_sync_camera_position_controls()
	_sync_camera_rotation_controls()

func _reset_camera() -> void:
	_camera.position = Vector3(-17.4, 38.64, 30.14)
	_camera.look_at(Vector3.ZERO)
	_camera.fov = 48.0
	_camera_fov.set_value_no_signal(48)
	_sync_camera_position_controls()
	_sync_camera_rotation_controls()

func _aim_at_member() -> void:
	if _selected_member < 0: return
	var target: Vector3 = _members[_selected_member].model.position + Vector3.UP
	if _camera.position.distance_to(target) < 0.001: return
	_camera.look_at(target)
	_sync_camera_rotation_controls()

func _initialize_camera() -> void:
	_camera.position = Vector3(-17.4, 38.64, 30.14)
	_camera.look_at(Vector3.ZERO)
	_camera.fov = 48.0
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT

func _sync_camera_position_controls() -> void:
	if _camera == null or _camera_position_x == null or _camera_position_updating: return
	_camera_position_updating = true
	_camera_position_x.set_value_no_signal(_camera.position.x)
	_camera_position_y.set_value_no_signal(_camera.position.y)
	_camera_position_z.set_value_no_signal(_camera.position.z)
	_camera_position_updating = false

func _apply_camera_position() -> void:
	if _camera == null or _camera_position_updating: return
	_camera.position = Vector3(_camera_position_x.value, _camera_position_y.value, _camera_position_z.value)
	_camera.fov = _camera_fov.value
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
func _apply_camera_lens() -> void:
	if _camera == null: return
	_camera.fov = _camera_fov.value
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT

func _sync_camera_rotation_controls() -> void:
	if _camera == null or _camera_rotation_x == null or _camera_rotation_updating: return
	_camera_rotation_updating = true
	_camera_rotation_x.set_value_no_signal(_camera.rotation_degrees.x)
	_camera_rotation_y.set_value_no_signal(_camera.rotation_degrees.y)
	_camera_rotation_z.set_value_no_signal(_camera.rotation_degrees.z)
	_camera_rotation_updating = false

func _apply_camera_rotation() -> void:
	if _camera == null or _camera_rotation_updating: return
	_camera.rotation_degrees = Vector3(_camera_rotation_x.value, _camera_rotation_y.value, _camera_rotation_z.value)
	_camera.fov = _camera_fov.value
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT

func _active_camera() -> Camera3D:
	return _external_camera if _external_view else _camera

func _reset_external_camera() -> void:
	_external_camera.position = Vector3(-24, 41, 38)
	_external_camera.look_at(Vector3.ZERO)

func _set_external_view(enabled: bool) -> void:
	_external_view = enabled
	_camera_dragging = false
	_pan_dragging = false
	_external_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	_preview.texture = _external_viewport.get_texture() if enabled else _viewport.get_texture()
	var dimensions := _external_viewport.size if enabled else _canvas_size
	_preview_frame.ratio = float(dimensions.x) / dimensions.y
	_view_label.text = "外部视角：仅供布景检查；拍摄仍使用拍摄相机" if enabled else "拍摄视角：当前画面用于成片"

func _rotate_selected(relative_x: float) -> void:
	if _placing_effect:
		if _selected_effect < 0: return
		var entry: Dictionary = _effects[_selected_effect]
		entry.yaw = wrapf(entry.yaw + relative_x * 0.5, -180, 180)
		_sample_effect(entry)
		_sync_effect_ui()
	elif _selected_member >= 0:
		var model: Node3D = _members[_selected_member].model
		model.rotation_degrees.y = wrapf(model.rotation_degrees.y + relative_x * 0.5, -180, 180)
		_sync_member_transform_controls()

func _screen_to_ground(screen: Vector2) -> Vector3:
	var camera := _active_camera()
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.y) < 0.0001: return Vector3.INF
	var distance := -origin.y / direction.y
	return origin + direction * distance if distance >= 0 else Vector3.INF

func _pointer_to_ground(point: Vector2) -> Vector3:
	var dimensions := _external_viewport.size if _external_view else _canvas_size
	var local := point * Vector2(dimensions) / _preview.size
	return _screen_to_ground(local)

func _process(delta: float) -> bool:
	if _capture_busy: return false
	for entry in _effects:
		if entry.playing:
			entry.time = minf(entry.time + delta, entry.duration)
			entry.playing = entry.time < entry.duration
			_sample_effect(entry)
		elif is_instance_valid(entry.node):
			# 定格时间保持不动，只更新朝向当前镜头的粒子面片。
			if entry.kind == "pantheon_arrival": entry.node.advance_visual(entry.time / entry.duration)
			else: entry.node.present(entry.time)
	if _selected_effect >= 0 and _effects[_selected_effect].playing: _sync_effect_ui()
	if _root_control != null:
		for number in _root_control.find_children("*", "SpinBox", true, false):
			if number.has_meta("slider"):
				var slider: HSlider = number.get_meta("slider")
				number.max_value = slider.max_value
				if not number.get_line_edit().has_focus(): number.set_value_no_signal(slider.value)
	if _selected_member >= 0 and _selected_member < _members.size():
		var player: AnimationPlayer = _members[_selected_member].player
		if player != null and player.is_playing():
			_members[_selected_member].time = player.current_animation_position
			_time_updating = true
			_time_slider.set_value_no_signal(player.current_animation_position)
			_time_label.text = "动作：%.3f / %.3f 秒" % [player.current_animation_position, _time_slider.max_value]
			_time_updating = false
	return false

func _place_at(point: Vector2) -> void:
	var position := _pointer_to_ground(point - _preview.global_position)
	if not position.is_finite(): return
	if _placing_effect:
		if _selected_effect < 0: return
		_effects[_selected_effect].position = position
		_sample_effect(_effects[_selected_effect])
		_sync_effect_ui()
	elif _selected_member >= 0:
		_members[_selected_member].model.position = position
		_sync_member_transform_controls()

func _input(event: InputEvent) -> void:
	if _preview == null or not event is InputEventMouse: return
	var camera := _active_camera()
	var in_preview := Rect2(_preview.global_position, _preview.size).has_point(event.position)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_camera_dragging = event.pressed and in_preview and not _drag_place
			if event.pressed and in_preview and _drag_place and not event.shift_pressed: _place_at(event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_dragging = event.pressed and in_preview
		elif in_preview and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			camera.position += camera.basis.z * (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			_sync_camera_position_controls()
	elif event is InputEventMouseMotion and in_preview:
		if _drag_place and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if event.shift_pressed: _rotate_selected(event.relative.x)
			else: _place_at(event.position)
		elif _camera_dragging:
			camera.rotation_degrees.y = wrapf(camera.rotation_degrees.y - event.relative.x * 0.2, -180, 180)
			camera.rotation_degrees.x = clampf(camera.rotation_degrees.x - event.relative.y * 0.2, -89.9, 89.9)
			_sync_camera_rotation_controls()
		elif _pan_dragging:
			camera.position += (-camera.basis.x * event.relative.x + camera.basis.y * event.relative.y) * 0.04
			_sync_camera_position_controls()

func _show_shots() -> void:
	if _shots.is_empty():
		_status.text = "先拍摄一张封面，再查看成片。"
		return
	if _shot_window == null:
		_shot_window = Window.new()
		_shot_window.title = "已拍摄封面 · 横竖版成片预览"
		_shot_window.size = Vector2i(1000, 700)
		root.add_child(_shot_window)
		_shot_window.close_requested.connect(_shot_window.hide)
		var tabs := TabContainer.new()
		tabs.name = "Shots"
		tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shot_window.add_child(tabs)
	var tabs := _shot_window.get_node("Shots")
	for child in tabs.get_children(): child.free()
	for ratio in _shots:
		var texture := TextureRect.new()
		texture.name = "横版 16比9" if ratio == "16x9" else "竖版 9比16"
		texture.texture = _shots[ratio]
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tabs.add_child(texture)
	_shot_window.popup_centered()

func _capture() -> void:
	if _capture_busy: return
	if DisplayServer.get_name() == "headless":
		_status.text = "拍摄需要实际渲染窗口"
		return
	_capture_busy = true
	# 暂停所有对象，输出与构图预览共享同一张固定分辨率纹理。
	for member in _members:
		if member.player != null:
			if member.player.is_playing(): member.time = member.player.current_animation_position
			member.player.pause()
	for entry in _effects: entry.playing = false
	await process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	_shots[_ratio] = ImageTexture.create_from_image(image)
	var name := _capture_name.text.strip_edges().get_file().get_basename()
	if name.is_empty(): name = "ClashLegends_cover"
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := _out_path if not _out_path.is_empty() else OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).path_join("%s_%s_%s.png" % [name, _ratio, stamp])
	if FileAccess.file_exists(path):
		path = path.get_basename() + "_%d.png" % Time.get_ticks_msec()
	var error := image.save_png(path)
	_status.text = "已保存：" + path if error == OK else "保存失败：" + error_string(error)
	if error == OK: print("COVER_SAVED:" + path)
	_capture_busy = false
	if not _smoke: _show_shots()

func _save_scene() -> bool:
	if not _scene_enabled or not _scene_ready: return false
	var state := SceneStore.snapshot(self)
	if state == _last_saved:
		_save_label.text = "布景已保存"
		return true
	var error := SceneStore.write(_scene_path, state)
	if error != OK:
		_save_label.text = "保存失败：" + error_string(error)
		return false
	_last_saved = state
	_save_label.text = "布景已保存 · " + Time.get_time_string_from_system()
	return true

func _restore_scene() -> void:
	if not FileAccess.file_exists(_scene_path): return
	var state := SceneStore.read(_scene_path)
	if state.is_empty():
		# 不以空场覆盖损坏/未知版本的数据，保留备份供恢复。
		_scene_enabled = false
		_save_label.text = "布景文件读取失败，已禁止覆盖保存"
		_status.text = "请保留原文件及 .bak 备份：" + ProjectSettings.globalize_path(_scene_path)
		return
	# 先检查所有模型，避免缺资源时只恢复半个场景并覆盖原文件。
	for entry in state.members:
		if _resolve_scene(entry.card_id, entry.team, entry.form) == null:
			_scene_enabled = false
			_save_label.text = "缺少模型，已保留原布景：" + entry.card_id
			return
	for entry in state.members:
		_add_member(entry.card_id, entry.team, entry.form, true)
		var member: Dictionary = _members.back()
		member.model.transform = entry.transform
		member.default_position = entry.default_position
		member.default_yaw = entry.default_yaw
		_apply_member_clip(member, entry.clip, entry.time)
	for entry in state.effects:
		var effect: Dictionary = entry.duplicate(true)
		effect.node = null
		effect.playing = false
		_effects.append(effect)
		_sample_effect(effect)
	_selected_member = clampi(state.selected_member, -1, _members.size() - 1)
	_selected_effect = clampi(state.selected_effect, -1, _effects.size() - 1)
	_refresh_member_ui()
	_sync_effect_ui()
	_ratio = state.ratio
	_camera_frames = state.frames.duplicate(true)
	# _set_ratio 会先保存当前相机，故先装入对应比例的已存机位。
	_camera.transform = _camera_frames[_ratio].transform
	_camera.fov = _camera_frames[_ratio].fov
	_set_ratio(_ratio)
	_external_camera.transform = state.external_transform
	_external_camera.fov = state.external_fov
	_set_external_view(state.external_view)
	_capture_name.text = state.capture_name
	_drag_place = state.drag_place
	_placing_effect = state.placing_effect
	_last_saved = SceneStore.snapshot(self)
	_save_label.text = "已恢复上次布景 · 修改后请手动保存"
	_status.text = "已恢复 %d 个单位、%d 个特效及横竖版机位；动作和特效保持保存时的定格。" % [_members.size(), _effects.size()]

func _close_studio() -> void:
	quit()
