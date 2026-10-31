class_name DeckBuilder
extends CanvasLayer
## 备战卡组、卡牌详情、主动技能选择和皮肤选择的独立 UI 模块。


var _deck: Array = []
# 详情浏览/编辑偏好可包含组外卡；交付对局时另按最终卡组投影。
var _active_skill_choices: Dictionary = {}
var _skin_choices: Dictionary = {}
var _deck_layer: CanvasLayer

var _deck_toggles := {}       # card_id -> 下方卡牌库按钮
var _deck_slot_buttons: Array[Button] = []
var _deck_selected: Array = []  # 当前卡组，顺序就是上方 8 个卡位的顺序
var _deck_confirm: Button
var _deck_status: Label
var _deck_average_label: Label
var _deck_ui_root: Control
var _deck_pool_grid: GridContainer
var _filter_buttons: Array[Button] = []
var _deck_sort_kind: Button
var _deck_sort_direction: Button
var _pool_count_label: Label
var _deck_pool_filter := "all"
var _deck_pool_sort := "name"
var _deck_pending_slot := -1
var _deck_context_popup: PanelContainer
var _deck_context_info: Button
var _deck_context_action: Button
var _deck_context_card_id := ""
var _deck_context_slot := -1
var _deck_context_from_pool := false
var _deck_context_anchor: Control
var _deck_info_overlay: Control
var _deck_info_active_option: OptionButton
var _deck_info_active_rules: PanelContainer
var _deck_info_active_cost_label: Label
var _deck_info_active_uses_label: Label
var _deck_info_active_description: Label
var _deck_info_skin_option: OptionButton

func open(initial_deck: Array, active_skill_choices: Dictionary, skin_choices: Dictionary, confirmed: Callable) -> void:
	_deck = initial_deck.duplicate()
	_active_skill_choices = active_skill_choices.duplicate(true)
	_skin_choices = skin_choices.duplicate(true)
	_pick_deck_ui(func() -> void:
		confirmed.call(_deck.duplicate(), _match_active_skill_choices(), _skin_choices.duplicate(true))
	)

func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 44.0)
	return button

func _deck_style(_background: Color, border: Color, _border_width: int = 2) -> StyleBoxTexture:
	return UIMaterials.panel(border.lerp(Color.WHITE, 0.6))

func _make_deck_card_button(card_id: String, is_slot: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = false
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("card_id", card_id)
	CardArt.apply_frame(button, 166.0 if is_slot else 178.0, false, 128.0 if is_slot else 140.0)
	if card_id.is_empty():
		CardArt.show_empty_slot(button, 1)
		button.disabled = false
	else:
		var stats: Dictionary = CardDB.get_card(card_id)
		var accent: Color = stats.get("color", CardArt.DEFAULT_ACCENT)
		CardArt.apply_to_button(button, card_id, stats.name, stats.cost, false, accent)
	return button

func _set_active_slot_badge(button: Button, enabled: bool) -> void:
	# 前两席拥有独立槽框；卡牌保持自己的色边，符文与战斗手牌一致。
	CardArt.set_active_skill_card(button, enabled)
	var frame := button.get_parent() as RuneSlotFrame
	if frame != null: frame.active = enabled

## 在对战开始前弹出选卡组界面；上方固定 8 个卡位，下方滚动卡池。
func _pick_deck_ui(after_start: Callable) -> void:
	_deck_selected = _deck.duplicate() if _deck.size() == 8 else []
	_deck_pool_filter = "all"
	_deck_pool_sort = "cost_asc"
	_deck_pending_slot = -1
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_deck_layer = layer
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	_deck_ui_root = root
	var background := TextureRect.new()
	background.texture = UIMaterials.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.anchor_left = 0.5
	margin.anchor_right = 0.5
	margin.offset_left = -360
	margin.offset_right = 360
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	root.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 56
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)
	var back := _toolbar_button("", "back", "返回")
	back.custom_minimum_size = Vector2(48, 48)
	back.pressed.connect(_clear_deck_ui)
	header.add_child(back)
	var title := _section_label("备战", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var random_button := _toolbar_button("随机", "shuffle", "随机选择八张卡牌与主动技能")
	random_button.name = "RandomDeck"
	random_button.custom_minimum_size = Vector2(104, 48)
	random_button.pressed.connect(_randomize_deck)
	header.add_child(random_button)

	var deck_panel := PanelContainer.new()
	deck_panel.add_theme_stylebox_override("panel", UIMaterials.panel(Color(0.80, 0.86, 0.91), 12))
	layout.add_child(deck_panel)
	var deck_box := VBoxContainer.new()
	deck_box.add_theme_constant_override("separation", 10)
	deck_panel.add_child(deck_box)
	var deck_header := HBoxContainer.new()
	deck_header.add_theme_constant_override("separation", 12)
	deck_box.add_child(deck_header)
	deck_header.add_child(_section_label("出战卡组", 20))
	_deck_status = _section_label("", 15, UIPalette.MUTED)
	_deck_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_header.add_child(_deck_status)
	deck_header.add_child(GoldCoin.icon(23))
	_deck_average_label = _section_label("", 16, UIPalette.GOLD_LIGHT)
	_deck_average_label.tooltip_text = "八张出战卡牌的平均金币费用；镜像法术的费用随上一张卡变化"
	deck_header.add_child(_deck_average_label)
	var deck_center := CenterContainer.new()
	deck_box.add_child(deck_center)
	var deck_grid := GridContainer.new()
	deck_grid.columns = 4
	deck_grid.add_theme_constant_override("h_separation", 12)
	deck_grid.add_theme_constant_override("v_separation", 8)
	deck_center.add_child(deck_grid)
	_deck_slot_buttons.clear()
	for i in range(8):
		var slot := _make_deck_card_button("", true)
		var frame := RuneSlotFrame.new()
		frame.name = "DeckSlotFrame%d" % (i + 1)
		frame.add_child(slot)
		deck_grid.add_child(frame)
		CardArt.show_empty_slot(slot, i + 1)
		_set_active_slot_badge(slot, i < 2)
		slot.tooltip_text = "符文席：携带主动技能" if i < 2 else "选择卡牌"
		slot.pressed.connect(_on_deck_slot_pressed.bind(i))
		_deck_slot_buttons.append(slot)

	var library_header := HBoxContainer.new()
	library_header.add_theme_constant_override("separation", 10)
	layout.add_child(library_header)
	library_header.add_child(_section_label("卡牌库", 22))
	_pool_count_label = _section_label("", 14, UIPalette.MUTED)
	_pool_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_header.add_child(_pool_count_label)
	_deck_sort_kind = _toolbar_button("费用", "", "切换按金币费用或名称排序")
	_deck_sort_kind.icon = GoldCoin.TEXTURE
	_deck_sort_kind.custom_minimum_size = Vector2(98, 40)
	_deck_sort_kind.pressed.connect(_toggle_sort_kind)
	library_header.add_child(_deck_sort_kind)
	_deck_sort_direction = _toolbar_button("", "asc", "费用从低到高，点击倒序")
	_deck_sort_direction.custom_minimum_size = Vector2(44, 40)
	_deck_sort_direction.pressed.connect(_toggle_sort_direction)
	library_header.add_child(_deck_sort_direction)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	layout.add_child(filter_row)
	_filter_buttons.clear()
	var group := ButtonGroup.new()
	var filters := ["all", "ground", "air", "building", "spell"]
	var names := ["全部", "地面", "空军", "建筑", "法术"]
	for index in filters.size():
		var button := _toolbar_button(names[index], filters[index], "显示" + names[index] + "卡牌")
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_deck_filter_selected.bind(index))
		filter_row.add_child(button)
		_filter_buttons.append(button)
	_filter_buttons[0].set_pressed_no_signal(true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 160.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var grid := GridContainer.new()
	_deck_pool_grid = grid
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid_center.add_child(grid)
	scroll.add_child(grid_center)
	_refresh_deck_pool()
	var footer := CenterContainer.new()
	layout.add_child(footer)
	_deck_confirm = _toolbar_button("开始游戏", "", "使用当前八张卡牌开始游戏")
	_deck_confirm.custom_minimum_size = Vector2(380, 58)
	_deck_confirm.add_theme_font_size_override("font_size", 22)
	_deck_confirm.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT)
	_deck_confirm.add_theme_stylebox_override("normal", UIMaterials.panel(Color(1.22, 1.12, 0.92)))
	_deck_confirm.add_theme_stylebox_override("hover", UIMaterials.panel(Color(1.45, 1.30, 1.05)))
	_deck_confirm.pressed.connect(func(): _confirm_deck(after_start))
	footer.add_child(_deck_confirm)
	_create_deck_context_popup(root)
	_update_deck_ui()

func _section_label(text: String, font_size: int, color: Color = UIPalette.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _toolbar_button(text: String, icon_name: String, hint: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", CardArt.ui_font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", UIPalette.TEXT)
	button.add_theme_color_override("font_pressed_color", UIPalette.GOLD_LIGHT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", UIPalette.MUTED)
	button.add_theme_constant_override("icon_max_width", 20)
	button.add_theme_constant_override("h_separation", 6)
	if not icon_name.is_empty(): button.icon = load("res://assets/ui/controls/" + icon_name + ".svg")
	button.add_theme_stylebox_override("normal", UIMaterials.panel(Color(0.65, 0.74, 0.80), 10))
	button.add_theme_stylebox_override("hover", UIMaterials.panel(Color(0.95, 1.02, 1.06), 10))
	button.add_theme_stylebox_override("pressed", UIMaterials.panel(Color(1.18, 1.08, 0.85), 10))
	button.add_theme_stylebox_override("disabled", UIMaterials.panel(Color(0.36, 0.43, 0.47), 10))
	return button

func _toggle_sort_kind() -> void:
	var descending := _deck_pool_sort.ends_with("desc")
	var use_name := _deck_pool_sort.begins_with("cost")
	_on_deck_sort_selected((3 if descending else 0) if use_name else (2 if descending else 1))

func _toggle_sort_direction() -> void:
	var descending := _deck_pool_sort.ends_with("desc")
	var use_name := _deck_pool_sort.begins_with("name")
	_on_deck_sort_selected((0 if descending else 3) if use_name else (1 if descending else 2))

func _refresh_sort_controls() -> void:
	if _deck_sort_kind == null: return
	var use_name := _deck_pool_sort.begins_with("name")
	var descending := _deck_pool_sort.ends_with("desc")
	_deck_sort_kind.text = "名称" if use_name else "费用"
	_deck_sort_kind.icon = preload("res://assets/ui/controls/name.svg") if use_name else GoldCoin.TEXTURE
	_deck_sort_direction.icon = preload("res://assets/ui/controls/desc.svg") if descending else preload("res://assets/ui/controls/asc.svg")
	_deck_sort_direction.tooltip_text = ("名称降序" if descending else "名称升序") if use_name else ("费用从高到低" if descending else "费用从低到高")

func _randomize_deck() -> void:
	var pool := CardDB.selectable_ids().duplicate()
	pool.shuffle()
	_deck_selected = pool.slice(0, 8)
	for index in range(mini(2, _deck_selected.size())):
		var card_id := String(_deck_selected[index])
		var skills := CardDB.active_skills_for(card_id)
		_active_skill_choices[card_id] = randi_range(0, skills.size() - 1) if not skills.is_empty() else 0
	_deck_pending_slot = -1
	_hide_deck_context()
	_close_card_info()
	_refresh_deck_pool()
	_update_deck_ui()

func _create_deck_context_popup(root: Control) -> void:
	_deck_context_popup = PanelContainer.new()
	_deck_context_popup.custom_minimum_size = Vector2(132.0, 96.0)
	_deck_context_popup.size = Vector2(132.0, 96.0)
	_deck_context_popup.z_index = 50
	_deck_context_popup.add_theme_stylebox_override("panel", _deck_style(UIPalette.PANEL, UIPalette.GOLD, 3))
	root.add_child(_deck_context_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_deck_context_popup.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	_deck_context_info = _make_deck_action_button("信息", UIPalette.PANEL_LIGHT, UIPalette.TEAL)
	_deck_context_info.pressed.connect(_open_selected_card_info)
	box.add_child(_deck_context_info)
	_deck_context_action = _make_deck_action_button("添加", Color(0.08, 0.55, 0.30), Color(0.38, 0.95, 0.58))
	_deck_context_action.pressed.connect(_perform_deck_context_action)
	box.add_child(_deck_context_action)
	_deck_context_popup.visible = false

func _make_deck_action_button(text: String, background: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(116.0, 38.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", CardArt.ui_font())
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _deck_style(background, border, 2))
	button.add_theme_stylebox_override("hover", _deck_style(background.lightened(0.12), border.lightened(0.12), 3))
	button.add_theme_stylebox_override("pressed", _deck_style(background.darkened(0.12), UIPalette.GOLD, 3))
	button.add_theme_stylebox_override("disabled", _deck_style(Color(0.08, 0.10, 0.14), Color(0.28, 0.32, 0.38), 2))
	return button

func _on_deck_pool_card_pressed(card_id: String) -> void:
	if not _deck_toggles.has(card_id):
		return
	if _deck_pending_slot >= 0:
		_add_card_to_pending_slot(card_id)
		return
	_show_deck_context(card_id, -1, true, _deck_toggles[card_id])

func _on_deck_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= 8:
		return
	var slot_card_id := String(_deck_selected[slot_index]) if slot_index < _deck_selected.size() else ""
	if slot_card_id.is_empty():
		_deck_pending_slot = -1 if _deck_pending_slot == slot_index else slot_index
		_hide_deck_context()
		_update_deck_ui()
		return
	_deck_pending_slot = -1
	_show_deck_context(slot_card_id, slot_index, false, _deck_slot_buttons[slot_index])

func _show_deck_context(card_id: String, slot_index: int, from_pool: bool, anchor: Control) -> void:
	if not CardDB.has_card(card_id) or _deck_context_popup == null:
		return
	if _deck_context_popup.visible and _deck_context_card_id == card_id and _deck_context_slot == slot_index and _deck_context_from_pool == from_pool:
		_hide_deck_context()
		_update_deck_ui()
		return
	_deck_pending_slot = -1
	_deck_context_card_id = card_id
	_deck_context_slot = slot_index
	_deck_context_from_pool = from_pool
	_deck_context_anchor = anchor
	_deck_context_action.text = "添加" if from_pool else "移除"
	if from_pool:
		_deck_context_action.disabled = _deck_selected.has(card_id) or _selected_card_count() >= 8
		_deck_context_action.tooltip_text = "已在卡组中" if _deck_selected.has(card_id) else ("卡组已满" if _selected_card_count() >= 8 else "添加到下一个空卡位")
		_deck_context_action.add_theme_stylebox_override("normal", _deck_style(Color(0.08, 0.55, 0.30), Color(0.38, 0.95, 0.58), 2))
	else:
		_deck_context_action.disabled = false
		_deck_context_action.tooltip_text = "从卡组移除"
		_deck_context_action.add_theme_stylebox_override("normal", _deck_style(Color(0.70, 0.16, 0.18), Color(1.0, 0.43, 0.43), 2))
	_deck_context_popup.visible = true
	_deck_context_popup.move_to_front()
	_update_deck_ui()
	_position_deck_context_popup.call_deferred()

func _add_card_to_pending_slot(card_id: String) -> void:
	if _deck_pending_slot < 0 or not _add_card_to_slot(card_id, _deck_pending_slot):
		return
	_deck_pending_slot = -1
	_hide_deck_context()
	_refresh_deck_pool()
	_update_deck_ui()

func _selected_card_count() -> int:
	var count := 0
	for card_id in _deck_selected:
		if not String(card_id).is_empty():
			count += 1
	return count

func _first_empty_deck_slot() -> int:
	for slot_index in range(8):
		if slot_index >= _deck_selected.size() or String(_deck_selected[slot_index]).is_empty():
			return slot_index
	return -1

func _add_card_to_slot(card_id: String, slot_index: int) -> bool:
	if not CardDB.has_card(card_id) or slot_index < 0 or slot_index >= 8:
		return false
	if _selected_card_count() >= 8 or _deck_selected.has(card_id):
		return false
	while _deck_selected.size() <= slot_index:
		_deck_selected.append("")
	_deck_selected[slot_index] = card_id
	return true

func _trim_trailing_empty_slots() -> void:
	while not _deck_selected.is_empty() and String(_deck_selected.back()).is_empty():
		_deck_selected.pop_back()

func _on_deck_filter_selected(index: int) -> void:
	var filters := ["all", "ground", "air", "building", "spell"]
	if index < 0 or index >= filters.size():
		return
	_deck_pool_filter = filters[index]
	for i in _filter_buttons.size(): _filter_buttons[i].set_pressed_no_signal(i == index)
	_hide_deck_context()
	_refresh_deck_pool()

func _on_deck_sort_selected(index: int) -> void:
	var sort_modes := ["name", "cost_asc", "cost_desc", "name_desc"]
	if index < 0 or index >= sort_modes.size():
		return
	_deck_pool_sort = sort_modes[index]
	_refresh_sort_controls()
	_hide_deck_context()
	_refresh_deck_pool()

func _deck_card_matches_filter(card_id: String) -> bool:
	if _deck_pool_filter == "all":
		return true
	var stats: Dictionary = CardDB.get_card(card_id)
	match _deck_pool_filter:
		"ground": return String(stats.get("type", "unit")) == "unit" and not bool(stats.get("is_air", false))
		"air": return String(stats.get("type", "unit")) == "unit" and bool(stats.get("is_air", false))
		"building": return String(stats.get("type", "unit")) == "building"
		"spell": return String(stats.get("type", "unit")) == "spell"
	return false

func _sort_deck_card_ids(first_id: String, second_id: String) -> bool:
	var cards := CardDB.all()
	var first_stats: Dictionary = cards[first_id]
	var second_stats: Dictionary = cards[second_id]
	if _deck_pool_sort == "cost_asc" or _deck_pool_sort == "cost_desc":
		var first_cost := int(first_stats.get("cost", 0))
		var second_cost := int(second_stats.get("cost", 0))
		if first_cost != second_cost:
			return first_cost < second_cost if _deck_pool_sort == "cost_asc" else first_cost > second_cost
	var first_name := String(first_stats.get("name", first_id))
	var second_name := String(second_stats.get("name", second_id))
	if first_name != second_name:
		return first_name > second_name if _deck_pool_sort == "name_desc" else first_name < second_name
	return first_id < second_id

func _refresh_deck_pool() -> void:
	if _deck_pool_grid == null:
		return
	for child in _deck_pool_grid.get_children():
		_deck_pool_grid.remove_child(child)
		child.queue_free()
	_deck_toggles.clear()
	var card_ids: Array = []
	for configured_id in CardDB.selectable_ids():
		var card_id := String(configured_id)
		if _deck_selected.has(card_id) or not _deck_card_matches_filter(card_id):
			continue
		card_ids.append(card_id)
	card_ids.sort_custom(Callable(self, "_sort_deck_card_ids"))
	if _pool_count_label != null: _pool_count_label.text = "%d 张" % card_ids.size()
	for card_id in card_ids:
		var card_button := _make_deck_card_button(card_id, false)
		card_button.pressed.connect(_on_deck_pool_card_pressed.bind(card_id))
		_deck_pool_grid.add_child(card_button)
		_deck_toggles[card_id] = card_button

func _position_deck_context_popup() -> void:
	if _deck_context_popup == null or not _deck_context_popup.visible or _deck_context_anchor == null or not is_instance_valid(_deck_context_anchor) or _deck_ui_root == null:
		return
	var anchor_rect := _deck_context_anchor.get_global_rect()
	var root_rect := _deck_ui_root.get_global_rect()
	var popup_size := _deck_context_popup.size
	var x := anchor_rect.position.x - root_rect.position.x + (anchor_rect.size.x - popup_size.x) * 0.5
	var y := anchor_rect.end.y - root_rect.position.y + 5.0
	x = clampf(x, 8.0, maxf(8.0, root_rect.size.x - popup_size.x - 8.0))
	if y + popup_size.y > root_rect.size.y - 76.0:
		y = anchor_rect.position.y - root_rect.position.y - popup_size.y - 5.0
	_deck_context_popup.position = Vector2(x, maxf(y, 8.0))

func _perform_deck_context_action() -> void:
	if _deck_context_card_id.is_empty():
		return
	if _deck_context_from_pool:
		var empty_slot := _first_empty_deck_slot()
		if empty_slot < 0 or not _add_card_to_slot(_deck_context_card_id, empty_slot):
			return
	else:
		if _deck_context_slot < 0 or _deck_context_slot >= _deck_selected.size() or String(_deck_selected[_deck_context_slot]).is_empty():
			return
		_deck_selected[_deck_context_slot] = ""
		_trim_trailing_empty_slots()
	_deck_pending_slot = -1
	_hide_deck_context()
	_refresh_deck_pool()
	_update_deck_ui()

func _hide_deck_context() -> void:
	_deck_context_card_id = ""
	_deck_context_slot = -1
	_deck_context_from_pool = false
	_deck_context_anchor = null
	if _deck_context_popup != null:
		_deck_context_popup.visible = false

func _open_selected_card_info() -> void:
	if _deck_context_card_id.is_empty() or not CardDB.has_card(_deck_context_card_id):
		return
	_open_card_info(_deck_context_card_id)

func _open_card_info(card_id: String) -> void:
	_close_card_info()
	_hide_deck_context()
	if _deck_ui_root == null or not CardDB.has_card(card_id):
		return
	var stats: Dictionary = CardDB.get_card(card_id)
	var accent: Color = stats.get("color", CardArt.DEFAULT_ACCENT)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.015, 0.035, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 80
	_deck_ui_root.add_child(overlay)
	_deck_info_overlay = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	# 信息页按内容自然收缩，避免固定大面板在内容较少时把下半部分留空。
	panel.custom_minimum_size = Vector2(650.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _deck_style(UIPalette.INK, UIPalette.GOLD, 3))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	var preview := _make_deck_card_button(card_id, false)
	CardArt.apply_frame(preview, 224.0)
	CardArt.apply_to_button(preview, card_id, stats.name, stats.cost, false, accent)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(preview)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 8)
	header.add_child(identity)
	var name_label := Label.new()
	name_label.text = String(stats.name)
	name_label.add_theme_font_override("font", CardArt.ui_font())
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.06))
	name_label.add_theme_constant_override("outline_size", 5)
	identity.add_child(name_label)
	var identity_line := Label.new()
	identity_line.text = "法术　·　动态费用（上一张卡本身费用）" if CardPlayHistory.is_mirror(card_id) else "%s　·　%d 费" % [CardDetails.type_name(String(stats.get("type", "unit")), stats), int(stats.cost)]
	identity_line.add_theme_font_override("font", CardArt.ui_font())
	identity_line.add_theme_font_size_override("font_size", 19)
	identity_line.add_theme_color_override("font_color", UIPalette.MUTED)
	identity.add_child(identity_line)
	# 皮肤入口固定在信息面板右上角，默认选择原皮；未来只需在卡牌数据中
	# 增加 skins 数组即可出现更多选项，皮肤选择不参与战斗数值。
	var skin_box := VBoxContainer.new()
	skin_box.custom_minimum_size = Vector2(124.0, 0.0)
	skin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	skin_box.add_theme_constant_override("separation", 4)
	header.add_child(skin_box)
	_deck_info_skin_option = _make_card_skin_option(card_id, stats)
	skin_box.add_child(_deck_info_skin_option)
	var separator := HSeparator.new()
	layout.add_child(separator)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 7)
	# 详情内容控制弹窗自身高度；当前属性量可完整放下，不再用会被压成零高的滚动容器。
	layout.add_child(details)
	details.add_child(_make_card_info_heading("简介"))
	details.add_child(_make_card_info_body(CardDetails.brief_description(stats)))
	details.add_child(_make_card_info_heading("属性"))
	details.add_child(_make_card_attribute_grid(stats))
	var member_sections := CardDetails.deployment_member_sections(stats)
	if not member_sections.is_empty():
		var member_scroll := ScrollContainer.new()
		member_scroll.name = "DeploymentMembers"
		member_scroll.custom_minimum_size.y = 180.0
		member_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		details.add_child(member_scroll)
		var member_body := VBoxContainer.new()
		member_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		member_body.add_theme_constant_override("separation", 7)
		member_scroll.add_child(member_body)
		for member in member_sections:
			member_body.add_child(_make_card_info_subheading("%s ×%d（每只）" % [member.name, member.count]))
			member_body.add_child(_make_card_attribute_rows(member.attributes))
	var upgrade_stats := CardDB.get_unit_stats(String(stats.get("deployment_upgrade_id", "")))
	if not upgrade_stats.is_empty():
		details.add_child(_make_card_info_subheading("%s（%d金币部署）" % [upgrade_stats.name, upgrade_stats.cost]))
		details.add_child(_make_card_attribute_grid(upgrade_stats))
	var transformed_stats: Dictionary = stats.get("transformed_stats", {})
	if not transformed_stats.is_empty():
		details.add_child(_make_card_info_subheading("%s（变形后）" % String(transformed_stats.get("name", "变形形态"))))
		details.add_child(_make_card_attribute_grid(transformed_stats))
	var periodic_spawn_id := String(stats.get("spawn_id", ""))
	var periodic_spawn_stats := CardDB.get_unit_stats(periodic_spawn_id)
	if float(stats.get("spawn_interval", 0.0)) > 0.0 and not periodic_spawn_stats.is_empty():
		details.add_child(_make_card_info_subheading("召唤物：%s（每批 %d 只）" % [String(periodic_spawn_stats.get("name", periodic_spawn_id)), int(stats.get("spawn_count", 1))]))
		details.add_child(_make_card_attribute_grid(periodic_spawn_stats, "%d /批" % int(stats.get("spawn_count", 1))))
	var passives := CardDetails.passives(stats)
	if not passives.is_empty():
		details.add_child(_make_card_info_heading("被动"))
		for passive in passives:
			details.add_child(_make_card_passive_row(String(passive.get("name", "被动")), String(passive.get("description", ""))))
	details.add_child(_make_card_info_heading("主动"))
	var skills := CardDB.active_skills_for(card_id)
	_deck_info_active_option = OptionButton.new()
	_style_deck_option(_deck_info_active_option)
	_deck_info_active_option.custom_minimum_size = Vector2(0.0, 46.0)
	_deck_info_active_option.add_theme_font_override("font", CardArt.ui_font())
	_deck_info_active_option.add_theme_font_size_override("font_size", 17)
	_deck_info_active_option.add_theme_constant_override("icon_max_width", 32)
	_deck_info_active_option.add_theme_color_override("icon_disabled_color", Color.WHITE)
	_deck_info_active_option.get_popup().add_theme_constant_override("icon_max_width", 32)
	if skills.is_empty():
		if String(stats.get("type", "unit")) == "spell":
			_deck_info_active_option.add_icon_item(CardArt.skill_icon(stats), String(stats.get("active_name", "强化" + String(stats.get("name", "法术")))))
		else:
			_deck_info_active_option.add_item("无主动技能")
		_deck_info_active_option.disabled = true
	else:
		for skill in skills:
			_deck_info_active_option.add_icon_item(CardArt.skill_icon(skill), String(skill.get("name", "未命名技能")))
		var selected_skill := clampi(int(_active_skill_choices.get(card_id, 0)), 0, skills.size() - 1)
		_active_skill_choices[card_id] = selected_skill
		_deck_info_active_option.select(selected_skill)
		_deck_info_active_option.disabled = skills.size() <= 1
		_deck_info_active_option.item_selected.connect(_on_info_active_skill_selected.bind(card_id))
	details.add_child(_deck_info_active_option)
	if not skills.is_empty():
		_deck_info_active_rules = _make_active_skill_rules(skills[clampi(int(_active_skill_choices.get(card_id, 0)), 0, skills.size() - 1)])
		details.add_child(_deck_info_active_rules)
	_deck_info_active_description = _make_card_info_body(CardDetails.active_choice_description(card_id, int(_active_skill_choices.get(card_id, 0))))
	details.add_child(_deck_info_active_description)
	var close := _make_deck_action_button("返回备战", UIPalette.PANEL_LIGHT, UIPalette.TEAL)
	close.custom_minimum_size = Vector2(220.0, 48.0)
	close.pressed.connect(_close_card_info)
	var close_center := CenterContainer.new()
	close_center.add_child(close)
	layout.add_child(close_center)
	overlay.move_to_front()

func _make_card_skin_option(card_id: String, stats: Dictionary) -> OptionButton:
	var option := OptionButton.new()
	_style_deck_option(option)
	option.custom_minimum_size = Vector2(124.0, 42.0)
	option.add_theme_font_override("font", CardArt.ui_font())
	option.add_theme_font_size_override("font_size", 15)
	option.tooltip_text = "选择外观；皮肤不改变战斗数值"
	var skins := _card_skin_entries(stats)
	var selected_id := String(_skin_choices.get(card_id, "default"))
	var selected_index := 0
	for i in range(skins.size()):
		var skin: Dictionary = skins[i]
		option.add_item(String(skin.get("name", "原皮")))
		if String(skin.get("id", "default")) == selected_id:
			selected_index = i
	_skin_choices[card_id] = String(skins[selected_index].get("id", "default"))
	option.select(selected_index)
	option.item_selected.connect(_on_info_skin_selected.bind(card_id, skins))
	return option

func _card_skin_entries(stats: Dictionary) -> Array:
	var skins: Array = [{"id": "default", "name": "原皮"}]
	for configured in stats.get("skins", []):
		if configured is Dictionary:
			var skin_id := String(configured.get("id", ""))
			if not skin_id.is_empty() and skin_id != "default":
				skins.append((configured as Dictionary).duplicate(true))
		elif configured is String and not String(configured).is_empty() and String(configured) != "default":
			skins.append({"id": String(configured), "name": String(configured)})
	return skins

func _make_card_info_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", UIPalette.GOLD)
	return label

func _make_card_info_body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UIPalette.TEXT)
	label.add_theme_constant_override("line_spacing", 4)
	return label

func _make_card_info_subheading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UIPalette.MUTED)
	return label

func _make_card_attribute_grid(stats: Dictionary, quantity_override: String = "") -> Control:
	return _make_card_attribute_rows(CardDetails.attributes(stats, quantity_override))

func _make_card_attribute_rows(attributes: Array[Dictionary]) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	for attribute in attributes:
		var attribute_value := String(attribute.get("value", ""))
		if attribute_value.is_empty():
			continue
		var item := PanelContainer.new()
		item.custom_minimum_size = Vector2(0.0, 32.0)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_theme_stylebox_override("panel", _deck_style(UIPalette.PANEL, UIPalette.LINE, 1))
		var label := Label.new()
		label.text = "%s：%s" % [String(attribute.get("name", "")), attribute_value]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", CardArt.ui_font())
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", UIPalette.TEXT)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.03, 0.08, 0.70))
		label.add_theme_constant_override("outline_size", 2)
		item.add_child(label)
		grid.add_child(item)
	return grid

func _make_card_passive_row(name: String, description: String) -> Label:
	var label := _make_card_info_body("%s：%s" % [name, description])
	label.custom_minimum_size = Vector2(0.0, 28.0)
	return label

func _make_active_skill_rules(skill: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 38.0)
	panel.add_theme_stylebox_override("panel", _deck_style(UIPalette.PANEL, UIPalette.LINE, 1))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_deck_info_active_cost_label = _make_active_skill_rule_label("")
	_deck_info_active_cost_label.add_theme_color_override("font_color", UIPalette.GOLD)
	_deck_info_active_uses_label = _make_active_skill_rule_label("")
	_deck_info_active_uses_label.add_theme_color_override("font_color", UIPalette.MUTED)
	row.add_child(_deck_info_active_cost_label)
	row.add_child(_deck_info_active_uses_label)
	_update_active_skill_rules(skill)
	return panel

func _make_active_skill_rule_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 16)
	return label

func _update_active_skill_rules(skill: Dictionary) -> void:
	if _deck_info_active_cost_label == null or _deck_info_active_uses_label == null:
		return
	_deck_info_active_cost_label.text = "金币消耗：%s" % CardDetails.format_number(maxf(float(skill.get("cost", 0.0)), 0.0))
	var owner_label := "本次编队" if StringName(skill.get("target_scope", "self")) == &"deployment_group" else "单个单位"
	_deck_info_active_uses_label.text = "%s：最多 %d 次　·　冷却 %s秒" % [
		owner_label,
		maxi(int(skill.get("max_uses", 1)), 1),
		CardDetails.format_number(maxf(float(skill.get("cooldown", 0.0)), 0.0)),
	]

	if bool(skill.get("unlimited_uses", false)):
		_deck_info_active_uses_label.text = "%s：次数不限 · 冷却 %s秒" % [owner_label, CardDetails.format_number(float(skill.get("cooldown", 0.0)))]
	if skill.has("cost_by_use"):
		var costs := PackedStringArray()
		for amount in skill.cost_by_use: costs.append(CardDetails.format_number(float(amount)))
		_deck_info_active_cost_label.text = "金币消耗：" + " → ".join(costs) + ("（封顶）" if bool(skill.get("unlimited_uses", false)) else "")

func _on_info_active_skill_selected(skill_index: int, card_id: String) -> void:
	var skills := CardDB.active_skills_for(card_id)
	if skills.is_empty():
		return
	_active_skill_choices[card_id] = clampi(skill_index, 0, skills.size() - 1)
	_update_active_skill_rules(skills[_active_skill_choices[card_id]])
	if _deck_info_active_description != null:
		_deck_info_active_description.text = CardDetails.active_choice_description(card_id, int(_active_skill_choices.get(card_id, 0)))

func _on_info_skin_selected(skin_index: int, card_id: String, skins: Array) -> void:
	if skin_index < 0 or skin_index >= skins.size():
		return
	var skin: Dictionary = skins[skin_index]
	_skin_choices[card_id] = String(skin.get("id", "default"))

func _close_card_info() -> void:
	if _deck_info_overlay != null:
		_deck_info_overlay.queue_free()
		_deck_info_overlay = null
		_deck_info_active_option = null
		_deck_info_active_rules = null
		_deck_info_active_cost_label = null
		_deck_info_active_uses_label = null
		_deck_info_active_description = null
		_deck_info_skin_option = null

func _update_deck_ui() -> void:
	if _deck_status == null:
		return
	var selected_count := _selected_card_count()
	if _deck_pending_slot >= 0:
		_deck_status.text = "第 %d 席待选" % (_deck_pending_slot + 1)
	else:
		_deck_status.text = "%d / 8" % selected_count
	var total_cost := 0.0
	var dynamic_cost := false
	for selected_id in _deck_selected:
		if not String(selected_id).is_empty():
			total_cost += float(CardDB.get_card(String(selected_id)).cost)
			dynamic_cost = dynamic_cost or CardPlayHistory.is_mirror(String(selected_id))
	if _deck_average_label != null:
		_deck_average_label.text = "平均 · 动态" if dynamic_cost else ("平均 —" if selected_count == 0 else "平均 %.1f" % (total_cost / selected_count))
	for i in range(_deck_slot_buttons.size()):
		var slot: Button = _deck_slot_buttons[i]
		var card_id := String(_deck_selected[i]) if i < _deck_selected.size() else ""
		if not card_id.is_empty():
			var stats: Dictionary = CardDB.get_card(card_id)
			slot.disabled = false
			var accent: Color = stats.get("color", CardArt.DEFAULT_ACCENT)
			CardArt.apply_to_button(slot, card_id, stats.name, stats.cost, false, accent)
			CardArt.set_selected(slot, not _deck_context_from_pool and _deck_context_slot == i and _deck_context_card_id == card_id)
			_set_active_slot_badge(slot, i < 2)
			slot.tooltip_text = ("主动技能位：点击查看信息或移除" if i < 2 else "普通卡位：点击查看信息或移除")
		else:
			slot.disabled = false
			CardArt.show_empty_slot(slot, i + 1)
			CardArt.set_selected(slot, _deck_pending_slot == i)
			_set_active_slot_badge(slot, i < 2)
	for id in _deck_toggles:
		var button: Button = _deck_toggles[id]
		button.disabled = false
		CardArt.set_selected(button, _deck_context_from_pool and _deck_context_card_id == id)
		var stats := CardDB.get_card(String(id))
		button.tooltip_text = "镜像法术 · 上一张卡本身费用 · 点击查看信息" if String(stats.get("spell_kind", "")) == "mirror" else "%s · %d 金币 · 点击查看信息" % [stats.name, int(stats.cost)]
	var ready := selected_count == 8
	if _deck_confirm != null:
		_deck_confirm.disabled = not ready
		_deck_confirm.text = "开始游戏" if ready else "还需选择 %d 张卡" % (8 - selected_count)

func _set_card_in_deck_badge(button: Button, in_deck: bool) -> void:
	var badge := button.get_node_or_null("InDeckBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "InDeckBadge"
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -54.0
		badge.offset_top = 5.0
		badge.offset_right = -4.0
		badge.offset_bottom = 29.0
		badge.text = "已加入"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", CardArt.ui_font())
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", Color(0.48, 1.0, 0.61))
		badge.add_theme_color_override("font_outline_color", Color(0.0, 0.08, 0.02))
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)
	badge.visible = in_deck
	button.move_child(badge, button.get_child_count() - 1)

func _confirm_deck(after_start: Callable) -> void:
	if _selected_card_count() != 8:
		return
	_deck = []
	for card_id in _deck_selected:
		if not String(card_id).is_empty():
			_deck.append(card_id)
	_clear_deck_ui()
	after_start.call()

func _match_active_skill_choices() -> Dictionary:
	var choices := {}
	for card_id in _deck:
		var skills := CardDB.active_skills_for(card_id)
		choices[card_id] = clampi(int(_active_skill_choices.get(card_id, 0)), 0, maxi(skills.size(), 1) - 1)
	return choices

func _clear_deck_ui() -> void:
	_close_card_info()
	if _deck_layer != null:
		_deck_layer.queue_free()
		_deck_layer = null
	_deck_toggles.clear()
	_deck_slot_buttons.clear()
	_deck_status = null
	_deck_confirm = null
	_deck_average_label = null
	_deck_ui_root = null
	_deck_pool_grid = null
	_filter_buttons.clear()
	_deck_sort_kind = null
	_deck_sort_direction = null
	_pool_count_label = null
	_deck_pending_slot = -1
	_deck_context_popup = null
	_deck_context_info = null
	_deck_context_action = null
	_deck_context_card_id = ""
	_deck_context_slot = -1
	_deck_context_from_pool = false
	_deck_context_anchor = null
	queue_free()

func _style_deck_option(option: OptionButton) -> void:
	# Arrow lives inside the metal bevel, with a separate text reserve.
	option.add_theme_constant_override("arrow_margin", 18)
	option.add_theme_constant_override("h_separation", 12)
	option.add_theme_stylebox_override("normal", _deck_style(UIPalette.PANEL, UIPalette.LINE, 1))
	option.add_theme_stylebox_override("hover", _deck_style(UIPalette.PANEL_LIGHT, UIPalette.TEAL, 1))
	option.add_theme_stylebox_override("pressed", _deck_style(UIPalette.INK, UIPalette.GOLD, 1))
	option.add_theme_stylebox_override("disabled", _deck_style(UIPalette.PANEL, UIPalette.LINE, 1))
	option.add_theme_color_override("font_color", UIPalette.TEXT)
	option.get_popup().add_theme_stylebox_override("panel", _deck_style(UIPalette.INK, UIPalette.GOLD, 1))
	option.get_popup().add_theme_stylebox_override("hover", _deck_style(UIPalette.PANEL_LIGHT, UIPalette.TEAL, 1))
