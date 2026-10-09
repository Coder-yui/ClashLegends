extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "沙漠皇帝", "cost": 8, "type": "unit",
			"description": "慢速远程后排，可对地对空。命中后2秒内死亡的敌军化为黄沙士兵，敌方建筑和防御塔化为会衰减生命的太阳圆盘。",
			"hp": 900, "damage": 130, "range": 240.0,
			"speed": SPEED_SLIGHTLY_SLOW, "interval": 1.6, "first_hit": 0.25,
			"projectile_speed": 0.0, "deploy_time": 2.0,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE, "mass": 4.0, "sight": 280.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"assist_conversion_window": 2.0, "assist_conversion_unit_id": "sand_soldier", "assist_conversion_building_id": "sun_disc",
			"active_skills": [{"name": "沙兵现身", "kind": "summon", "cost": 2, "max_uses": 1, "cooldown": 10.0,
				"spawn_id": "sand_soldier", "spawn_count": 4, "cast_duration": 0.8, "impact_delay": 0.25,
				"description": "在自身四周召唤4名黄沙士兵。"}],
		},
		"visual": {
			"color": Color(0.95, 0.72, 0.22), "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/azir/azir_view.tscn", "visual_forward_yaw": 0.0,
			"attack_hit_visual": "azir_beam",
			"projectile_visual_height": 60.0,
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/azir/beam_player.gd", "variant": "basic_attack"},
				{"provider": "res://assets/effects/azir/player.gd", "variant": "cast1"},
				{"provider": "res://assets/effects/azir/player.gd", "variant": "cast2"},
				{"provider": "res://assets/effects/azir/player.gd", "variant": "hit"}]},
			"visual_animations": {"deploy": "Respawn", "deploy_clip_ratio": 6.0 / 10.5, "idle": "Idle1_Base", "move": "Run",
				"attack": ["Azir_Attack1_anm", "Azir_Attack2_anm"],
				"attack_clip_ranges": [[0.0, 0.25], [0.0, 0.25]],
				"attack_hit": ["Azir_Attack1_anm", "Azir_Attack2_anm"],
				"attack_hit_clip_ranges": [[0.25, 2.3], [0.25, 2.3]], "attack_hit_duration": 1.35,
				"clip_blends": {"Respawn>Run": 0.18, "Respawn>Idle1_Base": 0.18,
					"Respawn>Azir_Attack1_anm": 0.12, "Respawn>Azir_Attack2_anm": 0.12},
				"transition_blends": {"sequence": 0.0}, "death": "Death", "death_duration": 1.2,
				"visual_actions": {"active": {"animation": "Azir_Spell2_anm", "kind": "skill"}}},
			"active_skills": [{"visual_action": "active", "icon_path": "res://assets/skills/azir_w.png"}],
		},
		# BEGIN IMPORTED AUDIO azir
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/azir/deploy.ogg"], "bus": "Voice", "volume_db": 0.0},
				"death": {
					"pool": [
						"res://assets/audio/units/azir/play_sfx_azir_base_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/azir/play_sfx_azir_azirbasicattack_oncast_r_d.wav"
				],
				[
					"res://assets/audio/units/azir/play_sfx_azir_azirbasicattack2_oncast_r.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/azir/play_sfx_azir_azirbasicattack_onhit_r1_d.wav",
					"res://assets/audio/units/azir/play_sfx_azir_azirbasicattack_onhit_r2_d.wav"
				],
				[
					"res://assets/audio/units/azir/play_sfx_azir_azirbasicattack2_onhit_r1.wav",
					"res://assets/audio/units/azir/play_sfx_azir_azirbasicattack2_onhit_r2.wav"
				]
			]
		},
		# END IMPORTED AUDIO azir
		"card_art": {"path": "res://assets/cards/azir_loading.jpg"},
	}
