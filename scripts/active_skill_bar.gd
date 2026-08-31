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

var _buttons: Array[Button] = []
var _ability_ids: Array[int] = [-1, -1]
var _base_labels: Array[String] = ["", ""]
var _deployment_ready: Array[bool] = [false, false]
var _pending: Array[bool] = [false, false]


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


func show_skill(slot_index: int, ability_id: int, card_name: String, skill_name: String, accent: Color, deployment_ready: bool = true) -> void:
	if slot_index < 0 or slot_index >= _buttons.size():
		return
	var button := _buttons[slot_index]
	_ability_ids[slot_index] = ability_id
	_base_labels[slot_index] = skill_name.left(1)
	_deployment_ready[slot_index] = deployment_ready
	_pending[slot_index] = false
	button.text = _base_labels[slot_index]
	button.tooltip_text = "主动槽 %d · %s · %s\n部署完成后可点击；点击后等待 0.5 秒，由最近部署的该槽单位释放" % [slot_index + 1, card_name, skill_name]
	button.add_theme_stylebox_override("normal", _circle_style(Color(accent.r * 0.34, accent.g * 0.34, accent.b * 0.34, 0.96), Color.WHITE, 3))
	button.add_theme_stylebox_override("hover", _circle_style(Color(accent.r * 0.55, accent.g * 0.55, accent.b * 0.55, 1.0), Color(0.62, 0.90, 1.0), 4))
	button.add_theme_stylebox_override("pressed", _circle_style(Color(accent.r * 0.24, accent.g * 0.24, accent.b * 0.24, 1.0), Color(1.0, 0.84, 0.28), 4))
	button.add_theme_stylebox_override("disabled", _circle_style(Color(0.08, 0.12, 0.18, 0.88), Color(0.42, 0.52, 0.62), 3))
	_refresh_slot(slot_index)
	button.visible = true


func set_pending(ability_id: int, pending: bool) -> void:
	var slot_index := _ability_ids.find(ability_id)
	if slot_index < 0:
		return
	_pending[slot_index] = pending
	_refresh_slot(slot_index)


func set_deployment_ready(ability_id: int, ready: bool) -> void:
	var slot_index := _ability_ids.find(ability_id)
	if slot_index < 0:
		return
	_deployment_ready[slot_index] = ready
	_refresh_slot(slot_index)


func remove_skill(ability_id: int) -> void:
	var slot_index := _ability_ids.find(ability_id)
	if slot_index < 0:
		return
	_ability_ids[slot_index] = -1
	_base_labels[slot_index] = ""
	_deployment_ready[slot_index] = false
	_pending[slot_index] = false
	_buttons[slot_index].visible = false
	_buttons[slot_index].disabled = false
	_buttons[slot_index].text = ""


func current_ability_id(slot_index: int) -> int:
	return _ability_ids[slot_index] if slot_index >= 0 and slot_index < _ability_ids.size() else -1


func is_slot_visible(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _buttons.size() and _buttons[slot_index].visible


func _on_slot_pressed(slot_index: int) -> void:
	var ability_id := current_ability_id(slot_index)
	if ability_id < 0:
		return
	set_pending(ability_id, true)
	skill_pressed.emit(ability_id)


func _refresh_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _buttons.size():
		return
	var button := _buttons[slot_index]
	button.disabled = _pending[slot_index] or not _deployment_ready[slot_index]
	button.text = "…" if _pending[slot_index] else _base_labels[slot_index]


func _circle_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(99)
	style.anti_aliasing = true
	return style
