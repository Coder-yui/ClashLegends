extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/voidfish_ranged.gd").definition().duplicate(true)
	data.gameplay.name = "虚空鱼（远程）"
	data.gameplay.description = "单只远程虚空鱼，用于工作台部署查看，也用于虚空再生生成；不能加入正式卡组。"
	data.gameplay.selectable = false
	data.gameplay.cost = 0
	for field in ["deployment_count", "deployment_spacing", "deployment_formation"]:
		data.gameplay.erase(field)
	data.gameplay.active_skills[0].erase("target_scope")
	data.gameplay.active_skills[0].description = "自身在3秒内被击杀时，原地生成一只新的远程虚空鱼；新鱼不继承再生或主动资格。"
	data.card_art = {"path": "res://assets/cards/voidfish_ranged_single_loading.png"}
	return data
