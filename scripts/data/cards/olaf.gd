extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "狂战士", "cost": 6, "type": "unit",
			"description": "两名狂战士并排冲锋，以双斧近战攻击地面敌人。",
			"hp": 780, "damage": 115, "range": MELEE_RANGE_MIN,
			"speed": SPEED_FAST, "interval": 1.2, "first_hit": 0.3,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 5.0, "sight": 220.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"deployment_count": 2, "deployment_spacing": 64.0, "deployment_formation": "line",
			"active_skills": [{"name": "残暴打击", "kind": "buff", "cost": 1, "max_uses": 1, "cooldown": 10.0,
				"target_scope": "deployment_group", "duration": 5.0, "shield": 180, "shield_duration": 2.5,
				"attack_speed_multiplier": 1.3, "heal_ratio": 0.3,
				"impact_delay": 0.0, "cast_duration": 0.0, "cast_locks": [],
				"description": "本次部署仍存活的狂战士各获得持续2.5秒的180护盾，以及持续5秒的30%攻速和30%普攻吸血。护盾提前耗尽不结束攻速与吸血；吸血按实际生命伤害计算。"},
				{"name": "诸神黄昏", "kind": "buff", "cost": 2, "max_uses": 1, "cooldown": 10.0,
				"target_scope": "deployment_group", "duration": 6.0, "speed_multiplier": 1.3, "attack_speed_multiplier": 1.3, "damage_multiplier": 1.3, "heal_ratio": 0.3,
				"control_immunity": true, "cleanse_controls": true, "impact_delay": 0.0, "cast_duration": 0.0, "cast_locks": [],
				"description": "本次部署存活的狂战士解除控制，并获得6秒控制免疫、30%移速、30%攻速、30%普攻增伤和30%普攻吸血。受控时可用，凝滞中不可用；生效期间免疫双方凝滞。"}],
		},
		"visual": {
			"color": Color(0.65, 0.36, 0.16), "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/olaf/olaf_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Idle4", "idle": "Idle1", "move": "Run", "control_immune_attack": ["Attack3", "Attack3"], "attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.8},
			"visual_active_buff_scene": "res://assets/effects/olaf/buff.tscn",
			"active_skills": [{"icon_path": "res://assets/skills/olaf_w.png", "resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/olaf/player.gd", "variant": "cas"}, {"provider": "res://assets/effects/olaf/player.gd", "variant": "shield"}, {"provider": "res://assets/effects/olaf/player.gd", "variant": "buf_glow"}, {"provider": "res://assets/effects/olaf/player.gd", "variant": "buf_blood"}]}}, {"icon_path": "res://assets/skills/olaf_r.png", "resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/olaf/player.gd", "variant": "r_cas"}, {"provider": "res://assets/effects/olaf/player.gd", "variant": "r_buf"}, {"provider": "res://assets/effects/olaf/player.gd", "variant": "r_buff_weap"}]}}],
		},
		# BEGIN IMPORTED AUDIO olaf
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/olaf/deploy.ogg", "res://assets/audio/units/olaf/deploy_pillage.wav", "res://assets/audio/units/olaf/deploy_bloodlust.wav"], "bus": "Voice", "scope": "deployment_group", "clip_volume_db": {"res://assets/audio/units/olaf/deploy.ogg": -12.0}},
				"control_immunity:start": {"pool": ["res://assets/audio/units/olaf/play_sfx_olaf_olafr_oncast.wav"], "bus": "Combat"},
				"control_immunity:sustain": {"pool": ["res://assets/audio/units/olaf/play_sfx_olaf_olafr_onbuffactivate.wav"], "bus": "Combat", "fade_out": 0.75},
				"control_immunity:attack_swing": {"pool": ["res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_oncast_r1_d.wav", "res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_oncast_r2_d.wav", "res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_oncast_r3_d.wav"], "bus": "Combat"},
				"control_immunity:attack_hit": {"pool": ["res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_onhit_1559186049_1153642577_r1_d.wav", "res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_onhit_1559186049_1153642577_r2_d.wav", "res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_onhit_1559186049_1153642577_r3_d.wav"], "bus": "Combat"},
				"active_buff:start": {
					"pool": [
						"res://assets/audio/units/olaf/play_sfx_olaf_olafw_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_buff:sustain": {
					"pool": [
						"res://assets/audio/units/olaf/play_sfx_olaf_olafw_onbuffactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/olaf/play_vo_olaf_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/olaf/play_vo_olaf_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/olaf/play_vo_olaf_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack_onhit_1559186049_1153642577_r3_d.wav"
				],
				[
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/olaf/play_sfx_olaf_olafbasicattack2_onhit_1559186049_1153642577_r3.wav"
				]
			]
		},
		# END IMPORTED AUDIO olaf
		"card_art": {"path": "res://assets/cards/olaf_loading.png"},
			}
