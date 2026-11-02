extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "藤蔓鞭击者", "cost": 3, "type": "building",
			"description": "挥动藤蔓攻击地面敌人，命中使其减速30%，持续2秒。",
			"hp": 720, "damage": 100, "range": 100.0,
			"speed": 0.0, "interval": 1.25, "first_hit": 0.31,
			"radius": 21.0, "size_tier": "slightly_large",
			"footprint_tiles": Vector2i(2, 2), "is_building": true,
			"lifespan": 24.0, "lifespan_hp_decay": true,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"on_hit_slow_duration": 2.0, "on_hit_slow_multiplier": 0.7,
			"active_skills": [{"name": "缠绕之根", "kind": "buff", "cost": 2, "max_uses": 2, "cooldown": 14.0,
				"duration": 6.0, "health_bonus_ratio": 0.5, "body_scale_multiplier": 1.25,
				"attack_speed_multiplier": 1.6,
				"cast_duration": 0.0, "impact_delay": 0.0, "cast_locks": [],
				"description": "持续6秒：最大生命值提高50%并获得新增生命，模型与碰撞增大25%，攻速提高60%。"}],
		},
		"visual": {
			"visual_active_buff_scene": "res://assets/effects/thorn_spitter/buff.tscn",
			"active_skills": [{"icon_path": "res://assets/skills/zyra_e.png", "resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/thorn_spitter/player.gd", "variant": "buff"}]}}],
			"visual_scene_path": "res://assets/units/vine_lasher/vine_lasher_view.tscn",
			"visual_radius": 30.0, "visual_forward_yaw": 0.0,
			"color": Color(0.8, 0.2, 0.2), "show_team_ring": false,
			"visual_animations": {"deploy": "Up", "idle": "Idle1", "attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.8},
		},
		# BEGIN IMPORTED AUDIO vine_lasher
		"audio": {
			"events": {
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/vine_lasher/play_sfx_zyra_zyraeplant_onbuffactivate_r1.wav",
						"res://assets/audio/units/vine_lasher/play_sfx_zyra_zyraeplant_onbuffactivate_r2.wav",
						"res://assets/audio/units/vine_lasher/play_sfx_zyra_zyraeplant_onbuffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/vine_lasher/play_sfx_zyra_zyraeplant_onbuffdeactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack_oncast_r1_d.wav",
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack_oncast_r2_d.wav",
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack2_oncast_r1.wav",
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack2_oncast_r2.wav",
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack_onhit_r1_d.wav",
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack_onhit_r2_d.wav",
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack_onhit_r3_d.wav"
				],
				[
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack2_onhit_r1.wav",
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack2_onhit_r2.wav",
					"res://assets/audio/units/vine_lasher/play_sfx_zyragraspingplant_zyraeplantattack2_onhit_r3.wav"
				]
			]
		},
		# END IMPORTED AUDIO vine_lasher
		"card_art": {"path": "res://assets/cards/vine_lasher_loading.png"},
	}
