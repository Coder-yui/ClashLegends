extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/voidfish_ranged.gd").definition().duplicate(true)
	data.gameplay.merge({
		"name": "远程虚空鱼大军", "cost": 5,
		"description": "在六边形顶点部署6只远程空中虚空鱼，可攻击地面和空中目标。虚空再生作用于本批存活成员。",
		"deployment_count": 6,
	}, true)
	data.visual.active_skills[0].icon_path = "res://assets/skills/voidfish_ranged_army_0.png"
	data.card_art = {"path": "res://assets/cards/voidfish_ranged_army_loading.png"}
	return data
