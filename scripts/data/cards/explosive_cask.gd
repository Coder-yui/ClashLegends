extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "爆破酒桶", "cost": 3, "type": "spell", "spell_kind": "explosive_cask",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 105.0, "duration": 1.5, "damage": 180, "knockback": 40.0,
			"flight_speed": 900.0, "flight_min_duration": 0.4,
			"tower_damage_multiplier": 0.3, "active_cost_bonus": 1,
			"description": "从己方水晶抛出酒桶，抵达后对圆形范围内敌方造成180伤害，并从爆心向外小幅击退。对空对地有效；建筑不被击退，防御塔与水晶承受30%伤害。",
			"active_skills": [{"name": "烈性火药", "kind": "spell_explosive_cask", "cost": 1,
				"max_uses": 1, "cooldown": 0.0, "damage": 270,
				"description": "爆炸伤害提高至270，范围和击退不变。"}],
		},
		"visual": {
			"resource_dependencies": {
				"effects": [
					{
						"provider": "res://scripts/presentation/explosive_cask_3d.gd",
						"variant": "default"
					}
				]
			}, "color": Color(0.85, 0.42, 0.12),
			"active_skills": [{"icon_path": "res://assets/skills/explosive_cask_0.png"}]},
		"card_art": {"path": "res://assets/cards/explosive_cask_loading.png"},
		"audio": {"events": {
			"spell:cast": {"pool": ["res://assets/audio/spells/explosive_cask/cast.wav"], "volume_db": 0.0, "bus": "Combat"},
			"spell:strike": {"pool": ["res://assets/audio/spells/explosive_cask/boom_1.wav", "res://assets/audio/spells/explosive_cask/boom_2.wav", "res://assets/audio/spells/explosive_cask/boom_3.wav", "res://assets/audio/spells/explosive_cask/boom_4.wav"], "volume_db": 0.0, "bus": "Combat"}}},
	}
