extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "蛮族之王", "cost": 7, "type": "unit",
			"description": "极高质量地面近战战士。战斗狂怒：普通攻击出手增加1点怒气，最多2点；满怒下一击造成双倍伤害并消耗怒气，暴击不产怒。",
			"hp": 1800, "damage": 180, "range": 64.0,
			"speed": SPEED_SLIGHTLY_SLOW, "interval": 1.7, "first_hit": 0.8, "attack_recovery_cancel_every_hits": 1, "attack_recovery_cancel_window": 0.23,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 9.0, "sight": 220.0, "is_air": false, "building_only": false, "can_attack_air": false,
			"skill_resource_max": 2.0, "rage_crit_multiplier": 2.0,
			"active_skills": [{"name": "无尽怒火", "kind": "undying_rage", "cost": 3, "max_uses": 1, "cooldown": 15.0, "duration": 4.0,
				"description": "立即满怒，4秒内生命最低为1，暴击不消耗怒气。除凝滞外可在控制期间释放；不解除控制，不恢复生命。"}],
		},
		"visual": {
			"color": Color(0.85, 0.22, 0.12), "skill_resource_full_color": Color(1.0, 0.16, 0.05),
			"visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_active_buff_scene": "res://assets/effects/tryndamere/undying_rage.tscn",
			"visual_scene_path": "res://assets/units/tryndamere/tryndamere_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "DeployIdle", "idle": "Idle1", "move": "Run", "attack": ["HeldAttack1", "HeldAttack2", "HeldCrit"], "death": "Death", "death_duration": 1.0},
			"active_skills": [{"resource_dependencies": {
				"effects": [
					{
						"provider": "res://assets/effects/tryndamere/undying_rage.gd",
						"variant": "default"
					}
				],
				"fields": [
					"visual_active_buff_scene"
				]
			}, "icon_path": "res://assets/skills/tryndamere_0.png"}],
		},
		"card_art": {"path": "res://assets/cards/tryndamere_loading.png"},
		"audio": {
  "attack_swing_lead_time": 0.4,
  "attack_swing": [
    [
      "res://assets/audio/units/tryndamere/attack1_1.wav",
      "res://assets/audio/units/tryndamere/attack1_2.wav",
      "res://assets/audio/units/tryndamere/attack1_3.wav",
      "res://assets/audio/units/tryndamere/attack1_4.wav"
    ],
    [
      "res://assets/audio/units/tryndamere/attack2_1.wav",
      "res://assets/audio/units/tryndamere/attack2_2.wav",
      "res://assets/audio/units/tryndamere/attack2_3.wav",
      "res://assets/audio/units/tryndamere/attack2_4.wav"
    ],
    [
      "res://assets/audio/units/tryndamere/crit_1.wav",
      "res://assets/audio/units/tryndamere/crit_2.wav",
      "res://assets/audio/units/tryndamere/crit_3.wav",
      "res://assets/audio/units/tryndamere/crit_4.wav"
    ]
  ],
  "attack_hit_by_segment": [
    [
      "res://assets/audio/units/tryndamere/hit1_1.wav",
      "res://assets/audio/units/tryndamere/hit1_2.wav",
      "res://assets/audio/units/tryndamere/hit1_3.wav",
      "res://assets/audio/units/tryndamere/hit1_4.wav"
    ],
    [
      "res://assets/audio/units/tryndamere/hit2_1.wav",
      "res://assets/audio/units/tryndamere/hit2_2.wav",
      "res://assets/audio/units/tryndamere/hit2_3.wav",
      "res://assets/audio/units/tryndamere/hit2_4.wav"
    ],
    [
      "res://assets/audio/units/tryndamere/crit_hit_1.wav",
      "res://assets/audio/units/tryndamere/crit_hit_2.wav",
      "res://assets/audio/units/tryndamere/crit_hit_3.wav",
      "res://assets/audio/units/tryndamere/crit_hit_4.wav"
    ]
  ],
  "events": {
"deploy:voice": {"clip_volume_db": {"res://assets/audio/units/tryndamere/deploy_1.ogg": -18.5}, "pool": ["res://assets/audio/units/tryndamere/deploy_1.ogg", "res://assets/audio/units/tryndamere/deploy_2.wav", "res://assets/audio/units/tryndamere/deploy_3.wav"], "bus": "Voice"},
    "active_buff:start": {
      "pool": [
        "res://assets/audio/units/tryndamere/ultimate_cast_1.wav"
      ]
    },
    "active_buff:sustain": {
      "pool": [
        "res://assets/audio/units/tryndamere/ultimate_sustain_1.wav"
      ]
    },
    "active_buff:end": {
      "pool": [
        "res://assets/audio/units/tryndamere/ultimate_end_1.wav"
      ]
    },
    "death": {
      "pool": [
        "res://assets/audio/units/tryndamere/death_1.wav",
        "res://assets/audio/units/tryndamere/death_2.wav",
        "res://assets/audio/units/tryndamere/death_3.wav"
      ],
      "bus": "Voice"
    }
  }
},
	}
