extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"hp": 1050,
			"damage": 88,
			"range": 64.0,
			"speed": 52.0,
			"interval": 1.1,
			"first_hit": 0.25,
			"passive_first_hit": 0.4,
			"size_tier": "slightly_large",
			"radius": 21.0,
			"mass": 5.0,
			"sight": 210.0,
			"is_air": false,
			"building_only": false,
			"can_attack_air": false,
			"on_hit_max_health_ratio": 0.1,
			"on_hit_tower_damage": 20,
			"attack_passive_multipliers": [
				0.0,
				0.0,
				0.0,
				1.0
			],
			"attack_lifesteal_ratios": [
				0.0,
				0.0,
				0.0,
				0.3
			],
			"name": "剑魔",
			"cost": 5,
			"type": "unit",
			"description": "普攻三刀后使用赐死剑气：额外造成目标最大生命10%的伤害，对塔/水晶固定附加20点；被动按实际生命伤害回复30%，护盾和过量伤害不吸血。",
			"form_lifetime": 5.0,
			"form_lifetime_after_transition": true,
			"form_speed_boost_duration": 1.0,
			"form_speed_boost_multiplier": 1.3,
			"form_refresh_on_kill": true,
			"active_transform_duration": 1.0,
			"revert_duration": 0.73,
			"transformed_stats": {
				"name": "大灭形态剑魔",
				"hp": 1350,
				"damage": 88,
				"range": 64.0,
				"speed": 52.0,
				"interval": 1.1,
				"first_hit": 0.25,
				"passive_first_hit": 0.4,
				"size_tier": "slightly_large",
				"radius": 21.0,
				"mass": 5.0,
				"sight": 210.0,
				"is_air": true,
				"building_only": false,
				"can_attack_air": true,
				"on_hit_max_health_ratio": 0.1,
				"on_hit_tower_damage": 20,
				"attack_passive_multipliers": [
					1.0,
					0.0,
					0.0
				],
				"attack_lifesteal_ratios": [
					0.5,
					0.2,
					0.2
				]
			},
			"active_skills": [
				{
					"name": "大灭",
					"kind": "timed_form",
					"cost": 3,
					"max_uses": 1,
					"cooldown": 0.0,
					"impact_delay": 0.0,
					"cast_duration": 1.0,
					"cast_locks": [
						"attack"
					],
					"description": "增加300最大与当前生命，成为可对地对空的空军，开启动画结束后持续5秒；开启时获得1秒30%加速。普攻吸血20%，被动吸血50%；下一击为被动，再按强化一刀、强化二刀、被动循环。击杀敌方单位刷新5秒、下一次被动和1秒加速。结束将超出基础上限的生命截回。"
				}
			]
		},
		"visual": {
			"active_skills": [{"icon_path": "res://assets/skills/aatrox_0.png"}],
		"color": Color(0.65, 0.12, 0.12),
			"visual_radius": 25.5,
			"visual_scene_path": "res://assets/units/aatrox/normal_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"transition_blends": {"locomotion": 0.1, "action_in": 0.1, "action_out": 0.1, "sequence": 0.1},
				"clip_blends": {
					"Idle1>Spell4": 0.0,
					"Idle1>Death": 0.0,
					"Idle1>Aatrox_ULT_Idle_anm": 0.0,
					"Run_Base>Spell4": 0.0,
					"Run_Base>Death": 0.0,
					"Run_Base>Aatrox_ULT_Idle_anm": 0.0,
					"Passive_Idle>Idle1": 0.0,
					"Passive_Idle>Run_Base": 0.0,
					"Passive_Idle>Attack1": 0.0,
					"Passive_Idle>Attack2": 0.0,
					"Passive_Idle>Attack3": 0.0,
					"Passive_Idle>Spell4": 0.0,
					"Passive_Idle>Attack1_Ult": 0.0,
					"Passive_Idle>Attack2_Ult": 0.0,
					"Passive_Idle>Death": 0.0,
					"Passive_Idle>Aatrox_ULT_Idle_anm": 0.0,
					"Passive_Run>Idle1": 0.0,
					"Passive_Run>Run_Base": 0.0,
					"Passive_Run>Attack1": 0.0,
					"Passive_Run>Attack2": 0.0,
					"Passive_Run>Attack3": 0.0,
					"Passive_Run>Spell4": 0.0,
					"Passive_Run>Attack1_Ult": 0.0,
					"Passive_Run>Attack2_Ult": 0.0,
					"Passive_Run>Death": 0.0,
					"Passive_Run>Aatrox_ULT_Idle_anm": 0.0,
					"Attack2>Attack_INTO_Run": 0.03,
					"Attack2>Spell4": 0.0,
					"Attack2>Aatrox_ULT_Idle_anm": 0.0,
					"Attack3>Spell4": 0.0,
					"Attack3>Aatrox_ULT_Idle_anm": 0.0,
					"Attack3>Passive_Run": 0.15,
					"Attack_INTO_Run>Idle1": 0.05,
					"Attack_INTO_Run>Attack1": 0.05,
					"Attack_INTO_Run>Attack2": 0.05,
					"Attack_INTO_Run>Attack3": 0.05,
					"Attack_INTO_Run>Spell4": 0.0,
					"Attack_INTO_Run>Attack1_Ult": 0.05,
					"Attack_INTO_Run>Attack2_Ult": 0.05,
					"Attack_INTO_Run>Death": 0.05,
					"Attack_INTO_Run>Aatrox_ULT_Idle_anm": 0.0,
					"Spell4>Run_Ult": 0.25,
					"Run_Ult>Spell4": 0.0,
					"Attack1_Ult>Attack_INTO_Run": 0.03,
					"Attack1_Ult>Spell4": 0.0,
					"Attack1_Ult>Aatrox_ULT_Idle_anm": 0.0,
					"Attack2_Ult>Attack_INTO_Run": 0.03,
					"Attack2_Ult>Spell4": 0.0,
					"Attack2_Ult>Aatrox_ULT_Idle_anm": 0.0,
					"Death>Idle1": 0.0,
					"Death>Run_Base": 0.0,
					"Death>Passive_Idle": 0.0,
					"Death>Passive_Run": 0.0,
					"Death>Attack1": 0.0,
					"Death>Attack2": 0.0,
					"Death>Attack3": 0.0,
					"Death>Spell4": 0.0,
					"Death>Attack1_Ult": 0.0,
					"Death>Attack2_Ult": 0.0,
					"Death>Aatrox_ULT_Idle_anm": 0.0,
					"Aatrox_sheath_run01_anm>Spell4": 0.0,
					"Aatrox_sheath_run01_anm>Aatrox_ULT_Idle_anm": 0.0,
					"Aatrox_ULT_Idle_anm>Spell4": 0.0,
					"Aatrox_ULT_Idle_anm>Death": 0.0
				},
				"deploy": "Respawn",
				"idle": "Idle1",
				"move": "Run_Base",
				"initial_move": "Aatrox_sheath_run01_anm",
				"empowered_move": "Passive_Run",
				"empowered_idle": "Passive_Idle",
				"transitions": {
					"Attack2>move": {"animation": "Attack_INTO_Run", "blend_in": 0.1, "blend_out": 0.1},
					"Passive_Attack>idle": {"animation": "Passive_Attack_out", "blend_in": 0.1, "blend_out": 0.1},
					"Passive_Attack>move": {"animation": "Passive_Attack_out", "blend_in": 0.1, "blend_out": 0.1}
				},
				"attack": [
					"Attack1",
					"Attack2",
					"Attack3",
					"Passive_Attack"
				],
				"death": "Death",
				"death_duration": 0.8,
				"death_clip_end": 0.8,
				"visual_actions": {
					"revert": {
						"animation": "ULT_out",
						"blend_in": 0.1,
						"blend_out": 0.1,
						"kind": "transform"
					}
				}
			},
			"transformed_stats": {
				"visual_radius": 25.5,
				"visual_scene_path": "res://assets/units/aatrox/ultimate_view.tscn",
				"visual_forward_yaw": 0.0,
				"visual_animations": {
				"transition_blends": {"locomotion": 0.1, "action_in": 0.1, "action_out": 0.1, "sequence": 0.1},
				"clip_blends": {
					"Idle1>Spell4": 0.0,
					"Idle1>Death": 0.0,
					"Idle1>Aatrox_ULT_Idle_anm": 0.0,
					"Run_Base>Spell4": 0.0,
					"Run_Base>Death": 0.0,
					"Run_Base>Aatrox_ULT_Idle_anm": 0.0,
					"Passive_Idle>Idle1": 0.0,
					"Passive_Idle>Run_Base": 0.0,
					"Passive_Idle>Attack1": 0.0,
					"Passive_Idle>Attack2": 0.0,
					"Passive_Idle>Attack3": 0.0,
					"Passive_Idle>Spell4": 0.0,
					"Passive_Idle>Attack1_Ult": 0.0,
					"Passive_Idle>Attack2_Ult": 0.0,
					"Passive_Idle>Death": 0.0,
					"Passive_Idle>Aatrox_ULT_Idle_anm": 0.0,
					"Passive_Run>Idle1": 0.0,
					"Passive_Run>Run_Base": 0.0,
					"Passive_Run>Attack1": 0.0,
					"Passive_Run>Attack2": 0.0,
					"Passive_Run>Attack3": 0.0,
					"Passive_Run>Spell4": 0.0,
					"Passive_Run>Attack1_Ult": 0.0,
					"Passive_Run>Attack2_Ult": 0.0,
					"Passive_Run>Death": 0.0,
					"Passive_Run>Aatrox_ULT_Idle_anm": 0.0,
					"Attack2>Attack_INTO_Run": 0.03,
					"Attack2>Spell4": 0.0,
					"Attack2>Aatrox_ULT_Idle_anm": 0.0,
					"Attack3>Spell4": 0.0,
					"Attack3>Aatrox_ULT_Idle_anm": 0.0,
					"Attack3>Passive_Run": 0.15,
					"Attack_INTO_Run>Idle1": 0.05,
					"Attack_INTO_Run>Attack1": 0.05,
					"Attack_INTO_Run>Attack2": 0.05,
					"Attack_INTO_Run>Attack3": 0.05,
					"Attack_INTO_Run>Spell4": 0.0,
					"Attack_INTO_Run>Attack1_Ult": 0.05,
					"Attack_INTO_Run>Attack2_Ult": 0.05,
					"Attack_INTO_Run>Death": 0.05,
					"Attack_INTO_Run>Aatrox_ULT_Idle_anm": 0.0,
					"Spell4>Run_Ult": 0.25,
					"Run_Ult>Spell4": 0.0,
					"Attack1_Ult>Attack_INTO_Run": 0.03,
					"Attack1_Ult>Spell4": 0.0,
					"Attack1_Ult>Aatrox_ULT_Idle_anm": 0.0,
					"Attack2_Ult>Attack_INTO_Run": 0.03,
					"Attack2_Ult>Spell4": 0.0,
					"Attack2_Ult>Aatrox_ULT_Idle_anm": 0.0,
					"Death>Idle1": 0.0,
					"Death>Run_Base": 0.0,
					"Death>Passive_Idle": 0.0,
					"Death>Passive_Run": 0.0,
					"Death>Attack1": 0.0,
					"Death>Attack2": 0.0,
					"Death>Attack3": 0.0,
					"Death>Spell4": 0.0,
					"Death>Attack1_Ult": 0.0,
					"Death>Attack2_Ult": 0.0,
					"Death>Aatrox_ULT_Idle_anm": 0.0,
					"Aatrox_sheath_run01_anm>Spell4": 0.0,
					"Aatrox_sheath_run01_anm>Aatrox_ULT_Idle_anm": 0.0,
					"Aatrox_ULT_Idle_anm>Spell4": 0.0,
					"Aatrox_ULT_Idle_anm>Death": 0.0
				},
					"deploy": "Respawn",
					"idle": "Aatrox_ULT_Idle_anm",
					"move": "Run_Ult",
					"attack": [
						"Passive_Attack_Ult",
						"Attack1_Ult",
						"Attack2_Ult"
					],
					"death": "Death",
					"death_duration": 0.8,
				"death_clip_end": 0.8,
					"visual_actions": {
						"transform_active": {
							"animation": "Spell4",
							"clip_ranges": [[0.0, 1.0]],
							"blend_in": 0.1,
							"blend_out": 0.1,
							"kind": "transform"
						}
					}
				}
			}
		},
		"card_art": {},
		"audio": {
			"attack_swing": [
				[
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack_oncast_1.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack_oncast_2.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack_oncast_3.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack_oncast_4.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack_oncast_5.wav"
				],
				[
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack2_oncast_1.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack2_oncast_2.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack2_oncast_3.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack2_oncast_4.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack2_oncast_5.wav"
				],
				[
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack3_oncast_1.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack3_oncast_2.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack3_oncast_3.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack3_oncast_4.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack3_oncast_5.wav"
				],
				[
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxpassiveattack_oncast_1.wav"
				]
			],
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack_onhit_1.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack_onhit_2.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack_onhit_3.wav"
				],
				[
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack2_onhit_1.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack2_onhit_2.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack2_onhit_3.wav"
				],
				[
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack3_onhit_1.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack3_onhit_2.wav",
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxbasicattack3_onhit_3.wav"
				],
				[
					"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxpassiveattack_onhit_1.wav"
				]
			],
			"events": {
				"death": {
					"pool": [
						"res://assets/audio/units/aatrox/play_sfx_aatrox_death3d_cast_1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"revert:start": {
					"pool": [
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxr_buffdeactivate_1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death:voice": {
					"pool": [
						"res://assets/audio/units/aatrox/play_vo_aatrox_death3d_1.wav",
						"res://assets/audio/units/aatrox/play_vo_aatrox_death3d_2.wav",
						"res://assets/audio/units/aatrox/play_vo_aatrox_death3d_3.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"deploy:voice": {
					"pool": [
						"res://assets/audio/units/aatrox/play_vo_aatrox_deploy_1.wav",
						"res://assets/audio/units/aatrox/play_vo_aatrox_deploy_2.wav",
						"res://assets/audio/units/aatrox/play_vo_aatrox_deploy_3.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"transformed_stats": {
				"attack_swing": [
					[
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxpassiveattack_oncast_1.wav"
					],
					[
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack1_oncast_1.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack1_oncast_2.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack1_oncast_3.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack1_oncast_4.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack1_oncast_5.wav"
					],
					[
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack2_oncast_1.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack2_oncast_2.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack2_oncast_3.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack2_oncast_4.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack2_oncast_5.wav"
					]
				],
				"attack_hit_by_segment": [
					[
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxpassiveattack_onhit_1.wav"
					],
					[
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack1_onhit_1.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack1_onhit_2.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack1_onhit_3.wav"
					],
					[
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack2_onhit_1.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack2_onhit_2.wav",
						"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxrattack2_onhit_3.wav"
					]
				],
				"events": {
					"death": {
						"pool": [
							"res://assets/audio/units/aatrox/play_sfx_aatrox_death3d_cast_1.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
					},
					"transform_active:start": {
						"pool": [
							"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxr_onbuffactivate_all_1.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
					},
					"death:voice": {
						"pool": [
							"res://assets/audio/units/aatrox/play_vo_aatrox_death3d_1.wav",
							"res://assets/audio/units/aatrox/play_vo_aatrox_death3d_2.wav",
							"res://assets/audio/units/aatrox/play_vo_aatrox_death3d_3.wav"
						],
						"volume_db": 0.0,
						"bus": "Voice"
					},
					"form:refresh": {
						"pool": [
							"res://assets/audio/units/aatrox/play_sfx_aatrox_aatroxr_onbuffactivate_all_1.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
					},
					"deploy:voice": {
						"pool": [
							"res://assets/audio/units/aatrox/play_vo_aatrox_deploy_1.wav",
							"res://assets/audio/units/aatrox/play_vo_aatrox_deploy_2.wav",
							"res://assets/audio/units/aatrox/play_vo_aatrox_deploy_3.wav"
						],
						"volume_db": 0.0,
						"bus": "Voice"
					}
				}
			}
		}
	}
