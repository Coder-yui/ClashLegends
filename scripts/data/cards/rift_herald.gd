extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "峡谷先锋", "cost": 8, "type": "unit",
			"description": "极大体型推进坦克，只攻击建筑。一生一次冲撞：接近建筑且直线路径无河水阻挡后准备，冲撞挤开沿途地面敌军并造成伤害；撞击建筑后扣除自身当前生命30%，爆发6只虚空蠕虫。桥面允许冲撞，水域不可穿越。",
			"hp": 1800, "damage": 120, "range": 40.0,
			"speed": SPEED_EXTREMELY_SLOW, "interval": 2.00, "first_hit": 0.50,
			"size_tier": SIZE_EXTREMELY_LARGE, "radius": RADIUS_EXTREMELY_LARGE,
			"mass": 12.0, "sight": 260.0, "deploy_time": 3.0,
			"is_air": false, "building_only": true, "can_attack_air": false,
			"rush_distance": 200.0, "rush_prepare_time": 2.5, "rush_speed": 400.0,
			"rush_path_damage": 100, "rush_building_damage": 500, "rush_push_distance": 48.0,
			"rush_self_health_ratio": 0.3, "rush_recovery_time": 0.65,
			"rush_spawn_id": "voidmite", "rush_spawn_count": 6, "rush_spawn_spread": 48.0,
			"active_skills": [{
				"name": "旋转重拳", "kind": "frontal", "shape": "fan",
				"description": "对前方半圆内的地面敌军和建筑造成210点伤害。准备、冲撞及撞后收势期间不可施放。",
				"cost": 1, "max_uses": 2, "cooldown": 6.0,
				"length": 100.0, "arc_degrees": 180.0, "projectile_count": 0,
				"damage": 210, "ground_only": true,
				"impact_delay": 1.57, "cast_duration": 3.00,
				"cast_locks": ["movement", "attack", "facing"],
			}],
		},
		"visual": {
			"visual_radius": RADIUS_EXTREMELY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/rift_herald/rift_herald_view.tscn",
			"visual_forward_yaw": 0.0,
			"color": Color(0.55, 0.22, 0.8),
			"visual_animations": {
  "deploy": "Spawn",
  "idle": "Idle_Base",
  "move": "Run",
  "attack": [
    "Attack1",
    "Attack2"
  ],
  "death": "Death",
  "death_duration": 1.0,
  "clip_blends": {
    "Run>Run": 0.0,
    "Spawn>Spawn": 0.0,
    "Attack1>Attack1": 0.0,
    "Attack3>Attack3": 0.0,
    "Attack2>Attack2": 0.0,
    "Dance>Dance": 0.0,
    "Dash_Hit>Dash_Hit": 0.01,
    "Dash_Hit>Dash_Windup": 0.01,
    "Dash_Windup>Dash_Hit": 0.01,
    "Dash_Windup>Dash_Windup": 0.01,
    "Idle_Base>Idle_Base": 0.0
  },
  "visual_actions": {
    "rush_prepare": {
      "animation": "Dash_Windup",
      "clip_ranges": [[0.0, 2.5]],
      "kind": "skill",
      "durations": [
        2.5
      ]
    },
    "rush_dash": {
      "animation": "Dash",
      "clip_ranges": [[2.5, 3.433333]],
      "kind": "skill"
    },
    "rush_hit": {
      "animation": "Dash_Hit",
      "kind": "skill",
      "durations": [
        0.65
      ]
    },
    "spinning_punch": {
      "animation": "SRU_RiftHerald_spinningpunch_anm",
      "kind": "skill",
      "durations": [
        3.0
      ]
    }
  }
},
			"active_skills": [{"visual_action": "spinning_punch"}],
		},
		"card_art": {},
		"audio": {
  "attack_swing": [
    [
      "res://assets/audio/units/rift_herald/attack_swing_1_1.wav"
    ],
    [
      "res://assets/audio/units/rift_herald/attack_swing_2_1.wav"
    ]
  ],
  "attack_hit_by_segment": [
    [
      "res://assets/audio/units/rift_herald/attack_hit_1_1.wav",
      "res://assets/audio/units/rift_herald/attack_hit_1_2.wav"
    ],
    [
      "res://assets/audio/units/rift_herald/attack_hit_2_1.wav",
      "res://assets/audio/units/rift_herald/attack_hit_2_2.wav"
    ]
  ],
  "attack_swing_volume_db": 0.0,
  "attack_hit_volume_db": 0.0,
  "events": {
    "deploy:start": {
      "pool": [
        "res://assets/audio/units/rift_herald/deploy_start_1.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "rush:start": {
      "pool": [
        "res://assets/audio/units/rift_herald/rush_start_1.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "rush:hit": {
      "pool": [
        "res://assets/audio/units/rift_herald/rush_hit_1.wav",
        "res://assets/audio/units/rift_herald/rush_hit_2.wav",
        "res://assets/audio/units/rift_herald/rush_hit_3.wav",
        "res://assets/audio/units/rift_herald/rush_hit_4.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "rush:path_hit": {
      "pool": [
        "res://assets/audio/units/rift_herald/rush_path_hit_1.wav",
        "res://assets/audio/units/rift_herald/rush_path_hit_2.wav",
        "res://assets/audio/units/rift_herald/rush_path_hit_3.wav",
        "res://assets/audio/units/rift_herald/rush_path_hit_4.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "spinning_punch:start": {
      "action_time": 0.31,
      "pool": [
        "res://assets/audio/units/rift_herald/spinning_punch_start_1.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "spinning_punch:release": {
      "action_time": 0.87,
      "pool": ["res://assets/audio/units/rift_herald/spinning_punch_release_1.wav"],
      "volume_db": 0.0, "bus": "Combat"
    },
    "spinning_punch:hit": {
      "pool": [
        "res://assets/audio/units/rift_herald/spinning_punch_hit_1.wav",
        "res://assets/audio/units/rift_herald/spinning_punch_hit_2.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "death": {
      "pool": [
        "res://assets/audio/units/rift_herald/death_1.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "rush_prepare:sustain": {
      "pool": [
        "res://assets/audio/units/rift_herald/rush_prepare_1.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    }
  }
},
	}
