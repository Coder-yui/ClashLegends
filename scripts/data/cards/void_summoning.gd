extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "虚空召唤", "cost": 5, "type": "spell", "spell_kind": "void_summoning",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 160.0, "duration": 8.0, "interval": 0.8, "spawn_initial_delay": 0.5, "spawn_id": "voidfish", "spawn_count": 10, "spawn_deploy_time": 0.8,
			"active_cost_bonus": 1,
			"description": "半径4格，持续8秒，首次0.5秒召唤，之后每0.8秒分散召出一只近战虚空鱼，共10只。每只出生特效结束后即可行动。",
			"active_skills": [{"name": "虚空献祭", "kind": "spell_void_summoning", "cost": 1, "max_uses": 1, "cooldown": 10.0,
				"description": "持续期间，范围内双方非建筑、非近战虚空鱼单位（包括远程虚空鱼）真正死亡时，在死亡位置额外召出一只己方虚空鱼。"}],
		},
		"visual": {"color": Color(0.55, 0.18, 0.8),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/void_summoning/player.gd", "variant": "zone"}]},
			"active_skills": [{"icon_path": "res://assets/skills/void_summoning_0.png"}]},
		"card_art": {"path": "res://assets/cards/void_summoning_loading.png"},
		"audio": {"events": {"spell:zone_sustain": {"pool": ["res://assets/audio/spells/void_summoning/cast_sequence_1.wav", "res://assets/audio/spells/void_summoning/cast_sequence_2.wav", "res://assets/audio/spells/void_summoning/cast_sequence_3.wav"], "volume_db": 0.0, "bus": "Combat", "natural_tail": true}}},
	}
