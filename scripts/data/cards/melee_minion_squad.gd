extends "res://scripts/data/card_schema.gd"
## 同质编队：一次出牌展开为四个独立近战兵，共享 deployment_group_id 与主动技能资格。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "近战兵小队", "cost": 2, "type": "unit", "selectable": true,
			"description": "一次部署4只近战小兵，站在正方形的4个顶点。主动技能：男爵之力，消耗1金币，为本次部署中仍存活的近战兵施加近战兵的男爵之力。",
			"spawn_plan": {
				"members": ["melee_minion", "melee_minion", "melee_minion", "melee_minion"],
				"spacing": 28.0, "formation": "square",
			},
			# 沿用近战兵男爵之力的效果、2次使用与5秒冷却，仅将主动技能消耗改为1金币并扩大到本次编队。
			"active_skills": [{
				"name": "男爵之力", "kind": "buff", "cost": 1, "max_uses": 2, "cooldown": 5.0,
				"target_scope": "deployment_group", "duration": 4.0,
				"speed_multiplier": 1.35, "damage_multiplier": 1.25,
				"copy_member_buff": true,
				"description": "消耗1金币。复用近战兵的男爵之力，为这次下牌中仍存活的近战兵提供移速135%与伤害125%，持续4秒。",
			}],
		},
		"visual": {
			"active_skills": [{"icon_path": "res://assets/skills/melee_minion_squad_0.png"}],
			"color": Color(0.48, 0.58, 0.82),
		},
		"card_art": {"path": "res://assets/cards/melee_minion_squad_loading.png"},
	}
