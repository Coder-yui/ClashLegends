extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "虚空女皇", "cost": 7, "type": "unit",
			"description": "大型空中推进单位，只攻击建筑；死亡后向周围分散生成8只可对地对空的虚空鱼。",
			"hp": 1500, "damage": 90, "range": MELEE_RANGE_MIN,
			"speed": SPEED_SLOW, "interval": 1.5, "first_hit": 0.15,
			"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE, "mass": 10.0, "sight": 240.0,
			"is_air": true, "building_only": true, "can_attack_air": false,
			"death_spawn_id": "voidfish", "death_spawn_count": 8, "death_spawn_spread": 100.0, "death_spawn_duration": 0.45,
			"active_skills": [{
				"name": "虚空突袭", "kind": "dash_strike", "cost": 1, "max_uses": 2, "cooldown": 6.0,
				"damage": 100, "length": 3.0 * ArenaRules.TILE_SIZE, "width": 48.0,
				"dash_duration": 0.4, "dash_reference_speed": SPEED_SLOW, "dash_spin": false, "air_only": true,
				"cast_duration": 0.6, "impact_delay": 0.0, "cast_locks": ["movement", "attack", "facing"],
				"description": "沿当前朝向突进3格，对路径上每名敌方空中单位造成100伤害一次；不伤害地面单位与建筑。",
			}],
		},
		"visual": {
			"color": Color(0.6, 0.27, 0.85), "visual_radius": RADIUS_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/belveth/belveth_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn_Ult_anm", "idle": "Idle_Ult_anm", "move": "Run_Ult_anm",
				"attack": ["AttackSwipe1_anm", "AttackSwipe2_anm"], "death": "Death", "death_duration": 1.0,
				"visual_actions": {"active": {"animation": ["Spell1_ult_in_anm", "Spell1_ult_out_anm", "Spell1_ult_toidle_anm"], "durations": [0.1666667, 0.2333333, 0.2], "kind": "skill"}},
			},
			"active_skills": [{"visual_action": "active", "icon_path": "res://assets/skills/belveth_q.png"}],
		},
		"card_art": {"path": "res://assets/cards/belveth_loading.png"}, "audio": {
  "attack_swing": [
    [
      "res://assets/audio/units/belveth/swing_1.wav",
      "res://assets/audio/units/belveth/swing_2.wav",
      "res://assets/audio/units/belveth/swing_3.wav"
    ],
    [
      "res://assets/audio/units/belveth/swing_1.wav",
      "res://assets/audio/units/belveth/swing_2.wav",
      "res://assets/audio/units/belveth/swing_3.wav"
    ]
  ],
  "attack_hit": [
    "res://assets/audio/units/belveth/hit_1.wav",
    "res://assets/audio/units/belveth/hit_2.wav",
    "res://assets/audio/units/belveth/hit_3.wav"
  ],
  "attack_swing_volume_db": -7.0,
  "attack_hit_volume_db": -7.0,
  "events": {
    "deploy:start": {
      "pool": [
        "res://assets/audio/units/belveth/deploy_1.wav"
      ],
      "volume_db": -5.0,
      "bus": "Combat"
    },
    "death": {
      "pool": [
        "res://assets/audio/units/belveth/death_1.wav"
      ],
      "volume_db": -5.0,
      "bus": "Combat"
    },
    "active:cast": {
      "pool": [
        "res://assets/audio/units/belveth/cast_1.wav"
      ],
      "volume_db": -4.0,
      "bus": "Combat"
    },
    "active:hit": {
      "pool": [
        "res://assets/audio/units/belveth/skill_hit_1.wav"
      ],
      "volume_db": -5.0,
      "bus": "Combat"
    }
  }
},
	}
