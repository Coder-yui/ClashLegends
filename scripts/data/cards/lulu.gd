extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "璐璐", "cost": 4, "type": "unit",
			"description": "远程召唤法师，可对地对空。部署完成向左右1.5格发出紫光，0.25秒后各生成一只皮克斯，之后每7秒召唤两只；眩晕、冰冻、凝滞期间延后发出，已发出的召唤不会中断。",
			"hp": 460, "damage": 48, "range": 180.0,
			"speed": SPEED_MEDIUM, "interval": 1.2, "first_hit": 0.29,
			"size_tier": SIZE_SLIGHTLY_SMALL, "radius": RADIUS_SLIGHTLY_SMALL,
			"mass": 2.0, "sight": 230.0,
			"projectile_speed": 380.0, "projectile_spawn_at_edge": true,
			"projectile_spawn_offset": 7.5, "projectile_collision_radius": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"spawn_id": "pix", "spawn_interval": 7.0, "spawn_count": 2,
			"spawn_side": "bilateral", "spawn_distance": 60.0, "spawn_deploy_time": 0.0, "spawn_flight_duration": 0.25, "spawn_defer_while_controlled": true,
			"active_skills": [{
				"name": "狂野生长", "kind": "permanent_growth", "cost": 2, "max_uses": 2, "cooldown": 7.0,
				"radius": 180.0, "health_bonus_ratio": 0.3, "body_scale_multiplier": 1.3,
				"knockback_radius": 80.0, "knockback": 40.0, "knockback_duration": 0.25,
				"cast_duration": 0.97, "impact_delay": 0.25,
				"description": "选择自身180范围内费用最高、同费最近的未增益友军（含自身，不含建筑和冰鸟蛋），生命上限与当前生命增加原上限30%，模型和碰撞半径增大30%，持续到死亡且不能重复获得；将目标周围80范围内的空中和地面敌方普通单位击退40。无合法目标时回退金币、次数和本次冷却。",
			}],
		},
		"visual": {
			"visual_radius": RADIUS_SLIGHTLY_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/lulu/lulu_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Lulu_idle0_anm", "idle": "Lulu_idle0_anm", "move": "Run", "attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 1.0, "visual_actions": {"growth": "Spell4"}},
			"active_skills": [{"visual_action": "growth", "icon_path": "res://assets/skills/lulu_0.png"}],
			"projectile_visual": "magic_orb", "projectile_visual_scale": 1.4, "projectile_visual_height": 50.0,
			"projectile_colors": [Color(0.54, 0.18, 0.86), Color(0.54, 0.18, 0.86)], "color": Color(0.7, 0.3, 1.0),
		},
		"card_art": {"path": "res://assets/cards/lulu_loading.png"},
		"audio": {"attack_hit": ["res://assets/audio/units/lulu/attack_hit_1.wav", "res://assets/audio/units/lulu/attack_hit_2.wav", "res://assets/audio/units/lulu/attack_hit_3.wav"], "attack_hit_volume_db": 0.0, "events": {"deploy:voice": {"clip_volume_db": {"res://assets/audio/units/lulu/deploy_voice.ogg": -12.5}, "pool": ["res://assets/audio/units/lulu/deploy_voice.ogg", "res://assets/audio/units/lulu/deploy_slide.wav", "res://assets/audio/units/lulu/deploy_dewdrop.wav"], "volume_db": 0.0, "bus": "Voice"}, "attack_launch": {"pool": ["res://assets/audio/units/lulu/attack_launch_1.wav", "res://assets/audio/units/lulu/attack_launch_2.wav", "res://assets/audio/units/lulu/attack_launch_3.wav"], "volume_db": 0.0, "bus": "Combat"}, "death": {"pool": ["res://assets/audio/units/lulu/death_1.wav"], "volume_db": 0.0, "bus": "Combat"}, "active:cast": {"pool": ["res://assets/audio/units/lulu/play_sfx_lulu_lulur_oncast_r1.wav", "res://assets/audio/units/lulu/play_sfx_lulu_lulur_oncast_r2.wav", "res://assets/audio/units/lulu/play_sfx_lulu_lulur_oncast_r3.wav"], "volume_db": 0.0, "bus": "Combat"}}},
	}
