extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "凝滞法术", "cost": 3, "type": "spell", "spell_kind": "stasis", "flight_speed": 900.0, "flight_min_duration": 0.4,
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 110.0, "duration": 3.0, "active_cost_bonus": 0,
			"description": "从己方水晶向目标区域发射星光，抵达后使范围内双方单位凝滞3秒。凝滞期间无法行动、被选取或受伤，保持碰撞。对空中单位、建筑卡和双方防御塔有效，水晶免疫。",
			"active_skills": [{"name": "友军优待", "kind": "spell_stasis", "cost": 0,
				"max_uses": 1, "cooldown": 0.0, "duration": 2.0,
				"description": "我方单位、建筑卡和防御塔凝滞时间缩短至2秒，敌方仍为3秒。"}],
		},
		"visual": {"color": Color(1.0, 0.78, 0.22), "active_skills": [{"icon_path": "res://assets/skills/stasis_0.png"}]},
		"card_art": {"path": "res://assets/cards/stasis_loading.png"},
		"audio": {"events": {
			"spell:cast": {"pool": ["res://assets/audio/spells/stasis/OnCast.wav"], "volume_db": 0.0, "bus": "Combat"},
			"spell:strike": {"pool": ["res://assets/audio/spells/stasis/explo.wav"], "volume_db": 0.0, "bus": "Combat"}}},
	}
