extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "攢聚雷", "cost": 3, "type": "spell", "spell_kind": "severing_bolt",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 65.0, "duration": 1.0, "spell_windup": 0.5, "damage": 120,
			"isolated_damage_multiplier": 2.5, "controlled_damage_multiplier": 2.0,
			"tower_damage_multiplier": 0.3, "active_cost_bonus": 0,
			"description": "0.5秒前奏后预警1秒，落雷对半径1.625格内敌军造成120伤害。仅命中一个敌军时造成2.5倍伤害；硬控目标受到2倍伤害，两者取较高值。对空、地面与建筑有效，防御塔和水晶承受30%。",
			"active_skills": [{"name": "攢聚惊雷", "kind": "spell_severing_bolt", "cost": 0,
				"max_uses": 1, "cooldown": 0.0, "isolated_damage_multiplier": 3.5, "controlled_damage_multiplier": 2.5,
				"description": "单体倍率提高至3.5倍，硬控倍率提高至2.5倍；同时满足时取较高值。"}],
		},
		"visual": {"color": Color(1.0, 0.55, 0.12),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/severing_bolt/player.gd", "variant": "warning"}, {"provider": "res://assets/effects/severing_bolt/player.gd", "variant": "warning_red"}, {"provider": "res://assets/effects/severing_bolt/player.gd", "variant": "impact"}, {"provider": "res://assets/effects/severing_bolt/player.gd", "variant": "hit"}]},
			"active_skills": [{"icon_path": "res://assets/skills/hwei_qw.png"}]},
		# BEGIN IMPORTED AUDIO severing_bolt
		"audio": {
			"events": {
				"spell:launch": {
					"pool": [
						"res://assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_oncast_r1.wav",
						"res://assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_oncast_r2.wav",
						"res://assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:warning": {
					"pool": [
						"res://assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_aoe_warning_r1.wav",
						"res://assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_aoe_warning_r2.wav",
						"res://assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_aoe_warning_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:impact": {
					"pool": [
						"res://assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_aoe_explode_r1.wav",
						"res://assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_aoe_explode_r2.wav",
						"res://assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_aoe_explode_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO severing_bolt
		"card_art": {"path": "res://assets/cards/severing_bolt_loading.png"},
	}
