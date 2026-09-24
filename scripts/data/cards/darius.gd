extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "德莱厄斯", "cost": 5, "type": "unit",
			"description": "高质量近战战士。普攻叠加3秒流血，每层每秒15伤害，最多4层，命中刷新全层时间。叠满获得4秒血怒：攻击伤害翻倍，命中直接施加4层并刷新血怒。",
			"hp": 1200, "damage": 110, "range": 35.0, "speed": SPEED_MEDIUM,
			"interval": 1.2, "first_hit": 0.30,
			"empowered_first_hit": 1.2 * 11.0 / 40.0,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 8.0, "sight": 220.0, "is_air": false, "building_only": false, "can_attack_air": false,
			"bleed_damage_per_second": 15.0, "bleed_duration": 3.0, "bleed_max_stacks": 4,
			"blood_rage_duration": 4.0, "blood_rage_damage_multiplier": 2.0,
			"active_skills": [{
				"name": "诺克萨斯断头台", "kind": "bleeding_execute", "cost": 2, "max_uses": 2, "cooldown": 16.0,
				"damage": 180, "execute_damage_per_stack": 0.25,
				"description": "下一击劈砍造成180伤害，按命中前每层流血增加25%，再施加1层流血；血怒使伤害翻倍并直接叠满。劈砍击杀获得或刷新血怒，并赠送一次免费追斩，不扣次数、不重启付费冷却。免费追斩优先保留，直至使用。",
			}],
		},
		"visual": {
			"color": Color(0.65, 0.12, 0.16), "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_active_buff_scene": "res://assets/effects/darius/blood_rage.tscn",
			"visual_scene_path": "res://assets/units/darius/darius_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Idle1", "idle": "Idle1", "move": "Run", "attack": ["Attack1", "Attack2"], "empowered_attack": "Spell4", "death": "Death", "death_duration": 1.0},
			"active_skills": [{"icon_path": "res://assets/skills/darius_r.png"}],
		},
		"card_art": {"path": "res://assets/cards/darius_loading.png"},
		"audio": {
  "attack_swing": [
    [
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack_oncast_r1_d.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack_oncast_r2_d.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack_oncast_r3_d.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack_oncast_r4_d.wav"
    ],
    [
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack2_oncast_r1.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack2_oncast_r2.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack2_oncast_r3.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack2_oncast_r4.wav"
    ]
  ],
  "attack_hit_by_segment": [
    [
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack_onhit_1559186049_1153642577_r1_d.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack_onhit_1559186049_1153642577_r2_d.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack_onhit_1559186049_1153642577_r3_d.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack_onhit_1559186049_1153642577_r4_d.wav"
    ],
    [
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack2_onhit_1559186049_1153642577_r1.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack2_onhit_1559186049_1153642577_r2.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack2_onhit_1559186049_1153642577_r3.wav",
      "res://assets/audio/units/darius/play_sfx_darius_dariusbasicattack2_onhit_1559186049_1153642577_r4.wav"
    ]
  ],
  "attack_swing_volume_db": -3.0,
  "attack_hit_volume_db": -5.0,
  "empowered_hit": [
    "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_onhit_r1.wav",
    "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_onhit_r2.wav",
    "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_onhit_r3.wav",
    "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_onhit_r4.wav"
  ],
  "events": {
    "deploy:voice": {
      "pool": [
        "res://assets/audio/units/darius/deploy_rise.wav",
        "res://assets/audio/units/darius/deploy_cowardice.wav",
        "res://assets/audio/units/darius/deploy_fight.wav"
      ],
      "volume_db": 0.0,
      "bus": "Voice"
    },
    "empowered_swing": {
      "pool": [
        "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_oncast_r1.wav",
        "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_oncast_r2.wav",
        "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_oncast_r3.wav",
        "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_oncast_r4.wav"
      ],
      "volume_db": -2.0,
      "bus": "Combat"
    },
    "blood_rage:sustain": {"pool": ["res://assets/audio/units/darius/play_sfx_darius_dariushemomax_loop.wav"], "volume_db": -9.0, "bus": "Combat"},
"blood_rage:start": {
      "pool": [
        "res://assets/audio/units/darius/play_sfx_darius_dariushemomax_onbuffactivate_r1.wav",
        "res://assets/audio/units/darius/play_sfx_darius_dariushemomax_onbuffactivate_r2.wav"
      ],
      "volume_db": -3.0,
      "bus": "Combat"
    },
    "execute:kill": {
      "pool": [
        "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_hit_kill_r1.wav",
        "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_hit_kill_r2.wav",
        "res://assets/audio/units/darius/play_sfx_darius_dariusexecute_hit_kill_r3.wav"
      ],
      "volume_db": -3.0,
      "bus": "Combat"
    },
    "death": {
      "pool": [
        "res://assets/audio/units/darius/play_sfx_darius_death3d_cast.wav"
      ],
      "volume_db": -3.0,
      "bus": "Combat"
    }
  }
},
	}
