extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "虚空鱼", "cost": 1, "type": "unit", "selectable": false,
			"description": "虚空女皇死亡后生成的小型空中近战单位，可以攻击地面和空中目标。",
			"hp": 110, "damage": 26, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.25, "first_hit": 0.41,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL, "mass": 1.8, "sight": 210.0,
			"is_air": true, "building_only": false, "can_attack_air": true,
		},
		"visual": {
			"color": Color(0.6, 0.27, 0.85), "visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/voidfish/voidfish_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Idle1", "idle": "Idle1", "move": "Run", "attack": ["attack_1_anm"], "death": "Death", "death_duration": 0.6},
		},
		"card_art": {}, "audio": {
  "attack_swing": [
    [
      "res://assets/audio/units/voidfish/swing_1.wav"
    ]
  ],
  "attack_hit": [
    "res://assets/audio/units/voidfish/hit_1.wav"
  ],
  "attack_swing_volume_db": -7.0,
  "attack_hit_volume_db": -7.0,
  "events": {
    "deploy:start": {
      "pool": [
        "res://assets/audio/units/voidfish/deploy_1.wav"
      ],
      "volume_db": -23.0,
      "bus": "Combat"
    },
    "death": {
      "pool": [
        "res://assets/audio/units/voidfish/death_1.wav",
        "res://assets/audio/units/voidfish/death_2.wav"
      ],
      "volume_db": -5.0,
      "bus": "Combat"
    }
  }
},
	}
