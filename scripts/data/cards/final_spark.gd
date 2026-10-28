extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "终极闪光", "cost": 3, "type": "spell", "spell_kind": "final_spark",
			"deploy_zone": "own_side", "deploy_half_only": true, "deploy_ignore_structures": true,
			"radius": 20.0, "wave_width": 40.0, "range": 800.0, "duration": 2.5, "spell_windup": 1.0,
			"damage": 300, "tower_damage_multiplier": 0.3, "active_cost_bonus": 1,
			"description": "仅在己方半场释放。预警1秒后向敌方爆发一道1格宽、20格长的闪光，对直线内敌方地面、空中单位和建筑造成一次300伤害。防御塔和水晶承受30%伤害。",
			"active_skills": [{"name": "夺目光辉", "kind": "spell_final_spark", "cost": 1, "max_uses": 1, "cooldown": 0.0,
				"blind_charges": 1, "description": "对命中的敌方非建筑单位施加1次致盲：下一次普通或强化攻击落空，仍正常消耗攻击。重复施加不叠加次数。"}],
		},
		"visual": {"color": Color(1.0, 0.8, 0.3),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/final_spark/player.gd", "variant": "cast"}, {"provider": "res://assets/effects/final_spark/player.gd", "variant": "beam"}]},
			"active_skills": [{"icon_path": "res://assets/skills/lux_p.png"}]},
		"card_art": {"path": "res://assets/cards/final_spark_loading.png"},
		"audio": {"events": {"spell:cast": {"pool": ["res://assets/audio/units/final_spark/cast_1.wav", "res://assets/audio/units/final_spark/cast_2.wav", "res://assets/audio/units/final_spark/cast_3.wav"], "volume_db": 0.0, "bus": "Combat"}, "spell:middle": {"pool": ["res://assets/audio/units/final_spark/middle_1.wav", "res://assets/audio/units/final_spark/middle_2.wav", "res://assets/audio/units/final_spark/middle_3.wav"], "volume_db": 0.0, "bus": "Combat"}, "spell:end": {"pool": ["res://assets/audio/units/final_spark/end_1.wav", "res://assets/audio/units/final_spark/end_2.wav", "res://assets/audio/units/final_spark/end_3.wav"], "volume_db": 0.0, "bus": "Combat"}}},
	}
