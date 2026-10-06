extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "金克丝", "cost": 5, "type": "unit",
			"description": "暴走萝莉：默认火箭炮，对地对空范围伤害。参与摧毁建筑后触发罪恶快感，获得6秒罪恶快感：每层提升30%攻速，再次触发叠层并刷新6秒，移速加成不叠加、重新从100%衰减。",
			"hp": 440, "damage": 100, "range": 220.0,
			"transform_duration": 0.37,
			"speed": SPEED_MEDIUM, "interval": 1.5, "first_hit": 0.22,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 3.0, "sight": 280.0,
			"projectile_speed": 500.0, "projectile_spawn_at_edge": true,
			"projectile_spawn_offset": 7.5, "projectile_collision_radius": 4.0, "splash_radius": 45.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"structure_assist_window": 3.0, "structure_haste_duration": 6.0,
			"structure_haste_attack_speed": 1.3, "structure_haste_speed_bonus": 1.0,
			"transformed_stats": {
				"name": "金克丝·轻机枪", "type": "unit", "hp": 440, "damage": 100, "range": 170.0,
				"speed": SPEED_MEDIUM, "interval": 1.0, "first_hit": 0.18,
				"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 3.0, "sight": 280.0,
				"projectile_speed": 650.0, "projectile_spawn_at_edge": true,
				"projectile_spawn_offset": 7.5, "projectile_collision_radius": 3.0, "splash_radius": 0.0,
				"is_air": false, "building_only": false, "can_attack_air": true,
				"hit_haste_max_stacks": 3, "hit_haste_per_stack": 0.15, "hit_haste_duration": 3.0,
			},
			"active_skills": [{
				"name": "枪炮交响曲！", "kind": "toggle_form", "cost": 0, "max_uses": 5, "cooldown": 4.0,
				"description": "立即切换武器属性，重置旧普攻后摇；切枪0.37秒期间不能攻击，硬控交互与变形一致。机枪射程170、间隔1秒，无溅射；每次命中加15%攻速，最多3层，刷新持续3秒。换武器清空机枪层数。",
			}],
		},
		"visual": {
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_active_buff_scene": "res://assets/units/jinx/haste_view.tscn",
			"visual_scene_path": "res://assets/units/jinx/jinx_view.tscn", "visual_forward_yaw": 0.0,
			"projectile_visual": "jinx_rocket", "projectile_impact_visual": "jinx_explosion", "projectile_visual_height": 44.0,
			"color": Color(0.9, 0.3, 0.65),
			"visual_animations": {
				"move_enter": "Jinx_Rlauncher_run_in_anm",
                "transitions": {"locomotion>idle": "Rlauncher_Idlein1", "attack>idle": "Rlauncher_Idlein1"},
                "visual_actions": {"transform": {"animation": "minigun_spell1_weapon2_anm", "kind": "transform", "blend_in": 0.04, "blend_out": 0.04}},
                "deploy": "Respawn", "idle": "Jinx_Rlauncher_idle1_anm", "move": "Jinx_Rlauncher_run_anm",
				"attack": ["Jinx_Rlauncher_attack1_anm", "Jinx_Rlauncher_attack2_anm"], "death": "Jinx_Rlauncher_death_anm", "death_duration": 0.8,
			},
			"transformed_stats": {
				"visual_active_buff_scene": "res://assets/units/jinx/haste_view.tscn",
			"visual_scene_path": "res://assets/units/jinx/jinx_view.tscn", "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
				"projectile_visual": "jinx_bullet", "projectile_impact_visual": "", "projectile_visual_height": 44.0,
				"visual_animations": {
					"move_enter": "Jinx_minigun_run_in_anm",
                    "transitions": {"locomotion>idle": "IdleIn1", "attack>idle": "IdleIn1"},
                    "visual_actions": {"transform": {"animation": "launcher_spell1_weapon2_anm", "kind": "transform", "blend_in": 0.04, "blend_out": 0.04}},
                    "deploy": "Respawn", "idle": "Idle1_Base", "move": "Run_Base",
					"attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.8,
				},
			},
			"active_skills": [{"icon_path": "res://assets/skills/jinx_0.png"}],
		},
		"card_art": {"path": "res://assets/cards/jinx_loading.png"}, "audio": {
  "events": {
    "attack_launch": {
      "pool": [
        "res://assets/audio/units/jinx/rocket_launch0.wav",
        "res://assets/audio/units/jinx/rocket_launch1.wav",
        "res://assets/audio/units/jinx/rocket_launch2.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "transform:start": {
      "pool": [
        "res://assets/audio/units/jinx/to_rocket0.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "structure_haste:start": {
      "pool": [
        "res://assets/audio/units/jinx/passive0.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "death": {
      "pool": [
        "res://assets/audio/units/jinx/death0.wav",
        "res://assets/audio/units/jinx/death1.wav",
        "res://assets/audio/units/jinx/death2.wav"
      ],
      "volume_db": 0.0,
      "bus": "Voice"
    },
    "deploy:start": {"pool": ["res://assets/audio/units/jinx/respawn.wav"], "volume_db": 0.0, "bus": "Combat"}
  },
  "attack_hit": [
    "res://assets/audio/units/jinx/rocket_hit0.wav",
    "res://assets/audio/units/jinx/rocket_hit1.wav",
    "res://assets/audio/units/jinx/rocket_hit2.wav"
  ],
  "attack_hit_volume_db": 0.0,
  "transformed_stats": {
    "attack_hit": ["res://assets/audio/units/jinx/gun_hit0.wav", "res://assets/audio/units/jinx/gun_hit1.wav", "res://assets/audio/units/jinx/gun_hit2.wav"],
    "attack_hit_volume_db": 0.0,
    "events": {
      "attack_launch": {
        "pool": [
          "res://assets/audio/units/jinx/gun_launch0.wav",
          "res://assets/audio/units/jinx/gun_launch1.wav",
          "res://assets/audio/units/jinx/gun_launch2.wav"
        ],
        "volume_db": 0.0,
        "bus": "Combat"
      },
      "transform:start": {
        "pool": [
          "res://assets/audio/units/jinx/to_gun0.wav"
        ],
        "volume_db": 0.0,
        "bus": "Combat"
      },
      "structure_haste:start": {
        "pool": [
          "res://assets/audio/units/jinx/passive0.wav"
        ],
        "volume_db": 0.0,
        "bus": "Combat"
      },
      "death": {
        "pool": [
          "res://assets/audio/units/jinx/death0.wav",
          "res://assets/audio/units/jinx/death1.wav",
          "res://assets/audio/units/jinx/death2.wav"
        ],
        "volume_db": 0.0,
        "bus": "Voice"
      },
      "deploy:start": {"pool": ["res://assets/audio/units/jinx/respawn.wav"], "volume_db": 0.0, "bus": "Combat"}
    }
  }
},
	}
