class_name ArtDevPanel
extends CanvasLayer
## 阶段 4 专用美术检查工具：选择卡牌/木桩、队伍后直接点击战场放置。

signal item_selected(item_id: String)
signal team_changed(team: int)
signal active_skill_requested
signal clear_requested
signal exit_requested

var _selected_id := "training_dummy"
var _team := 1
var _item_buttons: Dictionary = {}
var _team_button: Button
var _selection_label: Label
var _skill_button: Button

func setup(cards: Dictionary) -> void:
	layer = 30
	_build_ui(cards)
	_select_item(_selected_id)
	team_changed.emit(_team)

func _build_ui(cards: Dictionary) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(0.0, 158.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	panel.add_child(rows)

	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 8)
	rows.add_child(tools)
	_selection_label = Label.new()
	_selection_label.custom_minimum_size = Vector2(230.0, 0.0)
	tools.add_child(_selection_label)

	_team_button = Button.new()
	_team_button.toggle_mode = true
	_team_button.button_pressed = true
	_team_button.custom_minimum_size = Vector2(110.0, 34.0)
	_team_button.toggled.connect(_on_team_toggled)
	tools.add_child(_team_button)
	_update_team_text()

	var clear_button := Button.new()
	clear_button.text = "清空单位"
	clear_button.pressed.connect(func(): clear_requested.emit())
	tools.add_child(clear_button)
	var exit_button := Button.new()
	exit_button.text = "返回主菜单"
	exit_button.pressed.connect(func(): exit_requested.emit())
	tools.add_child(exit_button)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	rows.add_child(actions)
	_skill_button = Button.new()
	_skill_button.text = "释放主动技能"
	_skill_button.custom_minimum_size = Vector2(150.0, 32.0)
	_skill_button.pressed.connect(func(): active_skill_requested.emit())
	actions.add_child(_skill_button)
	var action_hint := Label.new()
	action_hint.text = "作用于当前所选卡牌最后放置的单位"
	actions.add_child(action_hint)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, 70.0)
	rows.add_child(scroll)
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 6)
	scroll.add_child(items)

	_add_item_button(items, "training_dummy", "训练木桩\n固定")
	var card_ids: Array = cards.keys()
	card_ids.sort()
	for card_id in card_ids:
		var stats: Dictionary = cards[card_id]
		var type: String = stats.get("type", "unit")
		var tag := "法术" if type == "spell" else ("建筑" if type == "building" else CardDB.speed_tier_name(stats.get("speed", 0.0)))
		_add_item_button(items, card_id, "%s\n%s" % [stats.name, tag])

func _add_item_button(parent: Container, item_id: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(92.0, 62.0)
	button.pressed.connect(_select_item.bind(item_id))
	parent.add_child(button)
	_item_buttons[item_id] = button

func _select_item(item_id: String) -> void:
	_selected_id = item_id
	for id in _item_buttons:
		(_item_buttons[id] as Button).button_pressed = id == item_id
	if item_id == "training_dummy":
		_selection_label.text = "当前：训练木桩｜点击战场放置"
	else:
		var stats: Dictionary = CardDB.all()[item_id]
		if stats.get("type", "unit") == "unit":
			var size_label := CardDB.size_tier_name(stats.get("size_tier", &""))
			_selection_label.text = "当前：%s｜体型：%s｜点击战场放置" % [stats.name, size_label]
		else:
			_selection_label.text = "当前：%s｜点击战场放置" % stats.name
	_update_action_buttons()
	item_selected.emit(item_id)

func _update_action_buttons() -> void:
	var has_active_skill := _selected_id != "training_dummy" and not CardDB.active_skills_for(_selected_id).is_empty()
	if _skill_button != null:
		_skill_button.disabled = not has_active_skill

func _on_team_toggled(pressed: bool) -> void:
	_team = 1 if pressed else 0
	_update_team_text()
	team_changed.emit(_team)

func _update_team_text() -> void:
	if _team_button != null:
		_team_button.text = "红方（木桩）" if _team == 1 else "蓝方（攻击）"
