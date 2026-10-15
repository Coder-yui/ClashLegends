extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "虚灵", "cost": 0, "type": "unit", "selectable": false,
			"description": "虚空先知召唤的小型地面近战单位，可在工作台单独放置。",
			"hp": 110, "damage": 38, "range": MELEE_RANGE_MIN, "speed": SPEED_MEDIUM,
			"interval": 0.9, "first_hit": 0.33, "deploy_time": 0.0,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL, "mass": 1.0, "sight": 180.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
		},
		"visual": {
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/malzahar/player.gd", "variant": "spawn"}]},
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/voidling/voidling_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Idle1", "idle": "Idle1", "move": "Run", "attack": ["Attack1", "Attack2", "Attack3"], "death": "Death", "death_duration": 0.8},
			"color": Color(0.6, 0.1, 0.8),
		},
		"audio": {"events": {"death": {"pool": ["res://assets/audio/units/voidling/death_1_1.wav", "res://assets/audio/units/voidling/death_2_2.wav", "res://assets/audio/units/voidling/death_3_1.wav"], "volume_db": 0.0, "bus": "Combat"}}, "attack_hit": ["res://assets/audio/units/voidling/attack_hit_1.wav", "res://assets/audio/units/voidling/attack_hit_2.wav", "res://assets/audio/units/voidling/attack_hit_3.wav"], "attack_hit_volume_db": 0.0, "attack_swing": [["res://assets/audio/units/voidling/attack_launch_1.wav", "res://assets/audio/units/voidling/attack_launch_2.wav", "res://assets/audio/units/voidling/attack_launch_3.wav"], ["res://assets/audio/units/voidling/attack_launch_1.wav", "res://assets/audio/units/voidling/attack_launch_2.wav", "res://assets/audio/units/voidling/attack_launch_3.wav"], ["res://assets/audio/units/voidling/attack_launch_1.wav", "res://assets/audio/units/voidling/attack_launch_2.wav", "res://assets/audio/units/voidling/attack_launch_3.wav"]]},
		"card_art": {"path": "res://assets/cards/voidling_loading.png"},
	}
