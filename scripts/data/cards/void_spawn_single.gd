extends "res://scripts/data/card_schema.gd"
## 工作台单体对象，复用虚空兽内容；不进入正式可选卡池。

static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/void_spawn.gd").definition().duplicate(true)
	data.gameplay.name = "虚空兽（单只）"
	data.gameplay.description = "用于工作台观察的单只虚空兽，保留牺牲攻城与虚空强化；不能单独加入正式卡组。"
	data.gameplay.cost = 0
	data.gameplay.selectable = false
	for field in ["deployment_count", "deployment_spacing", "deployment_formation"]:
		data.gameplay.erase(field)
	data.card_art = {"path": "res://assets/cards/void_spawn_single_loading.png"}
	data.audio.events["deploy:start"]["action_time"] = 23.0 / 34.0
	for kind in ["spawn", "trail"]:
		data.visual.resource_dependencies.effects.append({"provider": "res://assets/effects/void_spawn/player.gd", "variant": kind})
	return data
