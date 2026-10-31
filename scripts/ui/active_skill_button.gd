extends Button
## 只消费技能栏投影；无时钟、付款或玩法判断。角标在图标裁切层之外。
const DIAMETER := 58.0
const RING_RADIUS := 33.0
const RING_WIDTH := 3.0
const START := -PI * 0.5
var skill_icon: TextureRect
var cost_label: Label
var uses_label: Label
var cooldown_label: Label
var pending_label: Label
var lock_mark: Control
var resource: Dictionary = {}
var _fallback := ""

func _ready() -> void:
	size = Vector2.ONE * DIAMETER
	custom_minimum_size = size
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.09, 0.14)
		style.border_color = {"normal": Color(0.80, 0.88, 0.94), "hover": Color(0.62, 0.90, 1), "pressed": Color(1, 0.84, 0.28), "disabled": Color(0.46, 0.55, 0.65)}[state]
		style.set_border_width_all(3)
		style.set_corner_radius_all(99)
		style.anti_aliasing = true
		add_theme_stylebox_override(state, style)
	skill_icon = TextureRect.new()
	skill_icon.position = Vector2(4, 4)
	skill_icon.size = Vector2(50, 50)
	skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://scripts/ui/skill_icon_circle.gdshader")
	skill_icon.material = shader_material
	add_child(skill_icon)
	# 明确允许缺省图标时沿用项目文字占位，不用其他技能图片掩盖配置错误。
	var fallback := _label(Vector2(4, 4), Vector2(50, 50), 22)
	fallback.name = "Fallback"
	cooldown_label = _label(Vector2(4, 17), Vector2(50, 24), 20)
	var countdown_back := StyleBoxFlat.new()
	countdown_back.bg_color = Color(0.015, 0.02, 0.035, 0.55)
	countdown_back.set_corner_radius_all(7)
	cooldown_label.add_theme_stylebox_override("normal", countdown_back)
	var coin := Panel.new()
	coin.position = Vector2(-7, -7)
	coin.size = Vector2(25, 25)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.add_theme_stylebox_override("panel", GoldCoin.style())
	add_child(coin)
	cost_label = GoldCoin.amount(15)
	coin.add_child(cost_label)
	uses_label = _badge(Vector2(38, 43), Vector2(27, 23), Color(0.065, 0.14, 0.24), Color(0.55, 0.73, 0.9), 16)
	pending_label = _badge(Vector2(34, -6), Vector2(32, 19), Color(0.09, 0.2, 0.29), Color(0.58, 0.83, 1), 12)
	var lock := _badge(Vector2(-1, 40), Vector2(18, 17), Color(0.08, 0.10, 0.14), Color(0.6, 0.66, 0.72), 12)
	lock.text = ""
	lock_mark = lock
	var padlock := Control.new()
	padlock.set_script(preload("res://scripts/ui/skill_lock_mark.gd"))
	padlock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.add_child(padlock)

func _label(pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.035))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label

func _badge(pos: Vector2, dimensions: Vector2, fill: Color, edge: Color, font_size: int) -> Label:
	var label := _label(pos, dimensions, font_size)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	label.add_theme_stylebox_override("normal", style)
	return label

func present(state: Dictionary) -> void:
	var remaining := float(state.cooldown_left)
	var total := float(state.cooldown_total)
	var cooling := remaining > 0.0 and not bool(state.free_recast)
	var poor := bool(state.poor)
	var locked := bool(state.locked)
	disabled = not bool(state.can_submit)
	visible = bool(state.has_uses)
	resource = state.resource
	cost_label.text = BattleNumbers.format_value(float(state.cost))
	cost_label.add_theme_color_override("font_color", Color("9a231c") if poor else Color("352514"))
	uses_label.text = "∞" if bool(state.unlimited) else str(1 if bool(state.free_recast) else int(state.uses))
	cooldown_label.visible = cooling
	cooldown_label.text = countdown_text(remaining) if cooling else ""
	pending_label.visible = bool(state.pending)
	lock_mark.visible = locked
	skill_icon.modulate = Color(0.5, 0.5, 0.5) if locked else (Color(0.75, 0.75, 0.75) if poor else Color.WHITE)
	var material := skill_icon.material as ShaderMaterial
	material.set_shader_parameter("cooldown_active", cooling)
	material.set_shader_parameter("cooldown_completed", clampf(1.0 - remaining / maxf(total, 0.001), 0, 1))
	(get_node("Fallback") as Label).text = _fallback
	(get_node("Fallback") as Label).visible = skill_icon.texture == null and not cooling and not bool(state.pending)
	tooltip_text = state.tooltip
	queue_redraw()

static func countdown_text(remaining: float) -> String:
	return "%.1f" % maxf(0.1, ceilf(remaining * 10.0 - 0.00001) / 10.0)

func _has_point(point: Vector2) -> bool:
	return point.distance_squared_to(size * 0.5) <= pow(DIAMETER * 0.5, 2)

func _draw() -> void:
	if not bool(resource.get("visible", false)): return
	var segments := int(resource.segments)
	var center := Vector2.ONE * DIAMETER * 0.5
	var color: Color = resource.color
	var background := Color(0.09, 0.11, 0.16)
	if segments > 0:
		var step := TAU / segments
		var gap := minf(0.10, step * 0.24)
		for index in segments:
			var start := START + index * step + gap * 0.5
			var end := START + (index + 1) * step - gap * 0.5
			draw_arc(center, RING_RADIUS, start, end, 24, background, RING_WIDTH + 2, true)
			draw_arc(center, RING_RADIUS, start, end, 24, color if index < int(resource.stacks) else background, RING_WIDTH, true)
	else:
		draw_arc(center, RING_RADIUS, START, START + TAU, 96, background, RING_WIDTH + 2, true)
		if float(resource.ratio) > 0:
			draw_arc(center, RING_RADIUS, START, START + TAU * float(resource.ratio), 96, color, RING_WIDTH, true)

func _make_custom_tooltip(for_text: String) -> Object:
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = minf(320, get_viewport_rect().size.x - 24)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 15)
	return label
