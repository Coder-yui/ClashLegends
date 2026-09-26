extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "远程兵", "cost": 1, "type": "unit", "selectable": true,
			"description": "后排远程单位，能够攻击空中和地面目标并持续输出。",
			"hp": 135, "damage": 32, "range": 150.0,
			# Attack1/2 约在动作前段举杖发射；first_hit 是权威弹体生成时刻。
			"speed": SPEED_MEDIUM, "interval": 1.25, "first_hit": 0.42,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"mass": 1.8, "sight": 210.0,
			"projectile_speed": 360.0,
			"projectile_spawn_at_edge": false, "projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{"name": "男爵之力", "kind": "buff", "cost": 0, "max_uses": 2, "cooldown": 5.0, "duration": 5.0, "damage_multiplier": 1.25, "attack_speed_multiplier": 1.25,
				}],
		},
		"visual": {
			"active_buff_projectile_visual": "baron_ranged",
			"visual_active_buff_scene": "res://assets/effects/baron_minion/ranged_minion.tscn",
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_paths": [
				"res://assets/units/ranged_minion/ranged_minion_order_view.tscn",
				"res://assets/units/ranged_minion/ranged_minion_chaos_view.tscn",
			],
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 当前实际片段对的原表 TimeBlendData；缺失边仍用项目通用混合。
				"clip_blends": {
					"Run>Death": 0.0,
					"Attack1>Death": 0.0,
					"Attack2>Death": 0.0,
					"Idle1>Death": 0.0,
				},
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.5,
			}, "projectile_visual": "orb",
			# 权杖高度与前向偏移只决定小光球的绘制起点，不参与伤害、碰撞或射程。
			"projectile_visual_height": 19.0,
			"projectile_visual_forward_offset": 10.0,
			"projectile_colors": [Color(0.18, 0.66, 1.0), Color(1.0, 0.18, 0.22)],
			"color": Color(0.58, 0.62, 0.70),
		},
		# BEGIN EVENT AUDIO ranged_minion
		"audio": {
			"team_overrides": [
				{
					"events": {"spawn:start": {"pool": ["res://assets/audio/units/minion_shared/spawn_r1.wav", "res://assets/audio/units/minion_shared/spawn_r2.wav", "res://assets/audio/units/minion_shared/spawn_r3.wav"], "volume_db": 0.0, "bus": "Combat"}},
					"attack_hit_by_segment": [
						[
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack_onhit_r1.wav",
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack_onhit_r2.wav",
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack_onhit_r3.wav"
						],
						[
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack2_onhit_r1.wav",
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack2_onhit_r2.wav",
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack2_onhit_r3.wav"
						]
					],
					"attack_swing_volume_db": 0.0,
					"attack_hit_volume_db": 0.0,
					"attack_swing": [
						[
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack_oncast_r1.wav",
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack_oncast_r2.wav",
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack_oncast_r3.wav"
						],
						[
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack2_oncast_r1.wav",
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack2_oncast_r2.wav",
							"res://assets/audio/units/ranged_minion/order/play_sfx_sru_orderminionranged_sru_orderminionrangedbasicattack2_oncast_r3.wav"
						]
					]
				},
				{
					"events": {"spawn:start": {"pool": ["res://assets/audio/units/minion_shared/spawn_r1.wav", "res://assets/audio/units/minion_shared/spawn_r2.wav", "res://assets/audio/units/minion_shared/spawn_r3.wav"], "volume_db": 0.0, "bus": "Combat"}},
					"attack_hit_by_segment": [
						[
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack_onhit_r1.wav",
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack_onhit_r2.wav",
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack_onhit_r3.wav"
						],
						[
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack2_onhit_r1.wav",
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack2_onhit_r2.wav",
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack2_onhit_r3.wav"
						]
					],
					"attack_swing_volume_db": 0.0,
					"attack_hit_volume_db": 0.0,
					"attack_swing": [
						[
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack_oncast_r1.wav",
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack_oncast_r2.wav",
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack_oncast_r3.wav"
						],
						[
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack2_oncast_r1.wav",
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack2_oncast_r2.wav",
							"res://assets/audio/units/ranged_minion/chaos/play_sfx_sru_chaosminionranged_sru_chaosminionrangedbasicattack2_oncast_r3.wav"
						]
					]
				}
			],
		},
		# END EVENT AUDIO ranged_minion
		"card_art": {},
	}
