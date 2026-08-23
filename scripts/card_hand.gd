class_name CardHand
extends CanvasLayer
## 底部手牌 UI：4 张手牌 + 圣水条。
## CR 轮换机制：8 张卡组，4 张手牌，用一张从队列补一张。

signal card_selected(card_id: String)

var _elixir: ElixirManager
var _selected := ""
var _button_slots: Array[Button] = []
var _elixir_bar: ProgressBar
var _elixir_label: Label
var _next_label: Label

# 卡组轮换
var _hand: Array[String] = []   # 当前4张手牌
var _queue: Array[String] = []  # 等待队列4张
var _deck: Array = []           # 本次对战选定的 8 张卡组（空则随机 8 张）

func setup(elixir: ElixirManager, deck: Array = []) -> void:
	_elixir = elixir
	_deck = deck
	_init_deck()
	_build_ui()
	_elixir.changed.connect(_refresh)

func clear_selection() -> void:
	for b in _button_slots:
		b.button_pressed = false
	_selected = ""

## 卡牌使用后：从队列补一张，用过的牌排到队尾
func card_used(card_id: String) -> void:
	var idx := _hand.find(card_id)
	if idx < 0:
		return
	_hand[idx] = _queue.pop_front()
	_queue.push_back(card_id)
	_refresh(_elixir.elixir)

func _init_deck() -> void:
	# 优先使用对战前选定的 8 张卡组；未指定时从全部卡里随机取 8 张。
	var pool: Array = _deck.duplicate() if _deck.size() == 8 else []
	if pool.is_empty():
		pool = CardDB.all().keys()
		pool.shuffle()
		pool = pool.slice(0, 8)
	_hand.clear()
	_queue.clear()
	for i in range(4):
		_hand.append(pool[i])
	for i in range(4, 8):
		_queue.append(pool[i])

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 手牌区位于 720x1280 战场之外，不能遮住国王塔后的最后一行部署格。
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(0.0, 120.0)
	root.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# 圣水条
	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bar_row)
	_elixir_bar = ProgressBar.new()
	_elixir_bar.max_value = ElixirManager.MAX_ELIXIR
	_elixir_bar.custom_minimum_size = Vector2(560, 22)
	_elixir_bar.show_percentage = false
	bar_row.add_child(_elixir_bar)
	_elixir_label = Label.new()
	bar_row.add_child(_elixir_label)

	# 下一张卡预览
	_next_label = Label.new()
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_next_label)

	# 4 张手牌按钮
	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 10)
	vbox.add_child(card_row)
	for i in range(4):
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 70)
		b.pressed.connect(_on_slot_pressed.bind(i))
		card_row.add_child(b)
		_button_slots.append(b)
	_refresh(_elixir.elixir)

func _on_slot_pressed(slot_idx: int) -> void:
	var card_id := _hand[slot_idx]
	if _selected == card_id:
		clear_selection()
	else:
		clear_selection()
		_selected = card_id
		_button_slots[slot_idx].button_pressed = true
	card_selected.emit(_selected)

func _refresh(_value: float) -> void:
	if _elixir_bar == null:
		return
	_elixir_bar.value = _elixir.elixir
	_elixir_label.text = "金币 %d/%d" % [int(_elixir.elixir), int(ElixirManager.MAX_ELIXIR)]
	# 下一张卡预览
	if _next_label != null and _queue.size() > 0:
		var next_stats: Dictionary = CardDB.all()[_queue[0]]
		_next_label.text = "下一张: %s" % next_stats.name
	# 更新4张手牌按钮
	for i in range(4):
		var card_id := _hand[i]
		var stats: Dictionary = CardDB.all()[card_id]
		var b: Button = _button_slots[i]
		var type_tag := ""
		var type: String = stats.get("type", "unit")
		match type:
			"spell":
				type_tag = "[法术]"
			"building":
				type_tag = "[建筑]"
			_:
				type_tag = ""
		b.text = "%s %s\n%d 费" % [stats.name, type_tag, stats.cost]
		b.disabled = not _elixir.can_afford(stats.cost) and card_id != _selected
