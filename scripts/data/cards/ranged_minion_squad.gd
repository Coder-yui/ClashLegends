extends "res://scripts/data/card_schema.gd"
## 同质编队：一次出牌展开为三个独立远程兵，共享 deployment_group_id 与主动技能资格。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "远程兵小队", "cost": 2, "type": "unit", "selectable": true,
			"description": "一次部署3只远程小兵，站成紧凑三角形：1只在前、2只在后。主动技能：男爵之力，消耗1金币，为本次部署中仍存活的远程兵施加远程兵的男爵之力。",
			# 聚合卡提供完整单位字段以通过通用数据契约；真正生成时读取远程兵成员卡数据。
			"hp": 135, "damage": 32, "range": 150.0,
			"speed": SPEED_MEDIUM, "interval": 1.25, "first_hit": 0.42,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"mass": 1.8, "sight": 210.0,
			"deployment_count": 3, "deployment_spacing": 24.0, "deployment_formation": "polygon",
			"deployment_member_ids": ["ranged_minion", "ranged_minion", "ranged_minion"],
			"is_air": false, "building_only": false, "can_attack_air": true,
			# 沿用远程兵男爵之力的效果、2次使用与5秒冷却，仅将主动技能消耗改为1金币并扩大到本次编队。
			"active_skills": [{
				"name": "男爵之力", "kind": "buff", "cost": 1, "max_uses": 2, "cooldown": 5.0,
				"target_scope": "deployment_group", "duration": 5.0,
				"damage_multiplier": 1.25, "attack_speed_multiplier": 1.25,
				"copy_member_buff": true,
				"description": "消耗1金币。复用远程兵的男爵之力，为这次下牌中仍存活的远程兵提供攻速125%与伤害125%，持续5秒。",
			}],
		},
		"visual": {
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"color": Color(0.34, 0.64, 0.86),
		},
		"card_art": {},
	}
