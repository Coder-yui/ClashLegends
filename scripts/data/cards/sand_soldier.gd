extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/shurima_guard.gd").definition().duplicate(true)
	data.gameplay.name = "黄沙士兵"
	data.gameplay.description = "沙漠皇帝召唤的独立长矛士兵，只攻击地面目标，不继承皇帝的转化被动与主动技能。"
	data.gameplay.cost = 0
	data.gameplay.selectable = false
	for field in ["attack_pattern", "deployment_count", "deployment_spacing", "deployment_formation", "deploy_pocket_requires_both_towers", "active_skills"]:
		data.gameplay.erase(field)
	data.visual.erase("active_skills")
	data.audio.events.erase("active:cast")
	return data
