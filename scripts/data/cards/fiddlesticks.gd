extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "远古恐惧", "cost": 0, "type": "unit", "selectable": false,
			"description": "草间人的移动形态。每轮锁定射程内敌人吸血2秒，停0.75秒后重新选敌，回复实际伤害的50%。",
			"hp": 1200, "damage": 60, "range": 180.0, "sight": 250.0,
			"speed": SPEED_SLOW, "interval": 0.0, "first_hit": 0.0,
			"radius": RADIUS_SLIGHTLY_LARGE, "size_tier": SIZE_SLIGHTLY_LARGE, "mass": 6.0,
			"is_building": false, "is_air": false, "building_only": false, "can_attack_air": true,
			"is_continuous_attack": true, "attack_all_in_range": true, "drain_duration": 2.0, "drain_pause": 0.75, "innate_lifesteal_ratio": 0.5,
		},
		"visual": {
			"visual_scene_path": "res://assets/units/fiddlesticks/fiddlesticks_view.tscn",
			"visual_radius": 29.0, "visual_forward_yaw": 0.0,
			"color": Color(0.65, 0.23, 0.19),
			"visual_animations": {"transition_blends": {"locomotion": 0.14, "action_in": 0.1, "action_out": 0.14, "death": 0.08}, "idle": "fiddlesticks_idle1", "move": "fiddlesticks_run",
				"attack_enter": "fiddlesticks_spell2", "attack_loop": "fiddlesticks_spell2_channel",
				"transitions": {
					"fiddlesticks_run>idle": {"animation": "fiddlesticks_idlein1", "blend_in": 0.05, "blend_out": 0.0},
					"fiddlesticks_spell2_to_run>idle": {"animation": "fiddlesticks_idlein1", "blend_in": 0.05, "blend_out": 0.0},
					"fiddlesticks_spell2_channel>idle": {"animation": "fiddlesticks_spell2_channel_toidle", "blend_in": 0.0, "blend_out": 0.0},
					"attack>move": {"animation": "fiddlesticks_spell2_to_run", "blend_in": 0.0, "blend_out": 0.0},
					"fiddlesticks_spell2_channel_toidle>move": {"animation": "fiddlesticks_spell2_to_run", "blend_in": 0.1, "blend_out": 0.0},
				},
				"clip_blends": {
					"fiddlesticks_spell2>fiddlesticks_spell2_channel": 0.0,
					"fiddlesticks_run>fiddlesticks_spell2": 0.1,
					"fiddlesticks_idle1>fiddlesticks_spell2": 0.1,
					"fiddlesticks_spell2_to_run>fiddlesticks_spell2": 0.08,
					"fiddlesticks_spell2_channel_toidle>fiddlesticks_spell2": 0.08,
				},
				"death": "fiddlesticks_death_effigies", "death_duration": 1.94},
			"continuous_beam_color": Color(0.7, 0.08, 0.03, 0.8),
			"continuous_beam_origin_height": 45.0,
		},
		# BEGIN IMPORTED AUDIO fiddlesticks
		"audio": {
			"events": {
				"continuous_attack:start": {
					"pool": [
						"res://assets/audio/units/fiddlesticks/play_sfx_fiddlesticks_fiddlesticksw_oncast_r1.wav",
						"res://assets/audio/units/fiddlesticks/play_sfx_fiddlesticks_fiddlesticksw_oncast_r2.wav",
						"res://assets/audio/units/fiddlesticks/play_sfx_fiddlesticks_fiddlesticksw_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"continuous_attack:sustain": {
					"pool": [
						"res://assets/audio/units/fiddlesticks/play_sfx_fiddlesticks_fiddlestickswdrain_onbuffactivate_r1.wav",
						"res://assets/audio/units/fiddlesticks/play_sfx_fiddlesticks_fiddlestickswdrain_onbuffactivate_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": ["res://assets/audio/units/fiddlesticks/effigy_death_mobile_r1.wav", "res://assets/audio/units/fiddlesticks/effigy_death_mobile_r2.wav"],
					"volume_db": 0.0, "bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO fiddlesticks
		"card_art": {"path": "res://assets/cards/fiddlesticks_loading.png"},
	}
