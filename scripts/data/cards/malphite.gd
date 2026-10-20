extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "熔岩巨兽", "cost": 7, "type": "unit",
			"description": "大型慢速近战坦克。花岗岩护盾：部署时获得400点永久护盾，花岗岩护盾存在时，受到的伤害降低50%。破盾当次伤害先减半，再由护盾吸收，剩余扣除生命；其他护盾不会恢复此减伤。花岗岩护盾破碎后不再生。",
			"hp": 1600, "damage": 120, "range": MELEE_RANGE_MIN,
			"speed": SPEED_SLOW, "interval": 1.8, "first_hit": 0.82,
			"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE, "mass": 10.0, "sight": 220.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"deployment_shield": 400, "deployment_shield_reduction": 0.5,
			"active_skills": [{"name": "大地震颤", "kind": "nova", "cost": 1, "max_uses": 2, "cooldown": 8.0,
				"radius": 160.0, "damage": 160, "ground_only": true,
				"slow_duration": 2.0, "slow_multiplier": 0.7, "attack_slow_multiplier": 0.3,
				"impact_delay": 0.25, "cast_duration": 0.65, "cast_locks": ["movement", "attack", "facing"],
				"description": "拍击地面，对周围160像素圆形范围的地面敌人造成160伤害；降低30%移速和70%攻速，持续2秒。"}],
		},
		"visual": {
			"color": Color(0.52, 0.39, 0.24), "visual_radius": RADIUS_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/malphite/malphite_view.tscn", "visual_forward_yaw": 0.0,
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/malphite/player.gd", "variant": "shield"}, {"provider": "res://assets/effects/malphite/player.gd", "variant": "break"}]},
			"visual_animations": {"idle": "Idle1", "move": "Run", "attack": ["Attack1", "Attack2"],
				"death": "Death", "death_duration": 0.8,
				"visual_actions": {"active": {"animation": "Spell3", "kind": "skill"}}},
			"active_skills": [{"visual_action": "active", "icon_path": "res://assets/skills/malphite_e.png",
				"impact_visual_shape": "malphite_slam", "impact_visual_duration": 4.0,
				"resource_dependencies": {"effects": [{"provider": "res://assets/effects/malphite/player.gd", "variant": "cas"}, {"provider": "res://assets/effects/malphite/player.gd", "variant": "aoe"}]}}],
		},
		# BEGIN IMPORTED AUDIO malphite
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/malphite/deploy.ogg"], "bus": "Voice", "clip_volume_db": {"res://assets/audio/units/malphite/deploy.ogg": -12.0}},
				"active:cast": {
					"pool": [
						"res://assets/audio/units/malphite/play_sfx_malphite_landslide_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active:impact": {
					"pool": [
						"res://assets/audio/units/malphite/play_sfx_malphite_landslide_hit.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/malphite/play_sfx_malphite_malphiteshieldeffect_onbuffactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"deployment_shield:break": {
					"pool": [
						"res://assets/audio/units/malphite/play_sfx_malphite_malphiteshieldeffect_onbuffdeactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/malphite/play_vo_malphite_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/malphite/play_vo_malphite_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/malphite/play_vo_malphite_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack2_oncast_r1.wav",
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack2_oncast_r2.wav",
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack_onhit_1559186049_1153642577_r3_d.wav"
				],
				[
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/malphite/play_sfx_malphite_malphitebasicattack2_onhit_1559186049_1153642577_r3.wav"
				]
			]
		},
		# END IMPORTED AUDIO malphite
		"card_art": {"path": "res://assets/cards/malphite_loading.png"},
	}
