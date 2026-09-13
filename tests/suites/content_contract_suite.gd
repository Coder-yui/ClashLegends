class_name ContentContractSuite
extends RefCounted
## 新卡自动加入的轻量内容契约；角色专项测试只保留独特机制与动画时序。


func run(harness: Object) -> void:
	var errors := PackedStringArray()
	for card_id in CardDB.all():
		var stats: Dictionary = CardDB.get_card(card_id)
		if StringName(stats.get("type", "")) != &"spell":
			errors.append_array(SuiteUtils.visual_contract_errors(card_id, stats))
	harness._expect(
		errors.is_empty(),
		"全部单位/建筑卡的包装场景与动画映射通过通用内容契约%s" % ("" if errors.is_empty() else "：" + "；".join(errors)),
	)
	var missing_card_art: Array[String] = []
	for card_id in CardDB.selectable_ids():
		if CardArt.texture_for(card_id) == null:
			missing_card_art.append(card_id)
	harness._expect(missing_card_art.is_empty(), "全部可选卡按 card_id 自动发现卡面%s" % ("" if missing_card_art.is_empty() else "：" + "、".join(missing_card_art)))
