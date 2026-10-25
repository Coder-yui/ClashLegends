extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "浪潮法术", "cost": 2, "type": "spell", "spell_kind": "tidal_wave",
			"deploy_zone": "own_side", "deploy_half_only": true, "deploy_ignore_structures": true,
			"radius": 80.0, "wave_width": 160.0, "range": 440.0, "speed": 320.0, "duration": 1.4, "spell_windup": 0.5,
			"damage": 120, "knockback": 40.0, "tower_damage_multiplier": 0.3, "active_cost_bonus": 0,
			"description": "仅在己方半场释放。4格宽的浪潮向敌方推进11格，对碰到的敌方地面目标造成120伤害并向前击退1格，每个目标仅命中一次。建筑不被击退，防御塔和水晶承受30%伤害。",
			"active_skills": [{"name": "踏浪而行", "kind": "spell_tidal_wave", "cost": 0, "max_uses": 1, "cooldown": 0.0,
				"duration": 2.0, "speed_multiplier": 1.3,
				"description": "浪潮经过己方地面单位时，给予2秒30%移速加成；每次浪潮对每个单位只生效一次，不作用于建筑。"}],
		},
		"visual": {"color": Color(0.1, 0.75, 0.9),
			"resource_dependencies": {"effects": [{"provider": "res://scripts/presentation/tidal_wave_3d.gd", "variant": "default"}]},
			"active_skills": [{"icon_path": "res://assets/skills/nami_passive.png"}]},
		"card_art": {"path": "res://assets/cards/tidal_wave_loading.png"},
		"audio": {"events": {"spell:cast": {"pool": ["res://assets/audio/spells/tidal_wave/cast_1.wav", "res://assets/audio/spells/tidal_wave/cast_2.wav", "res://assets/audio/spells/tidal_wave/cast_3.wav"], "volume_db": 0.0, "bus": "Combat"},"spell:hit": {"pool": ["res://assets/audio/spells/tidal_wave/hit_1.wav", "res://assets/audio/spells/tidal_wave/hit_2.wav", "res://assets/audio/spells/tidal_wave/hit_3.wav"], "volume_db": 0.0, "bus": "Combat"},"spell:launch": {"pool": ["res://assets/audio/spells/tidal_wave/wave_1.wav", "res://assets/audio/spells/tidal_wave/wave_2.wav"], "volume_db": 0.0, "bus": "Combat"}}},
	}
