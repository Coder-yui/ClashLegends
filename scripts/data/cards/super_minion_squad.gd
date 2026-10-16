extends "res://scripts/data/card_schema.gd"
## 同质编队：一次出牌展开为两个并排超级兵，共享 deployment_group_id 与主动技能资格。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "攻城部队", "cost": 6, "type": "unit", "selectable": true,
			"description": "一次部署2只超级兵，并排站位，间隔2.5格。主动技能：男爵之力，消耗2金币，可用1次，为本次部署中仍存活的超级兵施加超级兵的男爵之力。",
			"spawn_plan": {
				"members": ["super_minion", "super_minion"],
				"spacing": 100.0, "formation": "line",
			},
			"active_skills": [{
				"name": "男爵之力", "kind": "buff", "cost": 2, "max_uses": 1, "cooldown": 7.0,
				"target_scope": "deployment_group", "duration": 5.0,
				"speed_multiplier": 1.35, "damage_multiplier": 1.35,
				"shield": 140.0, "shield_duration": 5.0,
				"copy_member_buff": true,
				"description": "消耗2金币，可用1次，冷却7秒。为这次下牌中仍存活的超级兵施加移速135%、伤害135%与140点护盾，持续5秒。",
			}],
		},
		"visual": {
			"active_skills": [{"icon_path": "res://assets/skills/super_minion_squad_0.png"}],
			"color": Color(0.52, 0.55, 0.62),
		},
		"card_art": {},
	}
