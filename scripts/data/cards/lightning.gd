extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "大型电击法术", "cost": 6, "type": "spell", "spell_kind": "lightning",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 120.0, "duration": 0.6, "damage": 460,
			"strike_count": 3, "strike_interval": 1.0, "stun_duration": 0.2,
			"tower_damage_multiplier": 0.3, "active_cost_bonus": 1,
			"description": "共3次电击，间隔1秒；每次重新选择范围内尚未被本次法术电击、当前生命最高的敌方目标，造成460伤害和0.2秒眩晕。对空对地及建筑有效，防御塔和水晶只承受30%伤害。",
			"active_skills": [{"name": "递增电击", "kind": "spell_lightning", "cost": 1,
				"max_uses": 1, "cooldown": 0.0, "strike_count": 3, "strike_damage_multiplier": 1.2,
				"description": "三段伤害依次为基础值的100%、120%、144%；空段跳过，后续段伤害档位不变。"}],
		},
		"visual": {"color": Color(1.0, 0.18, 0.35),
			"active_skills": [{"icon_path": "res://assets/skills/lightning_0.png"}]},
		"audio": {"events": {"spell:strike": {"pool": ["res://assets/audio/spells/lightning/strike_r1.wav", "res://assets/audio/spells/lightning/strike_r2.wav", "res://assets/audio/spells/lightning/strike_r3.wav"], "volume_db": 0.0, "bus": "Combat"}}},
		"card_art": {"path": "res://assets/cards/lightning_loading.png"},
	}
