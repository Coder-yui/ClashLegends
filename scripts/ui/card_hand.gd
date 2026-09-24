class_name CardHand
extends CanvasLayer
## 底部手牌 UI：4 张手牌 + 金币条。
## CR 轮换机制：8 张卡组，4 张手牌，用一张从队列补一张。

signal card_selected(card_id: String)

var _elixir: ElixirManager
var _selected := ""
var cost_query: Callable
var visual_card_query: Callable
var growth_progress_query: Callable
var _mirror_copy: Dictionary = {}
var _button_slots: Array[Button] = []
var _elixir_bar: ProgressBar
var _elixir_label: Label
var _next_label: Label
var _next_button: Button

const BATTLE_FIELD_HEIGHT := 1280.0
const HAND_AREA_HEIGHT := 120.0
const HAND_CARD_HEIGHT := 86.0
const HAND_CARD_WIDTH := 112.0

# 卡组轮换
var _hand: Array[String] = []   # 当前4张手牌
var _queue: Array[String] = []  # 等待队列4张
var _deck: Array = []           # 本次对战选定的 8 张卡组（空则随机 8 张）
var _pending_cards: Dictionary = {}  # 客户端已发出、等待主机确认的卡牌
var _active_skill_cards: Dictionary = {}  # 卡牌 ID -> 主动槽序号；标记跟随卡牌轮换

func setup(elixir: ElixirManager, deck: Array = []) -> void:
	_elixir = elixir
	_deck = deck
	_init_deck()
	_build_ui()
	_elixir.changed.connect(_refresh)

func clear_selection() -> void:
	for b in _button_slots:
		b.button_pressed = false
		CardArt.set_selected(b, false)
	_selected = ""

func get_hand() -> Array[String]:
	return _hand.duplicate()

func get_queue() -> Array[String]:
	return _queue.duplicate()

func get_deck() -> Array:
	return _deck.duplicate()

## 设置本局前两个卡位中的主动卡；表现标记只绑定 card_id，不绑定当前手牌索引。
func set_active_skill_cards(card_ids: Array) -> void:
	_active_skill_cards.clear()
	for slot_index in range(mini(card_ids.size(), 2)):
		var card_id := String(card_ids[slot_index])
		if card_id.is_empty() or not CardDB.has_card(card_id):
			continue
		_active_skill_cards[card_id] = slot_index
	_refresh(_elixir.elixir if _elixir != null else 0.0)

## 手牌只是权威 Card Cycle 的表现视图；主机确认后的完整状态由 Main 推送到这里。
func set_cycle_state(hand: Array, queue: Array) -> void:
	if hand.size() != 4 or queue.size() != 4:
		return
	_hand.clear()
	_queue.clear()
	for card_id in hand:
		_hand.append(String(card_id))
	for card_id in queue:
		_queue.append(String(card_id))
	_refresh(_elixir.elixir if _elixir != null else 0.0)

func set_card_pending(card_id: String, pending: bool) -> void:
	if pending:
		_pending_cards[card_id] = true
	else:
		_pending_cards.erase(card_id)
	_refresh(_elixir.elixir if _elixir != null else 0.0)

func is_card_pending(card_id: String) -> bool:
	return bool(_pending_cards.get(card_id, false))

## 卡牌使用后：从队列补一张，用过的牌排到队尾
func card_used(card_id: String) -> void:
	var idx := _hand.find(card_id)
	if idx < 0:
		return
	_hand[idx] = _queue.pop_front()
	_queue.push_back(card_id)
	_pending_cards.erase(card_id)
	_refresh(_elixir.elixir)

func _init_deck() -> void:
	# 优先使用对战前选定的 8 张卡组；未指定时从全部卡里随机取 8 张。
	var pool: Array = _deck.duplicate() if _deck.size() == 8 else []
	if pool.is_empty():
		pool = CardDB.selectable_ids()
		pool.shuffle()
		pool = pool.slice(0, 8)
	var cycle := CardCycle.new(pool)
	_hand.assign(cycle.hand())
	_queue.assign(cycle.queue())

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 手牌区固定在 1280~1400 的场外区域，卡框不能回伸到竞技场。
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = BATTLE_FIELD_HEIGHT
	panel.offset_bottom = BATTLE_FIELD_HEIGHT + HAND_AREA_HEIGHT
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.custom_minimum_size = Vector2(0.0, HAND_AREA_HEIGHT)
	panel.add_theme_stylebox_override("panel", CardArt.frame_style(Color(0.018, 0.085, 0.17, 0.99), Color(0.08, 0.50, 0.86, 1.0), 3, 0))
	root.add_child(panel)
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 10)
	content_margin.add_theme_constant_override("margin_right", 10)
	content_margin.add_theme_constant_override("margin_top", 2)
	content_margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(content_margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	content_margin.add_child(vbox)

	# 参考皇室战争：左侧下一张预览，中间是当前4张手牌。
	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 10)
	vbox.add_child(card_row)
	var next_drawer := PanelContainer.new()
	next_drawer.custom_minimum_size = Vector2(66.0, HAND_CARD_HEIGHT)
	next_drawer.add_theme_stylebox_override("panel", CardArt.frame_style(Color(0.025, 0.12, 0.24, 0.98), Color(0.10, 0.34, 0.58), 2, 7))
	card_row.add_child(next_drawer)
	var next_column := VBoxContainer.new()
	next_column.alignment = BoxContainer.ALIGNMENT_CENTER
	next_column.add_theme_constant_override("separation", 1)
	next_drawer.add_child(next_column)
	_next_label = Label.new()
	_next_label.text = "下一张"
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_label.add_theme_font_size_override("font_size", 11)
	_next_label.add_theme_color_override("font_color", Color(0.63, 0.82, 1.0))
	next_column.add_child(_next_label)
	_next_button = Button.new()
	_next_button.focus_mode = Control.FOCUS_NONE
	_next_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_button.disabled = true
	CardArt.apply_frame(_next_button, 60.0, true, 50.0)
	next_column.add_child(_next_button)
	var hand_row := HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.add_theme_constant_override("separation", 6)
	card_row.add_child(hand_row)
	# 4 张手牌按钮
	for i in range(4):
		var b := Button.new()
		b.toggle_mode = true
		CardArt.apply_frame(b, HAND_CARD_HEIGHT, true, HAND_CARD_WIDTH)
		b.pressed.connect(_on_slot_pressed.bind(i))
		hand_row.add_child(b)
		_button_slots.append(b)

	# 金币条放在当前手牌下方，卡牌抽屉不占用竞技场空间。
	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bar_row)
	_elixir_bar = ProgressBar.new()
	_elixir_bar.max_value = ElixirManager.MAX_ELIXIR
	_elixir_bar.custom_minimum_size = Vector2(500, 19)
	_elixir_bar.show_percentage = false
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.04, 0.12, 0.23, 0.95)
	bar_background.set_corner_radius_all(8)
	bar_background.border_color = Color(0.36, 0.08, 0.48, 0.95)
	bar_background.set_border_width_all(2)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.86, 0.18, 0.96, 1.0)
	bar_fill.set_corner_radius_all(8)
	_elixir_bar.add_theme_stylebox_override("background", bar_background)
	_elixir_bar.add_theme_stylebox_override("fill", bar_fill)
	var elixir_orb := Label.new()
	elixir_orb.text = "●"
	elixir_orb.add_theme_font_size_override("font_size", 18)
	elixir_orb.add_theme_color_override("font_color", Color(0.90, 0.24, 1.0))
	elixir_orb.add_theme_color_override("font_outline_color", Color(0.18, 0.01, 0.25))
	elixir_orb.add_theme_constant_override("outline_size", 4)
	bar_row.add_child(elixir_orb)
	_elixir_label = Label.new()
	_elixir_label.custom_minimum_size = Vector2(28.0, 0.0)
	_elixir_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_elixir_label.add_theme_font_size_override("font_size", 18)
	_elixir_label.add_theme_color_override("font_color", Color.WHITE)
	_elixir_label.add_theme_color_override("font_outline_color", Color(0.12, 0.01, 0.17))
	_elixir_label.add_theme_constant_override("outline_size", 4)
	bar_row.add_child(_elixir_label)
	bar_row.add_child(_elixir_bar)
	# 细分刻度让资源条更容易估算每张牌还差多少金币。
	for i in range(1, int(ElixirManager.MAX_ELIXIR)):
		var tick := ColorRect.new()
		tick.color = Color(0.12, 0.015, 0.18, 0.52)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.anchor_left = float(i) / ElixirManager.MAX_ELIXIR
		tick.anchor_right = float(i) / ElixirManager.MAX_ELIXIR
		tick.anchor_top = 0.18
		tick.anchor_bottom = 0.82
		tick.offset_left = -1.0
		tick.offset_right = 1.0
		_elixir_bar.add_child(tick)
	_refresh(_elixir.elixir)

func _on_slot_pressed(slot_idx: int) -> void:
	var card_id := _hand[slot_idx]
	if is_card_pending(card_id):
		return
	if _selected == card_id:
		clear_selection()
	else:
		clear_selection()
		_selected = card_id
		_button_slots[slot_idx].button_pressed = true
		CardArt.set_selected(_button_slots[slot_idx], true)
	card_selected.emit(_selected)

func _refresh(_value: float) -> void:
	if _elixir_bar == null:
		return
	_elixir_bar.value = _elixir.elixir
	_elixir_label.text = str(int(_elixir.elixir))
	# 下一张卡预览
	if _next_label != null and _next_button != null and _queue.size() > 0:
		var next_stats: Dictionary = CardDB.get_card(_queue[0])
		_next_label.text = "下一张"
		var next_accent: Color = next_stats.get("color", CardArt.DEFAULT_ACCENT)
		_apply_card(_next_button, _queue[0], next_stats, next_accent)
		CardArt.set_affordable(_next_button, true)
	# 更新4张手牌按钮
	for i in range(4):
		var card_id := _hand[i]
		var stats: Dictionary = CardDB.get_card(card_id)
		var b: Button = _button_slots[i]
		var accent: Color = stats.get("color", CardArt.DEFAULT_ACCENT)
		_apply_card(b, card_id, stats, accent)
		CardArt.set_active_skill_card(b, _active_skill_cards.has(card_id))
		var affordable := _elixir.can_afford(_display_cost(card_id, stats))
		var pending := is_card_pending(card_id)
		CardArt.set_affordable(b, (affordable or card_id == _selected) and not pending)
		CardArt.set_selected(b, card_id == _selected and not pending)
		b.disabled = pending or (not affordable and card_id != _selected)

## 主动槽法术卡按 active_cost_bonus 提升显示费用（治疗术主动选项 +1）；其余卡返回原费用。
func _display_cost(card_id: String, stats: Dictionary) -> int:
	if cost_query.is_valid(): return int(cost_query.call(card_id))
	if CardPlayHistory.is_mirror(card_id): return int(_mirror_copy.get("cost", 99))
	var cost := CardDB.deployment_cost(card_id, _elixir.elixir if _elixir != null else 0.0)
	if _active_skill_cards.has(card_id) and StringName(stats.get("type", "")) == &"spell":
		var cost_bonus := int(stats.get("active_cost_bonus", 0))
		if cost_bonus > 0:
			return cost + cost_bonus
	return cost

func set_mirror_copy(value: Dictionary) -> void:
	_mirror_copy = value.duplicate(true)
	_refresh(0.0)

func _apply_card(button: Button, card_id: String, stats: Dictionary, accent: Color) -> void:
	var actual_id := String(visual_card_query.call(card_id)) if visual_card_query.is_valid() else card_id
	if actual_id != card_id:
		stats = CardDB.get_card(actual_id)
		accent = stats.get("color", accent)
	var mirrored := CardPlayHistory.is_mirror(card_id)
	var source := String(_mirror_copy.get("card_id", "")) if mirrored else ""
	var title := String(stats.name)
	button.tooltip_text = String(stats.get("description", ""))
	if growth_progress_query.is_valid() and CardDB.get_card(card_id).has("growth_ranged_id"):
		var progress: Dictionary = growth_progress_query.call(card_id)
		button.tooltip_text += "\n本局成长：远程 %d/%d，近战 %d/%d" % [int(progress.get("ranged",0)),int(CardDB.get_card(card_id).growth_ranged_hits),int(progress.get("melee",0)),int(CardDB.get_card(card_id).growth_melee_hits)]
	if not source.is_empty(): title = "镜·" + String(CardDB.get_card(source).name)
	CardArt.apply_to_button(button, source if not source.is_empty() else actual_id, title, _display_cost(card_id, stats), true, Color(0.48, 0.91, 1.0) if mirrored else accent)
	CardArt.set_mirror_overlay(button, mirrored and not source.is_empty())
	if mirrored and source.is_empty():
		(button.get_node("CardCostBadge/CardCost") as Label).text = "?"
	if mirrored:
		button.tooltip_text = "镜像法术：" + ("尚未使用其他卡牌" if source.is_empty() else String(CardDB.get_card(source).name))
