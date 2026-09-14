class_name CardDBValidationSuite
extends RefCounted

func run(harness: Object) -> void:
	for invalid_registry in [{42: {}}, {"broken": 42}, {"broken": null}, {"broken": []}]:
		harness._expect(not CardDB.VALIDATOR.validate_all(invalid_registry).is_empty(), "注册表错误键或值返回内容错误")
	for id in ["gnar", "gwen", "ashe"]:
		var base := CardDB.get_card(id)
		var paths: Array = []
		_collect_leaf_paths(base, [], paths)
		for path in paths:
			var broken := base.duplicate(true)
			var parent: Variant = broken
			var field_path: String = id
			for index in path.size():
				field_path += ("[%d]" % path[index]) if path[index] is int else "." + str(path[index])
				if index < path.size() - 1: parent = parent[path[index]]
			parent[path[-1]] = null
			var errors: PackedStringArray = CardDB.VALIDATOR.validate_all({id: broken})
			harness._expect(not errors.is_empty() and field_path in "；".join(errors), "类型阶段定位异常叶子：" + field_path)
	var compiler = CardDB.DEFINITION_COMPILER
	for script in CardDB.DEFINITIONS:
		var id: String = script.resource_path.get_file().get_basename()
		harness._expect(compiler.validate(id, script.definition()).is_empty(), "%s 原始四域、技能与变形归属通过" % id)
	for malformed in [null, 42, [], "bad"]:
		var raw_errors: PackedStringArray = compiler.validate("broken", malformed)
		harness._expect(not raw_errors.is_empty() and "broken" in raw_errors[0] and "Dictionary" in raw_errors[0], "原始定义错误类型返回路径和期望类型")
	for domain in ["gameplay", "visual", "audio", "card_art"]:
		var raw_errors: PackedStringArray = compiler.validate("broken", {domain: 42})
		harness._expect(not raw_errors.is_empty() and ("broken." + domain) in raw_errors[0], "定义域容器先检查类型")
	var rejected_definitions := [
		{"gameplay": {"hp": 10}, "visual": {"hp": 20}},
		{"gameplay": {"color": Color.RED}},
		{"visual": {"projectile_collision_radius": 9}},
		{"audio": {"hp": 10}},
		{"gameplay": {"transformed_stats": {"hp": 20}}, "visual": {"transformed_stats": {"hp": 30}}},
		{"gameplay": {"active_skills": [{"damage": 10}]}, "visual": {"active_skills": [{"damage": 20}]}},
		{"gameplay": {"active_skills": [{}]}, "visual": {"active_skills": []}},
		{"gameplay": {"active_skills": [42]}},
		{"gameplay": {"active_skills": []}, "visual": {"active_skills": 42}},
	]
	for definition in rejected_definitions:
		harness._expect(not compiler.validate("broken", definition).is_empty() and CardDB.compile_definition(definition).is_empty(), "错域、重复或形状错误不进入平铺编译")
	var raw := {"gameplay": {"hp": 10, "active_skills": [{"damage": 2}], "transformed_stats": {"hp": 30}},
		"visual": {"color": Color.RED, "active_skills": [{"visual_action": "cast"}], "transformed_stats": {"color": Color.BLUE}},
		"audio": {"transformed_stats": {"attack_hit": ["probe.wav"]}}, "card_art": {"path": "probe.png"}}
	var compiled := CardDB.compile_definition(raw)
	harness._expect(compiled.active_skills[0] == {"damage": 2, "visual_action": "cast"}
		and compiled.transformed_stats == {"hp": 30, "color": Color.BLUE, "audio": {"attack_hit": ["probe.wav"]}}, "技能按索引、变形按域合并为原有平铺运行格式")
	compiled.active_skills[0].damage = 99
	compiled.transformed_stats.audio.attack_hit[0] = "changed.wav"
	harness._expect(raw.gameplay.active_skills[0].damage == 2 and raw.audio.transformed_stats.attack_hit[0] == "probe.wav", "编译结果深复制，不污染原始定义")
	for field in ["events", "attack_launch_by_segment", "attack_hit_once_by_segment", "team_overrides"]:
		for malformed in [42, true, null, "invalid"]:
			var probe := CardDB.get_card("gnar").duplicate(true)
			probe.audio[field] = malformed
			var shape_errors := PackedStringArray()
			CardDB.VALIDATOR._validate_audio_config("shape_probe", probe, shape_errors)
			harness._expect("shape_probe.audio." + field in "；".join(shape_errors), "音频坏容器返回字段路径错误而不抛脚本异常：" + field)
	var path_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_audio_path_pool("path_probe.audio.attack_hit", [42, null, {}], path_errors)
	harness._expect(path_errors.size() == 3 and "String" in "；".join(path_errors), "声音池非字符串元素在加载资源前报告类型错误")
	var errors := CardDB.validate_all()
	harness._expect(errors.is_empty(), "CardDB 当前全部卡牌通过字段、体型、弹体、资源、动画、建筑、双形态与主动技能校验%s" % (
		"" if errors.is_empty() else "：" + "；".join(errors)
	))
	var custom := CardDB.get_card("anivia").duplicate(true)
	var radius_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_combat_stats("custom", custom, true, radius_errors)
	var custom_ok := radius_errors.is_empty() and is_equal_approx(float(custom.radius), 20.0)
	custom.erase("custom_radius")
	CardDB.VALIDATOR._validate_combat_stats("standard", custom, true, radius_errors)
	harness._expect(custom_ok and not radius_errors.is_empty(), "显式自定义半径允许冰鸟 0.5 格，未声明的体型半径偏差仍拒绝")
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
	CardDB.VALIDATOR._validate_audio_config("audio_probe", {
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
	var masteryi_audio: Dictionary = CardDB.get_card("masteryi").get("audio", {})
	var masteryi_swing_groups: Array = masteryi_audio.get("attack_swing", [])
	var masteryi_swing_pools_ok := masteryi_swing_groups.size() == 3
	for pool in masteryi_swing_groups:
		masteryi_swing_pools_ok = masteryi_swing_pools_ok and pool is Array and not (pool as Array).is_empty()
	var masteryi_events: Dictionary = masteryi_audio.get("events", {})
	var masteryi_audio_ok := (
		masteryi_swing_pools_ok
		and (masteryi_audio.get("attack_hit", []) as Array).size() == 16
		and masteryi_events.has("active_buff:start")
		and masteryi_events.has("active_buff:sustain")
		and masteryi_events.has("active_buff:end")
		and masteryi_events.has("death")
	)
	harness._expect(masteryi_audio_ok, "CardDB 登记剑圣三段挥击、命中、高原血统起止/持续与死亡音频事件")
	var animation_schema_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_visual_config("animation_schema_probe", {
		"visual_animations": {
			"visual_actions": {"active": "Spell"},
			"visual_action_durations": {"active": 1.0},
			"transitions": {"skill>move": {"animation": "Spell_To_Run", "blend_in": 0.0, "blend_out": 0.02}},
			"transition_blends": {"action_in": 0.06, "action_out": 0.12},
		},
	}, animation_schema_errors)
	harness._expect(animation_schema_errors.is_empty(), "CardDB validator 登记 visual_action_durations、动作描述与逐边 transition blend 字段")
	var active_schema_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_active_skills("timeline_probe", {
		"visual_animations": {"visual_actions": {"active": {"animation": ["A", "B"], "durations": [1.0], "kind": "skill"}}},
		"active_skills": [{
			"name": "时间轴探针", "kind": "buff", "duration": 1.0,
			"cast_duration": 1.0, "impact_delay": 1.1,
			"visual_action": "active", "cast_locks": ["movement"],
		}],
	}, active_schema_errors)
	CardDB.VALIDATOR._validate_visual_config("timeline_probe", {
		"visual_animations": {"visual_actions": {"active": {"animation": ["A", "B"], "durations": [1.0], "kind": "skill"}}},
	}, active_schema_errors)
	var unknown_field_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_known_fields("probe", {"future_field": true}, [], unknown_field_errors)
	var has_impact_error := false
	var has_duration_error := false
	var has_lock_error := false
	for error in active_schema_errors:
		has_impact_error = has_impact_error or "impact_delay" in error
		has_duration_error = has_duration_error or "durations" in error
		has_lock_error = has_lock_error or "cast_locks" in error
	var transform_timing_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_active_skills("transform_timing_probe", {
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
	CardDB.VALIDATOR._validate_card("spell_probe", {
		"name": "探针", "cost": 1, "type": "spell", "description": "测试",
		"radius": 10.0, "duration": 1.0, "spell_kind": "missing", "color": Color.WHITE,
	}, spell_errors)
	var reference_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_references("reference_probe", {
		"spawn_id": "missing_unit",
		"active_skills": [{"kind": "summon", "spawn_id": "missing_active_unit"}],
	}, CardDB.all(), reference_errors)
	harness._expect(
		not spell_errors.is_empty() and "spell_kind" in "；".join(spell_errors)
		and reference_errors.size() == 2,
		"CardDB 在运行前拒绝未实现法术和失效的周期/主动召唤引用",
	)
	var hero_rework_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_combat_stats("resource_probe", {
		"hp": 100.0, "damage": 10.0, "range": 10.0, "speed": 10.0, "interval": 1.0,
		"first_hit": 0.2, "is_air": false, "building_only": false, "can_attack_air": false,
		"size_tier": "medium", "mass": 1.0, "sight": 100.0, "visual_radius": 20.0,
		"radius": CardDB.SIZE_RADII.medium,
		"skill_resource_max": 0.0, "skill_resource_attack_gain": 10.0,
		"deploy_sweep_radius": 90.0, "deploy_sweep_damage": -1.0, "deploy_sweep_knockback": 90.0,
		"deploy_sweep_duration": 0.0, "deploy_sweep_mass_factor_max": 0.0,
	}, true, hero_rework_errors)
	CardDB.VALIDATOR._validate_visual_config("attack_route_probe", {
		"visual_animations": {
			"attack": ["Attack1", "Attack2"],
			"attack_to_move": ["Attack1_ToRun"],
		},
	}, hero_rework_errors)
	CardDB.VALIDATOR._validate_active_skills("frontal_probe", {
		"active_skills": [{
			"name": "非法扇形", "kind": "frontal", "shape": "fan",
			"length": 0.0, "damage": -1.0, "arc_degrees": 180.0, "projectile_count": -1, "center_width": -1.0,
			"projectile_visual_height": -1.0, "projectile_visual_forward_offset": -1.0, "projectile_visual_width": 0.0,
			"impact_delay": 0.2, "cast_duration": 0.3,
		}],
	}, hero_rework_errors)
	var projectile_visual_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_projectile("projectile_visual_probe", {
		"projectile_speed": 100.0, "projectile_visual": "orb",
		"projectile_visual_scale": 0.0, "projectile_impact_visual": "unknown",
	}, projectile_visual_errors)
	CardDB.VALIDATOR._validate_active_skills("nova_probe", {
		"active_skills": [{
			"name": "非法范围击退", "kind": "nova", "radius": 90.0, "damage": 90.0,
			"knockback": 90.0, "knockback_duration": 0.0, "knockback_mass_factor_max": 0.0,
		}],
	}, hero_rework_errors)
	CardDB.VALIDATOR._validate_active_skills("empowered_probe", {
		"active_skills": [{
			"name": "非法强化普攻", "kind": "empowered_attack",
			"empowered_damage_multiplier": 0.0, "empowered_speed_multiplier": 0.5,
			"blind_charges": -1,
		}],
	}, hero_rework_errors)
	CardDB.VALIDATOR._validate_active_skills("forward_area_probe", {
		"active_skills": [{
			"name": "非法落星", "kind": "forward_area", "uses_skill_resource": true,
			"forward_distance": 0.0, "radius": 0.0, "damage": -1.0, "stun_duration": -1.0,
			"impact_delay": 2.0, "cast_duration": 1.0,
			"shockwave_damage": -1.0, "shockwave_duration": 0.0, "shockwave_end_radius": 0.0,
		}],
	}, hero_rework_errors)
	CardDB.VALIDATOR._validate_active_skills("continuous_area_probe", {
		"active_skills": [{
			"name": "非法持续范围", "kind": "continuous_area",
			"radius": 0.0, "damage": -1.0, "duration": 4.0, "tick_interval": 0.0,
			"cast_duration": 3.0,
		}],
	}, hero_rework_errors)
	CardDB.VALIDATOR._validate_combat_stats("extra_hit_probe", {
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

	for field in ["projectile_spawn_offset", "projectile_collision_radius", "projectile_speed"]:
		for value in ["bad", [], {}, NAN, INF, -1.0]:
			var errors_geometry := PackedStringArray()
			CardDB.VALIDATOR._validate_projectile("geometry", {field: value}, errors_geometry)
			harness._expect(not errors_geometry.is_empty() and field in "；".join(errors_geometry), "弹体权威字段 %s 拒绝错误类型、非有限和负值" % field)
	var edge_errors := PackedStringArray()
	CardDB.VALIDATOR._validate_projectile("geometry", {"projectile_spawn_at_edge": "true"}, edge_errors)
	CardDB.VALIDATOR._validate_projectile("geometry", {"projectile_collision_radius": 0.0}, edge_errors)
	harness._expect(edge_errors.size() == 2, "弹体边缘开关必须为布尔且碰撞半径严格大于零")

func _collect_leaf_paths(value: Variant, path: Array, result: Array) -> void:
	if value is Dictionary:
		for key in value: _collect_leaf_paths(value[key], path + [key], result)
	elif value is Array:
		for index in value.size(): _collect_leaf_paths(value[index], path + [index], result)
	else:
		result.append(path)
