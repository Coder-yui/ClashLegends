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
	var active_schema_errors := PackedStringArray()
	CardDB._validate_active_skills("timeline_probe", {
		"visual_animations": {"visual_actions": {"active": {"animation": ["A", "B"], "durations": [1.0], "kind": "skill"}}},
		"active_skill": {
			"name": "时间轴探针", "kind": "buff", "duration": 1.0,
			"cast_duration": 1.0, "impact_delay": 1.1,
			"visual_action": "active", "cast_locks": ["movement"],
		},
	}, active_schema_errors)
	CardDB._validate_visual_config("timeline_probe", {
		"visual_animations": {"visual_actions": {"active": {"animation": ["A", "B"], "durations": [1.0], "kind": "skill"}}},
	}, active_schema_errors)
	var unknown_field_errors := PackedStringArray()
	CardDB._validate_known_fields("probe", {"future_field": true}, [], unknown_field_errors)
	var has_impact_error := false
	var has_duration_error := false
	var has_lock_error := false
	for error in active_schema_errors:
		has_impact_error = has_impact_error or "impact_delay" in error
		has_duration_error = has_duration_error or "durations" in error
		has_lock_error = has_lock_error or "cast_locks" in error
	var transform_timing_errors := PackedStringArray()
	CardDB._validate_active_skills("transform_timing_probe", {
		"active_skill": {
			"name": "变形时间轴探针", "kind": "dual_form",
			"length": 1.0, "width": 1.0, "damage": 1.0,
			"impact_delay": 0.5, "cast_duration": 1.0, "stun_duration": 1.0,
			"transform_impact_delay": 0.5,
		},
	}, transform_timing_errors)
	var has_transform_timing_error := false
	for error in transform_timing_errors:
		has_transform_timing_error = has_transform_timing_error or "transform_impact_delay" in error
	harness._expect(
		has_impact_error and has_duration_error and has_lock_error
		and has_transform_timing_error
		and not unknown_field_errors.is_empty() and "未知或未登记字段" in unknown_field_errors[0],
		"CardDB validator 校验主动动作映射、动作时长数组、Impact/施法关系、全身动作攻击锁和统一未知字段提示",
	)
