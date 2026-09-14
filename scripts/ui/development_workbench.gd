class_name DevelopmentWorkbench
extends CanvasLayer
## 三个工作区共享卡牌选择；素材预览与真实战斗分离。
signal item_selected(item_id: String)
signal team_changed(team: int)
signal active_skill_selected(item_id: String, skill_index: int)
signal active_skill_requested(skill_index: int)
signal skill_resource_requested(value: float)
signal scenario_requested(action: String)
signal spell_active_changed(enabled: bool)
signal clear_requested
signal exit_requested
signal workspace_changed(battle_active: bool)

const SCENARIOS := preload("res://scripts/ui/workbench/battle_scenarios.gd")
var _scenario_option: OptionButton
var _scenario_hint: Label

var _cards: Dictionary
var _selected_id := "garen"
var _team := 0
var _form := 0
var _active_skill_choices: Dictionary = {}
var _workspace := 0
var _pages: Array[Control] = []
var _tabs: Array[Button] = []
var _background: ColorRect
var _card_option: OptionButton
var _search: LineEdit
var _team_button: Button
var _form_option: OptionButton
var _selection_label: Label
var _art: TextureRect
var _preview: WorkbenchModelPreview
var _animation_option: OptionButton
var _timeline: HSlider
var _time_label: Label
var _model_hint: Label
var _spell_active: CheckButton
var _skill_option: OptionButton
var _skill_button: Button
var _control_buttons: Array[Button] = []
var _unit_status_label: Label
var _resource_controls: HBoxContainer
var _resource_slider: HSlider
var _resource_value_label: Label
var _resource_max := 0.0
var _resource_supported := false
var _unit_available := false
var _unit_deployed := false
var _unit_casting := false
var _audio_cue: OptionButton
var _audio_list: ItemList
var _audio_entries: Array[Dictionary] = []
var _audition_catalog: Dictionary = {}
var _audio_player: AudioStreamPlayer
var _audio_status: Label
var _audio_timeline: HSlider
var _rotation: HSlider
var _zoom: HSlider

func setup(cards: Dictionary) -> void:
	layer = 30
	_cards = cards
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/workbench_auditions.json"))
	if catalog is Dictionary: _audition_catalog = catalog
	_build_ui()
	_filter_cards("")
	_select_item(_selected_id)
	show_workspace(0)

func _label(parent: Node, text: String, small: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_color_override("font_color", Color("9badc4") if small else Color("edf3ff"))
	node.add_theme_font_size_override("font_size", 16 if small else 20)
	parent.add_child(node)
	return node

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CardArt.frame_style(Color("172537"), Color("2b405a"), 1, 12))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Theme.new()
	root.theme.default_font = CardArt.ui_font()
	root.theme.default_font_size = 18
	add_child(root)
	_background = ColorRect.new()
	_background.color = Color("0b1320")
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	root.add_child(margin)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := _panel(layout)
	var title_row := _row(header)
	var title := _label(title_row, "卡牌开发工作台")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	_button(title_row, "返回主菜单", func(): exit_requested.emit()).size_flags_horizontal = Control.SIZE_SHRINK_END
	var choose := _row(header)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索名称 / ID"
	_search.custom_minimum_size = Vector2(170, 42)
	_search.text_changed.connect(_filter_cards)
	choose.add_child(_search)
	_card_option = OptionButton.new()
	_card_option.fit_to_longest_item = false
	_card_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_option.clip_text = true
	_card_option.item_selected.connect(func(index): _select_item(String(_card_option.get_item_metadata(index))))
	choose.add_child(_card_option)
	_team_button = _button(choose, "蓝方", func(): _on_team_toggled(_team == 0))
	_team_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var summary := _row(header)
	_art = TextureRect.new()
	_art.custom_minimum_size = Vector2(45, 62)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	summary.add_child(_art)
	_selection_label = _label(summary, "")
	_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_option = OptionButton.new()
	_form_option.add_item("基础形态")
	_form_option.add_item("变形素材")
	_form_option.item_selected.connect(func(index): _form = index; _refresh_assets())
	summary.add_child(_form_option)
	var tabs := _row(layout)
	var names := ["01 模型·动作", "02 实战·技能", "03 音频"]
	for i in names.size():
		var button := _button(tabs, names[i], show_workspace.bind(i))
		button.toggle_mode = true
		_tabs.append(button)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)
	for i in names.size():
		var page := VBoxContainer.new()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("separation", 12)
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(page)
		_pages.append(page)
	_build_model_page(_pages[0])
	_build_battle_page(_pages[1])
	_build_audio_page(_pages[2])
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_audio_player.finished.connect(func(): _audio_status.text = "播放结束 · 可选择其他变体")

func _build_model_page(page: Control) -> void:
	_model_hint = _label(page, "独立素材观察 · 真实动作衔接请到实战区检查", true)
	_preview = WorkbenchModelPreview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size.y = 250
	page.add_child(_preview)
	var controls := _panel(page)
	_animation_option = OptionButton.new()
	_animation_option.fit_to_longest_item = false
	_animation_option.clip_text = true
	_animation_option.custom_minimum_size.y = 44
	_animation_option.item_selected.connect(_play_animation)
	controls.add_child(_animation_option)
	var transport := _row(controls)
	_button(transport, "重播", func(): _play_animation(_animation_option.selected))
	_button(transport, "暂停", func(): _preview.set_playing(false))
	_button(transport, "继续", func(): _preview.set_playing(true))
	_button(transport, "+1/30 秒", func():
		if _preview.player != null: _preview.seek_seconds(minf(_timeline.max_value, _timeline.value + 1.0 / 30.0)))
	_timeline = HSlider.new()
	_timeline.step = 0.001
	_timeline.value_changed.connect(func(value): _preview.seek_seconds(value))
	controls.add_child(_timeline)
	_time_label = _label(controls, "0.00 / 0.00 s", true)
	var view := _row(controls)
	_label(view, "旋转", true).custom_minimum_size.x = 40
	_rotation = HSlider.new()
	_rotation.min_value = -180
	_rotation.max_value = 180
	_rotation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rotation.value_changed.connect(func(value): _preview.set_model_yaw(value))
	view.add_child(_rotation)
	_label(view, "缩放", true).custom_minimum_size.x = 40
	_zoom = HSlider.new()
	_zoom.min_value = 0.4
	_zoom.max_value = 2.5
	_zoom.step = 0.01
	_zoom.value = 1
	_zoom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom.value_changed.connect(func(value): _preview.set_zoom(value))
	view.add_child(_zoom)
	_button(view, "复位", _reset_camera).size_flags_horizontal = Control.SIZE_SHRINK_END

func _build_battle_page(page: Control) -> void:
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(space)
	var box := _panel(page)
	_label(box, "真实战场 · 点击空白处放置当前卡", false)
	_label(box, "无金币 / AI / 倒计时；技能保留正式前摇、命中与恢复。", true)
	var presets := _row(box)
	_scenario_option = OptionButton.new()
	_scenario_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for preset in SCENARIOS.PRESETS:
		_scenario_option.add_item(preset.name)
	presets.add_child(_scenario_option)
	_button(presets, "重建场景", func(): scenario_requested.emit("preset:" + String(SCENARIOS.PRESETS[_scenario_option.selected].id)))
	_scenario_hint = _label(box, "", true)
	_scenario_option.item_selected.connect(func(index): _scenario_hint.text = SCENARIOS.PRESETS[index].hint + " 重建会清空上一轮。")
	_scenario_option.item_selected.emit(0)
	var quick := _row(box)
	_button(quick, "放置当前卡", func(): scenario_requested.emit("spawn"))
	_button(quick, "敌方木桩", func(): scenario_requested.emit("target"))
	_button(quick, "清空重测", func(): clear_requested.emit())
	_spell_active = CheckButton.new()
	_spell_active.text = "强化法术"
	_spell_active.toggled.connect(func(enabled): spell_active_changed.emit(enabled))
	box.add_child(_spell_active)
	var skills := _row(box)
	_skill_option = OptionButton.new()
	_skill_option.fit_to_longest_item = false
	_skill_option.clip_text = true
	_skill_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_option.item_selected.connect(_on_skill_option_selected)
	skills.add_child(_skill_option)
	_skill_button = _button(skills, "释放所选技能", _on_active_skill_pressed)
	_skill_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_resource_controls = _row(box)
	_label(_resource_controls, "技能资源", true).autowrap_mode = TextServer.AUTOWRAP_OFF
	_resource_slider = HSlider.new()
	_resource_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_slider.value_changed.connect(_on_resource_value_changed)
	_resource_controls.add_child(_resource_slider)
	_resource_value_label = _label(_resource_controls, "", true)
	_resource_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_button(_resource_controls, "清零", func(): _request_resource_value(0)).size_flags_horizontal = Control.SIZE_SHRINK_END
	_button(_resource_controls, "充满", func(): _request_resource_value(_resource_max)).size_flags_horizontal = Control.SIZE_SHRINK_END
	var control := _row(box)
	for entry in [["冰冻 2s", "freeze"], ["眩晕 2s", "stun"], ["减速 3s", "slow"], ["减攻速 3s", "attack_slow"], ["死亡", "death"]]:
		_control_buttons.append(_button(control, entry[0], func(): scenario_requested.emit(entry[1])))
	_unit_status_label = _label(box, "先放置单位", true)

func _build_audio_page(page: Control) -> void:
	_label(page, "逐个检查声音与变体")
	_label(page, "这里播放配置文件；真实出手、命中、控制中断和持续声叠加请在实战区试听。切页或换卡自动停止试听。", true)
	_audio_cue = OptionButton.new()
	_audio_cue.fit_to_longest_item = false
	_audio_cue.custom_minimum_size.y = 44
	_audio_cue.item_selected.connect(_filter_audio)
	page.add_child(_audio_cue)
	_audio_list = ItemList.new()
	_audio_list.add_theme_constant_override("v_separation", 12)
	_audio_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_audio_list.item_activated.connect(func(index): _play_audio(int(_audio_list.get_item_metadata(index))))
	_audio_list.item_selected.connect(func(index):
		var entry: Dictionary = _audio_entries[int(_audio_list.get_item_metadata(index))]
		_audio_status.text = "%s · %s · %.1f dB\n%s" % [entry.cue, entry.bus, entry.volume, entry.path])
	page.add_child(_audio_list)
	var transport := _panel(page)
	var row := _row(transport)
	_button(row, "播放选中", func():
		var selected := _audio_list.get_selected_items()
		if not selected.is_empty(): _play_audio(int(_audio_list.get_item_metadata(selected[0]))))
	_button(row, "暂停 / 继续", func(): _audio_player.stream_paused = not _audio_player.stream_paused)
	_button(row, "停止", _stop_audio)
	_audio_timeline = HSlider.new()
	_audio_timeline.step = 0.01
	_audio_timeline.value_changed.connect(func(value):
		if _audio_player.playing: _audio_player.seek(value))
	transport.add_child(_audio_timeline)
	_audio_status = _label(transport, "选择一条声音；双击直接播放。", true)

func _filter_cards(query: String) -> void:
	_card_option.clear()
	var ids: Array = _cards.keys()
	ids.sort()
	ids.push_front("training_dummy")
	for id in ids:
		var title := "训练木桩" if id == "training_dummy" else String(_cards[id].get("name", id))
		if not query.is_empty() and not (title + " " + String(id)).to_lower().contains(query.to_lower()): continue
		_card_option.add_item(title + " · " + String(id))
		var index := _card_option.item_count - 1
		_card_option.set_item_metadata(index, id)
		if id == _selected_id: _card_option.select(index)
	_card_option.disabled = _card_option.item_count == 0
	if _card_option.item_count > 0:
		var found := false
		for index in _card_option.item_count:
			if String(_card_option.get_item_metadata(index)) == _selected_id: found = true
		if not found: _card_option.select(-1)

func _select_item(item_id: String) -> void:
	if item_id != "training_dummy" and not _cards.has(item_id): return
	_selected_id = item_id
	_form = 0
	_spell_active.set_pressed_no_signal(false)
	_spell_active.visible = String(_cards.get(item_id, {}).get("type", "")) == "spell" and _cards.get(item_id, {}).has("active_name")
	_spell_active.text = String(_cards.get(item_id, {}).get("active_name", "强化法术"))
	_form_option.select(0)
	_form_option.disabled = _workspace == 1 or not _cards.get(item_id, {}).has("transformed_stats")
	_selection_label.text = "%s\n%s" % [String(_cards.get(item_id, {}).get("name", "训练木桩")), item_id]
	_art.texture = CardArt.texture_for(item_id)
	for index in _card_option.item_count:
		if String(_card_option.get_item_metadata(index)) == item_id: _card_option.select(index)
	_unit_available = false
	_unit_deployed = false
	_unit_casting = false
	_refresh_skill_controls()
	var is_spell := String(_cards.get(item_id, {}).get("type", "")) == "spell"
	_skill_option.get_parent().visible = not is_spell
	_control_buttons[0].get_parent().visible = not is_spell
	_refresh_assets()
	item_selected.emit(item_id)

func _refresh_assets() -> void:
	_stop_audio()
	_form_option.select(_form)
	var stats := PresentationConfig.for_form(_cards.get(_selected_id, {}), _form)
	var clips := _preview.show_definition(stats, _team)
	_animation_option.clear()
	var mappings: Dictionary = {}
	_collect_mappings(stats.get("visual_animations", {}), "", mappings)
	for clip in clips:
		_animation_option.add_item("%s  ·  %s" % [clip, String(mappings.get(String(clip), "未映射片段"))])
		_animation_option.set_item_metadata(_animation_option.item_count - 1, clip)
	_animation_option.disabled = clips.is_empty()
	_model_hint.text = "无 3D 模型 · 法术请在实战区检查效果" if _preview.model == null else "独立素材观察 · %d 个片段 · 真实衔接请到实战区" % clips.size()
	_reset_camera()
	_timeline.max_value = 0.01
	_timeline.value = 0
	_time_label.text = "未选择动画"
	_timeline.editable = not clips.is_empty()
	if not clips.is_empty():
		var idle := String(stats.get("visual_animations", {}).get("idle", ""))
		var index := maxi(clips.find(idle), 0)
		_animation_option.select(index)
		_play_animation(index)
	_refresh_audio(PresentationConfig.audio_for(stats, _team))
	_preview.set_preview_active(_workspace == 0)

func _collect_mappings(value: Variant, path: String, output: Dictionary) -> void:
	if value is Dictionary:
		for key in value: _collect_mappings(value[key], path + "/" + String(key), output)
	elif value is Array:
		for i in value.size(): _collect_mappings(value[i], path + "[%d]" % i, output)
	elif value is String or value is StringName:
		output[String(value)] = String(output.get(String(value), "")) + (", " if output.has(String(value)) else "") + path.trim_prefix("/")

func _play_animation(index: int) -> void:
	if index < 0 or index >= _animation_option.item_count: return
	_preview.play_clip(String(_animation_option.get_item_metadata(index)))
	_timeline.max_value = _preview.player.current_animation_length

func _reset_camera() -> void:
	_rotation.set_value_no_signal(0)
	_zoom.set_value_no_signal(1)
	_preview.set_model_yaw(0)
	_preview.set_zoom(1)

func _refresh_audio(audio: Dictionary) -> void:
	_audio_entries.clear()
	_audio_list.clear()
	for cue in ["attack_swing", "attack_hit", "attack_launch_by_segment", "attack_hit_by_segment", "empowered_hit", "first_strike_hit"]:
		var pools: Array = audio.get(cue, [])
		for i in pools.size():
			var paths: Array = pools[i] if pools[i] is Array else [pools[i]]
			for path in paths: _add_audio(cue + "[%d]" % (i + 1) if cue in ["attack_swing", "attack_launch_by_segment", "attack_hit_by_segment"] else cue, String(path), (0.0 if cue == "attack_launch_by_segment" else float(audio.get("attack_swing_volume_db" if cue == "attack_swing" else "attack_hit_volume_db", -5.0 if cue == "attack_swing" else -4.0))), "Combat")
	for cue in audio.get("events", {}):
		var event: Dictionary = audio.events[cue]
		for path in event.get("pool", []): _add_audio(String(cue), String(path), float(event.get("volume_db", 0)), String(event.get("bus", "Combat")))
	for label in _audition_catalog.get(_selected_id, {}):
		var event: Dictionary = _audition_catalog[_selected_id][label]
		for path in event.get("pool", []): _add_audio("仅试听 · " + String(label), String(path), float(event.get("volume_db", 0.0)), String(event.get("bus", "Combat")))
	_audio_cue.clear()
	_audio_cue.add_item("全部事件")
	var cues: Array[String] = []
	for entry in _audio_entries:
		if String(entry.cue) not in cues: cues.append(String(entry.cue))
	for cue in cues: _audio_cue.add_item(cue)
	_audio_cue.disabled = cues.is_empty()
	_filter_audio(0)
	_audio_status.text = "未配置音频 · 当前对象没有可试听的声音。" if _audio_entries.is_empty() else "%d 个文件变体 · 选择后播放" % _audio_entries.size()

func _add_audio(cue: String, path: String, volume: float, bus: String) -> void:
	_audio_entries.append({"cue": cue, "path": path, "volume": volume, "bus": bus})

func _filter_audio(index: int) -> void:
	_audio_list.clear()
	var cue := _audio_cue.get_item_text(index) if index > 0 else ""
	for i in _audio_entries.size():
		var entry := _audio_entries[i]
		if not cue.is_empty() and String(entry.cue) != cue: continue
		_audio_list.add_item("%s  ·  %s" % [entry.cue, String(entry.path).get_file()])
		_audio_list.set_item_metadata(_audio_list.item_count - 1, i)
		_audio_list.set_item_tooltip(_audio_list.item_count - 1, entry.path)
	if _audio_list.item_count > 0: _audio_list.select(0)

func _play_audio(index: int) -> void:
	_stop_audio()
	if index < 0 or index >= _audio_entries.size(): return
	var entry := _audio_entries[index]
	if not ResourceLoader.exists(entry.path):
		_audio_status.text = "缺失文件：" + String(entry.path)
		return
	_audio_player.stream = load(entry.path) as AudioStream
	if _audio_player.stream == null: return
	_audio_player.bus = StringName(entry.bus)
	_audio_player.volume_db = float(entry.volume)
	_audio_player.play()
	_audio_timeline.max_value = maxf(_audio_player.stream.get_length(), 0.01)
	_audio_status.text = "%s · %s · %.1f dB\n%s" % [entry.cue, entry.bus, entry.volume, entry.path]

func _stop_audio() -> void:
	if _audio_player == null: return
	_audio_player.stop()
	_audio_player.stream_paused = false
	_audio_player.stream = null
	_audio_timeline.set_value_no_signal(0)
	_audio_status.text = "试听已停止"

func accepts_battle_input() -> bool:
	return _workspace == 1

func show_workspace(index: int) -> void:
	_workspace = clampi(index, 0, _pages.size() - 1)
	for i in _pages.size():
		_pages[i].visible = i == _workspace
		_tabs[i].set_pressed_no_signal(i == _workspace)
	_background.visible = _workspace != 1
	_form_option.visible = _workspace != 1
	_form_option.disabled = not _cards.get(_selected_id, {}).has("transformed_stats")
	_preview.set_preview_active(_workspace == 0)
	_stop_audio()
	if _workspace == 2:
		_audio_status.text = "未配置音频 · 当前对象没有可试听的声音。" if _audio_entries.is_empty() else "%d 个文件变体 · 按事件筛选，双击试听" % _audio_entries.size()
	workspace_changed.emit(_workspace == 1)

func _process(_delta: float) -> void:
	if _workspace == 0 and _preview.player != null and not _preview.player.assigned_animation.is_empty():
		var position := _preview.player.current_animation_position
		_timeline.set_value_no_signal(position)
		_time_label.text = "%.2f / %.2f s · 拖动时间轴暂停定位" % [position, _timeline.max_value]
	if _audio_player.playing:
		_audio_timeline.set_value_no_signal(_audio_player.get_playback_position())

func _refresh_skill_controls() -> void:
	var skills: Array[Dictionary] = []
	if _selected_id != "training_dummy":
		skills = CardDB.active_skills_for(_selected_id)
	_skill_option.clear()
	for skill in skills:
		_skill_option.add_item(String((skill as Dictionary).get("name", "主动技能")))
	var selected_index := 0
	if not skills.is_empty():
		selected_index = clampi(int(_active_skill_choices.get(_selected_id, 0)), 0, skills.size() - 1)
		_active_skill_choices[_selected_id] = selected_index
		_skill_option.select(selected_index)
	_skill_option.disabled = skills.is_empty()
	_update_resource_config(skills[selected_index] if not skills.is_empty() else {})
	_update_action_state(not skills.is_empty())

func _on_skill_option_selected(skill_index: int) -> void:
	var skills := CardDB.active_skills_for(_selected_id)
	if skills.is_empty():
		return
	var selected_index := clampi(skill_index, 0, skills.size() - 1)
	_active_skill_choices[_selected_id] = selected_index
	_update_resource_config(skills[selected_index])
	active_skill_selected.emit(_selected_id, selected_index)

func selected_skill_index() -> int:
	var skills := CardDB.active_skills_for(_selected_id)
	return clampi(int(_active_skill_choices.get(_selected_id, 0)), 0, skills.size() - 1) if not skills.is_empty() else -1

func _on_active_skill_pressed() -> void:
	var skill_index := selected_skill_index()
	if skill_index >= 0:
		active_skill_requested.emit(skill_index)

func _update_resource_config(skill: Dictionary) -> void:
	var stats: Dictionary = _cards.get(_selected_id, {})
	_resource_max = maxf(float(stats.get("skill_resource_max", 0.0)), 0.0)
	_resource_supported = bool(skill.get("uses_skill_resource", false)) and _resource_max > 0.0
	_resource_controls.visible = _resource_supported
	_resource_slider.max_value = maxf(_resource_max, 1.0)
	_resource_slider.step = 1.0
	_resource_slider.set_value_no_signal(0.0)
	_resource_slider.editable = _resource_supported and _unit_available
	_resource_value_label.text = "0/%s" % _format_number(_resource_max)

func update_selected_unit_state(available: bool, deployed: bool, casting: bool, resource_enabled: bool, resource_value: float, resource_max: float) -> void:
	_unit_available = available
	_unit_deployed = deployed
	_unit_casting = casting
	for button in _control_buttons: button.disabled = not available
	if not available:
		_unit_status_label.text = "法术不生成单位 · 点击战场选定效果落点" if String(_cards.get(_selected_id, {}).get("type", "")) == "spell" else "先放置单位"
	elif not deployed:
		_unit_status_label.text = "部署中"
	elif casting:
		_unit_status_label.text = "技能播放中"
	else:
		_unit_status_label.text = "当前对象：最后放置的同卡、同阵营单位"
	var has_skill := _skill_option.item_count > 0
	_update_action_state(has_skill)
	if _resource_supported:
		_resource_max = maxf(resource_max, _resource_max)
		_resource_slider.max_value = maxf(_resource_max, 1.0)
		_resource_slider.editable = available and resource_enabled
		_resource_slider.set_value_no_signal(clampf(resource_value, 0.0, _resource_max))
		_resource_value_label.text = "%s/%s" % [_format_number(resource_value), _format_number(_resource_max)]

func _update_action_state(has_skill: bool) -> void:
	_skill_button.disabled = not has_skill or not _unit_available or not _unit_deployed or _unit_casting

func _on_resource_value_changed(value: float) -> void:
	if _resource_supported and _unit_available:
		skill_resource_requested.emit(value)

func _request_resource_value(value: float) -> void:
	if not _resource_supported or not _unit_available:
		return
	_resource_slider.set_value_no_signal(clampf(value, 0.0, _resource_max))
	skill_resource_requested.emit(_resource_slider.value)

func _on_team_toggled(pressed: bool) -> void:
	_team = 1 if pressed else 0
	_unit_available = false
	_unit_deployed = false
	_unit_casting = false
	_update_team_text()
	_refresh_skill_controls()
	_refresh_assets()
	team_changed.emit(_team)

func _update_team_text() -> void:
	_team_button.text = "红方" if _team == 1 else "蓝方"

func _format_number(value: float) -> String:
	return BattleNumbers.format_value(value)

func update_live_details(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit): return
	var state := unit.presentation_state()
	var tags: Array[String] = []
	if state.frozen: tags.append("冰冻")
	if state.stunned: tags.append("眩晕")
	var action: String = String(state.action) if not state.action.is_empty() else ["部署", "待机", "移动", "攻击"][clampi(state.behavior, 0, 3)]
	_unit_status_label.text = "%s · HP %.0f/%.0f · %s\n攻击 #%d · 进度 %.2fs · 攻速 ×%.2f · %s" % [unit.card_id, unit.hp, unit.max_hp, action, state.attack_serial, state.attack_elapsed, state.attack_rate, " / ".join(tags) if not tags.is_empty() else "无冰冻/眩晕"]
	_skill_button.disabled = _skill_button.disabled or state.frozen or state.stunned
