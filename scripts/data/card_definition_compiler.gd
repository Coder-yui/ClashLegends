extends "res://scripts/data/card_schema.gd"
## 只负责原始定义的域契约及平铺编译；数值、资源与消费者语义由 validator 检查。

static func validate(label: String, definition: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not definition is Dictionary:
		_type_error(label, definition, "Dictionary", errors)
		return errors
	for domain in definition:
		if domain not in ["gameplay", "visual", "card_art", "audio"]:
			errors.append("%s.%s: 未知定义域" % [label, str(domain)])
		elif not definition[domain] is Dictionary:
			_type_error(label + "." + str(domain), definition[domain], "Dictionary", errors)
	if not errors.is_empty():
		return errors
	var game: Dictionary = definition.get("gameplay", {})
	var visual: Dictionary = definition.get("visual", {})
	var audio: Dictionary = definition.get("audio", {})
	for domain in ["gameplay", "visual", "audio", "card_art"]:
		for field in definition.get(domain, {}):
			var allowed := false
			match domain:
				"gameplay": allowed = field in CARD_FIELDS and field not in CARD_VISUAL_FIELDS and field not in ["audio", "card_art"]
				"visual": allowed = field in CARD_VISUAL_FIELDS or field in ["transformed_stats", "active_skills"]
				"audio": allowed = field in AUDIO_FIELDS or field == "transformed_stats"
				"card_art": allowed = field == "path"
			if not allowed:
				errors.append("%s.%s.%s: 字段不属于此定义域" % [label, domain, str(field)])
	for field in game:
		if visual.has(field) and field not in ["transformed_stats", "active_skills"]:
			errors.append("%s.%s: gameplay 与 visual 同名冲突，不允许静默覆盖" % [label, str(field)])
	var form := {}
	for domain in ["gameplay", "visual", "audio"]:
		if definition.get(domain, {}).has("transformed_stats"):
			form[domain] = definition[domain].transformed_stats
	if not form.is_empty():
		for error in validate(label + ".transformed_stats", form):
			for domain in ["gameplay", "visual", "audio"]:
				error = error.replace(label + ".transformed_stats." + domain, label + "." + domain + ".transformed_stats")
			errors.append(error)
	var skills = game.get("active_skills", [])
	var visuals = visual.get("active_skills", [])
	if not skills is Array:
		_type_error(label + ".gameplay.active_skills", skills, "Array", errors)
	elif not visuals is Array:
		_type_error(label + ".visual.active_skills", visuals, "Array", errors)
	else:
		if visual.has("active_skills") and visuals.size() != skills.size():
			errors.append("%s.visual.active_skills: 必须与 gameplay 技能数量一致（%d）" % [label, skills.size()])
		for domain in ["gameplay", "visual"]:
			var entries: Array = skills if domain == "gameplay" else visuals
			for index in entries.size():
				var path := "%s.%s.active_skills[%d]" % [label, domain, index]
				if not entries[index] is Dictionary:
					_type_error(path, entries[index], "Dictionary", errors)
					continue
				for field in entries[index]:
					var allowed: bool = field in SKILL_VISUAL_FIELDS if domain == "visual" else field in ACTIVE_SKILL_FIELDS and field not in SKILL_VISUAL_FIELDS
					if not allowed:
						errors.append("%s.%s: 字段不属于此定义域" % [path, str(field)])
					if domain == "visual" and index < skills.size() and skills[index] is Dictionary and skills[index].has(field):
						errors.append("%s.%s: 与 gameplay 同名冲突" % [path, str(field)])
	return errors

static func _type_error(path: String, value: Variant, expected: String, errors: PackedStringArray) -> void:
	errors.append("%s: 期望 %s，实际 %s（%s）" % [path, expected, type_string(typeof(value)), str(value)])

static func compile(definition: Dictionary) -> Dictionary:
	if not validate("definition", definition).is_empty():
		return {}
	return _compile_validated(definition)

static func _compile_validated(definition: Dictionary) -> Dictionary:
	var stats: Dictionary = definition.get("gameplay", {}).duplicate(true)
	var visual: Dictionary = definition.get("visual", {}).duplicate(true)
	var form := {}
	for domain in ["gameplay", "visual", "audio"]:
		if definition.get(domain, {}).has("transformed_stats"):
			form[domain] = definition[domain].transformed_stats
	stats.erase("transformed_stats")
	visual.erase("transformed_stats")
	var skill_visuals: Array = visual.get("active_skills", [])
	visual.erase("active_skills")
	for index in skill_visuals.size():
		stats.active_skills[index].merge(skill_visuals[index], false)
	stats.merge(visual, false)
	if definition.has("card_art"):
		stats.card_art = definition.card_art.duplicate(true)
	if definition.has("audio"):
		var audio: Dictionary = definition.audio.duplicate(true)
		audio.erase("transformed_stats")
		if not audio.is_empty() or not definition.audio.has("transformed_stats"):
			stats.audio = audio
	if not form.is_empty(): stats.transformed_stats = _compile_validated(form)
	return stats
