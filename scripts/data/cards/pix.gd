extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "皮克斯", "cost": 2, "type": "unit",
			"description": "一次部署五只皮克斯。体型极小的近距离空中射手，会发射紫色光弹。",
			# 生命和单次伤害都严格等于公主塔的一次攻击伤害。
			"hp": PRINCESS_TOWER_STATS.damage, "damage": PRINCESS_TOWER_STATS.damage,
			"range": 1.2 * 40.0,
			# Attack1/2 都约在 40% 处完成蓄势；first_hit 在固定模拟中生成光弹。
			"speed": SPEED_FAST, "interval": 1.0, "first_hit": 0.40,
			"size_tier": SIZE_EXTREMELY_SMALL, "radius": RADIUS_EXTREMELY_SMALL,
			"mass": 1.0, "sight": 180.0,
			"deployment_count": 5, "deployment_spacing": 36.0,
			"projectile_speed": 360.0,
			"projectile_spawn_at_edge": false, "projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
			"is_air": true, "building_only": false, "can_attack_air": true,
			"active_skills": [{
					"name": "仙灵汲取", "kind": "attack_lifesteal",
					"cost": 1, "max_uses": 1, "cooldown": 0.0,
					"target_scope": "deployment_group",
					"heal_ratio": 0.25, "max_health_ratio": 1.5,
					"description": "使这次部署中仍存活的所有皮克斯此后的每次普通攻击命中都回复该次实际扣除生命值25%的生命（不含护盾和过量伤害）；可溢出生命上限，最高达到150%。",
				}],
		},
		"visual": {
			"visual_radius": RADIUS_EXTREMELY_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/pix/pix_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"],
			}, "projectile_visual": "orb",
			# 统一悬空后的施法手位约在权威地面点上方 84px；只影响紫色光弹绘制起点。
			"projectile_visual_height": 84.0,
			"projectile_visual_forward_offset": 4.0,
			"projectile_colors": [Color(0.72, 0.24, 1.0), Color(0.72, 0.24, 1.0)],
			"color": Color(0.72, 0.24, 1.0),
		},
		# BEGIN IMPORTED AUDIO pix
		"audio": {
			"events": {
				"attack_launch": {
					"pool": [
						"res://assets/audio/units/pix/play_sfx_lulu_lulupassivemissilecontroller_onmissilecast_r1.wav",
						"res://assets/audio/units/pix/play_sfx_lulu_lulupassivemissilecontroller_onmissilecast_r2.wav",
						"res://assets/audio/units/pix/play_sfx_lulu_lulupassivemissilecontroller_onmissilecast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_hit": [
				"res://assets/audio/units/pix/play_sfx_lulu_lulupassivemissile_hit_r1.wav",
				"res://assets/audio/units/pix/play_sfx_lulu_lulupassivemissile_hit_r2.wav",
				"res://assets/audio/units/pix/play_sfx_lulu_lulupassivemissile_hit_r3.wav"
			],
			"attack_hit_volume_db": -5.0,
		},
		# END IMPORTED AUDIO pix
		"card_art": {},
	}
