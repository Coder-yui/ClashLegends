extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/olaf.gd").definition().duplicate(true)
	data.gameplay.name = "狂战士（单只）"
	data.gameplay.description = "工作台单只狂战士，保留残暴打击；不进入正式卡组。"
	data.gameplay.cost = 0
	data.gameplay.selectable = false
	for field in ["deployment_count", "deployment_spacing", "deployment_formation"]:
		data.gameplay.erase(field)
	data.gameplay.active_skills[0].erase("target_scope")
	return data
