extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "电击法术", "cost": 2, "type": "spell", "spell_kind": "zap",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 90.0, "duration": 0.6, "damage": 55,
			"strike_count": 1, "strike_interval": 1.0, "stun_duration": 0.2,
			"tower_damage_multiplier": 0.3, "active_cost_bonus": 1,
			"description": "范围中心落雷，对范围内敌方造成55伤害和0.2秒眩晕。对空对地及建筑有效，防御塔和水晶只承受30%伤害。",
			"active_skills": [{"name": "多重电击", "kind": "spell_lightning", "cost": 1,
				"max_uses": 1, "cooldown": 0.0, "strike_count": 2, "strike_damage_multiplier": 1.0,
				"description": "首次电击1秒后，在相同范围再次造成55伤害和0.2秒眩晕。"}],
		},
		"visual": {"color": Color(1.0, 0.18, 0.35),
			"active_skills": [{"icon_path": "res://assets/skills/zap_0.png"}]},
		"audio": {"events": {"spell:strike": {"pool": ["res://assets/audio/spells/zap/strike_r1.wav", "res://assets/audio/spells/zap/strike_r2.wav", "res://assets/audio/spells/zap/strike_r3.wav"], "volume_db": 0.0, "bus": "Combat"}}},
		"card_art": {"path": "res://assets/cards/zap_loading.png"},
	}
