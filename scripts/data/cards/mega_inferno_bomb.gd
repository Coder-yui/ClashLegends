extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "终极爆弹", "cost": 6, "type": "spell", "spell_kind": "mega_inferno_bomb",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 160.0, "inner_radius": 80.0, "damage": 360, "inner_damage": 600, "duration": 5.0,
			"flight_speed": 700.0, "flight_min_duration": 0.8, "tower_damage_multiplier": 0.3, "active_cost_bonus": 0,
			"description": "从己方水晶抛出重型炸弹，抵达后中心2格造成600伤害，外围至4格造成360伤害。对空、地面和建筑有效；防御塔与水晶承受30%。飞行速度每秒17.5格，至少0.8秒。",
			"active_skills": [{"name": "地狱火炮", "kind": "spell_mega_inferno_bomb", "cost": 0,
				"max_uses": 1, "cooldown": 0.0,
				"description": "命中时先移除普通伤害护盾，再造成伤害；对非建筑单位施加无持续时间的100%重伤，阻止治疗和吸血，不影响最大生命提升。梦魇的效果护盾仍可抵挡整次法术。重伤持续至单位死亡，重复命中不叠加。"}],
		},
		"visual": {"color": Color(1.0, 0.4, 0.08),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/mega_inferno_bomb/player.gd", "variant": "warning_ally"}, {"provider": "res://assets/effects/mega_inferno_bomb/player.gd", "variant": "warning_enemy"}, {"provider": "res://assets/effects/mega_inferno_bomb/player.gd", "variant": "missile"}, {"provider": "res://assets/effects/mega_inferno_bomb/player.gd", "variant": "impact"}]},
			"active_skills": [{"icon_path": "res://assets/skills/inferno_cannon.png"}]},
		# BEGIN IMPORTED AUDIO mega_inferno_bomb
		"audio": {
			"events": {
				"spell:cast": {
					"pool": [
						"res://assets/audio/units/mega_inferno_bomb/play_sfx_ziggs_ziggsr_onmissilelaunch_r1.wav",
						"res://assets/audio/units/mega_inferno_bomb/play_sfx_ziggs_ziggsr_onmissilelaunch_r2.wav",
						"res://assets/audio/units/mega_inferno_bomb/play_sfx_ziggs_ziggsr_onmissilelaunch_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:strike": {
					"pool": [
						"res://assets/audio/units/mega_inferno_bomb/play_sfx_ziggs_ziggsr_hit_r1.wav",
						"res://assets/audio/units/mega_inferno_bomb/play_sfx_ziggs_ziggsr_hit_r2.wav",
						"res://assets/audio/units/mega_inferno_bomb/play_sfx_ziggs_ziggsr_hit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:flight": {
					"pool": [
						"res://assets/audio/units/mega_inferno_bomb/play_sfx_ziggs_ziggsr_missilelaunch.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO mega_inferno_bomb
		"card_art": {"path": "res://assets/cards/mega_inferno_bomb_loading.png"},
	}
