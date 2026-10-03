extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "腐蚀法术", "cost": 4, "type": "spell", "spell_kind": "corrosion",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 110.0, "duration": 5.0, "damage": 60, "interval": 0.5, "tower_damage_multiplier": 0.3,
			"active_cost_bonus": 0,
			"description": "在圆形区域内持续5秒，每0.5秒一次，共10次，对圈内敌方地面、空中单位及建筑造成60伤害（共600）；对防御塔和水晶仅造成30%伤害（共180）；离开区域停止受伤。",
			"active_skills": [{"name": "强化腐蚀", "kind": "spell_corrosion", "cost": 0,
				"max_uses": 1, "cooldown": 0.0, "slow_multiplier": 0.8,
				"description": "敌方单位进入腐蚀区域立即降低20%移动速度，不必等待伤害节点；离开区域后减速迅速消失。"}],
		},
		"visual": {"color": Color(0.55, 0.18, 0.8),
			"active_skills": [{"icon_path": "res://assets/skills/corrosion_0.png"}]},
		"audio": {"events": {"spell:zone_sustain": {"pool": ["res://assets/audio/spells/corrosion/morgana_w_cast.wav"], "volume_db": 0.0, "bus": "Combat", "natural_tail": true}}},
		"card_art": {"path": "res://assets/cards/corrosion_loading.png"},
	}
