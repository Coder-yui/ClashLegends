class_name ActiveSkillBar
extends CanvasLayer
## 主动技能按钮只负责发出请求；技能是否可用及实际效果始终由主机权威校验。

signal skill_pressed(ability_id: int)

const BUTTON_SIZE := Vector2(58.0, 58.0)
## 对齐战场底部两侧、手牌区上方的固定圆位（720×1400 设计分辨率）。
const DESIGN_WIDTH := 720.0
const LEFT_SLOT_POSITION := Vector2(23.0, 1195.0)
const RIGHT_SLOT_POSITION := Vector2(DESIGN_WIDTH - LEFT_SLOT_POSITION.x - BUTTON_SIZE.x, LEFT_SLOT_POSITION.y)
const SLOT_POSITIONS := [LEFT_SLOT_POSITION, RIGHT_SLOT_POSITION]

## 按钮只读取 Main 的统一提交资格，不自行维护战斗或经济门禁。
var can_submit: Callable

var _buttons: Array[Button] = []
var _icons: Array[TextureRect] = []
var _pending_labels: Array[Label] = []
var _skill_names: Array[String] = ["", ""]
var _ability_ids: Array[int] = [-1, -1]
var _base_labels: Array[String] = ["", ""]
var _deployment_ready: Array[bool] = [false, false]
var _pending: Array[bool] = [false, false]
var _skill_costs: Array[float] = [0.0, 0.0]
var _max_uses: Array[int] = [1, 1]
var _uses_remaining: Array[int] = [0, 0]
var _cooldowns: Array[float] = [0.0, 0.0]
var _elixir := 0.0
var _rule_labels: Array[Label] = []


func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	for slot_index in range(2):
		var button := Button.new()
		button.position = SLOT_POSITIONS[slot_index]
		button.size = BUTTON_SIZE
		button.custom_minimum_size = BUTTON_SIZE
		button.clip_contents = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", CardArt.ui_font())
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.07))
		button.add_theme_constant_override("outline_size", 5)
		button.pressed.connect(_on_slot_pressed.bind(slot_index))
		button.visible = false
		root.add_child(button)
		_buttons.append(button)
		var icon := TextureRect.new()
		icon.position = Vector2(4.0, 4.0)
		icon.size = BUTTON_SIZE - Vector2(8.0, 8.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = preload("res://scripts/ui/skill_icon_circle.gdshader")
		icon.material = material
		button.add_child(icon)
		_icons.append(icon)
		var pending_label := Label.new()
		pending_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pending_label.add_theme_font_override("font", CardArt.ui_font())
		pending_label.add_theme_font_size_override("font_size", 24)
		pending_label.add_theme_color_override("font_outline_color", Color.BLACK)
		pending_label.add_theme_constant_override("outline_size", 5)
		pending_label.text = "…"
		pending_label.visible = false
		pending_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(pending_label)
		_pending_labels.append(pending_label)
		var rule_label := Label.new()
		rule_label.position = Vector2(clampf(SLOT_POSITIONS[slot_index].x + BUTTON_SIZE.x * 0.5 - 60.0, 4.0, DESIGN_WIDTH - 124.0), SLOT_POSITIONS[slot_index].y + BUTTON_SIZE.y + 2.0)
		rule_label.size = Vector2(120.0, 20.0)
		rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rule_label.add_theme_font_override("font", CardArt.ui_font())
		rule_label.add_theme_font_size_override("font_size", 12)
		rule_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
		rule_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.07))
		rule_label.add_theme_constant_override("outline_size", 4)
		rule_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule_label.visible = false
		root.add_child(rule_label)
		_rule_labels.append(rule_label)


func show_skill(slot_index: int, ability_id: int, skill_name: String, accent: Color, skill_cost: float = 0.0, max_uses: int = 1, uses_remaining: int = 1, cooldown: float = 0.0, deployment_ready: bool = true, icon: Texture2D = null) -> void:
	if slot_index < 0 or slot_index >= _buttons.size():
		return
	var button := _buttons[slot_index]
	_ability_ids[slot_index] = ability_id
	_skill_names[slot_index] = skill_name
	_icons[slot_index].texture = icon
	_icons[slot_index].visible = icon != null
	_base_labels[slot_index] = skill_name.left(1) if icon == null else ""
	_deployment_ready[slot_index] = deployment_ready
	_pending[slot_index] = false
	_skill_costs[slot_index] = maxf(skill_cost, 0.0)
	_max_uses[slot_index] = maxi(max_uses, 1)
	_uses_remaining[slot_index] = clampi(uses_remaining, 0, _max_uses[slot_index])
	_cooldowns[slot_index] = maxf(cooldown, 0.0)
	button.text = _base_labels[slot_index]
	button.tooltip_text = ""
	button.add_theme_stylebox_override("normal", _circle_style(Color(accent.r * 0.34, accent.g * 0.34, accent.b * 0.34, 0.96), Color.WHITE, 3))
	button.add_theme_stylebox_override("hover", _circle_style(Color(accent.r * 0.55, accent.g * 0.55, accent.b * 0.55, 1.0), Color(0.62, 0.90, 1.0), 4))
	button.add_theme_stylebox_override("pressed", _circle_style(Color(accent.r * 0.24, accent.g * 0.24, accent.b * 0.24, 1.0), Color(1.0, 0.84, 0.28), 4))
	button.add_theme_stylebox_override("disabled", _circle_style(Color(0.08, 0.12, 0.18, 0.88), Color(0.42, 0.52, 0.62), 3))
	button.visible = true
	_refresh_slot(slot_index)


func is_pending(ability_id: int) -> bool:
	var slot := _ability_ids.find(ability_id)
	return slot >= 0 and _pending[slot]


func set_pending(ability_id: int, pending: bool) -> void:
	var slot_index := _ability_ids.find(ability_id)
	if slot_index < 0:
		return
	_pending[slot_index] = pending
	_refresh_slot(slot_index)


func remove_skill(ability_id: int) -> void:
	var slot_index := _ability_ids.find(ability_id)
	if slot_index < 0:
		return
	_ability_ids[slot_index] = -1
	_base_labels[slot_index] = ""
	_skill_names[slot_index] = ""
	_icons[slot_index].texture = null
	_icons[slot_index].visible = false
	_pending_labels[slot_index].visible = false
	_deployment_ready[slot_index] = false
	_pending[slot_index] = false
	_skill_costs[slot_index] = 0.0
	_max_uses[slot_index] = 1
	_uses_remaining[slot_index] = 0
	_cooldowns[slot_index] = 0.0
	_buttons[slot_index].visible = false
	_buttons[slot_index].disabled = false
	_buttons[slot_index].text = ""
	if slot_index < _rule_labels.size():
		_rule_labels[slot_index].visible = false


func current_ability_id(slot_index: int) -> int:
	return _ability_ids[slot_index] if slot_index >= 0 and slot_index < _ability_ids.size() else -1


func set_elixir(value: float) -> void:
	_elixir = maxf(value, 0.0)
	for slot_index in _buttons.size():
		_refresh_slot(slot_index)


func update_skill_state(ability_id: int, uses_remaining: int, cooldown: float, deployment_ready: bool, skill_cost: float, max_uses: int) -> void:
	var slot_index := _ability_ids.find(ability_id)
	if slot_index < 0:
		return
	if _uses_remaining[slot_index] == clampi(uses_remaining, 0, maxi(max_uses, 1)) and _max_uses[slot_index] == maxi(max_uses, 1) and is_equal_approx(_cooldowns[slot_index], maxf(cooldown, 0.0)) and is_equal_approx(_skill_costs[slot_index], maxf(skill_cost, 0.0)) and _deployment_ready[slot_index] == deployment_ready:
		return
	_uses_remaining[slot_index] = clampi(uses_remaining, 0, maxi(max_uses, 1))
	_max_uses[slot_index] = maxi(max_uses, 1)
	_cooldowns[slot_index] = maxf(cooldown, 0.0)
	_skill_costs[slot_index] = maxf(skill_cost, 0.0)
	_deployment_ready[slot_index] = deployment_ready
	_refresh_slot(slot_index)


func is_slot_visible(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _buttons.size() and _buttons[slot_index].visible


func _on_slot_pressed(slot_index: int) -> void:
	var ability_id := current_ability_id(slot_index)
	if ability_id < 0:
		return
	skill_pressed.emit(ability_id)


func _refresh_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _buttons.size():
		return
	var button := _buttons[slot_index]
	var cooldown := _cooldowns[slot_index]
	var uses_remaining := _uses_remaining[slot_index]
	var skill_cost := _skill_costs[slot_index]
	button.disabled = not can_submit.is_valid() or not can_submit.call(_ability_ids[slot_index])
	button.text = "" if _pending[slot_index] else _base_labels[slot_index]
	_pending_labels[slot_index].visible = _pending[slot_index]
	_icons[slot_index].modulate = Color(0.42, 0.42, 0.42) if button.disabled or _pending[slot_index] else Color.WHITE
	if slot_index < _rule_labels.size():
		var rule_label := _rule_labels[slot_index]
		rule_label.visible = button.visible
		rule_label.text = "金币 %s · 次数 %d/%d" % [_format_number(skill_cost), uses_remaining, _max_uses[slot_index]]
	var state := "可用"
	if _pending[slot_index]:
		state = "等待权威执行"
	elif not _deployment_ready[slot_index]:
		state = "部署中"
	elif uses_remaining <= 0:
		state = "次数已用尽"
	elif cooldown > 0.001:
		state = "冷却 %s秒" % BattleNumbers.format_value(cooldown)
	elif _elixir < skill_cost:
		state = "金币不足"
	button.tooltip_text = "%s · 主动槽 %d\n消耗 %s 金币 · 剩余 %d/%d 次 · 冷却 %s 秒\n%s" % [_skill_names[slot_index], slot_index + 1, BattleNumbers.format_value(skill_cost), uses_remaining, _max_uses[slot_index], BattleNumbers.format_value(cooldown), state]


func _format_number(value: float) -> String:
	return BattleNumbers.format_value(value)


func _circle_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(99)
	style.anti_aliasing = true
	return style
