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
	var garen_audio: Dictionary = CardDB.get_card("garen").get("audio", {})
	var garen_audio_ok := (
		(garen_audio.get("attack_swing", []) as Array).size() == 2
		and (garen_audio.get("attack_hit", []) as Array).size() == 16
	)
	var audio_schema_errors := PackedStringArray()
	CardDB._validate_audio_config("audio_probe", {
		"visual_animations": {"attack": ["Attack1", "Attack2"]},
		"audio": {
			"attack_swing": [["res://missing.wav"]],
			"attack_hit": [],
		},
	}, audio_schema_errors)
	harness._expect(
		garen_audio_ok and "声音池数量" in "；".join(audio_schema_errors) and "资源不存在" in "；".join(audio_schema_errors),
		"CardDB 登记盖伦两段挥击/命中音频池，并拒绝段数不匹配与失效资源路径",
	)
	var animation_schema_errors := PackedStringArray()
	CardDB._validate_visual_config("animation_schema_probe", {
		"visual_animations": {
			"visual_actions": {"active": "Spell"},
			"visual_action_durations": {"active": 1.0},
			"transitions": {"skill>move": {"animation": "Spell_To_Run", "blend_in": 0.0, "blend_out": 0.02}},
			"transition_blends": {"action_in": 0.06, "action_out": 0.12},
		},
	}, animation_schema_errors)
	harness._expect(animation_schema_errors.is_empty(), "CardDB validator 登记 visual_action_durations、动作描述与逐边 transition blend 字段")
	var active_schema_errors := PackedStringArray()
	CardDB._validate_active_skills("timeline_probe", {
		"visual_animations": {"visual_actions": {"active": {"animation": ["A", "B"], "durations": [1.0], "kind": "skill"}}},
		"active_skills": [{
			"name": "时间轴探针", "kind": "buff", "duration": 1.0,
			"cast_duration": 1.0, "impact_delay": 1.1,
			"visual_action": "active", "cast_locks": ["movement"],
		}],
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
		"active_skills": [{
			"name": "变形时间轴探针", "kind": "dual_form",
			"length": 1.0, "width": 1.0, "damage": 1.0,
			"impact_delay": 0.5, "cast_duration": 1.0, "stun_duration": 1.0,
			"transform_impact_delay": 0.5,
		}],
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
	var spell_errors := PackedStringArray()
	CardDB._validate_card("spell_probe", {
		"name": "探针", "cost": 1, "type": "spell", "description": "测试",
		"radius": 10.0, "duration": 1.0, "spell_kind": "missing", "color": Color.WHITE,
	}, spell_errors)
	var reference_errors := PackedStringArray()
	CardDB._validate_references("reference_probe", {
		"spawn_id": "missing_unit",
		"active_skills": [{"kind": "summon", "spawn_id": "missing_active_unit"}],
	}, CardDB.all(), reference_errors)
	harness._expect(
		not spell_errors.is_empty() and "spell_kind" in "；".join(spell_errors)
		and reference_errors.size() == 2,
		"CardDB 在运行前拒绝未实现法术和失效的周期/主动召唤引用",
	)
	var hero_rework_errors := PackedStringArray()
	CardDB._validate_combat_stats("resource_probe", {
		"hp": 100.0, "damage": 10.0, "range": 10.0, "speed": 10.0, "interval": 1.0,
		"first_hit": 0.2, "is_air": false, "building_only": false, "can_attack_air": false,
		"size_tier": "medium", "mass": 1.0, "sight": 100.0, "visual_radius": 20.0,
		"radius": CardDB.SIZE_RADII.medium,
		"skill_resource_max": 0.0, "skill_resource_attack_gain": 10.0,
		"deploy_sweep_radius": 90.0, "deploy_sweep_damage": -1.0, "deploy_sweep_knockback": 90.0,
		"deploy_sweep_duration": 0.0, "deploy_sweep_mass_factor_max": 0.0,
	}, true, hero_rework_errors)
	CardDB._validate_visual_config("attack_route_probe", {
		"visual_animations": {
			"attack": ["Attack1", "Attack2"],
			"attack_to_move": ["Attack1_ToRun"],
		},
	}, hero_rework_errors)
	CardDB._validate_active_skills("frontal_probe", {
		"active_skills": [{
			"name": "非法扇形", "kind": "frontal", "shape": "fan",
			"length": 0.0, "damage": -1.0, "arc_degrees": 180.0, "projectile_count": -1, "center_width": -1.0,
			"projectile_visual_height": -1.0, "projectile_visual_forward_offset": -1.0, "projectile_visual_width": 0.0,
			"impact_delay": 0.2, "cast_duration": 0.3,
		}],
	}, hero_rework_errors)
	var projectile_visual_errors := PackedStringArray()
	CardDB._validate_projectile("projectile_visual_probe", {
		"projectile_speed": 100.0, "projectile_visual": "orb",
		"projectile_visual_scale": 0.0, "projectile_impact_visual": "unknown",
	}, projectile_visual_errors)
	CardDB._validate_active_skills("nova_probe", {
		"active_skills": [{
			"name": "非法范围击退", "kind": "nova", "radius": 90.0, "damage": 90.0,
			"knockback": 90.0, "knockback_duration": 0.0, "knockback_mass_factor_max": 0.0,
		}],
	}, hero_rework_errors)
	CardDB._validate_active_skills("empowered_probe", {
		"active_skills": [{
			"name": "非法强化普攻", "kind": "empowered_attack",
			"empowered_damage_multiplier": 0.0, "empowered_speed_multiplier": 0.5,
			"blind_charges": -1,
		}],
	}, hero_rework_errors)
	CardDB._validate_active_skills("forward_area_probe", {
		"active_skills": [{
			"name": "非法落星", "kind": "forward_area", "uses_skill_resource": true,
			"forward_distance": 0.0, "radius": 0.0, "damage": -1.0, "stun_duration": -1.0,
			"impact_delay": 2.0, "cast_duration": 1.0,
			"shockwave_damage": -1.0, "shockwave_duration": 0.0, "shockwave_end_radius": 0.0,
		}],
	}, hero_rework_errors)
	CardDB._validate_active_skills("continuous_area_probe", {
		"active_skills": [{
			"name": "非法持续范围", "kind": "continuous_area",
			"radius": 0.0, "damage": -1.0, "duration": 4.0, "tick_interval": 0.0,
			"cast_duration": 3.0,
		}],
	}, hero_rework_errors)
	CardDB._validate_combat_stats("extra_hit_probe", {
		"hp": 100.0, "damage": 10.0, "range": 10.0, "speed": 10.0, "interval": 1.0,
		"first_hit": 0.2, "is_air": false, "building_only": false, "can_attack_air": false,
		"size_tier": "medium", "mass": 1.0, "sight": 100.0, "visual_radius": 20.0,
		"radius": CardDB.SIZE_RADII.medium,
		"attack_extra_hit_damage_multipliers": [[], [0.5]], "attack_extra_hit_delays": [[]],
	}, true, hero_rework_errors)
	var hero_error_text := "；".join(hero_rework_errors)
	harness._expect(
		"skill_resource_max" in hero_error_text
		and "deploy_sweep_damage" in hero_error_text and "deploy_sweep_duration" in hero_error_text
		and "knockback_duration" in hero_error_text and "knockback_mass_factor_max" in hero_error_text
		and "attack_to_move" in hero_error_text
		and "length" in hero_error_text and "arc_degrees" in hero_error_text and "projectile_count" in hero_error_text and "center_width" in hero_error_text
		and "projectile_visual_height" in hero_error_text and "projectile_visual_forward_offset" in hero_error_text
		and "projectile_visual_width" in hero_error_text
		and "projectile_visual_scale" in "；".join(projectile_visual_errors) and "projectile_impact_visual" in "；".join(projectile_visual_errors)
		and "empowered_damage_multiplier" in hero_error_text
		and "empowered_speed_multiplier" in hero_error_text and "blind_charges" in hero_error_text
		and "forward_distance" in hero_error_text and "shockwave_duration" in hero_error_text
		and "tick_interval" in hero_error_text
		and "uses_skill_resource" in hero_error_text and "attack_extra_hit_delays" in hero_error_text,
		"CardDB 在运行前拒绝非法豪意、部署/主动击退、攻击转移动路线、前方/落点范围、追加刀和强化普攻配置",
	)
