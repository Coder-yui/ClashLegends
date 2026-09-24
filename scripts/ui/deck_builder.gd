class_name DeckBuilder
extends CanvasLayer
## 备战卡组、卡牌详情、主动技能选择和皮肤选择的独立 UI 模块。

const ARENA_BACKGROUND_TEXTURE := preload("res://assets/arena/arena_rift_v4.png")

var _deck: Array = []
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
var _deck_filter_option: OptionButton
var _deck_sort_option: OptionButton
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
		confirmed.call(_deck.duplicate(), _active_skill_choices.duplicate(true), _skin_choices.duplicate(true))
	)

func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 44.0)
	return button

func _deck_style(background: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	return CardArt.frame_style(background, border, border_width)

func _make_deck_card_button(card_id: String, is_slot: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = false
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("card_id", card_id)
	CardArt.apply_frame(button, 165.0 if is_slot else 172.0)
	if card_id.is_empty():
		CardArt.show_empty_slot(button, 1)
		button.disabled = false
	else:
		var stats: Dictionary = CardDB.get_card(card_id)
		var accent: Color = stats.get("color", CardArt.DEFAULT_ACCENT)
		CardArt.apply_to_button(button, card_id, stats.name, stats.cost, false, accent)
	return button

func _set_active_slot_badge(button: Button, enabled: bool) -> void:
	var badge := button.get_node_or_null("ActiveSlotBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "ActiveSlotBadge"
		badge.position = Vector2(4.0, 42.0)
		badge.custom_minimum_size = Vector2(72.0, 24.0)
		badge.text = "主动位"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", CardArt.ui_font())
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
		badge.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.08))
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)
	badge.visible = enabled
	button.move_child(badge, button.get_child_count() - 1)

## 在对战开始前弹出选卡组界面；上方固定 8 个卡位，下方滚动卡池。
func _pick_deck_ui(after_start: Callable) -> void:
	_deck_selected = _deck.duplicate() if _deck.size() == 8 else []
	_deck_pool_filter = "all"
	_deck_pool_sort = "name"
	_deck_pending_slot = -1
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_deck_layer = layer
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	_deck_ui_root = root
	var background_art := TextureRect.new()
	background_art.texture = ARENA_BACKGROUND_TEXTURE
	background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.modulate = Color(0.18, 0.32, 0.52, 0.28)
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background_art)
	var background_tint := ColorRect.new()
	background_tint.color = Color(0.018, 0.055, 0.12, 0.93)
	background_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background_tint)
	var top_glow := ColorRect.new()
	top_glow.color = Color(0.04, 0.42, 0.78, 0.20)
	top_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_glow.offset_bottom = 150.0
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_glow)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	root.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)
	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0.0, 78.0)
	header_panel.add_theme_stylebox_override("panel", _deck_style(Color(0.025, 0.16, 0.30, 0.96), Color(0.08, 0.55, 0.94), 2))
	vbox.add_child(header_panel)
	var header_box := VBoxContainer.new()
	header_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header_box.add_theme_constant_override("separation", -2)
	header_panel.add_child(header_box)
	var title := Label.new()
	title.text = "备战卡组"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08))
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "前两席携带主动；镜像在主动席时，也会复制其他席位预选的技能"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.84, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(subtitle)
	var deck_header := HBoxContainer.new()
	deck_header.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(deck_header)
	var deck_header_title := Label.new()
	deck_header_title.text = "我的卡组"
	deck_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_header_title.add_theme_font_size_override("font_size", 20)
	deck_header_title.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	deck_header.add_child(deck_header_title)
	_deck_average_label = Label.new()
	_deck_average_label.add_theme_font_size_override("font_size", 16)
	_deck_average_label.add_theme_color_override("font_color", Color(0.94, 0.48, 1.0))
	deck_header.add_child(_deck_average_label)
	var random_button := _make_deck_action_button("随机卡组", Color(0.08, 0.43, 0.72), Color(0.36, 0.78, 1.0))
	random_button.name = "RandomDeck"
	random_button.tooltip_text = "重新随机选择 8 张卡牌，主动槽随机选择可用技能"
	random_button.pressed.connect(_randomize_deck)
	deck_header.add_child(random_button)
	var deck_panel := PanelContainer.new()
	deck_panel.custom_minimum_size = Vector2(0.0, 352.0)
	deck_panel.add_theme_stylebox_override("panel", _deck_style(Color(0.025, 0.09, 0.17, 0.97), Color(0.10, 0.42, 0.70), 2))
	vbox.add_child(deck_panel)
	var deck_margin := MarginContainer.new()
	deck_margin.add_theme_constant_override("margin_left", 12)
	deck_margin.add_theme_constant_override("margin_right", 12)
	deck_margin.add_theme_constant_override("margin_top", 6)
	deck_margin.add_theme_constant_override("margin_bottom", 6)
	deck_panel.add_child(deck_margin)
	var deck_center := CenterContainer.new()
	deck_margin.add_child(deck_center)
	var deck_grid := GridContainer.new()
	deck_grid.columns = 4
	deck_grid.add_theme_constant_override("h_separation", 14)
	deck_grid.add_theme_constant_override("v_separation", 10)
	deck_center.add_child(deck_grid)
	_deck_slot_buttons.clear()
	for i in range(8):
		var slot := _make_deck_card_button("", true)
		CardArt.show_empty_slot(slot, i + 1)
		_set_active_slot_badge(slot, i < 2)
		slot.tooltip_text = "主动技能位" if i < 2 else "普通卡位"
		slot.pressed.connect(_on_deck_slot_pressed.bind(i))
		deck_grid.add_child(slot)
		_deck_slot_buttons.append(slot)
	_deck_status = Label.new()
	_deck_status.add_theme_font_size_override("font_size", 16)
	_deck_status.add_theme_color_override("font_color", Color(0.67, 0.82, 0.96))
	_deck_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_deck_status)
	var pool_header := Label.new()
	pool_header.text = "卡牌库"
	pool_header.add_theme_font_size_override("font_size", 20)
	pool_header.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	vbox.add_child(pool_header)
	var pool_controls := HBoxContainer.new()
	pool_controls.add_theme_constant_override("separation", 8)
	vbox.add_child(pool_controls)
	var filter_label := Label.new()
	filter_label.text = "类型"
	filter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	filter_label.add_theme_font_size_override("font_size", 15)
	filter_label.add_theme_color_override("font_color", Color(0.68, 0.84, 1.0))
	pool_controls.add_child(filter_label)
	_deck_filter_option = OptionButton.new()
	_deck_filter_option.custom_minimum_size = Vector2(150.0, 38.0)
	_deck_filter_option.add_theme_font_override("font", CardArt.ui_font())
	_deck_filter_option.add_theme_font_size_override("font_size", 15)
	for filter_name in ["全部", "地面", "空军", "建筑", "法术"]:
		_deck_filter_option.add_item(filter_name)
	_deck_filter_option.select(0)
	_deck_filter_option.item_selected.connect(_on_deck_filter_selected)
	pool_controls.add_child(_deck_filter_option)
	var sort_label := Label.new()
	sort_label.text = "排序"
	sort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sort_label.add_theme_font_size_override("font_size", 15)
	sort_label.add_theme_color_override("font_color", Color(0.68, 0.84, 1.0))
	pool_controls.add_child(sort_label)
	_deck_sort_option = OptionButton.new()
	_deck_sort_option.custom_minimum_size = Vector2(190.0, 38.0)
	_deck_sort_option.add_theme_font_override("font", CardArt.ui_font())
	_deck_sort_option.add_theme_font_size_override("font_size", 15)
	for sort_name in ["名称排序", "金币消耗递增", "金币消耗递减"]:
		_deck_sort_option.add_item(sort_name)
	_deck_sort_option.select(0)
	_deck_sort_option.item_selected.connect(_on_deck_sort_selected)
	pool_controls.add_child(_deck_sort_option)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 560.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	_deck_pool_grid = grid
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid_center.add_child(grid)
	scroll.add_child(grid_center)
	_refresh_deck_pool()
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)
	var back := _make_menu_button("返回")
	back.custom_minimum_size = Vector2(150, 52)
	back.add_theme_stylebox_override("normal", _deck_style(Color(0.08, 0.15, 0.24), Color(0.30, 0.46, 0.64), 2))
	back.pressed.connect(_clear_deck_ui)
	btn_row.add_child(back)
	_deck_confirm = _make_menu_button("开始对战")
	_deck_confirm.custom_minimum_size = Vector2(230, 52)
	_deck_confirm.add_theme_font_size_override("font_size", 20)
	_deck_confirm.add_theme_stylebox_override("normal", _deck_style(Color(0.05, 0.42, 0.74), Color(0.34, 0.78, 1.0), 3))
	_deck_confirm.add_theme_stylebox_override("hover", _deck_style(Color(0.08, 0.54, 0.88), Color(0.60, 0.90, 1.0), 3))
	_deck_confirm.add_theme_stylebox_override("pressed", _deck_style(Color(0.04, 0.32, 0.60), Color(1.0, 0.84, 0.32), 3))
	_deck_confirm.pressed.connect(func(): _confirm_deck(after_start))
	btn_row.add_child(_deck_confirm)
	_create_deck_context_popup(root)
	_update_deck_ui()

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
	_deck_context_popup.add_theme_stylebox_override("panel", _deck_style(Color(0.025, 0.12, 0.22, 0.99), Color(0.28, 0.72, 1.0), 3))
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
	_deck_context_info = _make_deck_action_button("信息", Color(0.08, 0.43, 0.72), Color(0.36, 0.78, 1.0))
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
	button.add_theme_stylebox_override("pressed", _deck_style(background.darkened(0.12), Color(1.0, 0.84, 0.30), 3))
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
	_hide_deck_context()
	_refresh_deck_pool()

func _on_deck_sort_selected(index: int) -> void:
	var sort_modes := ["name", "cost_asc", "cost_desc"]
	if index < 0 or index >= sort_modes.size():
		return
	_deck_pool_sort = sort_modes[index]
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
	return first_name < second_name if first_name != second_name else first_id < second_id

func _refresh_deck_pool() -> void:
	if _deck_pool_grid == null:
		return
	for child in _deck_pool_grid.get_children():
		child.queue_free()
	_deck_toggles.clear()
	var card_ids: Array = []
	for configured_id in CardDB.selectable_ids():
		var card_id := String(configured_id)
		if _deck_selected.has(card_id) or not _deck_card_matches_filter(card_id):
			continue
		card_ids.append(card_id)
	card_ids.sort_custom(Callable(self, "_sort_deck_card_ids"))
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
	panel.add_theme_stylebox_override("panel", _deck_style(Color(0.025, 0.075, 0.14, 0.995), accent.lightened(0.22), 3))
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
	name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.06))
	name_label.add_theme_constant_override("outline_size", 5)
	identity.add_child(name_label)
	var identity_line := Label.new()
	identity_line.text = "法术　·　动态费用（上一张卡本身费用）" if CardPlayHistory.is_mirror(card_id) else "%s　·　%d 费" % [CardDetails.type_name(String(stats.get("type", "unit")), stats), int(stats.cost)]
	identity_line.add_theme_font_override("font", CardArt.ui_font())
	identity_line.add_theme_font_size_override("font_size", 19)
	identity_line.add_theme_color_override("font_color", Color(0.68, 0.86, 1.0))
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
	_deck_info_active_option.custom_minimum_size = Vector2(0.0, 46.0)
	_deck_info_active_option.add_theme_font_override("font", CardArt.ui_font())
	_deck_info_active_option.add_theme_font_size_override("font_size", 17)
	_deck_info_active_option.add_theme_constant_override("icon_max_width", 32)
	_deck_info_active_option.add_theme_color_override("icon_disabled_color", Color.WHITE)
	_deck_info_active_option.get_popup().add_theme_constant_override("icon_max_width", 32)
	if skills.is_empty():
		if String(stats.get("type", "unit")) == "spell":
			_deck_info_active_option.add_item(String(stats.get("active_name", "强化" + String(stats.get("name", "法术")))))
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
	var close := _make_deck_action_button("返回备战", Color(0.08, 0.38, 0.68), Color(0.38, 0.80, 1.0))
	close.custom_minimum_size = Vector2(220.0, 48.0)
	close.pressed.connect(_close_card_info)
	var close_center := CenterContainer.new()
	close_center.add_child(close)
	layout.add_child(close_center)
	overlay.move_to_front()

func _make_card_skin_option(card_id: String, stats: Dictionary) -> OptionButton:
	var option := OptionButton.new()
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
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
	return label

func _make_card_info_body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.84, 0.91, 0.98))
	label.add_theme_constant_override("line_spacing", 4)
	return label

func _make_card_info_subheading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.64, 0.82, 1.0))
	return label

func _make_card_attribute_grid(stats: Dictionary, quantity_override: String = "") -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	for attribute in CardDetails.attributes(stats, quantity_override):
		var attribute_value := String(attribute.get("value", ""))
		if attribute_value.is_empty():
			continue
		var item := PanelContainer.new()
		item.custom_minimum_size = Vector2(0.0, 32.0)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_theme_stylebox_override("panel", _deck_style(Color(0.035, 0.12, 0.21, 0.88), Color(0.10, 0.30, 0.48, 0.75), 1))
		var label := Label.new()
		label.text = "%s：%s" % [String(attribute.get("name", "")), attribute_value]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", CardArt.ui_font())
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
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
	panel.add_theme_stylebox_override("panel", _deck_style(Color(0.035, 0.13, 0.22, 0.95), Color(0.18, 0.45, 0.65, 0.9), 1))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_deck_info_active_cost_label = _make_active_skill_rule_label("")
	_deck_info_active_cost_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34))
	_deck_info_active_uses_label = _make_active_skill_rule_label("")
	_deck_info_active_uses_label.add_theme_color_override("font_color", Color(0.60, 0.86, 1.0))
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
		_deck_status.text = "已选择 %d / 8　·　已选中第%d个卡槽，请点击下方卡牌　·　1、2 号为主动技能位" % [selected_count, _deck_pending_slot + 1]
	else:
		_deck_status.text = "已选择 %d / 8　·　点卡牌后选择信息或添加/移除　·　1、2 号为主动技能位" % selected_count
	var total_cost := 0.0
	var dynamic_cost := false
	for selected_id in _deck_selected:
		if not String(selected_id).is_empty():
			total_cost += float(CardDB.get_card(String(selected_id)).cost)
			dynamic_cost = dynamic_cost or CardPlayHistory.is_mirror(String(selected_id))
	if _deck_average_label != null:
		_deck_average_label.text = "平均金币  动态" if dynamic_cost else ("平均金币  --" if selected_count == 0 else "平均金币  %.2f" % (total_cost / selected_count))
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
		_deck_confirm.text = "开始对战" if ready else "请选择 8 张卡"

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
	_deck_filter_option = null
	_deck_sort_option = null
	_deck_pending_slot = -1
	_deck_context_popup = null
	_deck_context_info = null
	_deck_context_action = null
	_deck_context_card_id = ""
	_deck_context_slot = -1
	_deck_context_from_pool = false
	_deck_context_anchor = null
	queue_free()
