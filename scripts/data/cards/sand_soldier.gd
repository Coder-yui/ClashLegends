extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/shurima_guard.gd").definition().duplicate(true)
	data.gameplay.name = "黄沙士兵"
	data.gameplay.description = "沙漠皇帝召唤的独立长矛士兵，只攻击地面目标，不继承皇帝的转化被动与主动技能。"
	data.gameplay.cost = 0
	data.gameplay.selectable = false
	for field in ["attack_pattern", "deployment_count", "deployment_spacing", "deployment_formation", "deploy_pocket_requires_both_towers", "deploy_formation_requires_in_bounds"]:
		data.gameplay.erase(field)
	# 定义保留自用技能供工作台预览；实战召唤入口不会注册主动资格。
	data.gameplay.active_skills[0].erase("target_scope")
	data.gameplay.active_skills[0].description = "自身获得180点护盾，持续2秒；到期时盾未破则回复至满血。仅工作台可预览，实战召唤士兵无主动资格。"
	data.card_art = {"path": "res://assets/cards/sand_soldier_loading.png"}
	return data
