extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "星芒凝汇", "cost": 3, "type": "spell", "spell_kind": "stellar_convergence",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 160.0, "inner_radius": 60.0, "duration": 5.0,
			"damage": 6.0, "damage_interval": 0.25, "pull_speed": 40.0,
			"tower_damage_multiplier": 0.3, "active_cost_bonus": 1,
			"description": "生成持续5秒、半径4格的黑洞，每0.25秒对敌方地面、空中和建筑造成6伤害，并以每秒1格的外力牵引可移动单位。牵引不打断攻击，可抵抗自主移动；建筑不移动，防御塔与水晶承受30%伤害。",
			"active_skills": [{"name": "黑洞吞噬", "kind": "spell_stellar_convergence", "cost": 1,
				"max_uses": 1, "cooldown": 0.0, "execute_health_ratio": 0.15, "execute_buildings": false,
				"description": "身体触碰中心金色圆内部（半径1.5格）、生命严格低于15%的敌方单位被斩杀。无视护盾和减伤，不斩杀建筑，保留拒绝死亡、替身及复生规则。"}],
		},
		"visual": {"color": Color(0.3, 0.45, 0.95),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/stellar_convergence/player.gd", "variant": "zone"}, {"provider": "res://assets/effects/stellar_convergence/player.gd", "variant": "zone_red"}, {"provider": "res://assets/effects/stellar_convergence/player.gd", "variant": "core"}, {"provider": "res://assets/effects/stellar_convergence/player.gd", "variant": "core_red"}]},
			"active_skills": [{"icon_path": "res://assets/skills/aurelionsol_e.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/stellar_convergence/player.gd", "variant": "execute"}]}}]},
		# BEGIN IMPORTED AUDIO stellar_convergence
		"audio": {
			"events": {
				"spell:cast": {
					"pool": [
						"res://assets/audio/units/stellar_convergence/play_sfx_aurelionsol_aurelionsole_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:zone_sustain": {
					"pool": [
						"res://assets/audio/units/stellar_convergence/play_sfx_aurelionsol_aurelionsole_buffactivate_aoe_other.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:zone_end": {
					"pool": [
						"res://assets/audio/units/stellar_convergence/play_sfx_aurelionsol_aurelionsole_buffdeactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:hit": {
					"pool": [
						"res://assets/audio/units/stellar_convergence/play_sfx_aurelionsol_aurelionsole_hit_start_r1.wav",
						"res://assets/audio/units/stellar_convergence/play_sfx_aurelionsol_aurelionsole_hit_start_r2.wav",
						"res://assets/audio/units/stellar_convergence/play_sfx_aurelionsol_aurelionsole_hit_start_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:execute": {
					"pool": [
						"res://assets/audio/units/stellar_convergence/play_sfx_aurelionsol_aurelionsoledebuff_buffdeactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO stellar_convergence
		"card_art": {"path": "res://assets/cards/stellar_convergence_loading.png"},
	}
