extends "res://scripts/data/card_schema.gd"
## 异构重装编队：超级兵在前、炮车兵在后，共享 deployment_group_id 与主动技能资格。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "重装部队", "cost": 5, "type": "unit", "selectable": true,
			"description": "一次部署1只超级兵和1只炮车兵，前后站位，间隔2.5格。主动技能：男爵之力，按成员分别复用超级兵与炮车兵的男爵之力。",
			"spawn_plan": {
				"members": ["super_minion", "siege_minion"],
				"spacing": 100.0, "formation": "depth_line",
			},
			# 共用主动入口按超级兵男爵之力的施放门槛；copy_member_buff 会为每个成员读取自己的完整效果。
			"active_skills": [{
				"name": "男爵之力", "kind": "buff", "cost": 2, "max_uses": 1, "cooldown": 7.0,
				"target_scope": "deployment_group", "duration": 5.0,
				"speed_multiplier": 1.35, "damage_multiplier": 1.35,
				"shield": 140.0, "shield_duration": 5.0,
				"copy_member_buff": true,
				"description": "消耗2金币，可用1次，冷却7秒。超级兵与炮车兵分别获得各自的男爵之力，持续5秒。",
			}],
		},
		"visual": {
			"active_skills": [{"icon_path": "res://assets/skills/heavy_minion_squad_0.png"}],
			"color": Color(0.55, 0.58, 0.68),
		},
		"card_art": {"path": "res://assets/cards/heavy_minion_squad_loading.png"},
	}
