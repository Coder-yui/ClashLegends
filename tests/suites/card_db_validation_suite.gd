class_name CardDBValidationSuite
extends RefCounted

func run(harness: Object) -> void:
	var errors := CardDB.validate_all()
	harness._expect(errors.is_empty(), "CardDB 当前全部卡牌通过字段、体型、弹体、资源、动画、建筑、双形态与主动技能校验%s" % (
		"" if errors.is_empty() else "：" + "；".join(errors)
	))
	var access_api_ok := true
	for card_id in CardDB.selectable_ids():
		access_api_ok = access_api_ok and CardDB.has_card(card_id) and not CardDB.get_card(card_id).is_empty()
	harness._expect(access_api_ok and CardDB.get_card("missing_card").is_empty(), "CardDB 统一查询 API 正确处理可选卡与未知 card_id")
