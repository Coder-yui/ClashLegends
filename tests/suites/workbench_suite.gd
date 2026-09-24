extends "res://tests/suites/battle_suite.gd"
## 工作台 UI、素材隔离与真实技能预览契约；由统一回归按原有时序调用。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_artdev_active_skill_timeline()
	_check_artdev_workbench()
	_check_desktop_camera()
	_check_explicit_inspection()

func _check_artdev_active_skill_timeline() -> void:
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var source: Unit = _main._spawn_unit(0, "garen", Vector2(260.0, 680.0), 0.0, 0)
	var ability_id: int = source.active_ability_id
	var skill: Dictionary = {
		"name": "ArtDev 时间轴",
		"kind": "buff",
		"duration": 2.0,
		"cast_duration": 1.0,
		"impact_delay": 0.4,
		"shield": 100.0,
		"shield_duration": 2.0,
		"cast_locks": ["movement", "attack", "facing"],
	}
	var pending_before: int = _main._commands.inspect_impacts().size()
	var previewed: bool = _main.preview_active_skill(source, skill)
	var command_buffer_skipped: bool = (
		previewed
		and _main._commands.inspect_skills().is_empty()
		and _main._commands.inspect_impacts().size() == pending_before + 1
		and source.active_skill_cast_timer > 0.0
		and is_zero_approx(source.shield_hp)
	)
	_run_main_ticks(7)
	var no_early_impact: bool = is_zero_approx(source.shield_hp)
	_run_main_ticks(1)
	var impact_after_delay: bool = source.shield_hp > 0.0
	_expect(command_buffer_skipped and no_early_impact and impact_after_delay, "ArtDev 只跳过 Command Buffer，普通主动仍按 Cast Start→impact_delay→Gameplay Impact 结算")
	_main._on_active_skill_unit_died(ability_id)
	source.free()
	_main._deck = old_deck

func _check_artdev_workbench() -> void:
	var old_panel: DevelopmentWorkbench = _main._art_dev_panel
	var old_selection: String = _main._workbench.selection
	var old_team: int = _main._workbench.team
	var old_last_units: Dictionary = _main._workbench.last_units.duplicate()
	var old_choices: Dictionary = _main._workbench.skill_choices.duplicate(true)
	var panel := DevelopmentWorkbench.new()
	_main.add_child(panel)
	panel.setup(CardDB.all())
	_main._art_dev_panel = panel
	panel.item_selected.connect(_main._set_art_dev_selection)
	panel.team_changed.connect(_main._set_art_dev_team)
	panel.active_skill_selected.connect(_main._on_art_dev_active_skill_selected)
	panel.active_skill_requested.connect(_main._use_art_dev_active_skill)
	panel.skill_resource_requested.connect(_main._set_art_dev_skill_resource)

	panel._filter_cards("gwen")
	var search_ok: bool = panel._library.entries.size() == 1 and panel._library.entries[0].id == "gwen"
	panel._filter_cards("")
	panel._select_item("pix")
	var extra_forms := CardDB.all().values().filter(func(card): return card.has("transformed_stats")).size()
	var all_cards: bool = panel._library.entries.size() == CardDB.all().size() + extra_forms and panel._selected_id == "pix"
	panel.show_workspace(1)
	var battle_input := panel.accepts_battle_input()
	panel.show_workspace(0)
	_expect(search_ok and all_cards and battle_input and not panel.accepts_battle_input(), "开发工作台可搜索全部卡及系统对象，仅实战页接受战场放置，牌库浏览不受快捷栏八槽限制")

	for choice in ["aatrox:1", "gnar:1"]:
		panel._select_item(choice)
		_expect(panel._form == 1 and panel._preview.model != null and panel._selection_label.text.contains("大"), "工作台独立形态入口：" + choice)
	panel._select_item("pix")
	panel._filter_cards("does-not-exist")
	_expect(panel._library.entries.is_empty() and panel._selected_id == "pix", "搜索无结果不会悄悄改换当前审查卡牌")
	panel._filter_cards("")
	panel.show_workspace(1)
	panel.set_quick_cards(["garen", "garen", "unknown", "ashe", "freeze", "teemo", "xin", "gnar", "gwen", "sett", "aatrox"])
	_expect(panel._quick_cards.size() == 8 and panel._quick_cards[0] == "garen" and "aatrox" not in panel._quick_cards, "工作台快捷栏去重、过滤失效定义并限制八张")
	panel._select_item("garen")
	_expect(panel.has_placeable_selection(), "快捷栏选中卡可部署")
	panel.set_quick_cards([])
	_expect(panel._quick_cards.is_empty() and not panel.has_placeable_selection(), "空快捷栏不会隐式部署上一张卡")
	panel.set_quick_cards(["garen", "ashe"])
	panel._select_item("ashe")
	panel._on_team_toggled(true)
	_expect(panel._quick_cards == ["garen", "ashe"] and panel.has_placeable_selection(), "切阵营保留共享实验快捷栏")
	panel._on_team_toggled(false)
	panel._select_item("garen")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_2
	panel._input(key)
	_expect(panel._selected_id == "ashe", "数字键切换快捷卡")
	panel._show_library(true)
	panel._search.grab_focus()
	key.keycode = KEY_1
	panel._input(key)
	_expect(panel._selected_id == "ashe", "搜索输入数字不会误切卡")
	panel._show_library(false)
	panel._preferences_path = "user://workbench-regression.cfg"
	panel._persist = true
	panel.set_quick_cards(["ashe", "gnar:1"])
	panel._persist = false
	panel.set_quick_cards([])
	panel._load_quick_cards()
	_expect(panel._quick_cards == ["ashe", "gnar:1"], "快捷栏持久化保留顺序与独立形态")
	panel._persist = true
	panel.set_quick_cards([])
	panel._persist = false
	panel.set_quick_cards(["garen"])
	panel._load_quick_cards()
	_expect(panel._quick_cards.is_empty(), "空快捷栏也能持久化")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(panel._preferences_path))
	panel.set_quick_cards(["garen", "ashe"])
	panel._select_item("garen")
	var before_units := _main.get_tree().get_nodes_in_group("combatants").size()
	panel._preview.seek_seconds(0.2)
	var isolated_preview := panel._preview.player != null and not panel._preview.player.is_playing() and is_equal_approx(panel._preview.player.current_animation_position, 0.2)
	_expect(isolated_preview and _main.get_tree().get_nodes_in_group("combatants").size() == before_units, "素材动画可暂停定位且不生成权威单位或攻击")
	panel._preview.set_playing(true)
	panel._preview.player.advance(0.1)
	_expect(panel._preview.player.current_animation_position > 0.2, "模型拖动到任意时间后继续播放，不从头重播")
	panel.show_workspace(2)
	_expect(panel._audio_entries.all(func(entry): return float(entry.duration) > 0.0), "每个已接入音频变体均显示实际时长")
	panel._play_audio(0)
	var audio_started := panel._audio_player.playing and panel._audio_player.stream != null
	panel.show_workspace(0)
	var audio_stopped := not panel._audio_player.playing and panel._audio_player.stream == null
	panel._select_item("freeze")
	var formal_audio_only := panel._preview.model == null and not panel._audio_entries.is_empty() \
		and panel._audio_entries.any(func(entry): return String(entry.cue) == "spell:cast") \
		and panel._audio_entries.all(func(entry): return not String(entry.cue).begins_with("仅试听"))
	var catalog_ok := true
	for card_id in ["garen", "gwen"]:
		panel._select_item(card_id)
		var voice_entries := panel._audio_entries.filter(func(entry): return entry.cue == "deploy:voice")
		catalog_ok = catalog_ok and voice_entries.size() == 3 \
			and voice_entries.all(func(entry): return entry.bus == "Voice" and is_zero_approx(entry.volume))
	_expect(catalog_ok, "工作台列出盖伦和格温的全部部署变体并保留 Voice 总线和音量")
	panel._select_item("garen")
	_expect(audio_started and audio_stopped and formal_audio_only, "工作台试听切页清理，法术显示正式音频且不混入未接候选")
	var old_dev_mode: bool = _main._workbench.enabled
	var original_zones: int = _main._spell_system.slow_zones.size()
	_main._workbench.enabled = true
	_main.play_card(0, "freeze", Vector2.ZERO, {"immediate": true, "validate_position": false, "preview_active_spell": true})
	var enhanced_preview: bool = _main._spell_system.slow_zones.size() == original_zones + 1
	_main._workbench.enabled = false
	_main.play_card(0, "freeze", Vector2.ZERO, {"immediate": true, "validate_position": false, "preview_active_spell": true})
	_expect(enhanced_preview and _main._spell_system.slow_zones.size() == original_zones + 1, "工作台强化法术仍经统一出牌链，正式对战不接受开发强化开关")
	_main._spell_system.slow_zones.pop_back()
	_main._spell_system.slow_effects.pop_back()
	_main._spell_system.freeze_effects.pop_back()
	_main._spell_system.freeze_effects.pop_back()
	_main._workbench.enabled = old_dev_mode

	panel._select_item("gnar")
	panel._form = 1
	panel._refresh_assets()
	_expect(panel._preview.model.scene_file_path == String(CardDB.get_card("gnar").transformed_stats.visual_scene_path), "工作台形态素材使用共享解析器且不改变战场形态")
	panel.show_workspace(1)

	panel._select_item("garen")
	panel._on_skill_option_selected(1)
	var skill_switch_ok := (
		panel._skill_option.item_count == 2
		and panel.selected_skill_index() == 1
		and int(_main._workbench.skill_choices.get("garen", -1)) == 1
	)
	_expect(skill_switch_ok, "ArtDev 可在同一英雄的多个主动技能候选之间切换")

	panel._select_item("gwen")
	var gwen_stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	gwen_stats["deploy_time"] = 0.0
	var gwen := Unit.new()
	gwen.position = Vector2(260.0, 720.0)
	gwen.setup(0, gwen_stats, gwen_stats.name)
	gwen.card_id = "gwen"
	_main.add_child(gwen)
	_main._workbench.last_units[_main._art_dev_unit_key("gwen", 0)] = weakref(gwen)
	panel._on_team_toggled(false)
	_main._configure_art_dev_unit_skill(gwen)
	gwen.add_skill_resource(2.0)
	_main._sync_art_dev_panel_state()
	var gwen_resource_visible := (
		gwen.is_skill_resource_visible()
		and gwen.get_skill_resource_segment_count() == 3
		and panel._resource_controls.visible
		and is_equal_approx(panel._resource_slider.value, 2.0)
		and is_equal_approx(panel._resource_slider.max_value, 3.0)
	)
	panel._request_resource_value(3.0)
	panel._on_active_skill_pressed()
	var gwen_full_cast_ok := (
		is_zero_approx(gwen.skill_resource_value)
		and gwen.get_visual_action_name() == &"active_3"
		and gwen.is_active_skill_casting()
	)
	_expect(
		gwen_resource_visible and gwen_full_cast_ok,
		"ArtDev 放置格温后显示 3 段资源条，可调满并用满层资源播放对应强化技能动作",
	)

	panel._select_item("sett")
	var sett_stats: Dictionary = CardDB.get_card("sett").duplicate(true)
	sett_stats["deploy_time"] = 0.0
	var sett := Unit.new()
	sett.position = Vector2(460.0, 720.0)
	sett.setup(0, sett_stats, sett_stats.name)
	sett.card_id = "sett"
	_main.add_child(sett)
	_main._workbench.last_units[_main._art_dev_unit_key("sett", 0)] = weakref(sett)
	_main._configure_art_dev_unit_skill(sett)
	_main._sync_art_dev_panel_state()
	panel._request_resource_value(125.0)
	var sett_resource_visible := (
		sett.is_skill_resource_visible()
		and sett.get_skill_resource_segment_count() == 0
		and is_equal_approx(sett.skill_resource_value, 125.0)
		and is_equal_approx(panel._resource_slider.max_value, 200.0)
	)
	_expect(sett_resource_visible, "ArtDev 腕豪显示 0–200 连续豪意条并允许直接调整测试值")

	_main._commands.clear_impacts()
	_main._active_skill_effect_system.clear()
	if is_instance_valid(gwen):
		gwen.free()
	if is_instance_valid(sett):
		sett.free()
	_main._art_dev_panel = old_panel
	_main._workbench.selection = old_selection
	_main._workbench.team = old_team
	_main._workbench.last_units = old_last_units
	_main._workbench.skill_choices = old_choices
	panel.free()

func _check_desktop_camera() -> void:
	var layout := preload("res://scripts/ui/workbench/desktop_layout.gd").new()
	var window := _main.get_window()
	var original_size := window.content_scale_size
	var original_transform := window.canvas_transform
	layout.install(window)
	_expect(is_equal_approx(layout.zoom, 1.0), "开发战场默认完整地图100%")
	layout.center(1.0)
	var field_start := window.canvas_transform * Vector2.ZERO
	var field_end := window.canvas_transform * Vector2(720, 1280)
	_expect(field_start.x >= layout.FIELD_RECT.position.x and field_start.y >= layout.FIELD_RECT.position.y and field_end.x <= layout.FIELD_RECT.end.x and field_end.y <= layout.FIELD_RECT.end.y, "一键全图完整显示权威战场四角")
	layout.zoom_at(2.0, layout.FIELD_RECT.get_center())
	layout.pan(Vector2(10000, 10000))
	_expect(window.canvas_transform.origin.is_equal_approx(layout.FIELD_RECT.position), "放大后拖动到边界可观察战场左上角且不会丢失地图")
	layout.pan(Vector2(-20000, -20000))
	field_end = window.canvas_transform * Vector2(720, 1280)
	_expect(field_end.is_equal_approx(layout.FIELD_RECT.end), "放大后可拖至战场右下角")
	layout.restore()
	_expect(window.content_scale_size == original_size and window.canvas_transform == original_transform, "工作台退出恢复正式对局窗口与坐标变换")

func _check_explicit_inspection() -> void:
	var old_panel: DevelopmentWorkbench = _main._art_dev_panel
	var old_enabled: bool = _main._workbench.enabled
	var panel := DevelopmentWorkbench.new()
	_main.add_child(panel)
	panel.setup(CardDB.all())
	_main._art_dev_panel = panel
	_main._workbench.enabled = true
	_main._workbench.inspect_enabled = true
	panel.item_selected.connect(_main._set_art_dev_selection)
	panel.team_changed.connect(_main._set_art_dev_team)
	panel.active_skill_selected.connect(_main._on_art_dev_active_skill_selected)
	panel.active_skill_requested.connect(_main._use_art_dev_active_skill)
	panel.show_workspace(0)
	_expect(not panel._shelf_panel.visible, "模型页没有实战快捷栏")
	panel._show_library(true)
	_expect(not panel._library.multiple and panel._library.models_only, "模型选择框只选择已接入模型，不编辑快捷栏")
	panel.show_workspace(1)
	panel._on_team_toggled(false)
	panel.set_quick_cards(["garen"])
	panel._select_item("garen")
	_main._workbench_map_click(Vector2(200, 1000))
	var first: Unit = _main._art_dev_selected_unit()
	_expect(first != null and first.card_id == "garen", "快捷栏选卡后点击地图部署并选中")
	panel.set_select_mode(true)
	panel._select_item("ashe")
	panel._on_team_toggled(true)
	var count: int = _main.get_tree().get_nodes_in_group("combatants").size()
	_main._workbench_map_click(Vector2(600, 700))
	_expect(_main.get_tree().get_nodes_in_group("combatants").size() == count and _main._art_dev_selected_unit() == null, "选择模式点击空地只取消目标，不下牌")
	_main._workbench_map_click(first.position)
	_expect(_main._art_dev_selected_unit() == first and panel._skill_source() == "garen", "选中场上单位的技能来源不受待放置卡和阵营影响")
	first.set_meta("workbench_no_skill", true)
	_main._sync_art_dev_panel_state()
	_expect(panel._skill_button.disabled, "普通镜像标记不会因显式选中获得预选技能")
	first.remove_meta("workbench_no_skill")
	panel._select_item("training_dummy")
	_main._workbench_map_click(Vector2(500, 500))
	_expect(_main.get_tree().get_nodes_in_group("combatants").size() == count and panel.is_select_mode(), "木桩不自动退出选择模式，也不隐式放置")
	panel.set_select_mode(false)
	_main._workbench_map_click(Vector2(500, 500))
	var dummy: Unit = _main._art_dev_selected_unit()
	_expect(dummy != null and dummy.card_id == "training_dummy" and dummy.team == 1, "木桩按当前阵营与鼠标落点放置")
	panel.set_quick_cards([])
	panel._select_item("garen")
	count = _main.get_tree().get_nodes_in_group("combatants").size()
	_main._workbench_map_click(Vector2(200, 1100))
	_expect(_main.get_tree().get_nodes_in_group("combatants").size() == count and panel._inspection_controls.visible, "空栏不能部署，技能控制板保持可见")
	panel._show_library(true)
	_expect(panel._library.multiple and panel._library._shelf_grid.visible and not panel.accepts_battle_input(), "实战选择框上方选牌下方编辑槽位，遮罩期间不操作地图")
	panel._library.toggled.emit("garen")
	_expect(panel._quick_cards == ["garen"], "网格单击加入快捷栏")
	panel._library._shelf_grid.get_child(0).pressed.emit()
	_expect(panel._quick_cards.is_empty(), "编辑框点击槽位移除")
	panel._show_library(false)
	var group: Array[Unit] = _main._spawn_card_units(0, "minion_squad", Vector2(200, 850), 0.0)
	var other: Array[Unit] = _main._spawn_card_units(0, "minion_squad", Vector2(500, 850), 0.0)
	_main._workbench.inspect(group[1])
	_main._sync_art_dev_panel_state()
	_main._run_workbench_scenario("freeze")
	_expect(group[1].presentation_state().frozen and not group[0].presentation_state().frozen, "控制只影响选中的编队成员")
	_main._workbench.inspect(group[0])
	_main._sync_art_dev_panel_state()
	panel._select_item("ashe")
	_expect(_main._art_dev_selected_unit() == group[0] and panel._skill_scope.text.contains("整组"), "切待放置卡不换技能目标，整组技能明确标识范围")
	_main._use_art_dev_active_skill(0)
	_expect(group.all(func(unit): return unit.active_buff_timer > 0) and other.all(func(unit): return unit.active_buff_timer == 0), "选中成员施放原卡整组技能，隔离其他部署")
	group[0].take_damage(100000)
	_main._sync_art_dev_panel_state()
	_expect(_main._art_dev_selected_unit() == null and panel._skill_button.disabled, "选中成员死亡后禁止技能，不自动转移目标")
	_main._clear_art_dev_units()
	_expect(_main._workbench.target == null, "清场同时清除显式操作目标")
	_main._workbench.inspect_enabled = false
	_main._workbench.enabled = old_enabled
	_main._art_dev_panel = old_panel
	panel.free()
