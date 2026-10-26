extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "太阳耀斑", "cost": 2, "type": "spell", "spell_kind": "solar_flare",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 100.0, "inner_radius": 40.0, "duration": 1.75, "spell_windup": 0.9, "slow_multiplier": 0.2,
			"active_cost_bonus": 1,
			"description": "0.9秒后太阳光落下：中心1格内敌方单位眩晕1.75秒，外围至2.5格减速80%，持续1.75秒。不造成伤害，对空中单位有效；中心也可眩晕建筑卡和防御塔，水晶免疫控制。外围减速仅作用于普通单位。",
			"active_skills": [{"name": "日光", "kind": "spell_solar_flare", "cost": 1,
				"max_uses": 1, "cooldown": 0.0, "duration": 2.5, "damage": 100, "tower_damage_multiplier": 0.3,
				"description": "为命中的敌方单位、建筑卡、防御塔与水晶施加2.5秒日光。后续首次有效伤害消耗标记并追加100伤害（对防御塔与水晶为30）；重复施加刷新，不叠加。"}],
		},
		"visual": {"color": Color(1.0, 0.72, 0.12),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/solar_flare/player.gd", "variant": "warning"}, {"provider": "res://assets/effects/solar_flare/player.gd", "variant": "warning_red"}, {"provider": "res://assets/effects/solar_flare/player.gd", "variant": "impact"}]},
			"active_skills": [{"icon_path": "res://assets/skills/leona_p.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/solar_flare/player.gd", "variant": "mark"}, {"provider": "res://assets/effects/solar_flare/player.gd", "variant": "consume"}]}}]},
		# BEGIN IMPORTED AUDIO solar_flare
		"audio": {
			"events": {
				"spell:cast": {
					"pool": [
						"res://assets/audio/units/solar_flare/play_sfx_leona_leonasolarflare_oncast_r1.wav",
						"res://assets/audio/units/solar_flare/play_sfx_leona_leonasolarflare_oncast_r2.wav",
						"res://assets/audio/units/solar_flare/play_sfx_leona_leonasolarflare_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:impact": {
					"pool": [
						"res://assets/audio/units/solar_flare/play_sfx_leona_leonasolarflare_hit_r1.wav",
						"res://assets/audio/units/solar_flare/play_sfx_leona_leonasolarflare_hit_r2.wav",
						"res://assets/audio/units/solar_flare/play_sfx_leona_leonasolarflare_hit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:sunlight": {
					"pool": [
						"res://assets/audio/units/solar_flare/play_sfx_leona_leonasunlight_hit_r1.wav",
						"res://assets/audio/units/solar_flare/play_sfx_leona_leonasunlight_hit_r2.wav",
						"res://assets/audio/units/solar_flare/play_sfx_leona_leonasunlight_hit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO solar_flare
		"card_art": {"path": "res://assets/cards/solar_flare_loading.png"},
	}
