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
	var animation_schema_errors := PackedStringArray()
	CardDB._validate_visual_config("animation_schema_probe", {
		"visual_animations": {
			"visual_actions": {"active": "Spell"},
			"visual_action_durations": {"active": 1.0},
			"transitions": {"skill>move": "Spell_To_Run"},
			"transition_blends": {"action_in": 0.06, "action_out": 0.12},
		},
	}, animation_schema_errors)
	harness._expect(animation_schema_errors.is_empty(), "CardDB validator 登记 visual_action_durations、动作描述与统一 transition policy 字段")
