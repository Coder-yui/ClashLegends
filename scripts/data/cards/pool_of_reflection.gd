extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "庇护清泉", "cost": 3, "type": "spell", "spell_kind": "pool_of_reflection",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 110.0, "duration": 3.0, "shield_per_second": 60, "shield_duration": 1.0,
			"active_cost_bonus": 1,
			"description": "清泉持续3秒，为半径2.75格内友方非建筑单位每秒补充60护盾，不设护盾上限。离开清泉或清泉结束后护盾保留1秒。重叠清泉不加快补充。",
			"active_skills": [{"name": "渲浓", "kind": "spell_pool_of_reflection", "cost": 1, "max_uses": 1, "cooldown": 0.0,
				"shield": 120,
				"description": "落地立即为范围内友军提供120护盾。"}],
		},
		"visual": {"color": Color(0.2, 0.75, 0.9),
			"resource_dependencies": {"effects": [
				{"provider": "res://assets/effects/pool_of_reflection/player.gd", "variant": "area"},
				{"provider": "res://assets/effects/pool_of_reflection/player.gd", "variant": "area_red"},
				{"provider": "res://assets/effects/pool_of_reflection/player.gd", "variant": "shield"},
				{"provider": "res://assets/effects/pool_of_reflection/player.gd", "variant": "break"}]},
			"active_skills": [{"icon_path": "res://assets/skills/hwei_ww.png"}]},
		# BEGIN IMPORTED AUDIO pool_of_reflection
		"audio": {
			"events": {
				"spell:cast": {
					"pool": [
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiww_oncast_r1.wav",
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiww_oncast_r2.wav",
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiww_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:zone_sustain": {
					"pool": [
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiww_aoe_buffactivate_r_m.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:zone_end": {
					"pool": [
						"res://assets/audio/units/pool_of_reflection/stop_sfx_hwei_hweiww_aoe_buffactivate_r1_d.wav",
						"res://assets/audio/units/pool_of_reflection/stop_sfx_hwei_hweiww_aoe_buffactivate_r2_d.wav",
						"res://assets/audio/units/pool_of_reflection/stop_sfx_hwei_hweiww_aoe_buffactivate_r3_d.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"pool_shield:sustain": {
					"pool": [
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiwwshield_onbuffactivate_r1.wav",
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiwwshield_onbuffactivate_r2.wav",
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiwwshield_onbuffactivate_r3.wav"
					],
					"volume_db": -6.0,
					"bus": "Combat"
				},
				"spell:shield_end": {
					"pool": [
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiwwshield_onbuffdeactivate_r1.wav",
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiwwshield_onbuffdeactivate_r2.wav",
						"res://assets/audio/units/pool_of_reflection/play_sfx_hwei_hweiwwshield_onbuffdeactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO pool_of_reflection
		"card_art": {"path": "res://assets/cards/pool_of_reflection_loading.png"},
	}
