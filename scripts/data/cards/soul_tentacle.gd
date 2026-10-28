extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "灵魂触手", "cost": 4, "type": "building",
			"description": "预警后沿起手时锁定的方向拍击，造成范围伤害；敌人可躲开。",
			"hp": 1000, "damage": 180, "range": 160.0,
			"speed": 0.0, "interval": 2.65, "first_hit": 0.75,
			"radius": 21.0, "size_tier": "slightly_large",
			"footprint_tiles": Vector2i(3, 3), "is_building": true,
			"lifespan": 25.0, "lifespan_hp_decay": true,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"fixed_attack_length": 360.0, "fixed_attack_width": 80.0,
			"active_skills": [{"name": "过界信仰", "kind": "buff", "cost": 3, "max_uses": 1, "cooldown": 10.0,
				"duration": 8.0, "attack_speed_multiplier": 1.5, "untargetable": true, "pause_lifespan": true,
				"cast_duration": 0.0, "impact_delay": 0.0, "cast_locks": [],
				"description": "8秒内不可选取，暂停自然生命衰减，攻速提高50%。"}],
		},
		"visual": {
			"active_skills": [{"icon_path": "res://assets/skills/illaoi_r.png"}],
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/soul_tentacle/player.gd", "variant": "warning"}, {"provider": "res://assets/effects/soul_tentacle/player.gd", "variant": "active"}, {"provider": "res://assets/effects/soul_tentacle/player.gd", "variant": "spawn"}, {"provider": "res://assets/effects/soul_tentacle/player.gd", "variant": "burst"}, {"provider": "res://assets/effects/soul_tentacle/player.gd", "variant": "avatar"}, {"provider": "res://assets/effects/soul_tentacle/player.gd", "variant": "dormant"}, {"provider": "res://assets/effects/soul_tentacle/player.gd", "variant": "indicator_blue"}, {"provider": "res://assets/effects/soul_tentacle/player.gd", "variant": "indicator_red"}]},
			"visual_scene_path": "res://assets/units/soul_tentacle/soul_tentacle_view.tscn",
			"visual_radius": 30.0, "visual_forward_yaw": 0.0,
			"color": Color(0.2, 0.65, 0.55), "show_team_ring": false,
			"visual_animations": {"deploy": "illaoiminion_spawn", "idle": "illaoiminion_idleangry", "attack": "illaoiminion_attack1", "death": "illaoiminion_death", "death_duration": 0.8},
		},
		# BEGIN IMPORTED AUDIO soul_tentacle
		"audio": {
			"events": {
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentaclespawn_buffactivate_r1.wav",
						"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentaclespawn_buffactivate_r2.wav",
						"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentaclespawn_buffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"attack:ground": {
					"pool": [
						"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleattack_ground_hit_r1.wav",
						"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleattack_ground_hit_r2.wav",
						"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleattack_ground_hit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active:cast": {
					"pool": [
						"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleactive_onbuffcast_r1.wav",
						"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleactive_onbuffcast_r2.wav",
						"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleactive_onbuffcast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleattack_onbuffcast_r1.wav",
					"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleattack_onbuffcast_r2.wav",
					"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleattack_onbuffcast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit": [
				"res://assets/audio/units/soul_tentacle/play_sfx_illaoi_illaoitentacleattack_minion_hit.wav"
			],
			"attack_hit_volume_db": 0.0
		},
		# END IMPORTED AUDIO soul_tentacle
		"card_art": {"path": "res://assets/cards/soul_tentacle_loading.png"},
	}
