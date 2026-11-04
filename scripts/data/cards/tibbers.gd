extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {"name": "提伯斯", "cost": 0, "type": "unit", "selectable": false,
			"description": "空投熊召唤的近战衍生单位，无自然寿命。强化空投出生时获得永久灼烧与5秒攻速加成。",
			"hp": 1000, "damage": 100, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.2, "first_hit": 0.3, "deploy_time": 0.0,
			"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE, "mass": 4.0, "sight": 220.0,
			"is_air": false, "building_only": false, "can_attack_air": false},
		"visual": {"color": Color(0.95, 0.32, 0.08), "visual_radius": RADIUS_LARGE + VISUAL_RADIUS_PADDING,
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/airdrop_bear/player.gd", "variant": "body"}, {"provider": "res://assets/effects/airdrop_bear/player.gd", "variant": "arm"}, {"provider": "res://assets/effects/airdrop_bear/player.gd", "variant": "hand"}, {"provider": "res://assets/effects/airdrop_bear/player.gd", "variant": "leg"}, {"provider": "res://assets/effects/airdrop_bear/player.gd", "variant": "foot"}]},
			"visual_scene_path": "res://assets/units/tibbers/tibbers_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"idle": "annietibbers_idle1", "move": "annietibbers_run",
				"attack": ["annietibbers_attack1", "annietibbers_attack2"], "death": "annietibbers_death", "death_duration": 0.8}},
		# BEGIN IMPORTED AUDIO tibbers
		"audio": {
			"events": {
				"death": {
					"pool": [
						"res://assets/audio/units/tibbers/play_sfx_annietibbers_annier_death_buffactivate_r1.wav",
						"res://assets/audio/units/tibbers/play_sfx_annietibbers_annier_death_buffactivate_r2.wav",
						"res://assets/audio/units/tibbers/play_sfx_annietibbers_annier_death_buffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"burning_aura:sustain": {
					"pool": [
						"res://assets/audio/units/tibbers/play_sfx_annietibbers_annier_buffactivate_loop_r1.wav",
						"res://assets/audio/units/tibbers/play_sfx_annietibbers_annier_buffactivate_loop_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/tibbers/play_sfx_annietibbers_annietibbersbasicattack2_oncast_r.wav"
				],
				[
					"res://assets/audio/units/tibbers/play_sfx_annietibbers_annietibbersbasicattack2_oncast_r.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/tibbers/play_sfx_annietibbers_annietibbersbasicattack2_onhit_r1.wav",
					"res://assets/audio/units/tibbers/play_sfx_annietibbers_annietibbersbasicattack2_onhit_r2.wav",
					"res://assets/audio/units/tibbers/play_sfx_annietibbers_annietibbersbasicattack2_onhit_r3.wav"
				],
				[
					"res://assets/audio/units/tibbers/play_sfx_annietibbers_annietibbersbasicattack2_onhit_r1.wav",
					"res://assets/audio/units/tibbers/play_sfx_annietibbers_annietibbersbasicattack2_onhit_r2.wav",
					"res://assets/audio/units/tibbers/play_sfx_annietibbers_annietibbersbasicattack2_onhit_r3.wav"
				]
			]
		},
		# END IMPORTED AUDIO tibbers
		"card_art": {"path": "res://assets/cards/tibbers_loading.png"},
	}
