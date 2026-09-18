extends "res://scripts/data/card_schema.gd"
## 同质编队：一次出牌展开为三个炮车兵，共享 deployment_group_id 与主动技能资格。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "炮车部队", "cost": 7, "type": "unit", "selectable": true,
			"description": "一次部署3只炮车兵，站在三角形的3个顶点，三角形边长1.5格。主动技能：男爵之力，消耗3金币，可用1次，为本次部署中仍存活的炮车兵施加炮车兵的男爵之力。",
			# polygon 的 deployment_spacing 是中心到顶点的半径；60 / √3 ≈ 34.64 才能得到60像素的三角形边长。
			"hp": 390, "damage": 58, "range": 170.0,
			"speed": SPEED_MEDIUM, "interval": 1.65, "first_hit": 0.55,
			"size_tier": SIZE_SLIGHTLY_SMALL, "radius": RADIUS_SLIGHTLY_SMALL,
			"mass": 4.5, "sight": 230.0,
			"projectile_speed": 310.0,
			"projectile_spawn_at_edge": false, "projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
			"deployment_count": 3, "deployment_spacing": 34.64, "deployment_formation": "polygon",
			"deployment_member_ids": ["siege_minion", "siege_minion", "siege_minion"],
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "男爵之力", "kind": "buff", "cost": 3, "max_uses": 1, "cooldown": 8.0,
				"target_scope": "deployment_group", "duration": 5.0,
				"damage_multiplier": 1.5,
				"copy_member_buff": true,
				"description": "消耗3金币，可用1次，冷却8秒。为这次下牌中仍存活的炮车兵施加伤害150%，持续5秒。",
			}],
		},
		"visual": {
			"visual_radius": RADIUS_SLIGHTLY_SMALL + VISUAL_RADIUS_PADDING,
			"color": Color(0.38, 0.40, 0.44),
		},
		"card_art": {},
	}
