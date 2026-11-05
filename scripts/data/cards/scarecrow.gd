extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var mobile: Dictionary = preload("res://scripts/data/cards/fiddlesticks.gd").definition()
	var data := mobile.duplicate(true)
	data.gameplay.merge({
		"name": "草间人", "cost": 6, "type": "building", "selectable": true,
		"description": "每轮锁定射程内敌人吸血2秒，停0.75秒后重新选敌，每个目标每秒60伤害，回复实际伤害的50%。自然衰血持续50秒；治疗可延长存续。",
		"speed": 0.0, "is_building": true, "footprint_tiles": Vector2i(3, 3),
		"lifespan": 50.0, "lifespan_hp_decay": true, "transform_duration": 0.3,
		"active_skills": [{"name": "巫骇草人", "kind": "toggle_form", "cost": 1, "max_uses": 1, "cooldown": 20.0,
			"cast_duration": 0.0, "impact_delay": 0.0, "cast_locks": [],
			"description": "变为可移动的远古恐惧，保留当前生命，停止自然衰血。"}],
		"transformed_stats": mobile.gameplay.duplicate(true),
	}, true)
	data.visual.transformed_stats = mobile.visual.duplicate(true)
	data.visual.active_skills = [{"icon_path": "res://assets/skills/scarecrow_0.png", "resource_dependencies": {"fields": ["transformed_stats"]}}]
	if mobile.has("audio"):
		data.audio.transformed_stats = mobile.audio.duplicate(true)
	return data
