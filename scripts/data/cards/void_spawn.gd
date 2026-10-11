extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "虚空兽", "cost": 3, "type": "unit",
			"description": "并排部署2只虚空兽，只追击建筑。进入射程后立即牺牲自身，跃向固定落点，0.8秒后爆炸，只对锁定的目标建筑造成240伤害。",
			"hp": 166, "damage": 0, "range": MELEE_RANGE_MIN, "can_attack": false,
			"speed": SPEED_FAST, "interval": 0.8, "first_hit": 0.8,
			"size_tier": SIZE_SLIGHTLY_SMALL, "radius": RADIUS_SLIGHTLY_SMALL,
			"mass": 2.0, "sight": 180.0, "deploy_time": 1.0,
			"is_air": false, "building_only": true, "can_attack_air": false,
			"deployment_count": 2, "deployment_spacing": 48.0, "deployment_formation": "line",
			"sacrifice_damage": 240.0, "sacrifice_delay": 0.8,
			"active_skills": [{"name": "虚空强化", "kind": "sacrifice_empower", "cost": 1, "max_uses": 1, "cooldown": 0.0,
				"target_scope": "deployment_group", "damage_multiplier": 1.5, "health_bonus_ratio": 0.2, "body_scale_multiplier": 1.25, "speed_multiplier": 1.2}],
		},
		"visual": {
			"visual_active_buff_scene": "res://assets/effects/void_spawn/empowered.tscn",
			"active_skills": [{"resource_dependencies": {"fields": ["visual_active_buff_scene"]}, "icon_path": "res://assets/skills/void_spawn_0.png", "visual_scale_multiplier": 1.25}],
			"visual_radius": RADIUS_SLIGHTLY_SMALL + VISUAL_RADIUS_PADDING,
			"color": Color(0.65, 0.24, 0.85),
			"visual_scene_path": "res://assets/units/void_spawn/void_spawn_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "VoidSpawn_Spawn_anm", "idle": "Idle1", "move": "Run",
				"attack": ["VoidSpawn_TurretAttack1_anm"], "death": "Death", "death_duration": 2.2},
			"resource_dependencies": {"effects": [{"provider": "res://scripts/presentation/sacrifice_leap_3d.gd", "variant": "default"}, {"provider": "res://assets/effects/void_spawn/player.gd", "variant": "burst"}, {"provider": "res://assets/effects/void_spawn/player.gd", "variant": "death"}, {"provider": "res://assets/effects/void_spawn/player.gd", "variant": "energy"}, {"provider": "res://assets/effects/void_spawn/player.gd", "variant": "glow"}]},
		},
		"card_art": {"path": "res://assets/cards/void_spawn_loading.png"},
		"audio": {"events": {"active:cast": {"pool": ["res://assets/audio/units/void_spawn/deploy_start_2.wav"], "volume_db": 0.0, "bus": "Combat"}, "deploy:start": {"pool": ["res://assets/audio/units/void_spawn/deploy_start_1.wav"], "volume_db": 0.0, "bus": "Combat"}, "death": {"pool": ["res://assets/audio/units/void_spawn/death_1.wav", "res://assets/audio/units/void_spawn/death_2.wav"], "volume_db": 0.0, "bus": "Combat"}, "sacrifice:start": {"pool": ["res://assets/audio/units/void_spawn/sacrifice_start_1.wav", "res://assets/audio/units/void_spawn/sacrifice_start_2.wav", "res://assets/audio/units/void_spawn/sacrifice_start_3.wav"], "volume_db": 0.0, "bus": "Combat"}, "sacrifice:impact": {"pool": ["res://assets/audio/units/void_spawn/sacrifice_impact_1.wav", "res://assets/audio/units/void_spawn/sacrifice_impact_2.wav"], "volume_db": 0.0, "bus": "Combat"}}},
	}
