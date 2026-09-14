extends "res://tests/suites/battle_suite.gd"
## 工作台 UI、素材隔离与真实技能预览契约；由统一回归按原有时序调用。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_artdev_active_skill_timeline()
	_check_artdev_workbench()

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
	var pending_before: int = _main._commands.impacts.size()
	var previewed: bool = _main.preview_active_skill(source, skill)
	var command_buffer_skipped: bool = (
		previewed
		and _main._commands.skill_commands.is_empty()
		and _main._commands.impacts.size() == pending_before + 1
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
	var old_selection: String = _main._art_dev_selection
	var old_team: int = _main._art_dev_team
	var old_last_units: Dictionary = _main._art_dev_last_units.duplicate()
	var old_choices: Dictionary = _main._art_dev_active_skill_choices.duplicate(true)
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
	var search_ok := panel._card_option.item_count == 1 and String(panel._card_option.get_item_metadata(0)) == "gwen"
	panel._filter_cards("")
	panel._select_item("pix")
	var all_cards := panel._card_option.item_count == CardDB.all().size() + 1 and panel._selected_id == "pix"
	panel.show_workspace(1)
	var battle_input := panel.accepts_battle_input()
	panel.show_workspace(0)
	_expect(search_ok and all_cards and battle_input and not panel.accepts_battle_input(), "开发工作台可搜索全部卡及系统对象，仅实战页接受战场放置，无八卡槽限制")

	panel._filter_cards("does-not-exist")
	_expect(panel._card_option.disabled and panel._selected_id == "pix", "搜索无结果不会悄悄改换当前审查卡牌")
	panel._filter_cards("")
	panel._select_item("garen")
	var before_units := _main.get_tree().get_nodes_in_group("combatants").size()
	panel._preview.seek_seconds(0.2)
	var isolated_preview := panel._preview.player != null and not panel._preview.player.is_playing() and is_equal_approx(panel._preview.player.current_animation_position, 0.2)
	_expect(isolated_preview and _main.get_tree().get_nodes_in_group("combatants").size() == before_units, "素材动画可暂停定位且不生成权威单位或攻击")
	panel.show_workspace(2)
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
	var old_dev_mode: bool = _main._art_dev_mode
	var original_zones: int = _main._spell_system.slow_zones.size()
	_main._art_dev_mode = true
	_main.play_card(0, "freeze", Vector2.ZERO, {"immediate": true, "validate_position": false, "preview_active_spell": true})
	var enhanced_preview: bool = _main._spell_system.slow_zones.size() == original_zones + 1
	_main._art_dev_mode = false
	_main.play_card(0, "freeze", Vector2.ZERO, {"immediate": true, "validate_position": false, "preview_active_spell": true})
	_expect(enhanced_preview and _main._spell_system.slow_zones.size() == original_zones + 1, "工作台强化法术仍经统一出牌链，正式对战不接受开发强化开关")
	_main._spell_system.slow_zones.pop_back()
	_main._spell_system.slow_effects.pop_back()
	_main._spell_system.freeze_effects.pop_back()
	_main._spell_system.freeze_effects.pop_back()
	_main._art_dev_mode = old_dev_mode

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
		and int(_main._art_dev_active_skill_choices.get("garen", -1)) == 1
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
	_main._art_dev_last_units[_main._art_dev_unit_key("gwen", 0)] = weakref(gwen)
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
	_main._art_dev_last_units[_main._art_dev_unit_key("sett", 0)] = weakref(sett)
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

	_main._commands.impacts.clear()
	_main._active_skill_effect_system.clear()
	if is_instance_valid(gwen):
		gwen.free()
	if is_instance_valid(sett):
		sett.free()
	_main._art_dev_panel = old_panel
	_main._art_dev_selection = old_selection
	_main._art_dev_team = old_team
	_main._art_dev_last_units = old_last_units
	_main._art_dev_active_skill_choices = old_choices
	panel.free()
