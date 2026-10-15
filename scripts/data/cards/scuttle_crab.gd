extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "峡谷迅捷蟹", "cost": 2, "type": "unit",
			"description": "只追逐建筑的耐久支援单位，不造成攻击伤害。到达建筑前跳舞，每秒回复30生命；死亡留下半径110的治疗区域，持续6秒，每秒为友方普通单位回复25生命。",
			"hp": 550, "damage": 0, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.0,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 4.0, "sight": 200.0,
			"can_attack": false, "is_air": false, "building_only": true, "can_attack_air": false,
			"structure_mend_per_second": 30.0,
			"death_transition_delay": 1.0, "death_shrine_delay": 2.0, "death_heal_delay": 4.8, "death_heal_radius": 110.0, "death_heal_duration": 6.0, "death_heal_per_second": 25.0,
			"active_skills": [{"name": "谦卑", "kind": "nova", "cost": 1, "max_uses": 2, "cooldown": 8.0,
				"radius": 130.0, "damage": 0, "slow_duration": 3.0, "slow_multiplier": 0.6, "attack_slow_multiplier": 0.7,
				"ground_only": false, "cast_duration": 0.0, "cast_locks": [],
				"description": "周围130像素内敌方单位移动速度降低40%、攻击速度降低30%，持续3秒。"}],
		},
		"visual": {
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/scuttle_crab/normal_ward_antenna_wake/player.gd", "variant": "default"},
				{"provider": "res://assets/effects/scuttle_crab/shrine_green/player.gd", "variant": "default"},
				{"provider": "res://assets/effects/scuttle_crab/shrine_red/player.gd", "variant": "default"}]},
			"active_skills": [{"icon_path": "res://assets/skills/scuttle_crab_randuin.png", "impact_visual_shape": "randuin", "impact_visual_duration": 3.0,
				"resource_dependencies": {"effects": [{"provider": "res://assets/effects/scuttle_crab/randuin/player.gd", "variant": "default"}]}}],
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/scuttle_crab/scuttle_crab_view.tscn",
			"visual_forward_yaw": 0.0, "color": Color(0.35, 0.75, 0.65),
			"visual_animations": {"deploy": "Crab_Spawn", "idle": "Idle1", "move": "Run", "attack_loop": "Crab_Dance", "death_followup_scene_path": "res://assets/units/scuttle_crab/burrow_view.tscn", "death_followup_animation": "scuttle_shrine_sequence", "death_followup_immediate": true},
		},
		"card_art": {}, "audio": {
  "events": {
"shrine:leap": {"pool": ["res://assets/audio/units/scuttle_crab/death_leap_1.wav"], "volume_db": 0.0, "bus": "Combat"},
"shrine:start": {"pool": ["res://assets/audio/units/scuttle_crab/ward0.wav"], "volume_db": 0.0, "bus": "Combat"},
    "deploy:start": {
      "pool": [
        "res://assets/audio/units/scuttle_crab/play_sfx_sru_crab_spawn_cast.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "death": {
      "pool": [
        "res://assets/audio/units/scuttle_crab/play_sfx_sru_crab_death_cast.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "mend:sustain": {
      "pool": [
        "res://assets/audio/units/scuttle_crab/play_sfx_sru_crab_sru_dance_r1.wav",
        "res://assets/audio/units/scuttle_crab/play_sfx_sru_crab_sru_dance_r2.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    },
    "active:cast": {
      "pool": [
        "res://assets/audio/units/scuttle_crab/play_sfx_randuinsomen_oncast.wav"
      ],
      "volume_db": 0.0,
      "bus": "Combat"
    }
  }
},
	}
