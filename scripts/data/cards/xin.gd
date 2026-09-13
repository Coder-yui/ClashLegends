extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "赵信", "cost": 4, "type": "unit",
			"description": "近战战士，部署时发动新月护卫伤害并击退周围地面敌人，连续攻击还能恢复生命。",
			"hp": 620, "damage": 68, "range": 40.0,
			"speed": SPEED_SLIGHTLY_FAST, "interval": 0.9, "first_hit": 0.3,
			"deploy_time": 1.0,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 5.0, "sight": 220.0,
			# 部署时发动新月护卫：1 秒部署阶段只播放 Spell4，生成当帧立即伤害并击退四周地面敌人。
			# 期间不能移动和攻击，但可被索敌、碰撞和命中。
			# 建筑/防御塔会受伤但不会被击退；轻单位的质量倍率封顶 1.0，避免超过基础击退距离。
			"deploy_sweep_name": "新月护卫（部署）",
			"deploy_sweep_radius": 90.0,
			"deploy_sweep_damage": 90,
			"deploy_sweep_knockback": 90.0,
			"deploy_sweep_duration": 0.25,
			"deploy_sweep_mass_factor_max": 1.0,
			# 无畏战吼：三段普攻循环中的第三击（Passive_AA_01）命中时回复少许生命值。
			"heal_every_hits": 3, "heal_amount": 60,
			"color": Color(0.85, 0.30, 0.25),
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{
					"name": "新月护卫", "kind": "nova",
					"cost": 1, "max_uses": 2, "cooldown": 8.0,
					"description": "挥舞长枪震开周围敌人，造成范围伤害与击退；施放期间锁定移动、攻击和朝向。",
					"radius": 90.0, "damage": 90, "knockback": 90.0,
					"knockback_duration": 0.25, "knockback_mass_factor_max": 1.0,
					"ground_only": true,
					"impact_delay": 0.0, "cast_duration": 1.0,
					"cast_locks": ["movement", "attack", "facing"],
					"visual_action": "active",
				}],
		},
		"visual": { "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/xin/xin_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 部署与主动新月护卫都使用完整 1 秒 Spell4；动作本身不驱动权威效果。
				"deploy": "Spell4",
				"idle": "IdleBase", "move": "RunBase", "move_enter": "RunIn",
				# 原表分段候选与当前导出片段端点不一致，暂保留既有普攻配置，见卡牌文档。
				"attack": ["Attack1_Hit", "Attack3_Hit", "Passive_AA_01_XinZhaoRework_anm"],
				"attack_hit": [
					"Attack_AA_01_settle_XinZhaoRework_anm",
					"Attack_AA_03_settle_XinZhaoRework_anm",
					"Passive_AA_01_XinZhaoRework_anm",
				],
				"attack_hit_duration": 0.6,
				"attack_clip_ranges": [[], [], [0.0, 0.3]],
				"attack_hit_clip_ranges": [[], [], [0.3, 3.0]],
				"clip_blends": {
					"Passive_AA_01_XinZhaoRework_anm>Passive_AA_01_XinZhaoRework_anm": 0.0,
					"PassiveAA_to_Run_XinZhaoRework_anm>RunBase": 0.1,
				},
				# 第一、二段攻击复用通用 RunIn；第三段被动攻击使用素材专用转跑动作。
				"attack_to_move": ["", "", "PassiveAA_to_Run_XinZhaoRework_anm"],
				"visual_actions": {
					"active": {"animation": "Spell4", "durations": [1.0], "kind": "skill", "blend_in": 0.0},
				},
				"transitions": {
					"deploy>move": "Spell4_To_Run",
					"skill>move": "Spell4_To_Run",
				},
				"death": "Death", "death_duration": 0.8,
			},
		},
		# BEGIN IMPORTED AUDIO xin
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/xin/play_vo_xinzhao_xinzhaor_cast3d_r1_zh_cn.wav", "res://assets/audio/units/xin/play_vo_xinzhao_xinzhaor_cast3d_r2_zh_cn.wav", "res://assets/audio/units/xin/play_vo_xinzhao_xinzhaor_cast3d_r3_zh_cn.wav", "res://assets/audio/units/xin/play_vo_xinzhao_xinzhaor_cast3d_r4_zh_cn.wav"], "volume_db": 0.0, "bus": "Voice"},
				"active:voice": {"pool": ["res://assets/audio/units/xin/play_vo_xinzhao_xinzhaor_cast3d_r1_zh_cn.wav", "res://assets/audio/units/xin/play_vo_xinzhao_xinzhaor_cast3d_r2_zh_cn.wav", "res://assets/audio/units/xin/play_vo_xinzhao_xinzhaor_cast3d_r3_zh_cn.wav", "res://assets/audio/units/xin/play_vo_xinzhao_xinzhaor_cast3d_r4_zh_cn.wav"], "volume_db": 0.0, "bus": "Voice"},
				"deploy:hit": {"pool": ["res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaor_hitlocation_knockback_r1.wav", "res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaor_hitlocation_knockback_r2.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active:hit": {"pool": ["res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaor_hitlocation_knockback_r1.wav", "res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaor_hitlocation_knockback_r2.wav"], "volume_db": 0.0, "bus": "Combat"},
				"deploy:start": {"pool": ["res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaor_oncast_sweep.wav"], "volume_db": 0.0, "bus": "Combat"},
				"passive_heal": {"pool": ["res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaopassive_heal_buffactivate_r1.wav", "res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaopassive_heal_buffactivate_r2.wav", "res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaopassive_heal_buffactivate_r3.wav"], "volume_db": 0.0, "bus": "Combat"},

				"active:start": {
					"pool": [
						"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaor_oncast_sweep.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/xin/play_vo_xinzhao_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/xin/play_vo_xinzhao_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/xin/play_vo_xinzhao_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack2_oncast_r1.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack2_oncast_r2.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaopassivecritattack_oncast_r1.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaopassivecritattack_oncast_r2.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaopassivecritattack_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack_onhit_1559186049_1153642577_r2_d.wav",
				"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack_onhit_1559186049_1153642577_r3_d.wav"
			],
			"attack_hit_volume_db": -5.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack_onhit_1559186049_1153642577_r3_d.wav"
				],
				[
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaobasicattack2_onhit_1559186049_1153642577_r3.wav"
				],
				[
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaopassivecritattack_onhit_r1.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaopassivecritattack_onhit_r2.wav",
					"res://assets/audio/units/xin/play_sfx_xinzhao_xinzhaopassivecritattack_onhit_r3.wav"
				]
			]
		},
		# END IMPORTED AUDIO xin
		"card_art": {}, # 默认 assets/cards/<card_id>_loading.*
	}
