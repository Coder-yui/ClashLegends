extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "虚空蠕虫", "cost": 1, "type": "unit", "selectable": false,
			"description": "峡谷先锋撞击建筑时爆发的召唤物，体型小，135生命与55伤害，只攻击建筑。",
			"hp": 135, "damage": PRINCESS_TOWER_STATS.damage, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.33, "first_hit": 0.32,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"mass": 2.0, "sight": 180.0, "deploy_time": 1.0,
			"is_air": false, "building_only": true, "can_attack_air": false,
		},
		"visual": {
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/voidmite/voidmite_view.tscn",
			"visual_forward_yaw": 0.0,
			"color": Color(0.55, 0.22, 0.8),
			"visual_animations": {
  "deploy": "SRU_Horde_Mini_Hatch_anm",
  "idle": "Idle1",
  "move": "Ranged_Run",
  "attack": [
    "Ranged_Attack1"
  ],
  "death": "SRU_Horde_Mini_Death2_anm",
  "death_duration": 1.33,
  "clip_blends": {
    "Attack1a>Attack1a": 0.0,
    "Attack1a>Death1": 0.0,
    "Attack1a>Death2": 0.0,
    "Death1>Death1": 0.0,
    "Death1>Death2": 0.0,
    "Death2>Death1": 0.0,
    "Death2>Death2": 0.0,
    "Death3>Death1": 0.0,
    "Death3>Death2": 0.0,
    "Idle1>Death1": 0.0,
    "Idle1>Death2": 0.0,
    "Ranged_Attack1>Death1": 0.0,
    "Ranged_Attack1>Death2": 0.0,
    "Ranged_Run>Death1": 0.0,
    "Ranged_Run>Death2": 0.0,
    "Run1>Death1": 0.0,
    "Run1>Death2": 0.0,
    "Attack1B>Attack1B": 0.0,
    "Attack1a>Attack1B": 0.0,
    "Attack1B>Attack1a": 0.05,
    "Attack2B>Attack1a": 0.05,
    "Attack2a>Attack1a": 0.0,
    "Attack2a>Attack1B": 0.0,
    "Attack2B>Attack1B": 0.0,
    "Attack1a>Attack2a": 0.0,
    "Attack1B>Attack2a": 0.05,
    "Attack2a>Attack2a": 0.0,
    "Attack2B>Attack2a": 0.05,
    "Attack1a>Attack2B": 0.0,
    "Attack1B>Attack2B": 0.0,
    "Attack2a>Attack2B": 0.0,
    "Attack2B>Attack2B": 0.0,
    "Attack1a>Death3": 0.0,
    "Attack1B>Death1": 0.0,
    "Attack1B>Death2": 0.0,
    "Attack1B>Death3": 0.0,
    "Attack2a>Death1": 0.0,
    "Attack2a>Death2": 0.0,
    "Attack2a>Death3": 0.0,
    "Attack2B>Death1": 0.0,
    "Attack2B>Death2": 0.0,
    "Attack2B>Death3": 0.0,
    "Death1>Death3": 0.0,
    "Death2>Death3": 0.0,
    "Death3>Death3": 0.0,
    "Idle1>Death3": 0.0,
    "Ranged_Attack1>Death3": 0.0,
    "Ranged_Run>Death3": 0.0,
    "Run1>Death3": 0.0,
    "Run2>Death1": 0.0,
    "Run2>Death2": 0.0,
    "Run2>Death3": 0.0,
    "Run3>Death1": 0.0,
    "Run3>Death2": 0.0,
    "Run3>Death3": 0.0,
    "Run1>Run1": 0.0,
    "Run1>Run2": 0.05,
    "Run1>Run3": 0.0,
    "Run2>Run1": 0.05,
    "Run2>Run2": 0.0,
    "Run2>Run3": 0.05,
    "Run3>Run1": 0.0,
    "Run3>Run2": 0.05,
    "Run3>Run3": 0.0
  }
},
			
		},
		"card_art": {},
		"audio": {
  "attack_swing": [
    [
      "res://assets/audio/units/voidmite/attack_swing_1_1.wav",
      "res://assets/audio/units/voidmite/attack_swing_1_2.wav",
      "res://assets/audio/units/voidmite/attack_swing_1_3.wav",
      "res://assets/audio/units/voidmite/attack_swing_1_4.wav",
      "res://assets/audio/units/voidmite/attack_swing_1_5.wav"
    ]
  ],
  "attack_hit_by_segment": [
    [
      "res://assets/audio/units/voidmite/attack_hit_1_1.wav",
      "res://assets/audio/units/voidmite/attack_hit_1_2.wav",
      "res://assets/audio/units/voidmite/attack_hit_1_3.wav",
      "res://assets/audio/units/voidmite/attack_hit_1_4.wav"
    ]
  ],
  "attack_swing_volume_db": 0.0,
  "attack_hit_volume_db": 0.0,
  "events": {
    "deploy:start": {"pool": ["res://assets/audio/units/voidmite/deploy_start_1.wav", "res://assets/audio/units/voidmite/deploy_start_2.wav", "res://assets/audio/units/voidmite/deploy_start_3.wav"], "volume_db": 0.0, "bus": "Combat"},
    "death": {
      "pool": [
        "res://assets/audio/units/voidmite/death_1.wav",
        "res://assets/audio/units/voidmite/death_2.wav",
        "res://assets/audio/units/voidmite/death_3.wav",
        "res://assets/audio/units/voidmite/death_4.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    }
  }
},
	}
