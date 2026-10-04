extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "库奇", "cost": 4, "type": "unit",
			"description": "中体型空中远程后排，对地对空；携带三枚导弹，第三枚为超级导弹。",
			"hp": 360, "damage": 80, "range": 190.0,
			"speed": SPEED_MEDIUM, "interval": 1.2, "first_hit": 0.14,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 3.0, "sight": 260.0,
			"projectile_speed": 580.0, "projectile_spawn_at_edge": true,
			"projectile_spawn_offset": 7.5, "projectile_collision_radius": 4.0,
			"is_air": true, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "火箭轰击", "kind": "frontal", "shape": "fan",
				"cost": 1, "max_uses": 3, "cooldown": 3.0,
				"description": "向前发射一枚导弹，最多飞行300像素。碰到首个敌人即爆炸，对碰撞点55像素范围内地面和空中敌人造成100伤害；第三枚造成180伤害。飞到尽头未命中则消失。",
				"damage": 100, "damage_by_use": [100, 100, 180],
				"length": 300.0, "arc_degrees": 1.0, "projectile_count": 1,
				"projectile_stop_on_hit": true, "projectile_explosion_radius": 55.0,
				"ground_only": false, "impact_delay": 0.13, "cast_duration": 0.5,
				"projectile_launch_delay": 0.13, "projectile_flight_duration": 0.6,
				"cast_locks": ["movement", "attack", "facing"],
			}],
		},
		"visual": {
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/corki/corki_view.tscn", "visual_forward_yaw": 0.0,
			"projectile_visual": "corki_bullet", "projectile_visual_height": 60.0,
			"color": Color(1.0, 0.65, 0.18),
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.8,
				"visual_actions": {
					"active": {"animation": "Spell4", "kind": "skill", "durations": [0.5]},
					"active_big": {"animation": "Spell4", "kind": "skill", "durations": [0.5]},
				},
			},
			"active_skills": [{
				"icon_path": "res://assets/skills/corki_0.png", "visual_action": "active",
				"projectile_impact_visuals_by_use": ["corki_explosion", "corki_explosion", "corki_explosion_big"],
				"projectile_visuals_by_use": ["corki_missile", "corki_missile", "corki_missile_big"],
				"visual_actions_by_use": ["active", "active", "active_big"],
				"projectile_visual": "corki_missile", "projectile_impact_visual": "corki_explosion",
				"projectile_visual_height": 60.0, "projectile_visual_width": 12.0,
			}],
		},
		"card_art": {}, "audio": {
  "events": {
    "attack_launch": {
      "pool": [
        "res://assets/audio/units/corki/attack_launch0.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "active:start": {
      "pool": [
        "res://assets/audio/units/corki/active_start0.wav",
        "res://assets/audio/units/corki/active_start1.wav",
        "res://assets/audio/units/corki/active_start2.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "active:release": {
      "pool": [
        "res://assets/audio/units/corki/active_release0.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "active:hit": {
      "pool": [
        "res://assets/audio/units/corki/active_hit0.wav",
        "res://assets/audio/units/corki/active_hit1.wav",
        "res://assets/audio/units/corki/active_hit2.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "active_big:start": {
      "pool": [
        "res://assets/audio/units/corki/active_big_start0.wav",
        "res://assets/audio/units/corki/active_big_start1.wav",
        "res://assets/audio/units/corki/active_big_start2.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "active_big:release": {
      "pool": [
        "res://assets/audio/units/corki/active_big_release0.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "active_big:hit": {
      "pool": [
        "res://assets/audio/units/corki/active_big_hit0.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "deploy:voice": {"clip_volume_db": {"res://assets/audio/units/corki/deploy_ace.wav": -16.5},
      "pool": [
        "res://assets/audio/units/corki/deploy_ace.wav",
        "res://assets/audio/units/corki/deploy_ready.wav",
        "res://assets/audio/units/corki/deploy_burning.wav"
      ],
      "volume_db": 0.0,
      "bus": "Voice"
    },
    "death": {
      "pool": [
        "res://assets/audio/units/corki/death0.wav",
        "res://assets/audio/units/corki/death1.wav",
        "res://assets/audio/units/corki/death2.wav"
      ],
      "volume_db": 0.0,
      "bus": "Voice"
    }
  },
  "attack_swing_volume_db": 0.0,
  "attack_hit_volume_db": 0.0,
  "attack_swing": [["res://assets/audio/units/corki/attack_swing0.wav"], ["res://assets/audio/units/corki/attack_swing0.wav"]],
  "attack_hit": [
    "res://assets/audio/units/corki/attack_hit0.wav"
  ]
},
	}
