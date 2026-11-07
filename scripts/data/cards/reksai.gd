extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "虚空遁地兽", "cost": 3, "type": "unit",
			"description": "雷克塞，可在全图合法地面部署。破土而出：从己方水晶沿地下曲线以固定速度前进，距离越远等待越久，抵达后对周围2格内地面敌人造成80伤害并小幅击退；地下阶段不生成可受击单位。",
			"hp": 900, "damage": 60, "range": 40.0, "speed": SPEED_MEDIUM,
			"interval": 1.2, "first_hit": 0.2, "empowered_first_hit": 0.18,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 6.0, "sight": 220.0,
			"deploy_zone": "global", "pre_deploy_time": 0.05, "pre_deploy_burrow_speed": 320.0, "deploy_time": 0.75,
			"deploy_sweep_name": "破土而出", "deploy_sweep_radius": 80.0,
			"deploy_sweep_damage": 80, "deploy_sweep_knockback": 20.0,
			"deploy_sweep_duration": 0.2, "deploy_sweep_mass_factor_max": 1.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{
				"name": "女王之怒", "kind": "empowered_attack", "cost": 1, "max_uses": 2, "cooldown": 10.0,
				"description": "接下来3次攻击造成90点、半径1.5格的地面范围伤害。再次释放刷新为3次；死亡清除剩余次数。",
				"empowered_damage_multiplier": 1.5, "attack_count": 3, "radius": 60.0,
				"cast_duration": 0.0, "impact_delay": 0.0, "cast_locks": [],
			}],
		},
		"visual": {
			"visual_scene_path": "res://assets/units/reksai/reksai_view.tscn",
			"visual_pre_deploy_scene": "res://assets/units/reksai/arrival.tscn",
			"visual_active_buff_scene": "res://assets/units/reksai/empowered.tscn",
			"visual_forward_yaw": 0.0, "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"color": Color(0.49, 0.22, 0.62),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/reksai/player.gd", "variant": "travel"}, {"provider": "res://assets/effects/reksai/player.gd", "variant": "emerge"}, {"provider": "res://assets/effects/reksai/player.gd", "variant": "emerge_cast"}]},
			"visual_animations": {
				"idle": "Idle1_Base", "move": "Run1", "deploy": "Spell2_Knockup",
				"attack": ["Attack1", "Attack2"], "empowered_attack": ["Spell1", "Spell1B", "Spell1"],
				"death": "Death", "death_duration": 0.8,
			},
			"active_skills": [{"icon_path": "res://assets/skills/reksai_q.png", "resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/reksai/player.gd", "variant": "buff"}, {"provider": "res://assets/effects/reksai/player.gd", "variant": "swipe"}, {"provider": "res://assets/effects/reksai/player.gd", "variant": "swipe_second"}]}}],
		},
		# BEGIN IMPORTED AUDIO reksai
		"audio": {
			"events": {
				"empowered_buff:start": {"pool": ["res://assets/audio/units/reksai/play_sfx_reksai_reksaiq_onbuffactivate_r1.wav", "res://assets/audio/units/reksai/play_sfx_reksai_reksaiq_onbuffactivate_r2.wav", "res://assets/audio/units/reksai/play_sfx_reksai_reksaiq_onbuffactivate_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"empowered_buff:end": {"pool": ["res://assets/audio/units/reksai/play_sfx_reksai_reksaiq_onbuffdeactivate.wav"], "volume_db": 0.0, "bus": "Combat"},
				"pre_deploy:sustain": {"pool": ["res://assets/audio/units/reksai/w_movement_trail.wav"], "volume_db": 12.0, "bus": "Combat"},
				"active:cast": {
					"pool": [
						"res://assets/audio/units/reksai/play_sfx_reksai_reksaiq_oncast_r1.wav",
						"res://assets/audio/units/reksai/play_sfx_reksai_reksaiq_oncast_r2.wav",
						"res://assets/audio/units/reksai/play_sfx_reksai_reksaiq_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"deploy:hit": {
					"pool": [
						"res://assets/audio/units/reksai/play_sfx_reksai_reksaiw_hit_r1.wav",
						"res://assets/audio/units/reksai/play_sfx_reksai_reksaiw_hit_r2.wav",
						"res://assets/audio/units/reksai/play_sfx_reksai_reksaiw_hit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/reksai/play_sfx_reksai_reksaiw_buffdeactivate_r1.wav",
						"res://assets/audio/units/reksai/play_sfx_reksai_reksaiw_buffdeactivate_r2.wav",
						"res://assets/audio/units/reksai/play_sfx_reksai_reksaiw_buffdeactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death:voice": {
					"pool": [
						"res://assets/audio/units/reksai/play_vo_reksai_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/reksai/play_vo_reksai_death3d_r2_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/reksai/play_sfx_reksai_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"deploy:voice": {
					"pool": [
						"res://assets/audio/units/reksai/play_vo_reksai_move2dstandard_reksai_vo_2480312883_r10_zh_cn.wav",
						"res://assets/audio/units/reksai/play_vo_reksai_move2dstandard_reksai_vo_2480312883_r11_zh_cn.wav",
						"res://assets/audio/units/reksai/play_vo_reksai_move2dstandard_reksai_vo_2480312883_r12_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack2_oncast_r1.wav",
					"res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack2_oncast_r2.wav",
					"res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack2_oncast_r1.wav",
					"res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack2_oncast_r2.wav",
					"res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit": [
				"res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r2_d.wav",
				"res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r3_d.wav"
			],
			"attack_hit_volume_db": 0.0,
			"empowered_swing_by_segment": [
    [
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaiqattack_oncast_r1.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaiqattack_oncast_r2.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaiqattack_oncast_r3.wav"
    ],
    [
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaiqattack2_oncast_r1.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaiqattack2_oncast_r2.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaiqattack2_oncast_r3.wav"
    ],
    [
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaiqattack3_oncast_r1.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaiqattack3_oncast_r2.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaiqattack3_oncast_r3.wav"
    ]
],
			"empowered_hit_by_segment": [
    [
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r1_d.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r2_d.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r3_d.wav"
    ],
    [
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r1_d.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r2_d.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r3_d.wav"
    ],
    [
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r1_d.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r2_d.wav",
        "res://assets/audio/units/reksai/play_sfx_reksai_reksaibasicattack_onhit_1559186049_1153642577_r3_d.wav"
    ]
]
		},
		# END IMPORTED AUDIO reksai
		"card_art": {"path": "res://assets/cards/reksai_loading.png"},
	}
