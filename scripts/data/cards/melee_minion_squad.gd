extends "res://scripts/data/card_schema.gd"
## 同质编队：一次出牌展开为四个独立近战兵，共享 deployment_group_id 与主动技能资格。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "近战兵小队", "cost": 2, "type": "unit", "selectable": true,
			"description": "一次部署4只近战小兵，站在正方形的4个顶点。主动技能：男爵之力，消耗1金币，为本次部署中仍存活的近战兵施加近战兵的男爵之力。",
			# 聚合卡提供完整单位字段以通过通用数据契约；真正生成时读取近战兵成员卡数据。
			"hp": 210, "damage": 42, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.0, "first_hit": 0.32,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"mass": 2.0, "sight": 180.0,
			"deployment_count": 4, "deployment_spacing": 28.0, "deployment_formation": "square",
			"deployment_member_ids": ["melee_minion", "melee_minion", "melee_minion", "melee_minion"],
			"is_air": false, "building_only": false, "can_attack_air": false,
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
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"color": Color(0.48, 0.58, 0.82),
		},
		"card_art": {},
	}
