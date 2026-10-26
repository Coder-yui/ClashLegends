extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "扭曲空间", "cost": 2, "type": "spell", "spell_kind": "event_horizon",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 120.0, "duration": 3.0, "spell_windup": 0.75, "stun_duration": 1.5,
			"active_cost_bonus": 2,
			"description": "短暂延迟0.75秒后，形成半径3格、持续3秒的空间边界。碰到边界的敌方地面或空中单位眩晕1.5秒，每次施法对每个单位最多生效一次；不会对建筑（包括防御塔和水晶）造成眩晕，圈内不会自动眩晕。",
			"active_skills": [{"name": "黑暗物质", "kind": "spell_event_horizon", "cost": 2,
				"max_uses": 1, "cooldown": 0.0, "dark_matter_delay": 1.2, "radius": 65.0,
				"damage": 220, "tower_damage_multiplier": 0.3,
				"description": "首个成功眩晕的位置在1.2秒后落下黑暗物质，对半径1.625格内敌军造成220伤害，防御塔与水晶承受30%。每次法术仅触发一次。"}],
		},
		"visual": {"color": Color(0.5, 0.15, 0.85),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/event_horizon/player.gd", "variant": "warning"}, {"provider": "res://assets/effects/event_horizon/player.gd", "variant": "warning_red"}, {"provider": "res://assets/effects/event_horizon/player.gd", "variant": "cage"}, {"provider": "res://assets/effects/event_horizon/player.gd", "variant": "cage_red"}]},
			"active_skills": [{"icon_path": "res://assets/skills/veigar_w.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/event_horizon/player.gd", "variant": "meteor"}, {"provider": "res://assets/effects/event_horizon/player.gd", "variant": "impact"}, {"provider": "res://assets/effects/event_horizon/player.gd", "variant": "meteor_red"}, {"provider": "res://assets/effects/event_horizon/player.gd", "variant": "impact_red"}]}}]},
		# BEGIN IMPORTED AUDIO event_horizon
		"audio": {
			"events": {
				"spell:zone_sustain": {"pool": ["res://assets/audio/units/event_horizon/play_sfx_veigar_veigareventhorizon_loop_r1.wav", "res://assets/audio/units/event_horizon/play_sfx_veigar_veigareventhorizon_loop_r2.wav"], "volume_db": 0.0, "bus": "Combat"},
				"spell:cast": {
					"pool": [
						"res://assets/audio/units/event_horizon/play_sfx_veigar_veigareventhorizon_oncast_r1.wav",
						"res://assets/audio/units/event_horizon/play_sfx_veigar_veigareventhorizon_oncast_r2.wav",
						"res://assets/audio/units/event_horizon/play_sfx_veigar_veigareventhorizon_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:hit": {
					"pool": [
						"res://assets/audio/units/event_horizon/play_sfx_veigar_veigareventhorizon_buffactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:meteor": {
					"pool": [
						"res://assets/audio/units/event_horizon/play_sfx_veigar_veigardarkmatter_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:impact": {
					"pool": [
						"res://assets/audio/units/event_horizon/play_sfx_veigar_veigardarkmatter_hit.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO event_horizon
		"card_art": {"path": "res://assets/cards/event_horizon_loading.png"},
	}
