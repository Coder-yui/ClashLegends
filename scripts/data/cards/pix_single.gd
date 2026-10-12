extends "res://scripts/data/card_schema.gd"
## 工作台单只皮克斯，复用原卡模型、音频与技能，不进入正式卡池。
static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/pix.gd").definition().duplicate(true)
	data.gameplay.name = "皮克斯（单只）"
	data.gameplay.description = "用于工作台观察模型和仙灵汲取特效的单只皮克斯；不能加入正式卡组。"
	data.gameplay.cost = 0
	data.gameplay.selectable = false
	for field in ["deployment_count", "deployment_spacing", "deployment_formation"]:
		data.gameplay.erase(field)
	data.gameplay.active_skills[0].erase("target_scope")
	data.gameplay.active_skills[0].description = String(data.gameplay.active_skills[0].description).replace("使这次部署中仍存活的所有皮克斯", "使自身")
	data.card_art = {"path": "res://assets/cards/pix_single_loading.png"}
	return data
