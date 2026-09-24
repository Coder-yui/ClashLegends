extends VBoxContainer
## 常驻动作列表；已接入与未使用片段保持独立颜色，点击直接播放。
signal item_selected(index: int)
const MAPPED_COLOR := Color("73dfb2")
const UNMAPPED_COLOR := Color("a3afc0")
var selected := -1
var disabled := false:
	set(value):
		disabled = value
		_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
var item_count: int:
	get: return _list.item_count
var _list := ItemList.new()

func _ready() -> void:
	var legend := Label.new()
	legend.text = "全部动作 · 绿色已接入 / 灰色未使用 · 点击播放"
	legend.add_theme_font_size_override("font_size", 16)
	add_child(legend)
	_list.custom_minimum_size = Vector2(0, 300)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("v_separation", 8)
	add_child(_list)
	_list.item_selected.connect(func(index):
		selected = index
		item_selected.emit(index))

func clear() -> void:
	_list.clear()
	selected = -1

func add_item(label: String) -> void:
	var index := _list.add_item(label)
	_list.set_item_tooltip(index, label)

func set_item_metadata(index: int, value: Variant) -> void:
	_list.set_item_metadata(index, value)

func get_item_metadata(index: int) -> Variant:
	return _list.get_item_metadata(index)

func set_item_mapped(index: int, mapped: bool) -> void:
	_list.set_item_custom_fg_color(index, MAPPED_COLOR if mapped else UNMAPPED_COLOR)

func select(index: int) -> void:
	if index < 0 or index >= item_count: return
	selected = index
	_list.select(index)
	_list.ensure_current_is_visible()
