extends Control
## 初始界面只发出入口意图；卡组、联网和对局仍由Main编排。
signal solo_requested
signal workbench_requested
signal join_requested

const LOGO := preload("res://assets/ui/brand/clash_legends_logo.png")
var server_ip: LineEdit
var status: Label
var _column: VBoxContainer
var _logo: TextureRect

func build(background_texture: Texture2D) -> void:
	name = "ModeMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.name = "MenuBackground"
	background.texture = background_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := TextureRect.new()
	shade.name = "MenuShade"
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0.015, 0.035, 0.055, 0.32), Color(0.015, 0.035, 0.055, 0.65), Color(0.01, 0.02, 0.035, 0.92)])
	var veil := GradientTexture2D.new()
	veil.gradient = gradient
	veil.fill_from = Vector2(0, 0)
	veil.fill_to = Vector2(0, 1)
	shade.texture = veil
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_column = VBoxContainer.new()
	_column.name = "ModeOptions"
	_column.add_theme_constant_override("separation", 0)
	center.add_child(_column)
	_logo = TextureRect.new()
	_logo.name = "Title"
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_logo)
	var subtitle := _label("1V1  ·  实时卡牌对战", 19, UIPalette.GOLD_LIGHT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(subtitle)
	_gap(36)
	var solo := _button("单机对战", "Solo", true)
	solo.custom_minimum_size.y = 112
	solo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	solo.pressed.connect(func(): solo_requested.emit())
	_column.add_child(solo)
	var caption := _label("组建卡组，与 AI 交锋", 18, Color("c3d6dc"))
	caption.position = Vector2(28, 72)
	solo.add_child(caption)
	var arrow := _label("›", 40, UIPalette.GOLD_LIGHT)
	solo.add_child(arrow)
	arrow.anchor_left = 1.0
	arrow.anchor_right = 1.0
	arrow.anchor_top = 0.5
	arrow.anchor_bottom = 0.5
	arrow.offset_left = -54
	arrow.offset_right = -22
	arrow.offset_top = -30
	arrow.offset_bottom = 30
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gap(22)
	var network := PanelContainer.new()
	network.name = "NetworkPanel"
	network.add_theme_stylebox_override("panel", _surface(Color(0.025, 0.065, 0.085, 0.92), Color("485963"), 24))
	_column.add_child(network)
	var network_content := VBoxContainer.new()
	network_content.add_theme_constant_override("separation", 14)
	network.add_child(network_content)
	var heading := HBoxContainer.new()
	network_content.add_child(heading)
	var network_title := _label("联机对战", 23, UIPalette.TEXT)
	network_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(network_title)
	heading.add_child(_label("连接独立服务器", 16, UIPalette.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	network_content.add_child(row)
	server_ip = LineEdit.new()
	server_ip.name = "ServerIP"
	server_ip.text = "127.0.0.1"
	server_ip.placeholder_text = "服务器 IP 地址"
	server_ip.tooltip_text = "输入服务器 IP 地址"
	server_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_ip.custom_minimum_size = Vector2(0, 58)
	server_ip.add_theme_font_size_override("font_size", 21)
	server_ip.add_theme_color_override("font_color", UIPalette.TEXT)
	server_ip.add_theme_stylebox_override("normal", _surface(Color("09151e"), Color("354954"), 14))
	server_ip.add_theme_stylebox_override("focus", _focus_style())
	row.add_child(server_ip)
	var join := _button("连接", "Join")
	join.custom_minimum_size = Vector2(124, 58)
	join.pressed.connect(func(): join_requested.emit())
	server_ip.text_submitted.connect(func(_text: String): join_requested.emit())
	row.add_child(join)
	status = _label("", 18, UIPalette.GOLD_LIGHT)
	status.name = "Status"
	status.custom_minimum_size.y = 28
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(status)
	_gap(12)
	var workbench := _button("卡牌开发工作台", "Workbench")
	workbench.custom_minimum_size.y = 58
	workbench.add_theme_stylebox_override("normal", _surface(Color(0.02, 0.04, 0.055, 0.3), Color(0.36, 0.44, 0.47, 0.55), 12))
	workbench.add_theme_font_size_override("font_size", 21)
	workbench.add_theme_color_override("font_color", UIPalette.MUTED)
	workbench.pressed.connect(func(): workbench_requested.emit())
	_column.add_child(workbench)
	_gap(30)
	var footer := _label("F11  全屏 / 窗口", 15, Color("91a4ab"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(footer)
	resized.connect(_resize_content)
	_resize_content()

func _resize_content() -> void:
	var width := minf(544, maxf(280, size.x - 96))
	_column.custom_minimum_size.x = width
	_logo.custom_minimum_size.y = width * 0.61

func _gap(height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(space)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, node_name: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 30 if primary else 22)
	button.add_theme_color_override("font_color", UIPalette.TEXT)
	button.add_theme_color_override("font_hover_color", UIPalette.GOLD_LIGHT)
	button.add_theme_color_override("font_pressed_color", UIPalette.GOLD_LIGHT)
	for state in ["normal", "hover", "pressed"]:
		var tint := Color("87a9ba") if primary else Color("70818a")
		if state == "hover": tint = Color("b4cbd4")
		if state == "pressed": tint = Color("657d8b")
		var style := UIMaterials.panel(tint, 16) if primary else UIMaterials.fine_panel(tint, 12)
		if primary:
			style.content_margin_left = 28
			style.content_margin_right = 64
			style.content_margin_top = 12
			style.content_margin_bottom = 40
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", _focus_style())
	return button

func _surface(fill: Color, edge: Color, margin: float) -> StyleBoxFlat:
	var style := UIPalette.panel(fill, edge, 1, 4)
	style.set_content_margin_all(margin)
	return style

func _focus_style() -> StyleBoxFlat:
	var style := UIPalette.panel(Color.TRANSPARENT, UIPalette.GOLD_LIGHT, 2, 4)
	style.draw_center = false
	style.shadow_size = 0
	return style
