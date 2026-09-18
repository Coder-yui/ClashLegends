extends "res://scripts/data/card_schema.gd"
## 同质编队：一次出牌展开为两个并排超级兵，共享 deployment_group_id 与主动技能资格。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "攻城部队", "cost": 6, "type": "unit", "selectable": true,
			"description": "一次部署2只超级兵，并排站位，间隔1.5格。主动技能：男爵之力，消耗2金币，可用1次，为本次部署中仍存活的超级兵施加超级兵的男爵之力。",
			# 聚合卡提供完整单位字段以通过通用数据契约；真正生成时读取超级兵成员卡数据。
			"hp": 720, "damage": 72, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.15, "first_hit": 0.38,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 6.0, "sight": 200.0,
			"deployment_count": 2, "deployment_spacing": 60.0, "deployment_formation": "line",
			"deployment_member_ids": ["super_minion", "super_minion"],
			"is_air": false, "building_only": false, "can_attack_air": false,
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
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"color": Color(0.52, 0.55, 0.62),
		},
		"card_art": {},
	}
