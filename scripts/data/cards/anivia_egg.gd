extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "冰晶凤凰蛋", "cost": 0, "type": "unit", "selectable": false,
			"description": "冰晶凤凰被动复活期间的地面蛋形态；存活 3 秒后满血孵化。",
			"hp": PRINCESS_TOWER_STATS.damage * 3, "damage": 0, "range": 0.0,
			"speed": 0.0, "interval": 1.0,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"mass": 3.0, "sight": 0.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"timed_revival_id": "anivia", "timed_revival_delay": 3.0,
			"timed_revival_death_replacement_charges": 0,
		},
		"visual": { "visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/anivia/anivia_egg_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "death": "Death", "death_duration": 1.066667,
				"clip_blends": {"Idle1>Death": 0.0},
				"death_followup_immediate": true,
				"death_followup_scene_path": "res://assets/units/anivia/anivia_view.tscn",
				"death_followup_animation": "Death", "death_followup_duration": 2.4,
			},
			"color": Color(0.50, 0.86, 1.0), "timed_revival_visual_transition": "rebirth",
		},
		"audio": {"events": {"death": {"pool": ["res://assets/audio/units/anivia/play_vo_anivia_death3d_r1_zh_cn.wav", "res://assets/audio/units/anivia/play_vo_anivia_death3d_r2_zh_cn.wav", "res://assets/audio/units/anivia/play_vo_anivia_death3d_r3_zh_cn.wav"], "volume_db": 0.0, "bus": "Voice"}, "revival:sustain": {"pool": ["res://assets/audio/units/anivia/anivia_rebirth_full_half.wav"], "volume_db": 0.0}},
		},
		"card_art": {},
	}
