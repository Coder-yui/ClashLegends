extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "牧魂人", "cost": 4, "type": "unit",
			"description": "以重铲攻击地面敌人，命中点周围35范围内的敌人受到相同伤害。",
			"hp": 820, "damage": 110, "range": MELEE_RANGE_MIN,
			"speed": SPEED_SLIGHTLY_SLOW, "interval": 1.5, "first_hit": 0.27,
			"empowered_first_hit": 0.27,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 7.0, "sight": 220.0, "splash_radius": 35.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{"name": "临终仪式", "kind": "empowered_attack",
				"cost": 1, "max_uses": 3, "cooldown": 6.0,
				"empowered_damage_multiplier": 2.0, "hit_heal": 120,
				"description": "下一击范围伤害220，命中回复120生命，每击只回复一次。"}],
		},
		"visual": {
			"color": Color(0.25, 0.55, 0.52), "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/yorick/yorick_view.tscn", "visual_forward_yaw": 0.0,
			"attack_hit_visual": "splash_circle",
			"visual_animations": {"deploy": "IdleIn", "idle": "Idle1", "move": "Run_Base",
				"clip_blends": {"IdleIn>Run_Base": 0.18, "IdleIn>Idle1": 0.18,
					"IdleIn>Attack1": 0.12, "IdleIn>Attack2": 0.12, "IdleIn>Attack3": 0.12, "IdleIn>Spell1": 0.12},
				"attack": ["Attack1", "Attack2", "Attack3"], "empowered_attack": "Spell1", "death": "Death", "death_duration": 0.8},
			"active_skills": [{"icon_path": "res://assets/skills/yorick_q.png"}],
		},
		# BEGIN IMPORTED AUDIO yorick
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/yorick/deploy.ogg"], "clip_volume_db": {"res://assets/audio/units/yorick/deploy.ogg": -8.0}, "bus": "Voice"},
				"empowered_ready": {
					"pool": [
						"res://assets/audio/units/yorick/play_sfx_yorick_yorickq_oncast_r1.wav",
						"res://assets/audio/units/yorick/play_sfx_yorick_yorickq_oncast_r2.wav",
						"res://assets/audio/units/yorick/play_sfx_yorick_yorickq_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"empowered_swing": {
					"pool": [
						"res://assets/audio/units/yorick/play_sfx_yorick_yorickqattack_oncast_r.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/yorick/play_sfx_yorick_base_death_m.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"empowered_buff:sustain": {
					"pool": [
						"res://assets/audio/units/yorick/play_sfx_yorick_yorickqbuff_onbuffactivate_r1.wav",
						"res://assets/audio/units/yorick/play_sfx_yorick_yorickqbuff_onbuffactivate_r2.wav",
						"res://assets/audio/units/yorick/play_sfx_yorick_yorickqbuff_onbuffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack_oncast_r_d.wav"
				],
				[
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack2_oncast_r.wav"
				],
				[
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack_oncast_r_d.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack_onhit_1559186049_1153642577_r3_d.wav"
				],
				[
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack2_onhit_1559186049_1153642577_r3.wav"
				],
				[
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/yorick/play_sfx_yorick_yorickbasicattack_onhit_1559186049_1153642577_r3_d.wav"
				]
			],
			"empowered_hit": [
				"res://assets/audio/units/yorick/play_sfx_yorick_yorickqattack_hit_1559186049_1153642577_r.wav"
			]
		},
		# END IMPORTED AUDIO yorick
		"card_art": {"path": "res://assets/cards/yorick_loading.png"},
	}
