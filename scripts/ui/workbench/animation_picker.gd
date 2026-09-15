extends Button
## 保留紧凑的下拉选择，展开后逐行使用 ItemList 的文字颜色。
signal item_selected(index: int)
const MAPPED_COLOR := Color("73dfb2")
const UNMAPPED_COLOR := Color("a3afc0")
var selected := -1
var item_count: int:
	get: return _list.item_count
var _popup := PopupPanel.new()
var _list := ItemList.new()

func _ready() -> void:
	clip_text = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("172537")
	panel_style.border_color = Color("405570")
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(8)
	_popup.add_theme_stylebox_override("panel", panel_style)
	add_child(_popup)
	_list.custom_minimum_size = Vector2(600, 400)
	_list.add_theme_constant_override("v_separation", 8)
	_popup.add_child(_list)
	pressed.connect(_open)
	_list.item_selected.connect(func(index):
		select(index)
		_popup.hide()
		item_selected.emit(index))

func _open() -> void:
	var viewport_size := get_viewport_rect().size
	var popup_size := Vector2(minf(size.x, viewport_size.x - 32), minf(440, viewport_size.y - 64))
	_list.custom_minimum_size = popup_size
	_popup.popup(Rect2i(Vector2i(Vector2(global_position.x, maxf(16, global_position.y - popup_size.y))), Vector2i(popup_size)))
	if selected >= 0:
		_list.select(selected)
		_list.ensure_current_is_visible()
	_list.grab_focus()

func clear() -> void:
	_list.clear()
	selected = -1
	text = "无动画"

func add_item(label: String) -> void:
	_list.add_item(label)

func set_item_metadata(index: int, value: Variant) -> void:
	_list.set_item_metadata(index, value)

func get_item_metadata(index: int) -> Variant:
	return _list.get_item_metadata(index)

func set_item_mapped(index: int, mapped: bool) -> void:
	_list.set_item_custom_fg_color(index, MAPPED_COLOR if mapped else UNMAPPED_COLOR)

func select(index: int) -> void:
	if index < 0 or index >= item_count:
		return
	selected = index
	_list.select(index)
	text = _list.get_item_text(index)
	add_theme_color_override("font_color", _list.get_item_custom_fg_color(index))
