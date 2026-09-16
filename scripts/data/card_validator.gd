extends "res://scripts/data/card_schema.gd"
const SHAPES = preload("res://scripts/data/card_shape_validator.gd")

## 返回当前全部配置错误。空数组表示 CardDB 可以安全进入运行时。
static func validate_all(cards: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_numbers("princess_tower", PRINCESS_TOWER_STATS, errors)
	_validate_projectile("princess_tower", PRINCESS_TOWER_STATS, errors)
	_validate_numbers("nexus", NEXUS_STATS, errors)
	for raw_card_id in cards:
		if not raw_card_id is String and not raw_card_id is StringName:
			errors.append("card_id: 期望 String，实际 %s（%s）" % [type_string(typeof(raw_card_id)), str(raw_card_id)])
			continue
		var card_id := String(raw_card_id)
		if not cards[raw_card_id] is Dictionary:
			errors.append("%s: 期望 Dictionary，实际 %s（%s）" % [card_id, type_string(typeof(cards[raw_card_id])), str(cards[raw_card_id])])
			continue
		var stats: Dictionary = cards[raw_card_id]
		if not SHAPES.validate(card_id, stats, errors): continue
		_validate_card_id(card_id, errors)
		_validate_known_fields(card_id, stats, CARD_FIELDS, errors)
		_validate_numbers(card_id, stats, errors)
		_validate_card(card_id, stats, errors)
		_validate_references(card_id, stats, cards, errors)
	return errors

static func _validate_card_id(card_id: String, errors: PackedStringArray) -> void:
	if card_id.is_empty() or card_id != card_id.to_snake_case() or card_id.to_lower() != card_id:
		errors.append("%s: card_id 必须是非空英文 snake_case" % card_id)

static func _validate_card(card_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	if not SHAPES.validate(card_id, stats, errors): return
	_require_fields(card_id, stats, [&"name", &"cost", &"type", &"description", &"radius", &"color"], errors)
	var card_type := StringName(stats.get("type", ""))
	if card_type not in CARD_TYPES:
		errors.append("%s.type: 不支持的卡牌类型 %s" % [card_id, card_type])
		return
	if String(stats.get("name", "")).is_empty():
		errors.append("%s.name: 不能为空" % card_id)
	if float(stats.get("cost", -1.0)) < 0.0:
		errors.append("%s.cost: 必须 >= 0" % card_id)
	if float(stats.get("radius", 0.0)) <= 0.0:
		errors.append("%s.radius: 必须 > 0" % card_id)
	if stats.has("deploy_zone"):
		var dz := StringName(stats.get("deploy_zone", ""))
		if dz not in DEPLOY_ZONES:
			errors.append("%s.deploy_zone: 必须是 DEPLOY_ZONES 之一 (%s)" % [card_id, "、".join(DEPLOY_ZONES)])
	if stats.has("deploy_ignore_structures") and typeof(stats.deploy_ignore_structures) != TYPE_BOOL:
		errors.append("%s.deploy_ignore_structures: 必须是 bool" % card_id)
	if stats.has("pre_deploy_time") and float(stats.get("pre_deploy_time", 0.0)) < 0.0:
		errors.append("%s.pre_deploy_time: 必须 >= 0" % card_id)
	if float(stats.get("pre_deploy_time", 0.0)) > 0.0 and card_type == &"spell":
		errors.append("%s.pre_deploy_time: 法术不能使用单位预部署阶段" % card_id)
	if String(stats.get("deployment_formation", "ring")) not in ["ring", "line", "polygon"]:
		errors.append("%s.deployment_formation: 仅支持 ring/line/polygon" % card_id)
	if String(stats.get("deployment_formation", "ring")) == "line" and (int(stats.get("deployment_count", 1)) - 1) * float(stats.get("deployment_spacing", 0.0)) + 2.0 * float(stats.get("radius", 0.0)) > ArenaRules.FIELD_W:
		errors.append("%s: 横排宽度不能超过战场" % card_id)
	if stats.has("deployment_count"):
		if card_type != &"unit":
			errors.append("%s.deployment_count: 只有单位卡可以编队部署" % card_id)
		var deployment_count := int(stats.get("deployment_count", 0))
		if deployment_count <= 0:
			errors.append("%s.deployment_count: 必须 > 0" % card_id)
		if deployment_count > 1 and float(stats.get("deployment_spacing", 0.0)) <= 0.0:
			errors.append("%s.deployment_spacing: 编队数量大于 1 时必须 > 0" % card_id)
	match card_type:
		&"unit":
			_validate_combat_stats(card_id, stats, true, errors)
		&"building":
			_validate_combat_stats(card_id, stats, false, errors)
			_validate_building(card_id, stats, errors)
		&"spell":
			_require_fields(card_id, stats, [&"spell_kind", &"duration"], errors)
			var spell_kind := StringName(stats.get("spell_kind", ""))
			if spell_kind not in SPELL_KINDS:
				errors.append("%s.spell_kind: 系统不支持 %s" % [card_id, spell_kind])
			if float(stats.get("duration", 0.0)) <= 0.0:
				errors.append("%s.duration: 法术持续时间必须 > 0" % card_id)
			match spell_kind:
				&"heal":
					if float(stats.get("heal_amount", 0.0)) <= 0.0:
						errors.append("%s.heal_amount: 治疗法术必须配置 > 0 的治疗量" % card_id)
					if stats.has("active_cost_bonus") and int(stats.active_cost_bonus) < 0:
						errors.append("%s.active_cost_bonus: 必须是 >= 0 的整数" % card_id)
	var art = stats.get("card_art", {})
	if not art is Dictionary:
		errors.append("%s.card_art: 必须是 Dictionary" % card_id)
	else:
		_validate_known_fields(card_id + ".card_art", art, ["path"], errors)
		if art.has("path") and (not ResourceLoader.exists(String(art.path)) or not load(String(art.path)) is Texture2D):
			errors.append("%s.card_art.path: 必须是存在的 Texture2D" % card_id)
	_validate_visual_config(card_id, stats, errors)
	_validate_audio_config(card_id, stats, errors)
	_validate_active_skills(card_id, stats, errors)
	if stats.has("transformed_stats"):
		var transformed = stats.get("transformed_stats")
		if not transformed is Dictionary or (transformed as Dictionary).is_empty():
			errors.append("%s.transformed_stats: 必须是非空 Dictionary" % card_id)
		else:
			_validate_known_fields("%s.transformed_stats" % card_id, transformed, CARD_FIELDS, errors)
			_validate_combat_stats("%s.transformed_stats" % card_id, transformed, true, errors)
			_validate_visual_config("%s.transformed_stats" % card_id, transformed, errors)
			if transformed.has("audio"):
				var capabilities := stats.duplicate()
				capabilities.merge(transformed, true)
				_validate_audio_config("%s.transformed_stats" % card_id, capabilities, errors)

static func _validate_audio_config(label: String, stats: Dictionary, errors: PackedStringArray) -> void:
	if not SHAPES.validate(label, stats, errors): return
	if not stats.has("audio"):
		return
	var audio = stats.get("audio")
	if not audio is Dictionary:
		errors.append("%s.audio: 必须是 Dictionary" % label)
		return
	_validate_known_fields("%s.audio" % label, audio as Dictionary, AUDIO_FIELDS, errors)
	# 先确认容器形状，再执行事件能力、段数及跨字段规则，不能让校验器先崩溃。
	var malformed := false
	for field in ["events", "team_overrides", "attack_swing", "attack_hit", "attack_launch_by_segment", "attack_hit_by_segment", "attack_hit_once_by_segment", "empowered_hit", "first_strike_hit"]:
		if not audio.has(field):
			continue
		var expected := TYPE_DICTIONARY if field == "events" else TYPE_ARRAY
		if typeof(audio[field]) != expected:
			errors.append("%s.audio.%s: 期望 %s，实际 %s（%s）" % [label, field, type_string(expected), type_string(typeof(audio[field])), str(audio[field])])
			malformed = true
	if malformed:
		return

	if audio.has("team_overrides"):
		var teams = audio.team_overrides
		if not teams is Array or teams.size() != 2:
			errors.append("%s.audio.team_overrides: 必须包含双方两套配置" % label)
		else:
			for team in 2:
				if not teams[team] is Dictionary or teams[team].has("team_overrides"):
					errors.append("%s.audio.team_overrides: 必须是无嵌套阵营覆盖的 Dictionary" % label)
					continue
				var selected := stats.duplicate(true)
				selected.audio = PresentationConfig.audio_for(stats, team)
				_validate_audio_config("%s.team%d" % [label, team], selected, errors)
	if audio.has("attack_launch_until_impact"):
		if typeof(audio.attack_launch_until_impact) != TYPE_BOOL:
			errors.append("%s.audio.attack_launch_until_impact: 必须为布尔值" % label)
		elif audio.attack_launch_until_impact and (float(stats.get("projectile_speed", 0.0)) <= 0.0 or (not audio.get("events", {}).has("attack_launch") and audio.get("attack_launch_by_segment", []).is_empty())):
			errors.append("%s.audio.attack_launch_until_impact: 需要普通弹体及发射音频" % label)
	var events = audio.get("events", {})
	if not events is Dictionary:
		errors.append("%s.audio.events: 必须是 Dictionary" % label)
	else:
		for cue in events:
			if not cue is String and not cue is StringName:
				errors.append("%s.audio.events: 事件名称必须为 String，实际 %s" % [label, type_string(typeof(cue))])
				continue
			if not PresentationEvents.supports(stats, String(cue)):
				errors.append("%s.audio.events.%s: 未绑定的表现事件或机制无派发能力" % [label, cue])
			var event = events[cue]
			if not event is Dictionary:
				errors.append("%s.audio.events.%s: 必须是 Dictionary" % [label, cue])
				continue
			_validate_known_fields("%s.audio.events.%s" % [label, cue], event, [&"pool", &"volume_db", &"bus"], errors)
			if event.get("bus", "Combat") not in ["Combat", "Voice"]:
				errors.append("%s.audio.events.%s.bus: 只支持 Combat / Voice" % [label, cue])
			_validate_audio_path_pool("%s.audio.events.%s.pool" % [label, cue], event.get("pool", []), errors)
			if typeof(event.get("volume_db", 0.0)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(event.get("volume_db", 0.0))):
				errors.append("%s.audio.events.%s.volume_db: 必须是有限分贝数值" % [label, cue])
	if audio.has("attack_swing_lead_time"):
		var lead = audio.attack_swing_lead_time
		if typeof(lead) not in [TYPE_INT, TYPE_FLOAT] or float(lead) < 0.0 or float(stats.get("damage", 0.0)) <= 0.0:
			errors.append("%s.audio.attack_swing_lead_time: 必须是有普攻单位的非负秒数" % label)
	if audio.has("attack_hit_once_by_segment"):
		var grouped = audio.attack_hit_once_by_segment
		var animation_config = stats.get("visual_animations", {})
		var attack_clips = animation_config.get("attack", []) if animation_config is Dictionary else []
		var count: int = attack_clips.size() if attack_clips is Array else 1
		if not grouped is Array or grouped.size() != count:
			errors.append("%s.audio.attack_hit_once_by_segment: 必须与普攻段数一致" % label)
		else:
			for value in grouped:
				if typeof(value) != TYPE_BOOL:
					errors.append("%s.audio.attack_hit_once_by_segment: 元素必须为布尔值" % label)
	for key in ["attack_swing", "attack_hit", "attack_launch_by_segment", "attack_hit_by_segment", "empowered_hit", "first_strike_hit"]:
		if audio.has(key) and (String(stats.get("type", "")) == "spell" or float(stats.get("damage", 0.0)) <= 0.0):
			errors.append("%s.audio.%s: 无普攻能力" % [label, key])
	for field in ["attack_swing", "attack_launch_by_segment", "attack_hit_by_segment"]:
		var swing = (audio as Dictionary).get(field, [])
		if audio.has(field) and (not swing is Array or (swing as Array).is_empty()):
			errors.append("%s.audio.%s: 必须是按攻击段排列的非空声音池数组" % [label, field])
		elif audio.has(field):
			var animations = stats.get("visual_animations", {})
			var configured_attacks = (animations as Dictionary).get("attack", []) if animations is Dictionary else []
			var attack_count := (configured_attacks as Array).size() if configured_attacks is Array else (0 if String(configured_attacks).is_empty() else 1)
			if attack_count > 0 and attack_count != (swing as Array).size():
				errors.append("%s.audio.%s: 声音池数量必须与 visual_animations.attack 数量一致" % [label, field])
			for index in (swing as Array).size():
				_validate_audio_path_pool("%s.audio.%s[%d]" % [label, field, index], (swing as Array)[index], errors)
	if audio.has("attack_hit"):
		_validate_audio_path_pool("%s.audio.attack_hit" % label, audio.attack_hit, errors)
	if audio.has("empowered_hit"):
		if not PresentationEvents.supports(stats, "empowered_swing"):
			errors.append("%s.audio.empowered_hit: 无强化普攻机制" % label)
		_validate_audio_path_pool("%s.audio.empowered_hit" % label, audio.empowered_hit, errors)
	if (audio as Dictionary).has("first_strike_hit"):
		if float(stats.get("first_strike_damage_multiplier", 1.0)) == 1.0 or bool(stats.get("is_continuous_attack", false)):
			errors.append("%s.audio.first_strike_hit: 无首击机制" % label)
		_validate_audio_path_pool("%s.audio.first_strike_hit" % label, (audio as Dictionary).get("first_strike_hit", []), errors)
	for volume_field in [&"attack_swing_volume_db", &"attack_hit_volume_db"]:
		if (audio as Dictionary).has(volume_field) and typeof((audio as Dictionary)[volume_field]) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("%s.audio.%s: 必须是分贝数值" % [label, volume_field])

static func _validate_audio_path_pool(label: String, configured: Variant, errors: PackedStringArray) -> void:
	if not configured is Array or (configured as Array).is_empty():
		errors.append("%s: 必须是非空资源路径数组" % label)
		return
	for index in (configured as Array).size():
		var raw_path = (configured as Array)[index]
		if not raw_path is String:
			errors.append("%s[%d]: 期望 String 资源路径，实际 %s（%s）" % [label, index, type_string(typeof(raw_path)), str(raw_path)])
			continue
		var path: String = raw_path
		if path.is_empty() or not path.begins_with("res://"):
			errors.append("%s[%d]: 必须是 res:// 音频资源路径" % [label, index])
		elif not ResourceLoader.exists(path):
			errors.append("%s[%d]: 资源不存在 %s" % [label, index, path])
		elif not load(path) is AudioStream:
			errors.append("%s[%d]: 资源不是 AudioStream" % [label, index])

static func _validate_combat_stats(label: String, stats: Dictionary, require_size_tier: bool, errors: PackedStringArray) -> void:
	if not SHAPES.validate(label, stats, errors): return
	for field in ["attack_passive_multipliers", "attack_lifesteal_ratios"]:
		if not stats.has(field): continue
		var values: Array = stats[field]
		if values.is_empty() or values.any(func(value): return float(value) < 0.0 or float(value) > 1.0):
			errors.append("%s.%s: 需要非空的 0..1 比例数组" % [label, field])
		if float(stats.get("projectile_speed", 0.0)) > 0.0 or float(stats.get("splash_radius", 0.0)) > 0.0 or bool(stats.get("is_continuous_attack", false)) or not stats.get("attack_extra_hit_damage_multipliers", []).is_empty():
			errors.append("%s.%s: 当前仅支持无追加刀的单体近战" % [label, field])
	if stats.has("passive_first_hit"):
		var passive_delay := float(stats.passive_first_hit)
		if passive_delay <= 0.0 or passive_delay >= float(stats.get("interval", 0.0)) or stats.get("attack_passive_multipliers", []).is_empty():
			errors.append("%s.passive_first_hit: 需要被动攻击循环，且 0 < 前摇 < 攻击间隔" % label)
	if stats.has("attack_lifesteal_ratios") and stats.get("attack_lifesteal_ratios", []).size() != stats.get("attack_passive_multipliers", []).size():
		errors.append("%s.attack_lifesteal_ratios: 必须与被动循环等长" % label)
	var cycle_animations = stats.get("visual_animations", {}).get("attack", [])
	var cycle_animation_count: int = cycle_animations.size() if cycle_animations is Array else 1
	if stats.has("attack_passive_multipliers") and cycle_animation_count != stats.attack_passive_multipliers.size():
		errors.append("%s.attack_passive_multipliers: 必须与攻击动作等长" % label)
	if float(stats.get("form_speed_boost_duration", 0.0)) < 0.0 or float(stats.get("form_speed_boost_multiplier", 1.0)) < 1.0:
		errors.append("%s: 形态加速时长必须非负，倍率至少为1" % label)
	if float(stats.get("form_lifetime", 0.0)) < 0.0 or (bool(stats.get("form_refresh_on_kill", false)) and float(stats.get("form_lifetime", 0.0)) <= 0.0):
		errors.append("%s.form_lifetime: 刷新形态需要正数持续时间" % label)
	for field in [&"on_hit_max_health_ratio", &"on_hit_tower_damage"]:
		if stats.has(field) and (not (stats[field] is float or stats[field] is int) or not is_finite(float(stats[field])) or float(stats[field]) < 0.0):
			errors.append("%s.%s: 必须为非负有限数值" % [label, field])
	if float(stats.get("on_hit_max_health_ratio", 0.0)) > 1.0:
		errors.append("%s.on_hit_max_health_ratio: 必须 <= 1" % label)
	_require_fields(label, stats, [&"hp", &"damage", &"range", &"speed", &"interval", &"is_air", &"building_only", &"can_attack_air"], errors)
	if float(stats.get("damage", 0.0)) > 0.0:
		_require_fields(label, stats, [&"first_hit"], errors)
	for field in [&"hp", &"range", &"speed", &"interval"]:
		if float(stats.get(field, -1.0)) < 0.0:
			errors.append("%s.%s: 必须 >= 0" % [label, field])
	if float(stats.get("hp", 0.0)) <= 0.0:
		errors.append("%s.hp: 必须 > 0" % label)
	if stats.has("first_hit") and float(stats.first_hit) < 0.0:
		errors.append("%s.first_hit: 必须 >= 0" % label)
	if stats.has("custom_radius") and typeof(stats.custom_radius) != TYPE_BOOL:
		errors.append("%s.custom_radius: 必须为布尔值" % label)
	if require_size_tier:
		_require_fields(label, stats, [&"size_tier", &"mass", &"sight", &"visual_radius"], errors)
		var size_tier := StringName(stats.get("size_tier", ""))
		if not SIZE_RADII.has(size_tier):
			errors.append("%s.size_tier: 不属于七档体型" % label)
		elif not bool(stats.get("custom_radius", false)) and not is_equal_approx(float(stats.get("radius", 0.0)), float(SIZE_RADII[size_tier])):
			errors.append("%s.radius: 与 size_tier=%s 的规范半径不匹配" % [label, size_tier])
	if stats.has("visual_radius") and float(stats.visual_radius) < float(stats.get("radius", 0.0)):
		errors.append("%s.visual_radius: 不得小于权威 radius" % label)
	if stats.has("timed_revival_delay"):
		if float(stats.get("timed_revival_delay", 0.0)) <= 0.0:
			errors.append("%s.timed_revival_delay: 必须 > 0" % label)
	if stats.has("death_replacement_id") and int(stats.get("death_replacement_charges", 0)) <= 0:
		errors.append("%s.death_replacement_charges: 声明死亡替身时必须 > 0" % label)
	if stats.has("timed_revival_death_replacement_charges") and int(stats.get("timed_revival_death_replacement_charges", -1)) < 0:
		errors.append("%s.timed_revival_death_replacement_charges: 必须 >= 0" % label)
	for transition_field in [&"death_replacement_visual_transition", &"timed_revival_visual_transition"]:
		if stats.has(transition_field) and not StringName(stats.get(transition_field, "")) in VISUAL_SPAWN_TRANSITIONS:
			errors.append("%s.%s: 只支持 %s" % [label, transition_field, VISUAL_SPAWN_TRANSITIONS])
	if stats.has("deploy_sweep_radius"):
		_require_fields(label, stats, [&"deploy_sweep_damage", &"deploy_sweep_knockback", &"deploy_sweep_duration", &"deploy_sweep_mass_factor_max"], errors)
		if float(stats.get("deploy_sweep_radius", 0.0)) <= 0.0:
			errors.append("%s.deploy_sweep_radius: 必须 > 0" % label)
		for deploy_nonnegative in [&"deploy_sweep_damage", &"deploy_sweep_knockback"]:
			if float(stats.get(deploy_nonnegative, 0.0)) < 0.0:
				errors.append("%s.%s: 必须 >= 0" % [label, deploy_nonnegative])
		for deploy_positive in [&"deploy_sweep_duration", &"deploy_sweep_mass_factor_max"]:
			if float(stats.get(deploy_positive, 0.0)) <= 0.0:
				errors.append("%s.%s: 必须 > 0" % [label, deploy_positive])
	if stats.has("first_strike_damage_multiplier") and float(stats.first_strike_damage_multiplier) <= 0.0:
		errors.append("%s.first_strike_damage_multiplier: 必须 > 0" % label)
	for resource_field in [&"skill_resource_max", &"skill_resource_attack_gain", &"skill_resource_hit_gain", &"skill_resource_kill_gain", &"skill_resource_damage_gain_multiplier"]:
		if float(stats.get(resource_field, 0.0)) < 0.0:
			errors.append("%s.%s: 必须 >= 0" % [label, resource_field])
	for resource_decay_field in [&"skill_resource_decay_delay", &"skill_resource_decay_rate"]:
		if float(stats.get(resource_decay_field, 0.0)) < 0.0:
			errors.append("%s.%s: 必须 >= 0" % [label, resource_decay_field])
	if (
		float(stats.get("skill_resource_attack_gain", 0.0)) > 0.0
		or float(stats.get("skill_resource_hit_gain", 0.0)) > 0.0
		or float(stats.get("skill_resource_kill_gain", 0.0)) > 0.0
		or float(stats.get("skill_resource_damage_gain_multiplier", 0.0)) > 0.0
	) and float(stats.get("skill_resource_max", 0.0)) <= 0.0:
		errors.append("%s.skill_resource_max: 配置资源获取时必须 > 0" % label)
	_validate_projectile(label, stats, errors)
	var attack_extras = stats.get("attack_extra_hit_damage_multipliers", [])
	var attack_delays = stats.get("attack_extra_hit_delays", [])
	if attack_extras is Array:
		if not (attack_delays is Array) or (attack_delays as Array).size() != (attack_extras as Array).size():
			errors.append("%s.attack_extra_hit_delays: 必须与额外刀伤害配置长度一致" % label)
		else:
			for index in (attack_extras as Array).size():
				var multipliers = (attack_extras as Array)[index]
				var delays = (attack_delays as Array)[index]
				if not multipliers is Array or not delays is Array or (multipliers as Array).size() != (delays as Array).size():
					errors.append("%s.attack_extra_hit_damage_multipliers[%d]: 伤害与延迟必须是等长数组" % [label, index])
					continue
				for value in multipliers:
					if float(value) <= 0.0:
						errors.append("%s.attack_extra_hit_damage_multipliers[%d]: 倍率必须 > 0" % [label, index])
				for value in delays:
					if float(value) < 0.0:
						errors.append("%s.attack_extra_hit_delays[%d]: 延迟必须 >= 0" % [label, index])

static func _validate_projectile(label: String, stats: Dictionary, errors: PackedStringArray) -> void:
	if not SHAPES.validate(label, stats, errors): return
	if stats.has("projectile_spawn_at_edge") and not stats.projectile_spawn_at_edge is bool:
		errors.append("%s.projectile_spawn_at_edge: 必须是 bool" % label)
	for field in ["projectile_spawn_offset", "projectile_collision_radius", "projectile_speed"]:
		if not stats.has(field):
			continue
		var value = stats[field]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("%s.%s: 必须是有限数值" % [label, field])
			return
		if not is_finite(float(value)) or float(value) < 0.0 or (field == "projectile_collision_radius" and float(value) <= 0.0):
			errors.append("%s.%s: 必须是有限%s数值" % [label, field, "正" if field == "projectile_collision_radius" else "非负"])
	var speed := float(stats.get("projectile_speed", 0.0))
	if speed < 0.0:
		errors.append("%s.projectile_speed: 必须 >= 0" % label)
	if stats.has("active_buff_projectile_visual"):
		if speed <= 0.0 or not (stats.active_buff_projectile_visual is String or stats.active_buff_projectile_visual is StringName) or StringName(stats.active_buff_projectile_visual) != &"baron_siege":
			errors.append("%s.active_buff_projectile_visual: 需要远程弹体及已实现的 baron_siege" % label)
	if speed <= 0.0:
		return
	var visual := StringName(stats.get("projectile_visual", "orb"))
	if visual not in PROJECTILE_VISUALS:
		errors.append("%s.projectile_visual: 不支持 %s" % [label, visual])
	if float(stats.get("projectile_visual_height", 0.0)) < 0.0 or float(stats.get("projectile_visual_forward_offset", 0.0)) < 0.0:
		errors.append("%s: 弹体表现高度和前向偏移必须 >= 0" % label)
	if float(stats.get("projectile_visual_scale", 1.0)) <= 0.0:
		errors.append("%s.projectile_visual_scale: 必须 > 0" % label)
	if StringName(stats.get("projectile_impact_visual", "")) not in [&"", &"splash_wave"]:
		errors.append("%s.projectile_impact_visual: 只支持 splash_wave" % label)
	if stats.has("projectile_colors"):
		var colors = stats.projectile_colors
		if not colors is Array or colors.size() != 2 or not colors[0] is Color or not colors[1] is Color:
			errors.append("%s.projectile_colors: 必须是蓝/红双方两个 Color" % label)

static func _validate_building(card_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	_require_fields(card_id, stats, [&"is_building", &"footprint_tiles", &"lifespan", &"visual_radius"], errors)
	if not bool(stats.get("is_building", false)):
		errors.append("%s.is_building: building 卡必须为 true" % card_id)
	if stats.has("lifespan_hp_decay") and typeof(stats.lifespan_hp_decay) != TYPE_BOOL:
		errors.append("%s.lifespan_hp_decay: 必须是 bool" % card_id)
	if stats.has("tower_ruin_foundation") and typeof(stats.tower_ruin_foundation) != TYPE_BOOL:
		errors.append("%s.tower_ruin_foundation: 必须是 bool" % card_id)
	var footprint = stats.get("footprint_tiles")
	if not footprint is Vector2i or footprint.x <= 0 or footprint.y <= 0:
		errors.append("%s.footprint_tiles: 必须是正数 Vector2i" % card_id)
	if float(stats.get("speed", -1.0)) != 0.0:
		errors.append("%s.speed: 建筑必须为 0" % card_id)
	if float(stats.get("spawn_interval", 0.0)) < 0.0:
		errors.append("%s.spawn_interval: 必须 >= 0" % card_id)
	if float(stats.get("spawn_interval", 0.0)) > 0.0:
		_require_fields(card_id, stats, [&"spawn_id", &"spawn_count"], errors)
		if int(stats.get("spawn_count", 0)) <= 0:
			errors.append("%s.spawn_count: 周期召唤数量必须 > 0" % card_id)
	if int(stats.get("death_spawn_count", 0)) < 0:
		errors.append("%s.death_spawn_count: 必须 >= 0" % card_id)
	elif int(stats.get("death_spawn_count", 0)) > 0 and String(stats.get("death_spawn_id", "")).is_empty():
		errors.append("%s.death_spawn_id: 亡语召唤数量大于 0 时不能为空" % card_id)


static func _validate_references(card_id: String, stats: Dictionary, cards: Dictionary, errors: PackedStringArray) -> void:
	for field in [&"spawn_id", &"death_spawn_id", &"death_replacement_id", &"timed_revival_id"]:
		var referenced_id := String(stats.get(field, ""))
		if not referenced_id.is_empty() and not _unit_reference_exists(referenced_id, cards):
			errors.append("%s.%s: 引用了不存在或不可生成的单位 %s" % [card_id, field, referenced_id])
	var skills: Array = stats.get("active_skills", []) if stats.get("active_skills", []) is Array else []
	for index in range(skills.size()):
		var skill = skills[index]
		if not skill is Dictionary or StringName(skill.get("kind", "")) != &"summon":
			continue
		var spawn_id := String(skill.get("spawn_id", ""))
		if not _unit_reference_exists(spawn_id, cards):
			errors.append("%s.active_skills[%d].spawn_id: 引用了不存在或不可生成的单位 %s" % [card_id, index, spawn_id])


static func _unit_reference_exists(card_id: String, cards: Dictionary) -> bool:
	if not cards.has(card_id) or not cards[card_id] is Dictionary:
		return false
	return cards[card_id].get("type", "") in [&"unit", &"building"]

static func _validate_visual_config(label: String, stats: Dictionary, errors: PackedStringArray) -> void:
	if not SHAPES.validate(label, stats, errors): return
	for path_field in [&"visual_scene_path"]:
		var path := String(stats.get(path_field, ""))
		if not path.is_empty() and not ResourceLoader.exists(path):
			errors.append("%s.%s: 资源不存在 %s" % [label, path_field, path])
	if stats.has("visual_active_buff_scene"):
		var effect_path = stats.visual_active_buff_scene
		if not effect_path is String or not ResourceLoader.exists(effect_path):
			errors.append("%s.visual_active_buff_scene: 必须是存在的场景路径" % label)
		else:
			var packed = load(effect_path)
			if not packed is PackedScene:
				errors.append("%s.visual_active_buff_scene: 必须是 PackedScene" % label)
			else:
				var instance = packed.instantiate()
				if not instance is ActiveBuffVisual3D:
					errors.append("%s.visual_active_buff_scene: 根节点必须实现 ActiveBuffVisual3D" % label)
				instance.free()
	if stats.has("visual_scene_paths"):
		var paths = stats.visual_scene_paths
		if not paths is Array or paths.size() != 2:
			errors.append("%s.visual_scene_paths: 必须是蓝/红双方两个路径" % label)
		else:
			for path in paths:
				if not path is String or not ResourceLoader.exists(path):
					errors.append("%s.visual_scene_paths: 资源不存在 %s" % [label, path])
	if not stats.has("visual_animations"):
		return
	var animations = stats.visual_animations
	if not animations is Dictionary:
		errors.append("%s.visual_animations: 必须是 Dictionary" % label)
		return
	_validate_known_fields("%s.visual_animations" % label, animations, VISUAL_ANIMATION_FIELDS, errors)
	for field in ["attack_clip_ranges", "attack_hit_clip_ranges"]:
		if not animations.has(field): continue
		var ranges = animations[field]
		var clips = animations.get("attack" if field == "attack_clip_ranges" else "attack_hit", [])
		if not ranges is Array or not clips is Array or ranges.size() != clips.size():
			errors.append("%s.visual_animations.%s: 必须与对应攻击段等长" % [label, field])
			continue
		for section in ranges:
			if not section is Array:
				errors.append("%s.%s: 每段应为 [] 或 [start, end]" % [label, field])
			elif not section.is_empty():
				if section.size() != 2 or typeof(section[0]) not in [TYPE_FLOAT, TYPE_INT] or typeof(section[1]) not in [TYPE_FLOAT, TYPE_INT]:
					errors.append("%s.%s: 片段区间应为两个数值" % [label, field])
				elif not is_finite(float(section[0])) or not is_finite(float(section[1])) or float(section[0]) < 0.0 or float(section[1]) <= float(section[0]):
					errors.append("%s.%s: 片段区间必须有限且 end > start >= 0" % [label, field])
	if animations.has("death_clip_end"):
		var end = animations.death_clip_end
		if typeof(end) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(end)) or float(end) <= 0.0 or String(animations.get("death", "")).is_empty():
			errors.append("%s.visual_animations.death_clip_end: 需要死亡动画及有限正秒数" % label)
	if animations.has("attack_reference_interval"):
		var reference = animations.attack_reference_interval
		if typeof(reference) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(reference)) or float(reference) <= 0.0:
			errors.append("%s.visual_animations.attack_reference_interval: 必须是有限正秒数" % label)
		if not animations.has("attack_hit"):
			errors.append("%s.visual_animations.attack_reference_interval: 需要分段 attack_hit" % label)
		if animations.has("attack_hit_duration") or animations.has("attack_recover_delay"):
			errors.append("%s.visual_animations.attack_reference_interval: 不与手工 Hit/Recover 时长同时配置" % label)
	if animations.has("clip_blends"):
		var clip_blends = animations.clip_blends
		if not clip_blends is Dictionary:
			errors.append("%s.visual_animations.clip_blends: 必须是 Dictionary" % label)
		else:
			for edge in clip_blends:
				var pair := String(edge).split(">")
				var value = clip_blends[edge]
				if pair.size() != 2 or pair[0].is_empty() or pair[1].is_empty() or pair[1] == "*":
					errors.append("%s.visual_animations.clip_blends: 使用 源片段>目标片段（源可为 *）" % label)
				if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or float(value) < 0.0:
					errors.append("%s.visual_animations.clip_blends.%s: 必须是有限非负秒数" % [label, edge])
	for state in [
		&"deploy", &"idle", &"idle_cycle", &"move", &"move_enter", &"haste_move", &"move_cycle", &"attack", &"attack_hit", &"attack_recover",
		&"initial_move", &"attack_structure", &"attack_move", &"attack_to_move", &"empowered_idle", &"empowered_move", &"empowered_attack",
		&"empowered_attack_hit", &"empowered_attack_recover", &"empowered_attack_to_move",
	]:
		if not animations.has(state):
			continue
		var value = animations[state]
		if not value is String and not value is StringName and not value is Array:
			errors.append("%s.visual_animations.%s: 必须是动画名或动画名数组" % [label, state])
		elif value is Array:
			for animation_name in value:
				if not animation_name is String and not animation_name is StringName:
					errors.append("%s.visual_animations.%s: 数组只能包含动画名" % [label, state])
	var attack_values = animations.get("attack", [])
	var attack_count: int = attack_values.size() if attack_values is Array else (1 if animations.has("attack") else 0)
	for route_key in [&"attack_move", &"attack_to_move"]:
		if not animations.has(route_key):
			continue
		var route_values = animations.get(route_key, [])
		if route_values is Array and attack_count > 0 and route_values.size() != attack_count:
			errors.append("%s.visual_animations.%s: 按攻击段配置时必须与 attack 数量一致" % [label, route_key])
	if animations.has("visual_actions"):
		var actions = animations.visual_actions
		if not actions is Dictionary:
			errors.append("%s.visual_animations.visual_actions: 必须是 Dictionary" % label)
		else:
			for action in actions:
				var action_label := "%s.visual_animations.visual_actions.%s" % [label, action]
				var action_config = actions[action]
				if action_config is Dictionary:
					_validate_visual_action_descriptor(action_label, action_config, errors)
				else:
					_validate_animation_name_value(action_label, action_config, errors)
	if animations.has("visual_action_durations"):
		var durations = animations.visual_action_durations
		if not durations is Dictionary:
			errors.append("%s.visual_animations.visual_action_durations: 必须是 Dictionary" % label)
		else:
			for action in durations:
				_validate_positive_number_or_array("%s.visual_animations.visual_action_durations.%s" % [label, action], durations[action], errors)
	if animations.has("transitions"):
		var transitions = animations.transitions
		if not transitions is Dictionary:
			errors.append("%s.visual_animations.transitions: 必须是 Dictionary" % label)
		else:
			for transition in transitions:
				var transition_label := "%s.visual_animations.transitions.%s" % [label, transition]
				var transition_config = transitions[transition]
				if transition_config is Dictionary:
					_validate_visual_transition_descriptor(transition_label, transition_config, errors)
				else:
					_validate_animation_name_value(transition_label, transition_config, errors)
	if animations.has("transition_blends"):
		var blends = animations.transition_blends
		if not blends is Dictionary:
			errors.append("%s.visual_animations.transition_blends: 必须是 Dictionary" % label)
		else:
			_validate_known_fields("%s.visual_animations.transition_blends" % label, blends, TRANSITION_BLEND_FIELDS, errors)
			for blend_key in blends:
				var blend_value = blends[blend_key]
				if (not blend_value is float and not blend_value is int) or float(blend_value) < 0.0:
					errors.append("%s.visual_animations.transition_blends.%s: 必须是 >= 0 的秒数" % [label, blend_key])
	if animations.has("death_followup_immediate"):
		if typeof(animations.death_followup_immediate) != TYPE_BOOL:
			errors.append("%s.visual_animations.death_followup_immediate: 必须为布尔值" % label)
		elif animations.death_followup_immediate and (String(animations.get("death_followup_scene_path", "")).is_empty() or String(animations.get("death_followup_animation", "")).is_empty()):
			errors.append("%s.visual_animations.death_followup_immediate: 必须配置死亡替换场景及动画" % label)
	if animations.has("death_followup_scene_path") and not ResourceLoader.exists(String(animations.death_followup_scene_path)):
		errors.append("%s.visual_animations.death_followup_scene_path: 资源不存在" % label)

static func _validate_visual_action_descriptor(label: String, descriptor: Dictionary, errors: PackedStringArray) -> void:
	_validate_known_fields(label, descriptor, VISUAL_ACTION_DESCRIPTOR_FIELDS, errors)
	_require_fields(label, descriptor, [&"animation", &"kind"], errors)
	_validate_animation_name_value("%s.animation" % label, descriptor.get("animation", ""), errors)
	var kind := StringName(descriptor.get("kind", ""))
	if kind not in VISUAL_ACTION_KINDS:
		errors.append("%s.kind: 不支持的动作类型 %s" % [label, kind])
	if descriptor.has("durations"):
		_validate_positive_number_or_array("%s.durations" % label, descriptor.durations, errors)
		var animation_value = descriptor.get("animation", null)
		var duration_value = descriptor.get("durations", null)
		if animation_value is Array and duration_value is Array and animation_value.size() != duration_value.size():
			errors.append("%s.durations: 与 animation 数组长度必须匹配" % label)
	if descriptor.has("clip_ranges"):
		var clip_ranges = descriptor.clip_ranges
		var animation_value = descriptor.get("animation", null)
		if not clip_ranges is Array:
			errors.append("%s.clip_ranges: 必须是 Array" % label)
		elif animation_value is Array and clip_ranges.size() != animation_value.size():
			errors.append("%s.clip_ranges: 与 animation 数组长度必须匹配" % label)
		else:
			for clip_range in clip_ranges:
				if not clip_range is Array or clip_range.size() != 2:
					errors.append("%s.clip_ranges: 每段必须是 [开始秒, 结束秒]" % label)
					break
				if float(clip_range[0]) < 0.0 or float(clip_range[1]) <= float(clip_range[0]):
					errors.append("%s.clip_ranges: 必须满足 0 <= 开始秒 < 结束秒" % label)
					break
	for blend_field in [&"blend_in", &"blend_out", &"sequence_blend"]:
		if descriptor.has(blend_field):
			var blend_value = descriptor[blend_field]
			if (not blend_value is float and not blend_value is int) or float(blend_value) < 0.0:
				errors.append("%s.%s: 必须是 >= 0 的秒数" % [label, blend_field])
	if descriptor.has("priority") and int(descriptor.priority) < 0:
		errors.append("%s.priority: 必须 >= 0" % label)

static func _validate_visual_transition_descriptor(label: String, descriptor: Dictionary, errors: PackedStringArray) -> void:
	_validate_known_fields(label, descriptor, VISUAL_TRANSITION_DESCRIPTOR_FIELDS, errors)
	_require_fields(label, descriptor, [&"animation"], errors)
	_validate_animation_name_value("%s.animation" % label, descriptor.get("animation", ""), errors)
	for blend_field in [&"blend_in", &"blend_out", &"start_time"]:
		if not descriptor.has(blend_field):
			continue
		var blend_value = descriptor[blend_field]
		if (not blend_value is float and not blend_value is int) or not is_finite(float(blend_value)) or float(blend_value) < 0.0:
			errors.append("%s.%s: 必须是 >= 0 的秒数" % [label, blend_field])

static func _validate_animation_name_value(label: String, value: Variant, errors: PackedStringArray) -> void:
	if value is String or value is StringName:
		if String(value).is_empty():
			errors.append("%s: 动画名不能为空" % label)
		return
	if value is Array:
		if value.is_empty():
			errors.append("%s: 动画数组不能为空" % label)
		for animation_name in value:
			if (not animation_name is String and not animation_name is StringName) or String(animation_name).is_empty():
				errors.append("%s: 数组只能包含非空动画名" % label)
		return
	errors.append("%s: 必须是动画名或动画名数组" % label)

static func _validate_positive_number_or_array(label: String, value: Variant, errors: PackedStringArray) -> void:
	var values: Array = value if value is Array else [value]
	if values.is_empty():
		errors.append("%s: 不能为空" % label)
		return
	for duration in values:
		if (not duration is float and not duration is int) or float(duration) <= 0.0:
			errors.append("%s: 必须是正数或正数数组" % label)
			return

static func _validate_active_skills(card_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	if not SHAPES.validate(card_id, stats, errors): return
	var skills: Array = []
	if stats.has("active_skills"):
		if not stats.active_skills is Array:
			errors.append("%s.active_skills: 必须是 Array" % card_id)
		else:
			skills.append_array(stats.active_skills)
	for index in range(skills.size()):
		var skill = skills[index]
		var label := "%s.active_skills[%d]" % [card_id, index]
		if not skill is Dictionary:
			errors.append("%s: 必须是 Dictionary" % label)
			continue
		_validate_known_fields(label, skill, ACTIVE_SKILL_FIELDS, errors)
		_require_fields(label, skill, [&"name", &"kind", &"cost", &"max_uses", &"cooldown"], errors)
		var kind := StringName(skill.get("kind", ""))
		if kind not in ACTIVE_SKILL_KINDS:
			errors.append("%s.kind: 系统不支持 %s" % [label, kind])
			continue
		var skill_cost := float(skill.get("cost", -1.0))
		if skill_cost < 0.0:
			errors.append("%s.cost: 必须 >= 0" % label)
		var max_uses := int(skill.get("max_uses", 0))
		if max_uses <= 0:
			errors.append("%s.max_uses: 必须 > 0" % label)
		if float(skill.get("cooldown", -1.0)) < 0.0:
			errors.append("%s.cooldown: 必须 >= 0" % label)
		match kind:
			&"nova": _require_fields(label, skill, [&"radius", &"damage"], errors)
			&"timed_form":
				if stats.get("transformed_stats", {}).is_empty() or float(stats.get("form_lifetime", 0.0)) <= 0.0:
					errors.append("%s: 限时变形需要 transformed_stats 与正数 form_lifetime" % label)
			&"buff": _require_fields(label, skill, [&"duration"], errors)
			&"restoration_shield":
				_require_fields(label, skill, [&"shield", &"shield_duration"], errors)
				if float(skill.get("shield", 0.0)) <= 0.0 or float(skill.get("shield_duration", 0.0)) <= 0.0:
					errors.append("%s: 恢复护盾值与持续时间必须 > 0" % label)
			&"area_shield":
				_require_fields(label, skill, [&"radius", &"shield", &"shield_duration"], errors)
				for positive_field in [&"radius", &"shield", &"shield_duration"]:
					if float(skill.get(positive_field, 0.0)) <= 0.0:
						errors.append("%s.%s: 必须 > 0" % [label, positive_field])
			&"summon": _require_fields(label, skill, [&"spawn_id", &"spawn_count"], errors)
			&"dual_form": _require_fields(label, skill, [&"length", &"width", &"damage", &"impact_delay", &"cast_duration", &"stun_duration"], errors)
			&"frontal":
				_require_fields(label, skill, [&"shape", &"length", &"damage", &"impact_delay", &"cast_duration"], errors)
				var shape := StringName(skill.get("shape", ""))
				if float(skill.get("length", 0.0)) <= 0.0:
					errors.append("%s.length: 必须 > 0" % label)
				if float(skill.get("damage", 0.0)) < 0.0:
					errors.append("%s.damage: 必须 >= 0" % label)
				if shape == &"fan":
					_require_fields(label, skill, [&"arc_degrees"], errors)
					var arc_degrees := float(skill.get("arc_degrees", 0.0))
					if arc_degrees <= 0.0 or arc_degrees >= 180.0:
						errors.append("%s.arc_degrees: 必须在 0 到 180 之间" % label)
					if int(skill.get("projectile_count", 0)) < 0:
						errors.append("%s.projectile_count: 必须 >= 0" % label)
				elif shape == &"trapezoid":
					_require_fields(label, skill, [&"near_width", &"far_width"], errors)
					if float(skill.get("near_width", 0.0)) <= 0.0 or float(skill.get("far_width", 0.0)) <= 0.0:
						errors.append("%s: near_width/far_width 必须 > 0" % label)
				else:
					errors.append("%s.shape: 只支持 fan/trapezoid" % label)
			&"forward_area":
				_require_fields(label, skill, [&"forward_distance", &"radius", &"damage", &"stun_duration", &"impact_delay", &"cast_duration"], errors)
				var has_shockwave_config: bool = skill.has("shockwave_damage") or skill.has("shockwave_duration") or skill.has("shockwave_end_radius")
				if has_shockwave_config:
					_require_fields(label, skill, [&"shockwave_damage", &"shockwave_duration", &"shockwave_end_radius"], errors)
				for positive_field in [&"forward_distance", &"radius", &"cast_duration"]:
					if float(skill.get(positive_field, 0.0)) <= 0.0:
						errors.append("%s.%s: 必须 > 0" % [label, positive_field])
				if has_shockwave_config:
					for positive_field in [&"shockwave_duration", &"shockwave_end_radius"]:
						if float(skill.get(positive_field, 0.0)) <= 0.0:
							errors.append("%s.%s: 必须 > 0" % [label, positive_field])
				for nonnegative_field in [&"damage", &"stun_duration", &"impact_delay", &"shockwave_damage", &"shockwave_slow_duration"]:
					if skill.has(nonnegative_field) and float(skill.get(nonnegative_field, 0.0)) < 0.0:
						errors.append("%s.%s: 必须 >= 0" % [label, nonnegative_field])
				if skill.has("zone_duration"):
					if float(skill.get("zone_duration", 0.0)) <= 0.0:
						errors.append("%s.zone_duration: 必须 > 0" % label)
					if float(skill.get("zone_tick_interval", 0.0)) <= 0.0:
						errors.append("%s.zone_tick_interval: 必须 > 0" % label)
					if float(skill.get("zone_damage", 0.0)) < 0.0:
						errors.append("%s.zone_damage: 必须 >= 0" % label)
					if float(skill.get("zone_slow_duration", 0.0)) < 0.0:
						errors.append("%s.zone_slow_duration: 必须 >= 0" % label)
					if float(skill.get("zone_slow_multiplier", 1.0)) < 0.1 or float(skill.get("zone_slow_multiplier", 1.0)) > 1.0:
						errors.append("%s.zone_slow_multiplier: 必须在 0.1 到 1.0 之间" % label)
			&"continuous_area":
				_require_fields(label, skill, [&"radius", &"damage", &"duration", &"tick_interval", &"cast_duration"], errors)
				for positive_field in [&"radius", &"duration", &"tick_interval", &"cast_duration"]:
					if float(skill.get(positive_field, 0.0)) <= 0.0:
						errors.append("%s.%s: 必须 > 0" % [label, positive_field])
				if float(skill.get("damage", 0.0)) < 0.0:
					errors.append("%s.damage: 必须 >= 0" % label)
				if float(skill.get("duration", 0.0)) > float(skill.get("cast_duration", 0.0)):
					errors.append("%s.duration: 不得大于 cast_duration" % label)
			&"empowered_attack":
				_require_fields(label, skill, [&"empowered_damage_multiplier"], errors)
				if float(skill.get("empowered_damage_multiplier", 0.0)) <= 0.0:
					errors.append("%s.empowered_damage_multiplier: 必须 > 0" % label)
				if float(skill.get("empowered_speed_multiplier", 1.0)) < 1.0:
					errors.append("%s.empowered_speed_multiplier: 必须 >= 1" % label)
				if int(skill.get("blind_charges", 0)) < 0:
					errors.append("%s.blind_charges: 必须 >= 0" % label)
			&"attack_lifesteal":
				_require_fields(label, skill, [&"heal_ratio", &"max_health_ratio"], errors)
				if float(skill.get("heal_ratio", 0.0)) <= 0.0:
					errors.append("%s.heal_ratio: 必须 > 0" % label)
				if float(skill.get("max_health_ratio", 0.0)) < 1.0:
					errors.append("%s.max_health_ratio: 必须 >= 1" % label)
			&"spell_heal":
				if StringName(stats.get("type", "")) != &"spell" or StringName(stats.get("spell_kind", "")) != &"heal":
					errors.append("%s.kind: spell_heal 只能用于治疗法术" % label)
				_require_fields(label, skill, [&"heal_multiplier", &"global_heal"], errors)
				if float(skill.get("heal_multiplier", 0.0)) < 1.0:
					errors.append("%s.heal_multiplier: 治疗倍率必须 >= 1" % label)
				if skill.has("overheal_shield_ratio"):
					var overheal_shield_ratio := float(skill.get("overheal_shield_ratio", 0.0))
					if overheal_shield_ratio < 0.0 or overheal_shield_ratio > 1.0:
						errors.append("%s.overheal_shield_ratio: 溢出治疗转盾比例必须在 0 到 1 之间" % label)
					elif overheal_shield_ratio > 0.0 and float(skill.get("shield_duration", 0.0)) <= 0.0:
						errors.append("%s.shield_duration: 配置溢出治疗转盾时必须 > 0" % label)
		var target_scope := StringName(skill.get("target_scope", "self"))
		if target_scope not in ACTIVE_SKILL_TARGET_SCOPES:
			errors.append("%s.target_scope: 只支持 self/deployment_group" % label)
		if skill.has("center_ratio") and (float(skill.center_ratio) < 0.0 or float(skill.center_ratio) > 1.0):
			errors.append("%s.center_ratio: 必须在 0 到 1 之间" % label)
		for bool_field in [&"ignore_movement_slow", &"ignore_attack_speed_slow"]:
			if skill.has(bool_field) and typeof(skill.get(bool_field)) != TYPE_BOOL:
				errors.append("%s.%s: 必须是 bool" % [label, bool_field])
		if skill.has("center_width") and float(skill.center_width) < 0.0:
			errors.append("%s.center_width: 必须 >= 0" % label)
		if skill.has("fan_inner_arc") and typeof(skill.fan_inner_arc) != TYPE_BOOL:
			errors.append("%s.fan_inner_arc: 必须是 bool" % label)
		if skill.has("projectile_stop_on_hit"):
			if typeof(skill.projectile_stop_on_hit) != TYPE_BOOL:
				errors.append("%s.projectile_stop_on_hit: 必须是 bool" % label)
			elif skill.projectile_stop_on_hit and (String(skill.get("kind", "")) != "frontal" or String(skill.get("shape", "")) != "fan" or int(skill.get("projectile_count", 0)) <= 0 or float(skill.get("projectile_flight_duration", 0.0)) <= 0.0 or float(skill.get("length", 0.0)) <= 0.0):
				errors.append("%s.projectile_stop_on_hit: 需要 frontal/fan、正数箭矢数量、射程和飞行时长" % label)
		if skill.has("projectile_piercing"):
			if typeof(skill.projectile_piercing) != TYPE_BOOL:
				errors.append("%s.projectile_piercing: 必须是 bool" % label)
			elif skill.projectile_piercing and (String(skill.get("kind", "")) != "frontal" or (String(skill.get("shape", "")) != "fan" and not (String(skill.get("shape", "")) == "trapezoid" and int(skill.get("projectile_count", 0)) == 1 and float(skill.get("near_width", 0.0)) > 0.0 and is_equal_approx(float(skill.get("near_width", 0.0)), float(skill.get("far_width", 0.0))))) or int(skill.get("projectile_count", 0)) <= 0 or float(skill.get("projectile_flight_duration", 0.0)) <= 0.0 or float(skill.get("length", 0.0)) <= 0.0):
				errors.append("%s.projectile_piercing: 需要 frontal/fan 或单枚等宽 trapezoid、正数弹体数量、射程和飞行时长" % label)
		if bool(skill.get("projectile_piercing", false)) and bool(skill.get("projectile_stop_on_hit", false)):
			errors.append("%s: 穿透与命中停止不可同时启用" % label)
		if skill.has("projectile_visual") and StringName(skill.projectile_visual) not in [&"arrow", &"card", &"orb", &"laser", &"electromagnetic_wave"]:
			errors.append("%s.projectile_visual: 只支持 arrow/card/orb/laser/electromagnetic_wave" % label)
		if skill.has("projectile_launch_delay") and float(skill.projectile_launch_delay) < 0.0:
			errors.append("%s.projectile_launch_delay: 必须 >= 0" % label)
		if skill.has("projectile_flight_duration") and float(skill.projectile_flight_duration) < 0.0:
			errors.append("%s.projectile_flight_duration: 必须 >= 0" % label)
		if skill.has("projectile_visual_height") and float(skill.projectile_visual_height) < 0.0:
			errors.append("%s.projectile_visual_height: 必须 >= 0" % label)
		if skill.has("projectile_visual_forward_offset") and float(skill.projectile_visual_forward_offset) < 0.0:
			errors.append("%s.projectile_visual_forward_offset: 必须 >= 0" % label)
		if skill.has("projectile_visual_width") and float(skill.projectile_visual_width) <= 0.0:
			errors.append("%s.projectile_visual_width: 必须 > 0" % label)
		if skill.has("projectile_launch_delay") and skill.has("cast_duration") and float(skill.projectile_launch_delay) > float(skill.cast_duration):
			errors.append("%s.projectile_launch_delay: 不得大于 cast_duration" % label)
		if skill.has("knockback_duration") and float(skill.knockback_duration) <= 0.0:
			errors.append("%s.knockback_duration: 必须 > 0" % label)
		if skill.has("knockback_mass_factor_max") and float(skill.knockback_mass_factor_max) <= 0.0:
			errors.append("%s.knockback_mass_factor_max: 必须 > 0" % label)
		if float(skill.get("center_damage_multiplier", 1.0)) < 1.0:
			errors.append("%s.center_damage_multiplier: 必须 >= 1" % label)
		if skill.has("resource_damage_scale_max"):
			if float(skill.resource_damage_scale_max) < 1.0:
				errors.append("%s.resource_damage_scale_max: 必须 >= 1" % label)
			if float(stats.get("skill_resource_max", 0.0)) <= 0.0:
				errors.append("%s.resource_damage_scale_max: 卡牌必须配置正数 skill_resource_max" % label)
		if bool(skill.get("uses_skill_resource", false)) and float(stats.get("skill_resource_max", 0.0)) <= 0.0:
			errors.append("%s.uses_skill_resource: 卡牌必须配置正数 skill_resource_max" % label)
		if skill.has("resource_shield_max"):
			if float(skill.resource_shield_max) < 0.0:
				errors.append("%s.resource_shield_max: 必须 >= 0" % label)
			if not bool(skill.get("uses_skill_resource", false)):
				errors.append("%s.resource_shield_max: 必须搭配 uses_skill_resource" % label)
		if bool(skill.get("shield_on_cast_start", false)):
			if float(skill.get("shield_duration", 0.0)) <= 0.0:
				errors.append("%s.shield_on_cast_start: 必须配置正数 shield_duration" % label)
		if bool(skill.get("shield_decay", false)) and float(skill.get("shield_duration", 0.0)) <= 0.0:
			errors.append("%s.shield_decay: 必须配置正数 shield_duration" % label)
		if skill.has("resource_damage_by_stacks"):
			var damage_tiers = skill.resource_damage_by_stacks
			var expected_tiers := int(round(float(stats.get("skill_resource_max", 0.0)))) + 1
			if not damage_tiers is Array or (damage_tiers as Array).size() != expected_tiers:
				errors.append("%s.resource_damage_by_stacks: 必须覆盖 0 到满层的所有档位" % label)
		var expected_resource_tiers := int(round(float(stats.get("skill_resource_max", 0.0)))) + 1
		if skill.has("resource_visual_actions"):
			var resource_actions = skill.resource_visual_actions
			if not resource_actions is Array or (resource_actions as Array).size() != expected_resource_tiers:
				errors.append("%s.resource_visual_actions: 必须覆盖 0 到满层的所有档位" % label)
			elif resource_actions is Array:
				for resource_action in resource_actions:
					if String(resource_action).is_empty() or not _has_visual_action(stats, String(resource_action)):
						errors.append("%s.resource_visual_actions: visual_actions 中不存在 %s" % [label, resource_action])
		var hit_damage_tiers = skill.get("resource_hit_damage_sequences", null)
		var hit_delay_tiers = skill.get("resource_hit_delay_sequences", null)
		if hit_damage_tiers != null or hit_delay_tiers != null:
			if not hit_damage_tiers is Array or not hit_delay_tiers is Array:
				errors.append("%s.resource_hit_*_sequences: 两项都必须是 Array" % label)
			elif hit_damage_tiers.size() != expected_resource_tiers or hit_delay_tiers.size() != expected_resource_tiers:
				errors.append("%s.resource_hit_*_sequences: 必须覆盖 0 到满层的所有档位" % label)
			else:
				for tier_index in expected_resource_tiers:
					var damages = hit_damage_tiers[tier_index]
					var delays = hit_delay_tiers[tier_index]
					if not damages is Array or not delays is Array or damages.is_empty() or damages.size() != delays.size():
						errors.append("%s.resource_hit_*_sequences[%d]: 伤害与时刻必须是等长非空数组" % [label, tier_index])
						continue
					var previous_delay := -1.0
					for hit_index in damages.size():
						var hit_damage := float(damages[hit_index])
						var hit_delay := float(delays[hit_index])
						if hit_damage < 0.0:
							errors.append("%s.resource_hit_damage_sequences[%d]: 伤害必须 >= 0" % [label, tier_index])
						if hit_delay < 0.0 or hit_delay > float(skill.get("cast_duration", 0.0)) or hit_delay < previous_delay:
							errors.append("%s.resource_hit_delay_sequences[%d]: 时刻必须递增且位于施法窗口内" % [label, tier_index])
						previous_delay = hit_delay
		for flag in [&"cast_end_heal_requires_hit", &"applies_on_hit_passive"]:
			if skill.has(flag) and typeof(skill[flag]) != TYPE_BOOL:
				errors.append("%s.%s: 必须为布尔值" % [label, flag])
		if bool(skill.get("applies_on_hit_passive", false)) and (String(skill.get("kind", "")) != "frontal" or int(skill.get("projectile_count", 0)) > 0):
			errors.append("%s.applies_on_hit_passive: 仅支持直接结算的 frontal" % label)
		if bool(skill.get("cast_end_heal_requires_hit", false)) and (String(skill.get("kind", "")) != "frontal" or int(skill.get("projectile_count", 0)) > 0 or float(skill.get("full_resource_cast_end_heal", 0.0)) <= 0.0):
			errors.append("%s.cast_end_heal_requires_hit: 需要直接结算的 frontal 和正数满层结束治疗" % label)
		if skill.has("full_resource_cast_end_heal") and float(skill.full_resource_cast_end_heal) < 0.0:
			errors.append("%s.full_resource_cast_end_heal: 必须 >= 0" % label)
		if skill.has("full_resource_cast_duration") and float(skill.full_resource_cast_duration) <= 0.0:
			errors.append("%s.full_resource_cast_duration: 必须 > 0" % label)
		if skill.has("full_resource_impact_delay"):
			var full_cast := float(skill.get("full_resource_cast_duration", skill.get("cast_duration", 0.0)))
			if float(skill.full_resource_impact_delay) < 0.0 or float(skill.full_resource_impact_delay) > full_cast:
				errors.append("%s.full_resource_impact_delay: 必须位于满层施法窗口内" % label)
		if skill.has("cast_locks"):
			if not skill.cast_locks is Array:
				errors.append("%s.cast_locks: 必须是 Array" % label)
			else:
				for cast_lock in skill.cast_locks:
					if StringName(cast_lock) not in CAST_LOCKS:
						errors.append("%s.cast_locks: 不支持 %s" % [label, cast_lock])
		var visual_action := String(skill.get("visual_action", ""))
		if skill.has("visual_action") and visual_action.is_empty():
			errors.append("%s.visual_action: 动作名不能为空" % label)
		elif not visual_action.is_empty() and not _has_visual_action(stats, visual_action):
			errors.append("%s.visual_action: visual_animations.visual_actions 中不存在 %s" % [label, visual_action])
		var full_resource_action := String(skill.get("full_resource_visual_action", ""))
		if not full_resource_action.is_empty() and not _has_visual_action(stats, full_resource_action):
			errors.append("%s.full_resource_visual_action: visual_animations.visual_actions 中不存在 %s" % [label, full_resource_action])
		if not visual_action.is_empty() and skill.has("cast_locks") and skill.cast_locks is Array and StringName("attack") not in skill.cast_locks:
			errors.append("%s.cast_locks: 使用全身 visual_action 时必须包含 attack" % label)
		if skill.has("cast_duration") and float(skill.cast_duration) < 0.0:
			errors.append("%s.cast_duration: 必须 >= 0" % label)
		if skill.has("impact_delay"):
			var impact_delay := float(skill.impact_delay)
			if impact_delay < 0.0:
				errors.append("%s.impact_delay: 必须 >= 0" % label)
			if impact_delay > 0.0 and not skill.has("cast_duration") and kind != &"dual_form":
				errors.append("%s.impact_delay: 大于 0 时必须配置 cast_duration" % label)
			elif skill.has("cast_duration") and impact_delay > float(skill.cast_duration):
				errors.append("%s.impact_delay: 不得大于 cast_duration" % label)
		if skill.has("transform_cast_duration") and float(skill.transform_cast_duration) < 0.0:
			errors.append("%s.transform_cast_duration: 必须 >= 0" % label)
		if skill.has("transform_impact_delay"):
			var transform_impact_delay := float(skill.transform_impact_delay)
			if transform_impact_delay < 0.0:
				errors.append("%s.transform_impact_delay: 必须 >= 0" % label)
			if transform_impact_delay > 0.0 and not skill.has("transform_cast_duration"):
				errors.append("%s.transform_impact_delay: 大于 0 时必须配置 transform_cast_duration" % label)
			elif skill.has("transform_cast_duration") and transform_impact_delay > float(skill.transform_cast_duration):
				errors.append("%s.transform_impact_delay: 不得大于 transform_cast_duration" % label)

static func _has_visual_action(stats: Dictionary, action_name: String) -> bool:
	var candidates: Array[Dictionary] = [stats]
	var transformed = stats.get("transformed_stats")
	if transformed is Dictionary:
		candidates.append(transformed)
	for candidate in candidates:
		var animations = candidate.get("visual_animations", {})
		if animations is Dictionary and animations.get("visual_actions", {}) is Dictionary:
			if (animations.get("visual_actions", {}) as Dictionary).has(action_name):
				return true
	return false

static func _require_fields(label: String, data: Dictionary, fields: Array, errors: PackedStringArray) -> void:
	for field in fields:
		if not data.has(field):
			errors.append("%s.%s: 缺少必要字段" % [label, field])

static func _validate_known_fields(label: String, data: Dictionary, known_fields: Array, errors: PackedStringArray) -> void:
	for field in data:
		if (not field is String and not field is StringName) or field not in known_fields:
			errors.append("%s.%s: 未知或未登记字段" % [label, field])

## 开发工作台专用木桩，不进入正式卡牌池。

## 只遍历玩法结构；动画裁剪、音频排程和表现坐标不受数值精度限制。
static func _validate_numbers(label: String, data: Dictionary, errors: PackedStringArray) -> void:
	for raw_key in data:
		var key := str(raw_key)
		if key.begins_with("visual_") or key.begins_with("projectile_visual_") or key.begins_with("continuous_beam_") or key in ["audio", "card_art"]:
			continue
		var value = data[raw_key]
		if key == "transformed_stats" and value is Dictionary:
			_validate_numbers(label + "." + key, value, errors)
		elif key == "active_skills" and value is Array:
			for index in value.size():
				if value[index] is Dictionary:
					_validate_numbers("%s.active_skills[%d]" % [label, index], value[index], errors)
		elif key in INTEGER_NUMBER_FIELDS:
			_validate_number_value(label + "." + key, value, 1.0, errors, true)
		elif value is float or value is int or value is Array:
			var step := 0.0001 if key.ends_with("_ratio") or "multiplier" in key or key == "resource_damage_scale_max" else 0.01
			_validate_number_value(label + "." + key, value, step, errors)

static func _validate_number_value(label: String, value: Variant, step: float, errors: PackedStringArray, required_number: bool = false) -> void:
	if value is Array:
		for index in value.size():
			_validate_number_value("%s[%d]" % [label, index], value[index], step, errors, required_number)
	elif value is float or value is int:
		if (required_number and float(value) < 0.0) or not is_finite(float(value)) or absf(float(value) - snappedf(float(value), step)) > 0.0000001:
			errors.append("%s: 数值必须有限且符合精度 %s" % [label, str(step)])
	elif required_number:
		errors.append("%s: 必须是整数数值" % label)
