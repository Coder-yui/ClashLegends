extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "中型雷电法术", "cost": 4, "type": "spell", "spell_kind": "medium_lightning",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"spell_windup": 2.0, "radius": 100.0, "duration": 2.0, "damage": 240, "stun_duration": 2.0,
			"tower_damage_multiplier": 0.3, "active_cost_bonus": 1,
			"description": "蓄雷2秒后，对半径2.5格内敌方造成240伤害，对空对地及建筑有效。防御塔和水晶承受30%伤害；命中的防御塔失效2秒，复用眩晕规则，水晶与建筑卡不受失效控制。",
			"active_skills": [{"name": "霹天雳地", "kind": "spell_medium_lightning", "cost": 1,
				"max_uses": 1, "cooldown": 0.0, "shield": 180, "shield_duration": 3.0,
				"slow_duration": 2.0, "slow_multiplier": 0.7,
				"description": "落雷同时为范围内友方非建筑单位提供180点护盾，持续3秒；命中的敌方非建筑单位减速30%，持续2秒。"}],
		},
		"visual": {"color": Color(0.25, 0.65, 1.0),
			"resource_dependencies": {"effects": [{"provider": "res://scripts/presentation/medium_lightning_3d.gd", "variant": "default"}]},
			"active_skills": [{"icon_path": "res://assets/skills/medium_lightning_0.png"}]},
		"card_art": {"path": "res://assets/cards/medium_lightning_loading.png"},
		"audio": {"events": {
			"spell:cast": {"pool": ["res://assets/audio/spells/medium_lightning/cast.wav"], "volume_db": 0.0, "bus": "Combat"},
			"spell:warning": {"pool": ["res://assets/audio/spells/medium_lightning/warning.wav"], "volume_db": 0.0, "bus": "Combat"},
			"spell:warning_enemy": {"pool": ["res://assets/audio/spells/medium_lightning/warning_enemy.wav"], "volume_db": 0.0, "bus": "Combat"},
			"spell:hit": {"pool": ["res://assets/audio/spells/medium_lightning/hit.wav"], "volume_db": 0.0, "bus": "Combat"},
			"spell:zone_sustain": {"fade_out": 1.0, "fade_out_curve": "exp1", "pool": ["res://assets/audio/spells/medium_lightning/tower_sustain.wav"], "volume_db": -12.0, "bus": "Combat"},
			"spell:strike": {"pool": ["res://assets/audio/spells/medium_lightning/strike.wav"], "volume_db": 0.0, "bus": "Combat"},
			"spell:tower_disable": {"pool": ["res://assets/audio/spells/medium_lightning/tower_disable.wav"], "volume_db": -12.0, "bus": "Combat"}}},
	}
