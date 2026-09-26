extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "纳尔", "cost": 4, "type": "unit",
			"description": "循环双形态战士。小纳尔第6次命中变大，大纳尔第4次命中变小；小形态远程对空，大形态大体型近战。",
			# 默认形态：小纳尔。投掷回旋镖的权威弹体抵达目标后才结算伤害和被动层数。
			"hp": 430, "damage": 50, "range": 150.0,
			"speed": SPEED_FAST, "interval": 0.85, "first_hit": 0.30,
			"size_tier": SIZE_SLIGHTLY_SMALL, "radius": RADIUS_SLIGHTLY_SMALL,
			"mass": 2.5, "sight": 230.0,
			"projectile_speed": 420.0,
			"projectile_spawn_at_edge": true, "projectile_spawn_offset": 7.5, "projectile_collision_radius": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"transform_after_hits": 6,
			"revert_after_hits": 4,
			"transform_duration": 1.5,
			"active_transform_duration": 1.2,
			"revert_duration": 1.33,
			# 变身只替换权威战斗字段与表现映射；单位、net_id 和主动技能归属保持不变。
			"transformed_stats": {
				"name": "大纳尔",
				"hp": 820, "damage": 85, "range": MELEE_RANGE_MIN,
				"speed": SPEED_SLIGHTLY_SLOW, "interval": 1.15, "first_hit": 0.40,
				"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE,
				"mass": 9.0, "sight": 210.0,
				"projectile_speed": 0.0,
				"projectile_spawn_at_edge": false, "projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
				"is_air": false, "building_only": false, "can_attack_air": false,
			},
			"active_skills": [{
					"name": "怒气爆发", "kind": "dual_form",
					"cost": 2, "max_uses": 1, "cooldown": 8.0,
					"description": "当前形态立即释放前方重击；小形态会先变为大形态。命中时造成伤害并眩晕地面敌人。",
					"length": 140.0, "width": 60.0, "damage": 120,
					# 两种 Spell2 主体动作均从施法首帧开始，0.8s 手掌触地。
					"impact_delay": 0.8, "transform_impact_delay": 0.8,
					"cast_duration": 1.2, "transform_cast_duration": 1.2,
					"stun_duration": 1.0, "ground_only": true,
					"cast_locks": ["movement", "attack", "facing"],
				}],
		},
		"visual": {
			"visual_radius": RADIUS_SLIGHTLY_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/gnar/gnar_small_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle1_Base",
				"move": "Run_Base", "move_enter": "Run1_In",
				"attack": ["Gnar_Attack1_anm", "Gnar_Attack2_anm"],
				"clip_blends": {
					"Run1_In>Run_Base": 0.0,
					"Gnar_Attack1_anm>Gnar_Attack1_anm": 0.0,
					"Gnar_Attack1_anm>Gnar_Attack2_anm": 0.0,
					"Gnar_Attack2_anm>Gnar_Attack1_anm": 0.0,
					"Gnar_Attack2_anm>Gnar_Attack2_anm": 0.0,
				},
				"death": "Death", "death_duration": 0.8,
				"visual_actions": {
					"revert": {
						"animation": "gnar_runtime/Revert_Transform", "kind": "transform",
						"durations": [1.333333], "blend_out": 0.12,
					},
				},
			}, "projectile_visual": "boomerang",
			"projectile_visual_height": 30.0 * CHARACTER_SCALE_MULTIPLIER,
			"color": Color(0.93, 0.58, 0.18),
			"transformed_stats": {
				"visual_radius": RADIUS_LARGE + VISUAL_RADIUS_PADDING, "projectile_visual": "orb",
				"projectile_visual_height": 0.0,
				# END IMPORTED AUDIO gnar_mega
				"visual_scene_path": "res://assets/units/gnar/gnar_mega_view.tscn",
				"visual_forward_yaw": 0.0,
				"visual_animations": {
					"deploy": "Idle1_Base", "idle": "Idle1_Base",
					"move": "Run_Base", "move_enter": "Run_In",
					"attack": ["GnarBig_Attack1_anm", "GnarBig_Attack2_anm"],
					# Fast 是原表的攻速替代项，不作为连招第二段轮播。
					"attack_structure": ["GnarBig_Turret_Attack01_anm"],
					"clip_blends": {
						"Run_In>Run_Base": 0.0,
						"GnarBig_Attack1_anm>GnarBig_Attack1_anm": 0.1,
						"GnarBig_Attack1_anm>GnarBig_Attack2_anm": 0.1,
						"GnarBig_Attack2_anm>GnarBig_Attack1_anm": 0.1,
						"GnarBig_Attack2_anm>GnarBig_Attack2_anm": 0.1,
					},
					"death": "GnarBig_Death_anm", "death_duration": 0.27,
					"death_followup_scene_path": "res://assets/units/gnar/gnar_small_view.tscn",
					"death_followup_animation": "Death",
					"death_followup_duration": 0.8,
					"visual_actions": {
						"transform": {
							"animation": "gnar_runtime/Rage_Transform", "kind": "transform",
							"durations": [1.5], "blend_out": 0.12,
						},
						"transform_active": {
							"animation": "gnar_runtime/Rage_Spell2_Transform", "kind": "transform",
							"durations": [1.2], "blend_out": 0.12,
						},
						"active": {
							"animation": "GnarBig_Spell2_anm", "kind": "skill",
							"durations": [1.2], "blend_in": 0.06, "blend_out": 0.12,
						},
					},
				},
			},
			"active_skills": [{ "icon_path": "res://assets/skills/gnar_0.png", "visual_action": "active",
				}],
		},
		# BEGIN IMPORTED AUDIO gnar
		"audio": {
			"attack_launch_until_impact": true,
			"events": {
				# 小纳尔部署动画为 Respawn；使用两段短英雄语音随机补充部署声。
				"deploy:voice": {
					"pool": [
						"res://assets/audio/units/gnar/play_vo_gnar_attack2dgeneral_r1_en_us.wav",
						"res://assets/audio/units/gnar/play_vo_gnar_laugh3dgeneral_r2_en_us.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"attack_launch": {
					"pool": [
						"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack_onmissilelaunch_r1_d.wav",
						"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack_onmissilelaunch_r2_d.wav",
						"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack_onmissilelaunch_r3_d.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"revert:sustain": {
					"pool": [
						"res://assets/audio/units/gnar/play_sfx_gnar_gnartransformback_buffactivate_r1.wav",
						"res://assets/audio/units/gnar/play_sfx_gnar_gnartransformback_buffactivate_r2.wav",
						"res://assets/audio/units/gnar/play_sfx_gnar_gnartransformback_buffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/gnar/play_vo_gnar_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/gnar/play_vo_gnar_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/gnar/play_vo_gnar_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack_onhit_r1_d.wav",
				"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack_onhit_r2_d.wav",
				"res://assets/audio/units/gnar/play_sfx_gnar_gnarbasicattack_onhit_r3_d.wav"
			],
			"attack_hit_volume_db": -5.0,
			"transformed_stats": {
				"events": {
					"active:hit": {"pool": ["res://assets/audio/units/gnar/play_sfx_gnar_gnarbigw_hit2_r1.wav", "res://assets/audio/units/gnar/play_sfx_gnar_gnarbigw_hit2_r2.wav", "res://assets/audio/units/gnar/play_sfx_gnar_gnarbigw_hit2_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
					"transform_active:hit": {"pool": ["res://assets/audio/units/gnar/play_sfx_gnar_gnarbigw_hit2_r1.wav", "res://assets/audio/units/gnar/play_sfx_gnar_gnarbigw_hit2_r2.wav", "res://assets/audio/units/gnar/play_sfx_gnar_gnarbigw_hit2_r3.wav"], "volume_db": 0.0, "bus": "Combat"},

					"transform:sustain": {
						"pool": [
							"res://assets/audio/units/gnar/play_sfx_gnar_gnartransform_onbuffactivate_r1.wav",
							"res://assets/audio/units/gnar/play_sfx_gnar_gnartransform_onbuffactivate_r2.wav",
							"res://assets/audio/units/gnar/play_sfx_gnar_gnartransform_onbuffactivate_r3.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
					},
					"transform_active:sustain": {
						"pool": [
							"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigw_oncast_r.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
					},
					"active:sustain": {
						"pool": [
							"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigw_oncast_r.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
					},
					"death": {
						"pool": [
							"res://assets/audio/units/gnar/play_vo_gnar_death3d_r1_zh_cn.wav",
							"res://assets/audio/units/gnar/play_vo_gnar_death3d_r2_zh_cn.wav",
							"res://assets/audio/units/gnar/play_vo_gnar_death3d_r3_zh_cn.wav"
						],
						"volume_db": 0.0,
						"bus": "Voice"
					}
				},
				"attack_swing": [
					[
						"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigbasicattack_oncast_r1_d.wav",
						"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigbasicattack_oncast_r2_d.wav",
						"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigbasicattack_oncast_r3_d.wav"
					],
					[
						"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigbasicattack2_oncast_r1_d.wav",
						"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigbasicattack2_oncast_r2_d.wav",
						"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigbasicattack2_oncast_r3_d.wav"
					]
				],
				"attack_swing_volume_db": -3.0,
				"attack_hit": [
					"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigbasicattack_onhit_r1_d.wav",
					"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigbasicattack_onhit_r2_d.wav",
					"res://assets/audio/units/gnar/play_sfx_gnar_gnarbigbasicattack_onhit_r3_d.wav"
				],
				"attack_hit_volume_db": -5.0,
			},
		},
		# END IMPORTED AUDIO gnar
		"card_art": {},
	}
