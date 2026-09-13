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
	builder._clear_deck_ui()
	await _main.get_tree().process_frame
