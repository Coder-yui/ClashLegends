extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "凛冬之柱", "cost": 3, "type": "building", "deploy_zone": "global",
			"description": "可全图部署。周围2.75格敌方单位与建筑移速降低30%、攻速降低25%，同类减益取最强；离开范围或冰柱死亡后失效。不影响防御塔和水晶。",
			"hp": 600, "damage": 0, "range": 0.0, "speed": 0.0, "interval": 1.0,
			"radius": RADIUS_SLIGHTLY_LARGE, "size_tier": SIZE_SLIGHTLY_LARGE, "deploy_time": 1.0,
			"footprint_tiles": Vector2i(3, 3), "can_attack": false, "is_air": false,
			"is_building": true, "building_only": false, "can_attack_air": false,
			"lifespan": 20.0, "lifespan_hp_decay": true,
			"debuff_aura_radius": 110.0, "debuff_aura_active_radius": 200.0,
			"debuff_aura_move_multiplier": 0.7, "debuff_aura_attack_multiplier": 0.75,
			"active_skills": [{"name": "冰封领域", "kind": "buff", "cost": 1, "max_uses": 1,
				"cooldown": 10.0, "duration": 5.0, "impact_delay": 0.0, "cast_duration": 0.0, "cast_locks": [],
				"description": "将减速与减攻速光环扩大至5格，持续5秒。"}],
		},
		"visual": {
			"visual_scene_path": "res://assets/units/pillar_of_ice/pillar_view.tscn",
			"visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING, "visual_forward_yaw": 0.0,
			"color": Color(0.4, 0.8, 1.0), "visual_animations": {"deploy": "Rise", "idle": "Idle", "death": "Death", "death_duration": 0.8},
			"active_skills": [{"icon_path": "res://assets/skills/pillar_of_ice_w.png"}],
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/pillar_of_ice/player.gd", "variant": "pillar"}]},
		},
		"audio": {
  "events": {
    "deploy:start": {
      "pool": [
        "res://assets/audio/units/pillar_of_ice/e_rise.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat",
      "owner": "unit"
    },
    "idle:sustain": {
      "pool": [
        "res://assets/audio/units/pillar_of_ice/w_loop.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat",
      "fade_in": 0.1,
      "fade_out": 0.15
    },
    "death": {
      "pool": [
        "res://assets/audio/units/pillar_of_ice/e_fall.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "active_buff:start": {
      "pool": [
        "res://assets/audio/units/pillar_of_ice/w_cast.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat",
      "owner": "unit"
    }
  }
},
		"card_art": {"path": "res://assets/cards/pillar_of_ice.png"},
	}
