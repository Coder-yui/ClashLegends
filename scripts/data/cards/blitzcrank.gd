extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "蒸汽机器人", "cost": 3, "type": "unit",
			"description": "近战机器人，近身优先，锁定2至4.5格内的敌方地面单位，瞄准1秒后拉到身前；不牵引建筑。",
			"hp": 560, "damage": 70, "range": 56.0,
			"speed": SPEED_MEDIUM, "interval": 1.6, "first_hit": 0.77,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 5.0, "sight": 220.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"auto_pull_min_range": 80.0, "auto_pull_range": 180.0, "auto_pull_break_range": 220.0, "auto_pull_windup": 1.0, "auto_pull_flight": 0.3, "auto_pull_duration": 0.3,
			"active_skills": [{
				"name": "能量铁拳", "kind": "empowered_attack",
				"cost": 1, "max_uses": 2, "cooldown": 7.0,
				"description": "刷新普攻，下一次攻击造成1.5倍伤害并眩晕敌方单位1秒。",
				"empowered_damage_multiplier": 1.5, "stun_duration": 1.0,
			}],
		},
		"visual": {
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/blitzcrank/blitzcrank_view.tscn",
			"visual_forward_yaw": 0.0,
			"attack_hit_visual": "blitzcrank_e",
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/blitzcrank/player.gd", "variant": "qcas"}, {"provider": "res://assets/effects/blitzcrank/player.gd", "variant": "qmis"}, {"provider": "res://assets/effects/blitzcrank/player.gd", "variant": "qreturn"}]},
			"visual_animations": {
				"idle": "Idle1", "move": "Run", "attack": ["Attack1", "Attack2"],
				"empowered_attack": "Spell3", "death": "Death", "death_duration": 0.8,
				"visual_actions": {"auto_pull": {"animation": "Spell1", "durations": [0.65], "kind": "skill", "blend_in": 0.0}},
			},
			"color": Color(0.85, 0.65, 0.18),
			"active_skills": [{"icon_path": "res://assets/skills/blitzcrank_e.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/blitzcrank/player.gd", "variant": "ebuf"}, {"provider": "res://assets/effects/blitzcrank/player.gd", "variant": "etar"}]}}],
		},
		# BEGIN IMPORTED AUDIO blitzcrank
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/blitzcrank/champion_choose_53_zh_cn.ogg"], "volume_db": 0.0, "bus": "Voice", "clip_volume_db": {"res://assets/audio/units/blitzcrank/champion_choose_53_zh_cn.ogg": -8.0}},
				"pull:start": {
					"pool": [
						"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_rocketgrab_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"pull:hit": {
					"pool": [
						"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_rocketgrabmissile_onhit.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"empowered_buff:start": {
					"pool": [
						"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_powerfist_onbuffactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"empowered_swing": {
					"pool": [
						"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_powerfist_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death:voice": {
					"pool": [
						"res://assets/audio/units/blitzcrank/play_vo_blitzcrank_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/blitzcrank/play_vo_blitzcrank_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/blitzcrank/play_vo_blitzcrank_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_onhit_1559186049_1153642577_r3.wav"
				],
				[
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_blitzcrankbasicattack2_onhit_1559186049_1153642577_r3.wav"
				]
			],
			"empowered_hit": [
				"res://assets/audio/units/blitzcrank/play_sfx_blitzcrank_powerfist_hit.wav"
			]
		},
		# END IMPORTED AUDIO blitzcrank
		"card_art": {"path": "res://assets/cards/blitzcrank_loading.png"},
	}
