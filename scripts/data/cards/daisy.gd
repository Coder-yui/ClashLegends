extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "小菊", "cost": 4, "type": "unit", "selectable": false,
			"description": "翠神召唤的大型近战前排，只攻击地面。小菊，猛击！每第三击额外造成60伤害并眩晕目标1秒。",
			"hp": 1100, "damage": 100, "range": MELEE_RANGE_MIN, "sight": 220.0,
			"speed": SPEED_MEDIUM, "interval": 1.4, "first_hit": 0.4, "deploy_time": 1.3,
			"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE, "mass": 8.0,
			"attack_pattern": [1.4, 1.4, 1.4], "attack_damage_multipliers": [1.0, 1.0, 1.6],
			"attack_stun_durations": [0.0, 0.0, 1.0],
			"is_air": false, "building_only": false, "can_attack_air": false,
		},
		"visual": {
			"color": Color(0.53, 0.65, 0.36), "visual_radius": RADIUS_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/daisy/daisy_view.tscn", "visual_forward_yaw": 0.0, "attack_hit_visual": "daisy_slam",
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/ivern/player.gd", "variant": "spawn"}, {"provider": "res://assets/effects/ivern/player.gd", "variant": "slam"}]},
			"visual_animations": {"deploy": "IvernMinion_spawn_anm", "idle": "IvernMinion_idle_anm", "move": "Run",
				"attack": ["Attack1", "Attack2", "Attack3"], "death": "Death", "death_duration": 0.8},
		},
		# BEGIN IMPORTED AUDIO daisy
		"audio": {
			"events": {
				"death": {"pool": ["res://assets/audio/units/daisy/death.wav"], "volume_db": 0.0, "bus": "Combat"},
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisyspawn_cast_r.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_attack_into_r1.wav",
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_attack_into_r2.wav",
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_attack_into_r3.wav"
				],
				[
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_attack_into_r1.wav",
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_attack_into_r2.wav",
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_attack_into_r3.wav"
				],
				[
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_slam_into.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_hit_r1.wav",
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_hit_r2.wav",
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_hit_r3.wav"
				],
				[
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_hit_r1.wav",
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_hit_r2.wav",
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_hit_r3.wav"
				],
				[
					"res://assets/audio/units/daisy/play_sfx_ivern_ivernr_daisy_slam_hit_r.wav"
				]
			]
		},
		# END IMPORTED AUDIO daisy
		"card_art": {"path": "res://assets/cards/daisy_loading.png"},
	}
