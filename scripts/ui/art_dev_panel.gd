class_name ArtDevPanel
extends CanvasLayer
## 美术检查工作台：底栏只保留训练木桩与 8 张测试卡；完整卡池按需展开编辑。

signal item_selected(item_id: String)
signal team_changed(team: int)
signal active_skill_selected(item_id: String, skill_index: int)
signal active_skill_requested(skill_index: int)
signal skill_resource_requested(value: float)
signal clear_requested
signal exit_requested

const LOADOUT_SIZE := 8
const DOCK_HEIGHT := 240.0

var _selected_id := "training_dummy"
var _team := 1
var _cards: Dictionary = {}
var _test_card_ids: Array[String] = []
var _active_skill_choices: Dictionary = {}
var _loadout_buttons: Array[Button] = []
var _pool_buttons: Dictionary = {}

var _selection_label: Label
var _team_button: Button
var _edit_button: Button
var _dummy_button: Button
var _skill_option: OptionButton
var _skill_button: Button
var _unit_status_label: Label
var _resource_controls: HBoxContainer
var _resource_slider: HSlider
var _resource_value_label: Label
var _resource_max := 0.0
var _resource_supported := false
var _unit_available := false
var _unit_deployed := false
var _unit_casting := false

var _picker_panel: PanelContainer
var _picker_count_label: Label
var _picker_hint_label: Label
var _picker_done_button: Button

func setup(cards: Dictionary, initial_card_ids: Array = []) -> void:
	layer = 30
	_cards = cards.duplicate(true)
	_test_card_ids = _normalized_initial_loadout(initial_card_ids)
	_build_ui()
	_refresh_loadout_buttons()
	_refresh_picker_buttons()
	_select_item(_selected_id)
	team_changed.emit(_team)

func _normalized_initial_loadout(initial_card_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_id in initial_card_ids:
		var card_id := String(raw_id)
		if _cards.has(card_id) and card_id not in result:
			result.append(card_id)
		if result.size() >= LOADOUT_SIZE:
			return result
	var fallback_ids: Array = _cards.keys()
	fallback_ids.sort()
	for raw_id in fallback_ids:
		var card_id := String(raw_id)
		if bool((_cards[card_id] as Dictionary).get("selectable", true)) and card_id not in result:
			result.append(card_id)
		if result.size() >= LOADOUT_SIZE:
			break
	return result

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_bottom_dock(root)
	_build_card_picker(root)

func _build_bottom_dock(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(0.0, DOCK_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	rows.add_child(tools)
	_selection_label = Label.new()
	_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tools.add_child(_selection_label)
	_team_button = Button.new()
	_team_button.toggle_mode = true
	_team_button.button_pressed = true
	_team_button.custom_minimum_size = Vector2(82.0, 32.0)
	_team_button.toggled.connect(_on_team_toggled)
	tools.add_child(_team_button)
	_update_team_text()
	_edit_button = Button.new()
	_edit_button.text = "编辑测试卡"
	_edit_button.custom_minimum_size = Vector2(104.0, 32.0)
	_edit_button.pressed.connect(_toggle_card_picker)
	tools.add_child(_edit_button)
	var clear_button := Button.new()
	clear_button.text = "清空场景"
	clear_button.pressed.connect(func(): clear_requested.emit())
	tools.add_child(clear_button)
	var exit_button := Button.new()
	exit_button.text = "返回"
	exit_button.pressed.connect(func(): exit_requested.emit())
	tools.add_child(exit_button)

	var active_row := HBoxContainer.new()
	active_row.add_theme_constant_override("separation", 6)
	rows.add_child(active_row)
	var active_label := Label.new()
	active_label.text = "主动技能"
	active_row.add_child(active_label)
	_skill_option = OptionButton.new()
	_skill_option.custom_minimum_size = Vector2(164.0, 32.0)
	_skill_option.item_selected.connect(_on_skill_option_selected)
	active_row.add_child(_skill_option)
	_skill_button = Button.new()
	_skill_button.text = "播放技能"
	_skill_button.custom_minimum_size = Vector2(96.0, 32.0)
	_skill_button.pressed.connect(_on_active_skill_pressed)
	active_row.add_child(_skill_button)
	_unit_status_label = Label.new()
	_unit_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unit_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_unit_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	active_row.add_child(_unit_status_label)

	_resource_controls = HBoxContainer.new()
	_resource_controls.add_theme_constant_override("separation", 6)
	rows.add_child(_resource_controls)
	var resource_label := Label.new()
	resource_label.text = "资源"
	_resource_controls.add_child(resource_label)
	_resource_slider = HSlider.new()
	_resource_slider.min_value = 0.0
	_resource_slider.max_value = 1.0
	_resource_slider.step = 1.0
	_resource_slider.custom_minimum_size = Vector2(220.0, 0.0)
	_resource_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_slider.value_changed.connect(_on_resource_value_changed)
	_resource_controls.add_child(_resource_slider)
	_resource_value_label = Label.new()
	_resource_value_label.custom_minimum_size = Vector2(58.0, 0.0)
	_resource_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resource_controls.add_child(_resource_value_label)
	var empty_button := Button.new()
	empty_button.text = "清零"
	empty_button.pressed.connect(func(): _request_resource_value(0.0))
	_resource_controls.add_child(empty_button)
	var full_button := Button.new()
	full_button.text = "充满"
	full_button.pressed.connect(func(): _request_resource_value(_resource_max))
	_resource_controls.add_child(full_button)

	var loadout := GridContainer.new()
	loadout.columns = 5
	loadout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout.add_theme_constant_override("h_separation", 4)
	loadout.add_theme_constant_override("v_separation", 4)
	rows.add_child(loadout)
	_dummy_button = Button.new()
	_dummy_button.text = "训练木桩\n固定"
	_dummy_button.toggle_mode = true
	_dummy_button.clip_text = true
	_dummy_button.custom_minimum_size = Vector2(132.0, 52.0)
	_dummy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dummy_button.pressed.connect(_select_item.bind("training_dummy"))
	loadout.add_child(_dummy_button)
	for index in LOADOUT_SIZE:
		var button := Button.new()
		button.toggle_mode = true
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size = Vector2(132.0, 52.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_loadout_button_pressed.bind(index))
		loadout.add_child(button)
		_loadout_buttons.append(button)

func _build_card_picker(root: Control) -> void:
	_picker_panel = PanelContainer.new()
	_picker_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_picker_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_picker_panel.offset_bottom = -DOCK_HEIGHT
	_picker_panel.custom_minimum_size = Vector2(0.0, 365.0)
	_picker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker_panel.visible = false
	root.add_child(_picker_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	_picker_panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	margin.add_child(rows)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	rows.add_child(header)
	var title := Label.new()
	title.text = "全部卡牌｜从下方 8 个卡槽移除旧卡，再从这里加入新卡"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_picker_count_label = Label.new()
	_picker_count_label.custom_minimum_size = Vector2(58.0, 0.0)
	header.add_child(_picker_count_label)
	_picker_done_button = Button.new()
	_picker_done_button.text = "完成"
	_picker_done_button.custom_minimum_size = Vector2(76.0, 32.0)
	_picker_done_button.pressed.connect(_close_card_picker)
	header.add_child(_picker_done_button)
	_picker_hint_label = Label.new()
	_picker_hint_label.text = "选满 8 张后即可关闭面板继续测试。已选卡会高亮。"
	rows.add_child(_picker_hint_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var card_ids: Array = _cards.keys()
	card_ids.sort_custom(func(a: Variant, b: Variant):
		var a_stats: Dictionary = _cards[a]
		var b_stats: Dictionary = _cards[b]
		var a_type := String(a_stats.get("type", "unit"))
		var b_type := String(b_stats.get("type", "unit"))
		var a_rank := _card_type_rank(a_type, bool(a_stats.get("selectable", true)))
		var b_rank := _card_type_rank(b_type, bool(b_stats.get("selectable", true)))
		return a_rank < b_rank if a_rank != b_rank else String(a_stats.name).naturalnocasecmp_to(String(b_stats.name)) < 0
	)
	for raw_card_id in card_ids:
		var card_id := String(raw_card_id)
		var stats: Dictionary = _cards[card_id]
		var type := String(stats.get("type", "unit"))
		var selectable := bool(stats.get("selectable", true))
		var tag := "法术" if type == "spell" else ("建筑" if type == "building" else ("单位" if selectable else "系统"))
		var button := Button.new()
		button.text = "%s\n%s" % [String(stats.name), tag]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(108.0, 54.0)
		button.tooltip_text = "%s\n%s" % [String(stats.get("description", "")), card_id]
		button.pressed.connect(_toggle_pool_card.bind(card_id))
		grid.add_child(button)
		_pool_buttons[card_id] = button

func _card_type_rank(type: String, selectable: bool) -> int:
	if type == "unit" and selectable:
		return 0
	if type == "building":
		return 1
	if type == "spell":
		return 2
	return 3

func _on_loadout_button_pressed(index: int) -> void:
	if index < 0 or index >= _test_card_ids.size():
		return
	if is_card_picker_open():
		var removed_id := _test_card_ids[index]
		_test_card_ids.remove_at(index)
		_picker_hint_label.text = "已移除%s；从全部卡牌中选一张补入。" % String((_cards[removed_id] as Dictionary).name)
		_refresh_loadout_buttons()
		_refresh_picker_buttons()
		if _selected_id == removed_id:
			_select_item("training_dummy")
		return
	_select_item(_test_card_ids[index])

func _toggle_pool_card(card_id: String) -> void:
	var existing_index := _test_card_ids.find(card_id)
	if existing_index >= 0:
		_test_card_ids.remove_at(existing_index)
		_picker_hint_label.text = "已移除%s。" % String((_cards[card_id] as Dictionary).name)
	elif _test_card_ids.size() < LOADOUT_SIZE:
		_test_card_ids.append(card_id)
		_picker_hint_label.text = "已加入%s。" % String((_cards[card_id] as Dictionary).name)
	else:
		_picker_hint_label.text = "测试卡已满；先点一张高亮卡或下方卡槽将它移除。"
	_refresh_loadout_buttons()
	_refresh_picker_buttons()

func _refresh_loadout_buttons() -> void:
	for index in _loadout_buttons.size():
		var button := _loadout_buttons[index]
		if index < _test_card_ids.size():
			var card_id := _test_card_ids[index]
			var stats: Dictionary = _cards[card_id]
			button.text = String(stats.name)
			button.tooltip_text = "%s\n%s" % [String(stats.get("description", "")), card_id]
			button.disabled = false
			button.button_pressed = card_id == _selected_id
		else:
			button.text = "+\n空卡槽"
			button.tooltip_text = "在全部卡牌面板中补入测试卡"
			button.disabled = not is_card_picker_open()
			button.button_pressed = false
	if _dummy_button != null:
		_dummy_button.button_pressed = _selected_id == "training_dummy"

func _refresh_picker_buttons() -> void:
	for raw_id in _pool_buttons:
		var card_id := String(raw_id)
		(_pool_buttons[card_id] as Button).button_pressed = card_id in _test_card_ids
	if _picker_count_label != null:
		_picker_count_label.text = "%d / %d" % [_test_card_ids.size(), LOADOUT_SIZE]
	if _picker_done_button != null:
		_picker_done_button.disabled = _test_card_ids.size() != LOADOUT_SIZE

func _toggle_card_picker() -> void:
	if is_card_picker_open():
		_close_card_picker()
	else:
		_picker_panel.show()
		_edit_button.text = "收起卡池"
		_picker_hint_label.text = "选满 8 张后即可关闭面板继续测试。已选卡会高亮。"
		_refresh_loadout_buttons()
		_refresh_picker_buttons()

func _close_card_picker() -> void:
	if _test_card_ids.size() != LOADOUT_SIZE:
		_picker_hint_label.text = "还需补满 %d 张测试卡。" % (LOADOUT_SIZE - _test_card_ids.size())
		return
	_picker_panel.hide()
	_edit_button.text = "编辑测试卡"
	_refresh_loadout_buttons()

func is_card_picker_open() -> bool:
	return _picker_panel != null and _picker_panel.visible

func get_test_card_ids() -> Array[String]:
	return _test_card_ids.duplicate()

func _select_item(item_id: String) -> void:
	if item_id != "training_dummy" and not _cards.has(item_id):
		return
	_selected_id = item_id
	if item_id == "training_dummy":
		_selection_label.text = "当前：训练木桩｜点击战场放置"
	else:
		var stats: Dictionary = _cards[item_id]
		if String(stats.get("type", "unit")) == "unit":
			_selection_label.text = "当前：%s｜体型：%s｜点击战场放置" % [stats.name, CardDB.size_tier_name(stats.get("size_tier", &""))]
		else:
			_selection_label.text = "当前：%s｜点击战场放置" % stats.name
	_unit_available = false
	_unit_deployed = false
	_unit_casting = false
	_refresh_loadout_buttons()
	_refresh_skill_controls()
	item_selected.emit(item_id)

func _refresh_skill_controls() -> void:
	var skills: Array[Dictionary] = []
	if _selected_id != "training_dummy":
		skills = CardDB.active_skills_for(_selected_id)
	_skill_option.clear()
	for skill in skills:
		_skill_option.add_item(String((skill as Dictionary).get("name", "主动技能")))
	var selected_index := 0
	if not skills.is_empty():
		selected_index = clampi(int(_active_skill_choices.get(_selected_id, 0)), 0, skills.size() - 1)
		_active_skill_choices[_selected_id] = selected_index
		_skill_option.select(selected_index)
	_skill_option.disabled = skills.is_empty()
	_update_resource_config(skills[selected_index] if not skills.is_empty() else {})
	_update_action_state(not skills.is_empty())

func _on_skill_option_selected(skill_index: int) -> void:
	var skills := CardDB.active_skills_for(_selected_id)
	if skills.is_empty():
		return
	var selected_index := clampi(skill_index, 0, skills.size() - 1)
	_active_skill_choices[_selected_id] = selected_index
	_update_resource_config(skills[selected_index])
	active_skill_selected.emit(_selected_id, selected_index)

func selected_skill_index() -> int:
	var skills := CardDB.active_skills_for(_selected_id)
	return clampi(int(_active_skill_choices.get(_selected_id, 0)), 0, skills.size() - 1) if not skills.is_empty() else -1

func _on_active_skill_pressed() -> void:
	var skill_index := selected_skill_index()
	if skill_index >= 0:
		active_skill_requested.emit(skill_index)

func _update_resource_config(skill: Dictionary) -> void:
	var stats: Dictionary = _cards.get(_selected_id, {})
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
	if not available:
		_unit_status_label.text = "先放置单位"
	elif not deployed:
		_unit_status_label.text = "部署中"
	elif casting:
		_unit_status_label.text = "技能播放中"
	else:
		_unit_status_label.text = "作用于最后放置单位"
	var has_skill := _selected_id != "training_dummy" and not CardDB.active_skills_for(_selected_id).is_empty()
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
	team_changed.emit(_team)

func _update_team_text() -> void:
	_team_button.text = "红方" if _team == 1 else "蓝方"

func _format_number(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else "%.1f" % value
