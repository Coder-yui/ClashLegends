class_name DeckBuilderSuite
extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_main._deck = []
	_main._pick_deck_ui(func() -> void: return)
	await _main.get_tree().process_frame
	await _main.get_tree().process_frame
	var builder: DeckBuilder = _main._deck_builder
	_expect(not builder._deck_slot_buttons[0].disabled and builder._deck_slot_buttons[0].text == "+", "空卡组位置显示加号并可点击选择位置")
	builder._deck_slot_buttons[0].emit_signal("pressed")
	_expect(builder._deck_pending_slot == 0 and not builder._deck_context_popup.visible, "点击空卡槽后进入指定位置添加状态")
	var ashe_button: Button = builder._deck_toggles["ashe"]
	ashe_button.emit_signal("pressed")
	await _main.get_tree().process_frame
	_expect(builder._deck_selected == ["ashe"] and not builder._deck_toggles.has("ashe"), "从牌库选牌后添加到指定卡槽并从牌库隐藏")
	builder._on_deck_slot_pressed(0)
	builder._perform_deck_context_action()
	_expect(builder._deck_selected.is_empty() and builder._deck_toggles.has("ashe"), "移除卡槽卡牌后重新显示在牌库")
	builder._on_deck_filter_selected(3)
	_expect(builder._deck_toggles.has("tombstone") and not builder._deck_toggles.has("garen"), "牌库可以按建筑类型筛选")
	builder._on_deck_filter_selected(0)
	builder._on_deck_sort_selected(1)
	var asc_pool: Array = builder._deck_pool_grid.get_children()
	var asc_first_id: String = String(asc_pool[0].get_meta("card_id", ""))
	var asc_last_id: String = String(asc_pool[-1].get_meta("card_id", ""))
	var asc_ok: bool = asc_pool.size() > 1 and int(CardDB.get_card(asc_first_id).cost) <= int(CardDB.get_card(asc_last_id).cost)
	builder._on_deck_sort_selected(2)
	var desc_pool: Array = builder._deck_pool_grid.get_children()
	var desc_first_id: String = String(desc_pool[0].get_meta("card_id", ""))
	var desc_last_id: String = String(desc_pool[-1].get_meta("card_id", ""))
	var desc_ok: bool = desc_pool.size() > 1 and int(CardDB.get_card(desc_first_id).cost) >= int(CardDB.get_card(desc_last_id).cost)
	_expect(asc_ok and desc_ok, "牌库支持按金币消耗递增或递减排序")
	builder._on_deck_sort_selected(0)
	builder._on_deck_pool_card_pressed("garen")
	_expect(
		builder._deck_context_popup.visible
		and builder._deck_context_from_pool
		and builder._deck_context_action.text == "添加"
		and builder._deck_selected.is_empty(),
		"点击卡牌库卡牌只显示信息/添加，不会立即改动卡组"
	)
	builder._on_deck_pool_card_pressed("garen")
	_expect(not builder._deck_context_popup.visible, "再次点击同一张牌会收起信息/添加操作")
	builder._on_deck_pool_card_pressed("garen")
	builder._perform_deck_context_action()
	_expect(builder._deck_selected == ["garen"], "卡牌库的添加操作把卡牌放入下一个空卡位")
	builder._on_deck_slot_pressed(0)
	_expect(
		builder._deck_context_popup.visible
		and not builder._deck_context_from_pool
		and builder._deck_context_action.text == "移除",
		"点击卡槽卡牌显示信息/移除"
	)
	builder._open_selected_card_info()
	await _main.get_tree().process_frame
	_expect(
		builder._deck_info_overlay != null
		and builder._deck_info_active_option.item_count == 2
		and not builder._deck_info_active_option.disabled
		and builder._deck_info_active_rules != null
		and builder._deck_info_active_cost_label.text.contains("金币消耗")
		and builder._deck_info_active_uses_label.text.contains("最多 2 次")
		and builder._deck_info_active_uses_label.text.contains("冷却")
		and builder._skin_choices.get("garen", "") == "default",
		"信息页展示主动技能选择、金币消耗、单位次数、冷却与默认原皮入口"
	)
	builder._close_card_info()
	builder._on_deck_slot_pressed(0)
	builder._perform_deck_context_action()
	_expect(builder._deck_selected.is_empty(), "卡槽的移除操作移除选中卡牌")
	for trial in range(12):
		builder._randomize_deck()
		var unique := {}
		for id in builder._deck_selected:
			unique[id] = true
		_expect(builder._deck_selected.size() == 8 and unique.size() == 8 and not builder._deck_confirm.disabled, "随机卡组填满八个不重复卡位并可进入游戏")
		for index in range(2):
			var id := String(builder._deck_selected[index])
			var skills := CardDB.active_skills_for(id)
			var choice := int(builder._active_skill_choices.get(id, -1))
			_expect(choice >= 0 and choice < maxi(skills.size(), 1), "随机主动槽使用该卡合法技能索引")
	builder._clear_deck_ui()
	await _main.get_tree().process_frame

	var loading_match = load("res://scenes/main.tscn").instantiate()
	_main.get_tree().root.add_child(loading_match)
	loading_match._deck = ["tombstone", "gnar", "garen", "ashe", "pix", "xin", "heal", "freeze"]
	var started := Time.get_ticks_msec()
	loading_match._start_local_with_loading()
	loading_match._start_local_with_loading()
	await _main.get_tree().create_timer(0.2, true).timeout
	_expect(_main.get_tree().paused and loading_match._battle_loading and not loading_match._audio_manager.can_process(), "加载阶段暂停战斗与音频，重复点击不重复开局")
	while loading_match._battle_loading:
		await _main.get_tree().process_frame
	_expect(Time.get_ticks_msec() - started >= 1000 and not _main.get_tree().paused and loading_match._towers.size() == 6, "加载至少一秒后恢复对局且只创建一份战场")
	_expect(loading_match._resources.cards.has("imp") and loading_match._resources.cards.has("super_minion"), "本场资源准备递归包含召唤物和后续超级兵")
	var transformed := PresentationConfig.for_form(CardDB.get_card("gnar"), 1)
	_expect(loading_match._resources.resources.has(PresentationConfig.scene_path(transformed, 1)), "本场资源覆盖对方模型与变身形态")
	var event: Dictionary = PresentationConfig.audio_stats("world_nexus_order").audio.events.death
	_expect(loading_match._audio_manager._stream_pool_cache.has("\n".join(PackedStringArray(event.pool))), "水晶爆炸音轨在开局前已建立缓存")
	var path := PresentationConfig.scene_path(CardDB.get_card("melee_minion"), 0)
	var pool: MatchModelPool = loading_match._battle_presentation.model_pool
	_expect(pool.warmed_particle_systems.size() == LolParticleEffect3D.system_names().size(), "原生强化/弹体/命中粒子在加载阶段全部预热")
	var dependencies_ok := true
	for dependency in LolParticleEffect3D.dependency_paths():
		dependencies_ok = dependencies_ok and loading_match._resources.resources.has(dependency)
	_expect(dependencies_ok and not LolParticleEffect3D._materials.is_empty() and not LolParticleEffect3D._meshes.is_empty(), "动态粒子纹理、网格和材质模板提前保留，首次技能不再读取资源")
	var prepared_count: int = pool.instances[path].size()
	var source_count := _main.get_tree().get_nodes_in_group("combatants").size()
	var unit = loading_match._spawn_unit(0, "melee_minion", Vector2(300, 800), 0.0)
	_expect(pool.instances[path].size() == prepared_count - 1 and unit != null, "正式小兵领取预建模型，避免首次登场实例化与动画库复制")
	_expect(_main.get_tree().get_nodes_in_group("combatants").size() == source_count + 1, "预热样本不进入权威单位列表")
	loading_match.free()
