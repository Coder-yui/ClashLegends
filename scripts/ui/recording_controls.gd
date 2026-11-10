extends HBoxContainer
## 备战录像入口与游戏内设置；系统文件选择器只负责目录/编码器选择。
var options: RefCounted
var _toggle: Button
var _dialog: CanvasLayer
var _directory: Label
var _summary: Label
var _quality_buttons: Array[Button] = []

func _label(text: String, size: int, color: Color = UIPalette.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_override("font", CardArt.ui_font())
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT if primary else UIPalette.TEXT)
	button.add_theme_color_override("font_pressed_color", UIPalette.GOLD_LIGHT)
	button.add_theme_stylebox_override("normal", UIMaterials.fine_panel(Color(1.15, 1.08, 0.92) if primary else Color(0.72, 0.90, 1.0), 12))
	button.add_theme_stylebox_override("hover", UIMaterials.fine_panel(Color(1.4, 1.3, 1.1), 12))
	button.add_theme_stylebox_override("pressed", UIMaterials.fine_panel(Color(1.55, 1.35, 0.85), 12))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = UIPalette.GOLD_LIGHT
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	return button

func setup(value: RefCounted) -> void:
	options = value
	name = "RecordingControls"
	add_theme_constant_override("separation", 12)
	_toggle = _button("")
	_toggle.name = "RecordMatch"
	_toggle.toggle_mode = true
	_toggle.button_pressed = options.enabled
	_update_toggle()
	_toggle.toggled.connect(_set_enabled)
	add_child(_toggle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	var settings := _button("录像设置")
	settings.name = "RecordingSettings"
	settings.pressed.connect(_show_settings)
	add_child(settings)

func _update_toggle() -> void:
	_toggle.text = "●  本场录像 · 已开启" if options.enabled else "○  录制本场对局"

func _set_enabled(enabled: bool) -> void:
	options.enabled = enabled
	options.save()
	_update_toggle()
	if enabled:
		var error: String = options.validate()
		if not error.is_empty():
			options.enabled = false
			_toggle.set_pressed_no_signal(false)
			options.save()
			_update_toggle()
			_show_settings()
			_summary.text = error

func _close_settings() -> void:
	if is_instance_valid(_dialog): _dialog.queue_free()
	_dialog = null
	(find_child("RecordingSettings", true, false) as Button).grab_focus()

func _input(event: InputEvent) -> void:
	if is_instance_valid(_dialog) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_settings()

func _show_settings() -> void:
	if is_instance_valid(_dialog): _dialog.queue_free()
	_dialog = CanvasLayer.new()
	_dialog.layer = 110
	add_child(_dialog)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.025, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "RecordingPanel"
	panel.custom_minimum_size.x = 628
	panel.add_theme_stylebox_override("panel", UIMaterials.panel(Color(1.06, 1.08, 1.08), 28))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := _label("对局录像", 30, UIPalette.GOLD_LIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := _button("×")
	close.custom_minimum_size.x = 48
	close.pressed.connect(_close_settings)
	heading.add_child(close)
	box.add_child(_label("留下这场对决", 19, Color("9aaeb8")))
	var intro := _label("固定 9:16 竖屏 · 保留完整手牌与操作界面\n开局自动录制，结算后保存", 18)
	box.add_child(intro)
	box.add_child(_label("录制画质", 20, UIPalette.GOLD_LIGHT))
	var qualities := HBoxContainer.new()
	qualities.add_theme_constant_override("separation", 10)
	box.add_child(qualities)
	_quality_buttons.clear()
	var group := ButtonGroup.new()
	var captions := ["省资源\n720p · 30 帧", "标准\n1080p · 30 帧", "流畅\n1080p · 60 帧"]
	for index in captions.size():
		var button := _button(captions[index])
		button.name = "RecordingQuality%d" % index
		button.custom_minimum_size = Vector2(184, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = options.preset == index
		button.pressed.connect(func():
			options.preset = index
			options.save()
			_update_summary()
		)
		qualities.add_child(button)
		_quality_buttons.append(button)
	var sound_row := HBoxContainer.new()
	box.add_child(sound_row)
	var sound_title := _label("游戏声音", 20, UIPalette.GOLD_LIGHT)
	sound_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_row.add_child(sound_title)
	var sound := _button("已开启" if options.sound else "已关闭")
	sound.name = "RecordingSound"
	sound.toggle_mode = true
	sound.button_pressed = options.sound
	sound.custom_minimum_size.x = 130
	sound.toggled.connect(func(enabled: bool):
		options.sound = enabled
		sound.text = "已开启" if enabled else "已关闭"
		options.save()
	)
	sound_row.add_child(sound)
	box.add_child(_label("保存位置", 20, UIPalette.GOLD_LIGHT))
	var location := HBoxContainer.new()
	location.add_theme_constant_override("separation", 12)
	box.add_child(location)
	var path_panel := PanelContainer.new()
	path_panel.add_theme_stylebox_override("panel", UIMaterials.fine_panel(Color(0.55, 0.70, 0.8), 12))
	path_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location.add_child(path_panel)
	_directory = _label(options.directory, 16, Color("a6bac4"))
	_directory.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_directory.custom_minimum_size.x = 300
	_directory.tooltip_text = options.directory
	path_panel.add_child(_directory)
	var choose := _button("更改…")
	choose.pressed.connect(_choose_directory)
	location.add_child(choose)
	_summary = _label("", 17, Color("9aaeb8"))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(0, 52)
	box.add_child(_summary)
	if options.encoder().is_empty():
		var encoder := _button("选择视频编码器…")
		encoder.pressed.connect(_choose_encoder)
		box.add_child(encoder)
	var done := _button("完成设置", true)
	done.custom_minimum_size.y = 58
	done.pressed.connect(_close_settings)
	box.add_child(done)
	_update_summary()
	# 模态设置内循环焦点，Tab不落回被遮挡的备战按钮。
	var buttons := panel.find_children("*", "Button", true, false)
	for index in buttons.size():
		var button := buttons[index] as Button
		button.focus_next = button.get_path_to(buttons[(index + 1) % buttons.size()])
		button.focus_previous = button.get_path_to(buttons[(index + buttons.size() - 1) % buttons.size()])
	done.grab_focus()

func _update_summary() -> void:
	if not is_instance_valid(_summary): return
	_summary.text = "约 %s MB / 分钟 · MP4\n窗口大小不会改变成片范围，设置自动保存。" % ["38", "75", "120"][options.preset]
	if options.encoder().is_empty(): _summary.text = "尚未找到视频编码器，请先选择 FFmpeg。"

func _choose_directory() -> void:
	var picker := FileDialog.new()
	picker.title = "选择录像保存文件夹"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	picker.current_dir = options.directory if DirAccess.dir_exists_absolute(options.directory) else OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)
	_dialog.add_child(picker)
	picker.dir_selected.connect(func(path: String):
		options.directory = path
		options.save()
		_directory.text = path
		_directory.tooltip_text = path
		_update_summary()
		picker.queue_free()
	)
	picker.canceled.connect(picker.queue_free)
	picker.popup_centered_ratio(0.7)

func _choose_encoder() -> void:
	var picker := FileDialog.new()
	picker.title = "选择 FFmpeg"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	_dialog.add_child(picker)
	picker.file_selected.connect(func(path: String): options.encoder_path = path; options.save(); _update_summary(); picker.queue_free())
	picker.canceled.connect(picker.queue_free)
	picker.popup_centered_ratio(0.7)
