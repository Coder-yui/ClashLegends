extends "res://scripts/data/card_schema.gd"
## 同质编队：一次出牌展开为三个炮车兵，共享 deployment_group_id 与主动技能资格。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "炮车部队", "cost": 7, "type": "unit", "selectable": true,
			"description": "一次部署3只炮车兵，站在三角形的3个顶点，三角形边长1.5格。主动技能：男爵之力，消耗3金币，可用1次，为本次部署中仍存活的炮车兵施加炮车兵的男爵之力。",
			# polygon 的 spawn_plan.spacing 是中心到顶点的半径；60 / √3 ≈ 34.64 才能得到60像素的三角形边长。
			"spawn_plan": {
				"members": ["siege_minion", "siege_minion", "siege_minion"],
				"spacing": 34.64, "formation": "polygon",
			},
			"active_skills": [{
				"name": "男爵之力", "kind": "buff", "cost": 3, "max_uses": 1, "cooldown": 8.0,
				"target_scope": "deployment_group", "duration": 5.0,
				"damage_multiplier": 1.5,
				"copy_member_buff": true,
				"description": "消耗3金币，可用1次，冷却8秒。为这次下牌中仍存活的炮车兵施加伤害150%，持续5秒。",
			}],
		},
		"visual": {
			"active_skills": [{"icon_path": "res://assets/skills/siege_minion_squad_0.png"}],
			"color": Color(0.38, 0.40, 0.44),
		},
		"card_art": {},
	}
