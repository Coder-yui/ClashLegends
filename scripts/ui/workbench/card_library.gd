extends VBoxContainer
## 可搜索的正式内容目录；浏览选择与加入实验快捷栏是两个独立动作。
signal selected(id: String)
signal toggled(id: String)
signal closed
const CATALOG := preload("res://scripts/ui/workbench/card_catalog.gd")
var cards: Dictionary
var entries: Array[Dictionary] = []
var shelf: Array[String] = []
var search: LineEdit
var _category := "all"
var _grid: GridContainer
var _hint: Label
var multiple := false
var models_only := false
var _shelf_grid: GridContainer

func setup(definitions: Dictionary) -> void:
	cards = definitions
	add_theme_constant_override("separation", 10)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	search = LineEdit.new()
	search.placeholder_text = "搜索中文名称 / ID"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 42
	search.text_changed.connect(filter)
	toolbar.add_child(search)
	var close := Button.new()
	close.text = "完成选择 · 关闭"
	close.pressed.connect(func(): closed.emit())
	toolbar.add_child(close)
	var categories := HBoxContainer.new()
	add_child(categories)
	var group := ButtonGroup.new()
	for entry in [["全部", "all"], ["单位", "unit"], ["建筑", "building"], ["法术", "spell"], ["衍生 / 形态", "system"]]:
		var button := Button.new()
		button.text = entry[0]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = entry[1] == "all"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():
			_category = entry[1]
			filter(search.text))
		categories.add_child(button)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 16)
	add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	_shelf_grid = GridContainer.new()
	_shelf_grid.columns = 4
	_shelf_grid.add_theme_constant_override("h_separation", 8)
	_shelf_grid.add_theme_constant_override("v_separation", 8)
	add_child(_shelf_grid)
	filter("")

func filter(query: String) -> void:
	entries = CATALOG.entries(cards, query, _category)
	if models_only:
		entries = entries.filter(func(entry): return not (entry.id.ends_with(":1") and cards.get(entry.base_id, {}).has("deployment_upgrade_id")))
		entries = entries.filter(func(entry): return not PresentationConfig.scene_path(CATALOG.stats_for_form(cards.get(entry.base_id, {}), 1 if entry.id.ends_with(":1") else 0), 0).is_empty())
	entries = entries.filter(func(entry): return entry.id != "training_dummy")
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_hint.text = ("%d 个结果 · 点击加入 · 下方点击移除 · %d/8" % [entries.size(), shelf.size()]) if multiple else ("%d 个对象 · 点击方块选中" % entries.size())
	if entries.is_empty(): _hint.text = "没有匹配的卡牌，试试其他名称或分类。"
	for entry in entries:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(cell)
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 136)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.clip_text = true
		cell.add_child(card)
		CardArt.apply_to_button(card, entry.base_id, entry.name, int(cards.get(entry.base_id, {}).get("cost", 0)), true)
		card.tooltip_text = entry.name + " · " + entry.id
		card.disabled = multiple and (entry.id in shelf or shelf.size() >= 8)
		card.pressed.connect(func():
			if multiple: toggled.emit(entry.id)
			else: selected.emit(entry.id))
		CardArt.set_selected(card, entry.id in shelf, true)
	_shelf_grid.visible = multiple
	for child in _shelf_grid.get_children():
		_shelf_grid.remove_child(child)
		child.queue_free()
	if multiple:
		for i in 8:
			var slot := Button.new()
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.custom_minimum_size.y = 52
			slot.clip_text = true
			_shelf_grid.add_child(slot)
			if i < shelf.size():
				var id := shelf[i]
				var definition := CATALOG.stats_for_form(cards.get(id.get_slice(":", 0), {}), 1 if id.ends_with(":1") else 0)
				slot.text = "%d · %s ×" % [i + 1, definition.get("name", id)]
				slot.pressed.connect(func(): toggled.emit(id))
			else:
				slot.text = "%d · 空槽" % (i + 1)
				slot.disabled = true

func configure(edit_shelf: bool, only_models: bool) -> void:
	multiple = edit_shelf
	models_only = only_models
	filter(search.text)

func update_shelf(value: Array[String]) -> void:
	shelf = value.duplicate()
	filter(search.text)
