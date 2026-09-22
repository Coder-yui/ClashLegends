extends "res://scripts/data/card_schema.gd"
## 所有语义/资源校验之前的类型阶段。字段白名单仍由 CardSchema 管理。
const TEXT_FIELDS := ["icon_path", "rush_spawn_id", "name", "type", "description", "size_tier", "deploy_zone", "spawn_id", "spawn_side", "death_spawn_id", "death_replacement_id", "death_replacement_visual_transition", "timed_revival_id", "timed_revival_visual_transition", "active_buff_projectile_visual", "projectile_visual", "projectile_impact_visual", "deploy_sweep_name", "spell_kind", "active_name", "visual_active_buff_scene", "visual_scene_path", "kind", "visual_action", "shape", "full_resource_visual_action", "target_scope", "deployment_formation"]
const BOOL_FIELDS := ["deploy_pocket_requires_both_towers", "form_lifetime_after_transition", "form_refresh_on_kill", "selectable", "custom_radius", "is_air", "is_building", "building_only", "can_attack_air", "is_continuous_attack", "deploy_ignore_structures", "show_team_ring", "lifespan_hp_decay", "tower_ruin_foundation", "projectile_spawn_at_edge", "shield_decay", "shield_on_cast_start", "independent_on_creation", "ignore_movement_slow", "ignore_attack_speed_slow", "ground_only", "fan_inner_arc", "projectile_stop_on_hit", "projectile_piercing", "uses_skill_resource", "cast_end_heal_requires_hit", "applies_on_hit_passive", "shockwave_full_only", "global_heal", "copy_member_buff"]
const NUMERIC_ARRAY_FIELDS := ["attack_passive_multipliers", "attack_lifesteal_ratios", "attack_pattern", "attack_damage_multipliers", "attack_extra_hit_damage_multipliers", "attack_extra_hit_delays", "resource_damage_by_stacks", "resource_hit_damage_sequences", "resource_hit_delay_sequences"]

static func validate(label: String, stats: Dictionary, errors: PackedStringArray, skill: bool = false) -> bool:
	var before := errors.size()
	for key in stats:
		var path := label + "." + str(key)
		if not _text(key):
			_error(path, key, "String 字段名", errors)
			continue
		if key not in (ACTIVE_SKILL_FIELDS if skill else CARD_FIELDS): continue
		var value = stats[key]
		if key in TEXT_FIELDS:
			check(path, value, "text", errors)
		elif key in BOOL_FIELDS:
			check(path, value, "bool", errors)
		elif key in ["color", "continuous_beam_color", "skill_resource_full_color"]:
			check(path, value, "color", errors)
		elif key == "footprint_tiles":
			check(path, value, "vector2i", errors)
		elif key in ["visual_scene_paths", "resource_visual_actions", "cast_locks", "deployment_member_ids"]:
			array(path, value, "text", errors)
		elif key == "projectile_colors":
			array(path, value, "color", errors)
		elif key in NUMERIC_ARRAY_FIELDS:
			array(path, value, "numbers" if key in ["resource_hit_damage_sequences", "resource_hit_delay_sequences", "attack_extra_hit_damage_multipliers", "attack_extra_hit_delays"] else "number", errors)
		elif key == "active_skills":
			if check(path, value, "array", errors):
				for index in value.size():
					var child := "%s[%d]" % [path, index]
					if check(child, value[index], "dictionary", errors): validate(child, value[index], errors, true)
		elif key == "transformed_stats":
			if check(path, value, "dictionary", errors): validate(path, value, errors)
		elif key == "card_art":
			if check(path, value, "dictionary", errors) and value.has("path"): check(path + ".path", value.path, "text", errors)
		elif key == "audio":
			_audio(path, value, errors)
		elif key == "visual_animations":
			_animations(path, value, errors)
		else:
			check(path, value, "number", errors)
	return errors.size() == before

static func _audio(path: String, value: Variant, errors: PackedStringArray) -> void:
	if not check(path, value, "dictionary", errors): return
	for key in value:
		var child := path + "." + str(key)
		if not _text(key):
			_error(child, key, "String 字段名", errors)
			continue
		match key:
			"team_overrides":
				if check(child, value[key], "array", errors):
					for index in value[key].size(): _audio("%s[%d]" % [child, index], value[key][index], errors)
			"events":
				if not check(child, value[key], "dictionary", errors): continue
				for cue in value[key]:
					var event_path := child + "." + str(cue)
					if not check(event_path, cue, "text", errors) or not check(event_path, value[key][cue], "dictionary", errors): continue
					var event: Dictionary = value[key][cue]
					if event.has("pool"): array(event_path + ".pool", event.pool, "text", errors)
					if event.has("bus"): check(event_path + ".bus", event.bus, "text", errors)
					if event.has("owner"): check(event_path + ".owner", event.owner, "text", errors)
					if event.has("volume_db"): check(event_path + ".volume_db", event.volume_db, "number", errors)
					if event.has("action_time"): check(event_path + ".action_time", event.action_time, "number", errors)
			"attack_swing", "attack_launch_by_segment", "attack_hit_by_segment":
				if check(child, value[key], "array", errors):
					for index in value[key].size(): array("%s[%d]" % [child, index], value[key][index], "text", errors)
			"attack_hit", "empowered_hit", "first_strike_hit": array(child, value[key], "text", errors)
			"attack_launch_until_impact": check(child, value[key], "bool", errors)
			"attack_hit_once_by_segment": array(child, value[key], "bool", errors)
			_: if key in AUDIO_FIELDS: check(child, value[key], "number", errors)

static func _animations(path: String, value: Variant, errors: PackedStringArray) -> void:
	if not check(path, value, "dictionary", errors): return
	for key in value:
		var child := path + "." + str(key)
		if not _text(key):
			_error(child, key, "String 字段名", errors)
			continue
		if key not in VISUAL_ANIMATION_FIELDS: continue
		match key:
			"visual_actions", "transitions":
				if not check(child, value[key], "dictionary", errors): continue
				for action in value[key]:
					var action_path := child + "." + str(action)
					if not check(action_path, action, "text", errors): continue
					var descriptor = value[key][action]
					if not descriptor is Dictionary:
						check(action_path, descriptor, "names", errors)
						continue
					for field in descriptor:
						var field_path := action_path + "." + str(field)
						if not check(field_path, field, "text", errors): continue
						if field == "animation": check(field_path, descriptor[field], "names", errors)
						elif field == "kind": check(field_path, descriptor[field], "text", errors)
						elif field in ["durations", "clip_ranges"]: array(field_path, descriptor[field], "numbers", errors)
						else: check(field_path, descriptor[field], "number", errors)
			"visual_action_durations", "clip_blends", "transition_blends":
				if check(child, value[key], "dictionary", errors):
					for entry in value[key]:
						check(child + "." + str(entry), entry, "text", errors)
						check(child + "." + str(entry), value[key][entry], "numbers", errors)
			"death_followup_immediate": check(child, value[key], "bool", errors)
			"deploy_durations", "attack_clip_ranges", "attack_hit_clip_ranges": array(child, value[key], "numbers", errors)
			"deploy_clip_ratio", "attack_hit_duration", "attack_recover_delay", "attack_reference_interval", "death_duration", "death_clip_end", "death_followup_duration": check(child, value[key], "numbers", errors)
			"death", "death_followup_scene_path", "death_followup_animation": check(child, value[key], "text", errors)
			_: check(child, value[key], "names", errors)

static func array(path: String, value: Variant, element: String, errors: PackedStringArray) -> void:
	if not check(path, value, "array", errors): return
	for index in value.size(): check("%s[%d]" % [path, index], value[index], element, errors)

static func check(path: String, value: Variant, expected: String, errors: PackedStringArray) -> bool:
	var valid := false
	match expected:
		"text": valid = _text(value)
		"bool": valid = value is bool
		"color": valid = value is Color
		"vector2i": valid = value is Vector2i
		"array": valid = value is Array
		"dictionary": valid = value is Dictionary
		"number": valid = (value is int or value is float) and is_finite(float(value))
		"names":
			if value is Array:
				array(path, value, "text", errors)
				return true
			valid = _text(value)
		"numbers":
			if value is Array:
				array(path, value, "number", errors)
				return true
			valid = (value is int or value is float) and is_finite(float(value))
	if not valid: _error(path, value, expected, errors)
	return valid

static func _text(value: Variant) -> bool:
	return value is String or value is StringName

static func _error(path: String, value: Variant, expected: String, errors: PackedStringArray) -> void:
	var names := {"text": "String / StringName", "number": "有限 int / float 数值", "numbers": "有限数值或数值数组", "names": "动画名或动画名数组", "dictionary": "Dictionary", "array": "Array", "bool": "bool", "color": "Color", "vector2i": "Vector2i"}
	errors.append("%s: 期望 %s，实际 %s（%s）" % [path, names.get(expected, expected), type_string(typeof(value)), str(value)])
