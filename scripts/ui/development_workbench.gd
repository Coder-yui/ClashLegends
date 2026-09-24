class_name DevelopmentWorkbench
extends CanvasLayer
## 三个工作区共享卡牌选择；素材预览与真实战斗分离。
signal item_selected(item_id: String)
signal team_changed(team: int)
signal form_selected(form: int)
signal active_skill_selected(item_id: String, skill_index: int)
signal active_skill_requested(skill_index: int)
signal skill_resource_requested(value: float)
signal scenario_requested(action: String)
signal spell_active_changed(enabled: bool)
signal clear_requested
signal exit_requested
signal workspace_changed(battle_active: bool)

const SCENARIOS := preload("res://scripts/ui/workbench/battle_scenarios.gd")
var _scenario_option: OptionButton
var _scenario_hint: Label

var _cards: Dictionary
var _selected_id := "garen"
var _team := 0
var _form := 0
var _active_skill_choices: Dictionary = {}
var _workspace := 0
var _pages: Array[Control] = []
var _tabs: Array[Button] = []
var _background: ColorRect
const LIBRARY := preload("res://scripts/ui/workbench/card_library.gd")
const DESKTOP := preload("res://scripts/ui/workbench/desktop_layout.gd")
const PREFERENCES := "user://workbench_quick_cards.cfg"
var _desktop: RefCounted
var _persist := false
var _preferences_path := PREFERENCES
var _quick_cards: Array[String] = []
var _quick_grid: GridContainer
var _quick_hint: Label
var _library: VBoxContainer
var _library_open := false
var _preset_button: Button
var _battle_paused := false
var _pause_button: Button
var _zoom_label: Label
var _shelf_panel: Control
var _library_overlay: Control
var _audio_right: VBoxContainer
var _card_info: ScrollContainer
var _audio_surface: Control
var _choose_button: Button
var _select_mode := false
var _mode_label: Label
var _select_mode_button: Button
var _preset_row: Control
var _inspection_controls: VBoxContainer
var _inspection_bound := false
var _inspection_source := ""
var _skill_scope: Label
var _audio_time: Label
var _spell_choice: OptionButton
var _search: LineEdit
var _team_button: Button
var _form_option: OptionButton
var _selection_label: Label
var _art: TextureRect
var _preview: WorkbenchModelPreview
var _animation_option: VBoxContainer
var _timeline: HSlider
var _time_label: Label
var _model_hint: Label
var _spell_active: CheckButton
var _skill_option: OptionButton
var _skill_button: Button
var _control_buttons: Array[Button] = []
var _unit_status_label: Label
var _resource_controls: HBoxContainer
var _resource_slider: HSlider
var _resource_value_label: Label
var _resource_max := 0.0
var _resource_supported := false
var _unit_available := false
var _unit_deployed := false
var _unit_casting := false
var _audio_cue: OptionButton
var _audio_list: ItemList
var _audio_entries: Array[Dictionary] = []
var _audio_player: AudioStreamPlayer
var _audio_status: Label
var _audio_timeline: HSlider
var _rotation: HSlider
var _zoom: HSlider

func setup(cards: Dictionary) -> void:
	layer = 30
	_cards = cards
	_build_ui()
	_filter_cards("")
	_select_item(_selected_id)
	show_workspace(0)

func _label(parent: Node, text: String, small: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_color_override("font_color", Color("9badc4") if small else Color("edf3ff"))
	node.add_theme_font_size_override("font_size", 16 if small else 20)
	parent.add_child(node)
	return node

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.add_theme_stylebox_override("pressed", CardArt.frame_style(Color("214866"), Color("72ceff"), 2))
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row

func _panel(parent: Node, compact: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CardArt.frame_style(Color("172537"), Color("2b405a"), 1, 12))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 8 if compact else 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5 if compact else 10)
	margin.add_child(box)
	return box

func _build_ui() -> void:
	var underlay := CanvasLayer.new()
	underlay.layer = -100
	add_child(underlay)
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b1320")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underlay.add_child(backdrop)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.name = "WorkbenchRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Theme.new()
	root.theme.default_font = CardArt.ui_font()
	root.theme.default_font_size = 18
	add_child(root)
	_background = ColorRect.new()
	_background.color = Color("0b1320")
	_background.position = Vector2.ZERO
	_background.size = Vector2(640, 1000)
	root.add_child(_background)
	for rect in [Rect2(640, 0, 16, 1000), Rect2(656, 0, 784, 20), Rect2(1424, 20, 16, 980), Rect2(656, 980, 768, 20)]:
		var border := ColorRect.new()
		border.color = _background.color
		border.position = rect.position
		border.size = rect.size
		root.add_child(border)
	var margin := MarginContainer.new()
	margin.position = Vector2.ZERO
	margin.size = Vector2(640, 1000)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	root.add_child(margin)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := _panel(layout)
	var title_row := _row(header)
	var title := _label(title_row, "卡牌开发工作台")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	_button(title_row, "返回主菜单", func(): exit_requested.emit()).size_flags_horizontal = Control.SIZE_SHRINK_END
	var tabs := _row(header)
	var names := ["模型", "实战", "音频与信息"]
	for i in names.size():
		var button := _button(tabs, names[i], show_workspace.bind(i))
		button.toggle_mode = true
		_tabs.append(button)
	var choose := _row(header)
	_choose_button = _button(choose, "选择模型", func(): _show_library(not _library_open))
	_team_button = _button(choose, "蓝方", func(): _on_team_toggled(_team == 0))
	_team_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var summary := _row(header)
	_art = TextureRect.new()
	_art.custom_minimum_size = Vector2(45, 62)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	summary.add_child(_art)
	_selection_label = _label(summary, "")
	_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_option = OptionButton.new()
	_form_option.add_item("基础形态")
	_form_option.add_item("变形形态")
	_form_option.item_selected.connect(func(index): _select_item(_selected_id + (":1" if index == 1 else "")))
	summary.add_child(_form_option)
	var shelf := _panel(layout)
	_shelf_panel = shelf.get_parent().get_parent()
	var shelf_title := _row(shelf)
	_quick_hint = _label(shelf_title, "实验快捷栏 · 0/8", true)
	_quick_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(shelf_title, "清空快捷栏", func(): set_quick_cards([])).size_flags_horizontal = Control.SIZE_SHRINK_END
	_quick_grid = GridContainer.new()
	_quick_grid.columns = 4
	_quick_grid.add_theme_constant_override("h_separation", 8)
	_quick_grid.add_theme_constant_override("v_separation", 8)
	shelf.add_child(_quick_grid)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)
	for i in names.size():
		var page := VBoxContainer.new()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("separation", 12)
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(page)
		_pages.append(page)
	_build_model_page(_pages[0])
	_preview.reparent(root)
	_preview.position = DESKTOP.FIELD_RECT.position
	_preview.size = DESKTOP.FIELD_RECT.size
	_build_battle_page(_pages[1])
	_audio_surface = Control.new()
	_audio_surface.position = DESKTOP.FIELD_RECT.position
	_audio_surface.size = DESKTOP.FIELD_RECT.size
	root.add_child(_audio_surface)
	var audio_bg := ColorRect.new()
	audio_bg.color = Color("0b1320")
	audio_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_audio_surface.add_child(audio_bg)
	_audio_right = VBoxContainer.new()
	_audio_right.set_anchors_preset(Control.PRESET_FULL_RECT)
	_audio_right.add_theme_constant_override("separation", 12)
	_audio_surface.add_child(_audio_right)
	_build_audio_page(_pages[2])
	_library_overlay = Control.new()
	_library_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_library_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.75)
	_library_overlay.add_child(shade)
	var dialog := PanelContainer.new()
	dialog.position = Vector2(64, 64)
	dialog.size = Vector2(1312, 872)
	dialog.add_theme_stylebox_override("panel", CardArt.frame_style(Color("172537"), Color("405570"), 2, 12))
	_library_overlay.add_child(dialog)
	var padding := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: padding.add_theme_constant_override("margin_" + edge, 16)
	dialog.add_child(padding)
	_library = LIBRARY.new()
	padding.add_child(_library)
	_library.setup(_cards)
	_search = _library.search
	_library.selected.connect(func(id):
		_select_item(id)
		_show_library(false))
	_library.toggled.connect(_toggle_quick_card)
	_library.closed.connect(func(): _show_library(false))
	_library_overlay.hide()
	_refresh_quick_cards()
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_audio_player.finished.connect(func():
		_audio_status.text = "播放结束 · 可选择其他变体"
		_audio_timeline.set_value_no_signal(_audio_timeline.max_value)
		_audio_time.text = "%.2f / %.2f s" % [_audio_timeline.max_value, _audio_timeline.max_value])

func _build_model_page(page: Control) -> void:
	_model_hint = _label(page, "独立素材观察 · 真实动作衔接请到实战区检查", true)
	_preview = WorkbenchModelPreview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size.y = 250
	page.add_child(_preview)
	var controls := _panel(page)
	controls.get_parent().get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_animation_option = preload("res://scripts/ui/workbench/animation_picker.gd").new()
	_animation_option.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_animation_option.item_selected.connect(_play_animation)
	controls.add_child(_animation_option)
	var transport := _row(controls)
	_button(transport, "重播", func(): _play_animation(_animation_option.selected))
	_button(transport, "暂停", func(): _preview.set_playing(false))
	_button(transport, "继续", func(): _preview.set_playing(true))
	_timeline = HSlider.new()
	_timeline.step = 0.001
	_timeline.value_changed.connect(func(value): _preview.seek_seconds(value))
	controls.add_child(_timeline)
	_time_label = _label(controls, "0.00 / 0.00 s", true)
	var view := _row(controls)
	_label(view, "旋转", true).custom_minimum_size.x = 40
	_rotation = HSlider.new()
	_rotation.min_value = -180
	_rotation.max_value = 180
	_rotation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rotation.value_changed.connect(func(value): _preview.set_model_yaw(value))
	view.add_child(_rotation)
	_label(view, "缩放", true).custom_minimum_size.x = 40
	_zoom = HSlider.new()
	_zoom.min_value = 0.4
	_zoom.max_value = 2.5
	_zoom.step = 0.01
	_zoom.value = 1
	_zoom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom.value_changed.connect(func(value): _preview.set_zoom(value))
	view.add_child(_zoom)
	_button(view, "复位", _reset_camera).size_flags_horizontal = Control.SIZE_SHRINK_END

func _build_battle_page(page: Control) -> void:
	page.add_theme_constant_override("separation", 6)
	var tools := _row(page)
	_button(tools, "木桩", func(): _select_item("training_dummy"))
	_button(tools, "清场", func(): clear_requested.emit())
	_pause_button = _button(tools, "暂停", func():
		_battle_paused = not _battle_paused
		_pause_button.text = "继续" if _battle_paused else "暂停"
		workspace_changed.emit(_workspace == 1 and not _battle_paused))
	_button(tools, "复位", func(): _set_battle_zoom(1.0)).tooltip_text = "地图复位到 100%"
	_select_mode_button = _button(tools, "放置", func(): set_select_mode(not _select_mode))
	_select_mode_button.toggle_mode = true
	_select_mode_button.tooltip_text = "点击切换放置 / 选择模式"
	_mode_label = _label(page, "", true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_theme_constant_override("separation", 6)
	_inspection_controls = _panel(body, true)
	_label(_inspection_controls, "技能控制板")
	_unit_status_label = _label(_inspection_controls, "未选中单位 · 切到选择模式后点击地图单位", true)
	_spell_active = CheckButton.new()
	_spell_active.text = "强化法术"
	_spell_active.toggled.connect(func(enabled): spell_active_changed.emit(enabled))
	_inspection_controls.add_child(_spell_active)
	_spell_choice = OptionButton.new()
	_spell_choice.item_selected.connect(func(index): active_skill_selected.emit(_selected_id, index))
	_inspection_controls.add_child(_spell_choice)
	var skills := _row(_inspection_controls)
	_skill_option = OptionButton.new()
	_skill_option.fit_to_longest_item = false
	_skill_option.clip_text = true
	_skill_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_option.item_selected.connect(_on_skill_option_selected)
	skills.add_child(_skill_option)
	_skill_button = _button(skills, "释放所选技能", _on_active_skill_pressed)
	_skill_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_skill_scope = _label(_inspection_controls, "控制仅作用于选中成员；技能按原卡规则执行", true)
	_resource_controls = _row(_inspection_controls)
	_label(_resource_controls, "技能资源", true).autowrap_mode = TextServer.AUTOWRAP_OFF
	_resource_slider = HSlider.new()
	_resource_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_slider.value_changed.connect(_on_resource_value_changed)
	_resource_controls.add_child(_resource_slider)
	_resource_value_label = _label(_resource_controls, "", true)
	_resource_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_button(_resource_controls, "清零", func(): _request_resource_value(0)).size_flags_horizontal = Control.SIZE_SHRINK_END
	_button(_resource_controls, "充满", func(): _request_resource_value(_resource_max)).size_flags_horizontal = Control.SIZE_SHRINK_END
	var scene_controls := _panel(body, true)
	var scene_title := _row(scene_controls)
	_label(scene_title, "场景控制板").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_label = _label(scene_title, "100%", true)
	_zoom_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_zoom_label.tooltip_text = "地图滚轮缩放 · 右键 / 中键拖动"
	var presets := _row(scene_controls)
	_preset_row = presets
	_scenario_option = OptionButton.new()
	_scenario_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for preset in SCENARIOS.PRESETS:
		_scenario_option.add_item(preset.name)
	presets.add_child(_scenario_option)
	_preset_button = _button(presets, "重建场景", func(): scenario_requested.emit("preset:" + String(SCENARIOS.PRESETS[_scenario_option.selected].id)))
	_scenario_hint = _label(scene_controls, "", true)
	_scenario_option.item_selected.connect(func(index): _scenario_hint.text = SCENARIOS.PRESETS[index].hint + " 重建会清空上一轮。")
	_scenario_option.item_selected.emit(0)
	var effects := _panel(body, true)
	_label(effects, "控制技能控制板")
	effects.tooltip_text = "仅作用于地图上选中的单位"
	var control := _row(effects)
	for entry in [["冰冻 2s", "freeze"], ["眩晕 2s", "stun"], ["减速 3s", "slow"], ["减攻速 3s", "attack_slow"], ["死亡", "death"]]:
		_control_buttons.append(_button(control, entry[0], func(): scenario_requested.emit(entry[1])))
	_compact_battle_controls(page)
	set_select_mode(false)

func _compact_battle_controls(node: Node) -> void:
	if node is Button:
		node.custom_minimum_size.y = 32
	if node is Label:
		node.add_theme_font_size_override("font_size", 16)
	for child in node.get_children():
		_compact_battle_controls(child)

func _build_audio_page(page: Control) -> void:
	_label(page, "逐个检查声音与变体")
	_label(page, "这里播放配置文件；真实出手、命中、控制中断和持续声叠加请在实战区试听。切页或换卡自动停止试听。", true)
	_audio_cue = OptionButton.new()
	_audio_cue.fit_to_longest_item = false
	_audio_cue.custom_minimum_size.y = 44
	_audio_cue.item_selected.connect(_filter_audio)
	page.add_child(_audio_cue)
	_audio_list = ItemList.new()
	_audio_list.add_theme_constant_override("v_separation", 12)
	_audio_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_audio_list.item_activated.connect(func(index): _play_audio(int(_audio_list.get_item_metadata(index))))
	_audio_list.item_selected.connect(func(index):
		var entry: Dictionary = _audio_entries[int(_audio_list.get_item_metadata(index))]
		_audio_status.text = "%s · %.2fs · %s · %.1f dB\n%s" % [entry.cue, entry.duration, entry.bus, entry.volume, entry.path])
	page.add_child(_audio_list)
	var transport := _panel(page)
	var row := _row(transport)
	_button(row, "播放选中", func():
		var selected := _audio_list.get_selected_items()
		if not selected.is_empty(): _play_audio(int(_audio_list.get_item_metadata(selected[0]))))
	_button(row, "暂停 / 继续", func(): _audio_player.stream_paused = not _audio_player.stream_paused)
	_button(row, "停止", _stop_audio)
	_audio_timeline = HSlider.new()
	_audio_timeline.step = 0.01
	_audio_timeline.value_changed.connect(func(value):
		if _audio_player.playing: _audio_player.seek(value))
	transport.add_child(_audio_timeline)
	_audio_time = _label(transport, "0.00 / 0.00 s", true)
	_audio_status = _label(transport, "选择一条声音；双击直接播放。", true)
	_card_info = preload("res://scripts/ui/workbench/card_info.gd").new()
	_card_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_audio_right.add_child(_card_info)

func _filter_cards(query: String) -> void:
	_library.filter(query)

func enable_desktop_layout() -> void:
	_desktop = DESKTOP.new()
	_desktop.install(get_window())
	_persist = true
	_load_quick_cards()

func _load_quick_cards() -> void:
	var config := ConfigFile.new()
	if config.load(_preferences_path) == OK:
		var saved = config.get_value("experiment", "cards", [])
		if saved is Array: set_quick_cards(saved)
	if not _quick_cards.is_empty(): _select_item(_quick_cards[0])
	else: _refresh_quick_cards()

func _exit_tree() -> void:
	if _desktop != null: _desktop.restore()

func set_quick_cards(ids: Array) -> void:
	_quick_cards.clear()
	var allowed := {}
	for entry in preload("res://scripts/ui/workbench/card_catalog.gd").entries(_cards):
		if entry.id != "training_dummy": allowed[entry.id] = true
	for id in ids:
		if id is String and allowed.has(id) and id not in _quick_cards:
			_quick_cards.append(id)
		if _quick_cards.size() == 8: break
	_refresh_quick_cards()
	if _library != null: _library.update_shelf(_quick_cards)
	if _persist:
		var config := ConfigFile.new()
		config.set_value("experiment", "cards", _quick_cards)
		if config.save(_preferences_path) != OK: push_warning("工作台快捷栏保存失败")

func _toggle_quick_card(id: String) -> void:
	var ids := _quick_cards.duplicate()
	if id in ids: ids.erase(id)
	elif ids.size() < 8: ids.append(id)
	set_quick_cards(ids)

func _refresh_quick_cards() -> void:
	if _quick_grid == null: return
	for child in _quick_grid.get_children():
		_quick_grid.remove_child(child)
		child.queue_free()
	var current := _selected_id + (":1" if _form == 1 else "")
	_quick_hint.text = "实验快捷栏 %d/8 · 1–8 切卡 · 双方共用" % _quick_cards.size()
	for i in 8:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 48)
		button.clip_text = true
		_quick_grid.add_child(button)
		if i >= _quick_cards.size():
			button.text = "%d  ＋ 选牌" % (i + 1)
			button.pressed.connect(func(): _show_library(true))
		else:
			var id := _quick_cards[i]
			var base_id := id.get_slice(":", 0)
			var stats := PresentationConfig.for_form(_cards.get(base_id, {}), 1 if id.ends_with(":1") else 0)
			button.text = "%d  %s" % [i + 1, stats.get("name", "训练木桩")]
			button.icon = CardArt.texture_for(base_id)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 36)
			button.toggle_mode = true
			button.button_pressed = id == current
			button.add_theme_stylebox_override("pressed", CardArt.frame_style(Color("214866"), Color("72ceff"), 2))
			button.tooltip_text = "点击或按 %d 选择；到牌库可移除" % (i + 1)
			button.pressed.connect(func(): _select_item(id))
	if _selected_id != "training_dummy" and current not in _quick_cards:
		_quick_hint.text = "实验快捷栏 · %d/8 · 当前对象未入栏，请选卡后放置" % _quick_cards.size()
	if _preset_button != null: _preset_button.disabled = not has_placeable_selection()
	_refresh_mode_label()

func has_placeable_selection() -> bool:
	return not _select_mode and (_selected_id == "training_dummy" or (_selected_id + (":1" if _form == 1 else "")) in _quick_cards)

func _show_library(open: bool) -> void:
	_library_open = open
	_library_overlay.visible = open
	if open:
		_library.configure(_workspace == 1, _workspace == 0)
		_search.grab_focus()
	else: _search.release_focus()
	workspace_changed.emit(_workspace == 1 and not open and not _battle_paused)

func set_select_mode(value: bool) -> void:
	_select_mode = value
	_select_mode_button.text = "选择" if value else "放置"
	_select_mode_button.set_pressed_no_signal(value)
	_refresh_quick_cards()

func is_select_mode() -> bool:
	return _select_mode

func _refresh_mode_label() -> void:
	if _mode_label == null: return
	var title := String(PresentationConfig.for_form(_cards.get(_selected_id, {}), _form).get("name", "训练木桩"))
	_mode_label.text = ("选择模式" if _select_mode else "放置模式") + " · 待放置：" + title + (" · 蓝方" if _team == 0 else " · 红方")

func _refresh_page_chrome() -> void:
	_shelf_panel.visible = _workspace == 1
	_choose_button.text = "选择实验卡 · 编辑 0–8 槽" if _workspace == 1 else "选择模型 / 对象"
	_preset_row.visible = true
	_scenario_hint.visible = true
	_audio_surface.visible = _workspace == 2
	_preview.visible = _workspace == 0

func _input(event: InputEvent) -> void:
	if _library_open:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_show_library(false)
			get_viewport().set_input_as_handled()
		return
	if _workspace == 1 and _desktop != null:
		if event is InputEventMouse and DESKTOP.FIELD_RECT.has_point(event.position):
			if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				_desktop.zoom_at(_desktop.zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), event.position)
				_zoom_label.text = "%d%%" % roundi(_desktop.zoom * 100)
				get_viewport().set_input_as_handled()
				return
			if event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
				_desktop.pan(event.relative)
				get_viewport().set_input_as_handled()
				return
	if _workspace != 1: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	var index: int = event.keycode - KEY_1
	if index >= 0 and index < _quick_cards.size():
		_select_item(_quick_cards[index])
		get_viewport().set_input_as_handled()

func _set_battle_zoom(value: float) -> void:
	if _desktop == null: return
	_desktop.center(value)
	_zoom_label.text = "%d%%" % roundi(_desktop.zoom * 100)

func _select_item(item_id: String) -> void:
	var requested_form := 1 if item_id.ends_with(":1") else 0
	item_id = item_id.get_slice(":", 0)
	if item_id != "training_dummy" and not _cards.has(item_id): return
	_selected_id = item_id
	_form = requested_form
	_spell_active.set_pressed_no_signal(false)
	var is_spell := String(_cards.get(item_id, {}).get("type", "")) == "spell"
	var has_spell_choices := is_spell and not CardDB.active_skills_for(item_id).is_empty()
	_spell_active.visible = is_spell and not has_spell_choices and _cards.get(item_id, {}).has("active_name")
	_spell_active.text = String(_cards.get(item_id, {}).get("active_name", "强化法术"))
	_spell_choice.clear()
	for skill in CardDB.active_skills_for(item_id): _spell_choice.add_item(String(skill.get("name", "强化法术")))
	_spell_choice.visible = has_spell_choices
	_form_option.select(_form)
	_form_option.disabled = not _cards.get(item_id, {}).has("transformed_stats")
	_selection_label.text = "%s\n%s" % [String(PresentationConfig.for_form(_cards.get(item_id, {}), _form).get("name", "训练木桩")), item_id]
	_art.texture = CardArt.texture_for(item_id)
	_refresh_quick_cards()
	_unit_available = false
	_unit_deployed = false
	_unit_casting = false
	_refresh_skill_controls()
	if not _inspection_bound:
		_skill_option.get_parent().visible = not is_spell or has_spell_choices
		_skill_button.visible = not is_spell
		_control_buttons[0].get_parent().visible = not is_spell
	_refresh_assets()
	item_selected.emit(item_id)
	form_selected.emit(_form)

func _refresh_assets() -> void:
	_card_info.show_card(_selected_id, PresentationConfig.for_form(_cards.get(_selected_id, {}), _form))
	_stop_audio()
	_form_option.select(_form)
	var stats := PresentationConfig.for_form(_cards.get(_selected_id, {}), _form)
	var clips := _preview.show_definition(stats, _team)
	_animation_option.clear()
	var mappings: Dictionary = {}
	_collect_mappings(stats.get("visual_animations", {}), "", mappings)
	for clip in clips:
		_animation_option.add_item("%s · %.2fs · %s" % [clip, _preview.player.get_animation(clip).length, ("已接入 " + String(mappings[clip])) if mappings.has(String(clip)) else "未使用"])
		_animation_option.set_item_metadata(_animation_option.item_count - 1, clip)
		_animation_option.set_item_mapped(_animation_option.item_count - 1, mappings.has(String(clip)))
	_animation_option.disabled = clips.is_empty()
	_model_hint.text = "无 3D 模型 · 法术请在实战区检查效果" if _preview.model == null else "独立素材观察 · %d 个片段 · 真实衔接请到实战区" % clips.size()
	_reset_camera()
	_timeline.max_value = 0.01
	_timeline.value = 0
	_time_label.text = "未选择动画"
	_timeline.editable = not clips.is_empty()
	if not clips.is_empty():
		var idle := String(stats.get("visual_animations", {}).get("idle", ""))
		var index := maxi(clips.find(idle), 0)
		_animation_option.select(index)
		_play_animation(index)
	_refresh_audio(PresentationConfig.audio_for(stats, _team))
	_preview.set_preview_active(_workspace == 0)

func _collect_mappings(value: Variant, path: String, output: Dictionary) -> void:
	if value is Dictionary:
		for key in value: _collect_mappings(value[key], path + "/" + String(key), output)
	elif value is Array:
		for i in value.size(): _collect_mappings(value[i], path + "[%d]" % i, output)
	elif value is String or value is StringName:
		output[String(value)] = String(output.get(String(value), "")) + (", " if output.has(String(value)) else "") + path.trim_prefix("/")

func _play_animation(index: int) -> void:
	if index < 0 or index >= _animation_option.item_count: return
	_preview.play_clip(String(_animation_option.get_item_metadata(index)))
	_timeline.max_value = _preview.player.current_animation_length

func _reset_camera() -> void:
	_rotation.set_value_no_signal(0)
	_zoom.set_value_no_signal(1)
	_preview.set_model_yaw(0)
	_preview.set_zoom(1)

func _refresh_audio(audio: Dictionary) -> void:
	_audio_entries.clear()
	_audio_list.clear()
	_audio_entries.assign(WorkbenchAudioCatalog.collect(audio))
	for entry in _audio_entries:
		var stream := load(String(entry.path)) as AudioStream if ResourceLoader.exists(entry.path) else null
		entry["duration"] = stream.get_length() if stream != null else 0.0
	_audio_cue.clear()
	_audio_cue.add_item("全部事件")
	var cues: Array[String] = []
	for entry in _audio_entries:
		if String(entry.cue) not in cues: cues.append(String(entry.cue))
	for cue in cues: _audio_cue.add_item(cue)
	_audio_cue.disabled = cues.is_empty()
	_filter_audio(0)
	_audio_status.text = "未配置音频 · 当前对象没有可试听的声音。" if _audio_entries.is_empty() else "%d 个文件变体 · 选择后播放" % _audio_entries.size()


func _filter_audio(index: int) -> void:
	_audio_list.clear()
	var cue := _audio_cue.get_item_text(index) if index > 0 else ""
	for i in _audio_entries.size():
		var entry := _audio_entries[i]
		if not cue.is_empty() and String(entry.cue) != cue: continue
		_audio_list.add_item("%s · %.2fs · %s" % [entry.cue, entry.duration, String(entry.path).get_file()])
		_audio_list.set_item_metadata(_audio_list.item_count - 1, i)
		_audio_list.set_item_tooltip(_audio_list.item_count - 1, entry.path)
	if _audio_list.item_count > 0: _audio_list.select(0)

func _play_audio(index: int) -> void:
	_stop_audio()
	if index < 0 or index >= _audio_entries.size(): return
	var entry := _audio_entries[index]
	if not ResourceLoader.exists(entry.path):
		_audio_status.text = "缺失文件：" + String(entry.path)
		return
	_audio_player.stream = load(entry.path) as AudioStream
	if _audio_player.stream == null: return
	_audio_player.bus = StringName(entry.bus)
	_audio_player.volume_db = float(entry.volume)
	_audio_player.play()
	_audio_timeline.max_value = maxf(_audio_player.stream.get_length(), 0.01)
	_audio_status.text = "%s · %s · %.1f dB\n%s" % [entry.cue, entry.bus, entry.volume, entry.path]

func _stop_audio() -> void:
	if _audio_player == null: return
	_audio_player.stop()
	_audio_player.stream_paused = false
	_audio_player.stream = null
	_audio_timeline.set_value_no_signal(0)
	_audio_status.text = "试听已停止"
	_audio_time.text = "0.00 / 0.00 s"

func accepts_battle_input() -> bool:
	return _workspace == 1 and not _library_open

func show_workspace(index: int) -> void:
	_workspace = clampi(index, 0, _pages.size() - 1)
	for i in _pages.size():
		_pages[i].visible = i == _workspace
		_tabs[i].set_pressed_no_signal(i == _workspace)
	_refresh_page_chrome()
	_background.visible = true
	_show_library(false)
	_form_option.visible = true
	_form_option.disabled = not _cards.get(_selected_id, {}).has("transformed_stats")
	_preview.visible = _workspace == 0
	_preview.set_preview_active(_workspace == 0)
	_stop_audio()
	if _workspace == 2:
		_audio_status.text = "未配置音频 · 当前对象没有可试听的声音。" if _audio_entries.is_empty() else "%d 个文件变体 · 按事件筛选，双击试听" % _audio_entries.size()
	workspace_changed.emit(_workspace == 1 and not _battle_paused)

func _process(_delta: float) -> void:
	if _workspace == 0 and _preview.player != null and not _preview.player.assigned_animation.is_empty():
		var position := _preview.player.current_animation_position
		_timeline.set_value_no_signal(position)
		_time_label.text = "%.2f / %.2f s · 拖动时间轴暂停定位" % [position, _timeline.max_value]
	if _audio_player.playing:
		_audio_timeline.set_value_no_signal(_audio_player.get_playback_position())
		_audio_time.text = "%.2f / %.2f s" % [_audio_player.get_playback_position(), _audio_timeline.max_value]

var _mirror_source := ""
var _mirror_skill_enabled := false

var _growth_skill_source := ""

func _skill_source() -> String:
	if _inspection_bound: return _inspection_source
	if not _growth_skill_source.is_empty() and CardDB.get_card(_selected_id).has("growth_ranged_id"): return _growth_skill_source
	return _mirror_source if CardPlayHistory.is_mirror(_selected_id) else _selected_id

func set_mirror_source(source: String, enabled: bool) -> void:
	if _mirror_source != source or _mirror_skill_enabled != enabled:
		_mirror_source = source
		_mirror_skill_enabled = enabled
		_refresh_skill_controls()
	_skill_option.get_parent().visible = enabled
	_skill_button.visible = enabled
	_control_buttons[0].get_parent().visible = enabled

func _refresh_skill_controls() -> void:
	var skills: Array[Dictionary] = []
	if not _skill_source().is_empty() and _skill_source() != "training_dummy":
		skills = CardDB.active_skills_for(_skill_source())
	_skill_option.clear()
	for skill in skills:
		_skill_option.add_item(String((skill as Dictionary).get("name", "主动技能")))
	var selected_index := 0
	if not skills.is_empty():
		selected_index = clampi(int(_active_skill_choices.get(_skill_source(), 0)), 0, skills.size() - 1)
		_active_skill_choices[_skill_source()] = selected_index
		_skill_option.select(selected_index)
	_skill_option.disabled = skills.is_empty()
	_update_resource_config(skills[selected_index] if not skills.is_empty() else {})
	_update_scope(skills[selected_index] if not skills.is_empty() else {})
	_update_action_state(not skills.is_empty())

func _on_skill_option_selected(skill_index: int) -> void:
	var skills := CardDB.active_skills_for(_skill_source())
	if skills.is_empty():
		return
	var selected_index := clampi(skill_index, 0, skills.size() - 1)
	_active_skill_choices[_skill_source()] = selected_index
	_update_resource_config(skills[selected_index])
	_update_scope(skills[selected_index])
	active_skill_selected.emit(_skill_source(), selected_index)

func selected_skill_index() -> int:
	var skills := CardDB.active_skills_for(_skill_source())
	return clampi(int(_active_skill_choices.get(_skill_source(), 0)), 0, skills.size() - 1) if not skills.is_empty() else -1

func _on_active_skill_pressed() -> void:
	var skill_index := selected_skill_index()
	if skill_index >= 0:
		active_skill_requested.emit(skill_index)

func _update_resource_config(skill: Dictionary) -> void:
	var stats: Dictionary = _cards.get(_skill_source(), {})
	_resource_max = maxf(float(stats.get("skill_resource_max", 0.0)), 0.0)
	_resource_supported = bool(skill.get("uses_skill_resource", false)) and _resource_max > 0.0
	_resource_controls.visible = _resource_supported
	_resource_slider.max_value = maxf(_resource_max, 1.0)
	_resource_slider.step = 1.0
	_resource_slider.set_value_no_signal(0.0)
	_resource_slider.editable = _resource_supported and _unit_available
	_resource_value_label.text = "0/%s" % _format_number(_resource_max)

func update_selected_unit_state(available: bool, deployed: bool, casting: bool, resource_enabled: bool, resource_value: float, resource_max: float) -> void:
	_unit_available = available
	_unit_deployed = deployed
	_unit_casting = casting
	for button in _control_buttons: button.disabled = not available
	if not available:
		_unit_status_label.text = "未选中存活单位 · 切到选择模式点击单位；死亡后不会转移目标"
	elif not deployed:
		_unit_status_label.text = "部署中"
	elif casting:
		_unit_status_label.text = "技能播放中"
	else:
		_unit_status_label.text = "当前对象：最后放置的同卡、同阵营单位"
	var has_skill := _skill_option.item_count > 0
	_update_action_state(has_skill)
	if _resource_supported:
		_resource_max = maxf(resource_max, _resource_max)
		_resource_slider.max_value = maxf(_resource_max, 1.0)
		_resource_slider.editable = available and resource_enabled
		_resource_slider.set_value_no_signal(clampf(resource_value, 0.0, _resource_max))
		_resource_value_label.text = "%s/%s" % [_format_number(resource_value), _format_number(_resource_max)]

func _update_action_state(has_skill: bool) -> void:
	_skill_button.disabled = not has_skill or not _unit_available or not _unit_deployed or _unit_casting

func _on_resource_value_changed(value: float) -> void:
	if _resource_supported and _unit_available:
		skill_resource_requested.emit(value)

func _request_resource_value(value: float) -> void:
	if not _resource_supported or not _unit_available:
		return
	_resource_slider.set_value_no_signal(clampf(value, 0.0, _resource_max))
	skill_resource_requested.emit(_resource_slider.value)

func _on_team_toggled(pressed: bool) -> void:
	_team = 1 if pressed else 0
	_unit_available = false
	_unit_deployed = false
	_unit_casting = false
	_update_team_text()
	_refresh_skill_controls()
	_refresh_assets()
	_refresh_mode_label()
	team_changed.emit(_team)

func _update_team_text() -> void:
	_team_button.text = "红方" if _team == 1 else "蓝方"

func _format_number(value: float) -> String:
	return BattleNumbers.format_value(value)

func update_live_details(unit: Unit) -> void:
	var source := unit.card_id if not _inspection_bound and is_instance_valid(unit) and CardDB.get_card(_selected_id).has("growth_ranged_id") else ""
	if source != _growth_skill_source:
		_growth_skill_source = source
		_refresh_skill_controls()
	if unit == null or not is_instance_valid(unit): return
	var state := unit.presentation_state()
	var tags: Array[String] = []
	if state.frozen: tags.append("冰冻")
	if state.stunned: tags.append("眩晕")
	var action: String = String(state.action) if not state.action.is_empty() else ["部署", "待机", "移动", "攻击"][clampi(state.behavior, 0, 3)]
	_unit_status_label.text = "%s · %s · 批次 %d\nHP %.0f/%.0f · %s · 攻击 #%d · %.2fs · ×%.2f · %s" % [CardDB.get_card(unit.card_id).get("name", "训练木桩"), "蓝方" if unit.team == 0 else "红方", unit.deployment_group_id, unit.hp, unit.max_hp, action, state.attack_serial, state.attack_elapsed, state.attack_rate, " / ".join(tags) if not tags.is_empty() else "无冰冻/眩晕"]
	_skill_button.disabled = _skill_button.disabled or state.frozen or state.stunned

func bind_inspected_unit(unit: Unit, source: String) -> void:
	var changed := not _inspection_bound or source != _inspection_source
	_inspection_bound = true
	_inspection_source = source
	if changed: _refresh_skill_controls()
	_skill_option.get_parent().visible = true
	_skill_button.visible = true
	_control_buttons[0].get_parent().visible = true

func _update_scope(skill: Dictionary) -> void:
	if _skill_scope == null: return
	_skill_scope.text = "控制：仅选中成员 · 技能：" + ("同次部署整组存活成员" if String(skill.get("target_scope", "self")) == "deployment_group" else "选中单位施放，按技能规则命中")
