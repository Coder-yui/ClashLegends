class_name ActiveSkillBar
extends CanvasLayer
## 资格与计时来自现有权威/副本；只发请求，不自行扣费、扣次数或推进CD。
signal skill_pressed(ability_id: int)
const LAYOUT := preload("res://scripts/ui/battle_layout.gd")
const BUTTON := preload("res://scripts/ui/active_skill_button.gd")
const BUTTON_SIZE := Vector2.ONE * LAYOUT.SKILL_SIZE
const ICON_SIZE := Vector2(50, 50)
const DESIGN_WIDTH := 720.0
const LEFT_SLOT_POSITION := Vector2(23, 0)
const RIGHT_SLOT_POSITION := Vector2(DESIGN_WIDTH - LEFT_SLOT_POSITION.x - BUTTON_SIZE.x, 0)
const SLOT_POSITIONS := [LEFT_SLOT_POSITION, RIGHT_SLOT_POSITION]
var can_submit: Callable
var _buttons: Array = []
var _icons: Array[TextureRect] = []
var _pending_labels: Array[Label] = []
var _ability_ids: Array[int] = [-1, -1]
var _states: Array[Dictionary] = [{}, {}]
var _elixir := 0.0

func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.size = Vector2(DESIGN_WIDTH, 85)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	apply_layout(get_viewport().get_visible_rect().size)
	for slot in 2:
		var button := BUTTON.new()
		button.position = SLOT_POSITIONS[slot]
		button.visible = false
		root.add_child(button)
		button.pressed.connect(_on_slot_pressed.bind(slot))
		_buttons.append(button)
		_icons.append(button.skill_icon)
		_pending_labels.append(button.pending_label)

func apply_layout(view_size: Vector2) -> void:
	scale = Vector2.ONE * LAYOUT.ui_scale(view_size)
	offset = LAYOUT.skill_origin(view_size)

func show_skill(slot: int, ability_id: int, skill_name: String, _accent: Color, skill_cost: float = 0, max_uses: int = 1, uses_remaining: int = 1, cooldown: float = 0, deployment_ready: bool = true, icon: Texture2D = null, description: String = "") -> void:
	if slot < 0 or slot >= _buttons.size(): return
	_ability_ids[slot] = ability_id
	_states[slot] = {"name": skill_name, "description": description, "cost": skill_cost, "uses": uses_remaining,
		"unlimited": max_uses == 0, "cooldown_total": cooldown, "cooldown_left": 0.0, "free_recast": false,
		"deployment_ready": deployment_ready, "pending": false, "resource": {}, "locked": not deployment_ready, "reason": ""}
	_icons[slot].texture = icon
	_buttons[slot]._fallback = skill_name.left(1) if icon == null else ""
	_refresh_slot(slot)

func is_pending(ability_id: int) -> bool:
	var slot := _ability_ids.find(ability_id)
	return slot >= 0 and bool(_states[slot].get("pending", false))

func set_pending(ability_id: int, pending: bool) -> void:
	var slot := _ability_ids.find(ability_id)
	if slot < 0: return
	_states[slot].pending = pending
	_pending_labels[slot].text = "…"
	_refresh_slot(slot)

func set_pending_seconds(ability_id: int, seconds: float) -> void:
	var slot := _ability_ids.find(ability_id)
	if slot < 0 or not is_pending(ability_id): return
	_pending_labels[slot].text = BUTTON.countdown_text(seconds) if seconds > 0 else "…"

func remove_skill(ability_id: int) -> void:
	var slot := _ability_ids.find(ability_id)
	if slot < 0: return
	_ability_ids[slot] = -1
	_states[slot] = {}
	_icons[slot].texture = null
	_pending_labels[slot].visible = false
	_buttons[slot].visible = false
	_buttons[slot].disabled = true

func current_ability_id(slot: int) -> int:
	return _ability_ids[slot] if slot >= 0 and slot < _ability_ids.size() else -1

func set_elixir(value: float) -> void:
	_elixir = maxf(value, 0)
	for slot in _buttons.size(): _refresh_slot(slot)

func update_skill_state(ability_id: int, uses_remaining: int, cooldown: float, deployment_ready: bool, skill_cost: float, max_uses: int, free_recast: bool = false, presentation: Dictionary = {}) -> void:
	var slot := _ability_ids.find(ability_id)
	if slot < 0: return
	var state := _states[slot]
	state.uses = maxi(uses_remaining, 0)
	state.cooldown_left = maxf(cooldown, 0)
	state.deployment_ready = deployment_ready
	state.cost = maxf(skill_cost, 0)
	state.unlimited = max_uses == 0
	state.free_recast = free_recast
	state.resource = presentation.get("resource", {})
	state.locked = presentation.get("locked", not deployment_ready)
	state.reason = presentation.get("reason", "" if deployment_ready else "部署中")
	_refresh_slot(slot)

func is_slot_visible(slot: int) -> bool:
	return slot >= 0 and slot < _buttons.size() and _buttons[slot].visible

func _on_slot_pressed(slot: int) -> void:
	var id := current_ability_id(slot)
	if id < 0 or is_pending(id) or not can_submit.is_valid() or not can_submit.call(id): return
	skill_pressed.emit(id)

func _refresh_slot(slot: int) -> void:
	if slot < 0 or slot >= _buttons.size() or _states[slot].is_empty(): return
	var state := _states[slot]
	state.can_submit = not bool(state.pending) and can_submit.is_valid() and can_submit.call(_ability_ids[slot])
	# 免费重施本身仍是一份真实资格，即使付费次数已用尽也保留入口。
	state.has_uses = bool(state.unlimited) or int(state.uses) > 0 or bool(state.free_recast)
	state.poor = _elixir < float(state.cost)
	var reasons: Array[String] = []
	if bool(state.pending): reasons.append("等待权威执行；执行前复核，取消按原规则退款")
	if not String(state.reason).is_empty(): reasons.append(state.reason)
	if float(state.cooldown_left) > 0.0: reasons.append("%s冷却 %s 秒" % ["付费技能" if bool(state.free_recast) else "", BUTTON.countdown_text(state.cooldown_left)])
	if bool(state.poor): reasons.append("金币不足")
	if bool(state.free_recast): reasons.append("免费追斩可用（付费剩余 %d 次）" % int(state.uses))
	if reasons.is_empty(): reasons.append("可用" if bool(state.can_submit) else "当前不能提交技能指令")
	state.tooltip = "%s\n%s\n消耗 %s 金币 · 剩余 %s 次\n%s" % [state.name, state.description, BattleNumbers.format_value(state.cost), "∞" if bool(state.unlimited) else str(1 if bool(state.free_recast) else state.uses), "\n".join(reasons)]
	_buttons[slot].present(state)
