extends "res://scripts/data/card_schema.gd"
## 异构编队：一次出牌展开为六个独立 Unit，共享 deployment_group_id；成员仍读取各自卡牌数据。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "小兵分队", "cost": 3, "type": "unit", "selectable": true,
			"description": "一次部署3只近战兵和3只远程兵，按六边形的6个顶点站位。主动技能：男爵之力，2金币，可用1次，冷却6秒；为这次下牌仍存活的小兵施加各自的男爵之力。",
			# 聚合卡仍提供完整单位字段以通过通用数据契约；真正生成时由 deployment_member_ids 读取成员卡数据。
			"hp": 210, "damage": 42, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.0, "first_hit": 0.32,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"mass": 2.0, "sight": 180.0,
			"deployment_count": 6, "deployment_spacing": 44.0, "deployment_formation": "polygon",
			# 位置顺序对应六边形顶点：近战兵在朝向前方的三点，远程兵在后方三点；红方由通用阵型旋转镜像。
			"deployment_member_ids": ["melee_minion", "melee_minion", "ranged_minion", "ranged_minion", "ranged_minion", "melee_minion"],
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "男爵之力", "kind": "buff", "cost": 2, "max_uses": 1, "cooldown": 6.0,
				"target_scope": "deployment_group", "duration": 5.0,
				"speed_multiplier": 1.35, "damage_multiplier": 1.25, "attack_speed_multiplier": 1.25,
				"copy_member_buff": true,
				"description": "可用1次，冷却6秒。给这次下牌仍存活的所有小兵施加其自身的男爵之力：近战兵获得移速135%与伤害125%，持续4秒；远程兵获得攻速125%与伤害125%，持续5秒。",
			}],
		},
		"visual": {
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"color": Color(0.36, 0.62, 0.88),
		},
		"card_art": {},
	}
