extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "炮车兵", "cost": 3, "type": "unit", "selectable": true,
			"description": "远程炮击单位，攻击距离较远，适合从后方压制敌方建筑。",
			"hp": 390, "damage": 58, "range": 170.0,
			"speed": SPEED_MEDIUM, "interval": 1.65, "first_hit": 0.55,
			"size_tier": SIZE_SLIGHTLY_SMALL, "radius": RADIUS_SLIGHTLY_SMALL,
			"mass": 4.5, "sight": 230.0,
			"projectile_speed": 310.0,
			"projectile_spawn_at_edge": false, "projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{"name": "男爵之力", "kind": "buff", "cost": 1, "max_uses": 2, "cooldown": 8.0, "duration": 5.0, "damage_multiplier": 1.5,
				}],
		},
		"visual": {
			"active_buff_projectile_visual": "baron_siege",
			"visual_active_buff_scene": "res://assets/effects/baron_minion/siege_minion.tscn",
			"visual_radius": RADIUS_SLIGHTLY_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_paths": [
				"res://assets/units/siege_minion/siege_minion_order_view.tscn",
				"res://assets/units/siege_minion/siege_minion_chaos_view.tscn",
			],
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 当前实际片段对的原表 TimeBlendData；缺失边仍用项目通用混合。
				"clip_blends": {
					"Run>Death": 0.0,
					"Attack2_BASE>Death": 0.0,
					"Idle1>Death": 0.0,
					"Attack1_BASE>Death": 0.0,
				},
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1_BASE", "Attack2_BASE"], "death": "Death", "death_duration": 0.5,
			}, "projectile_visual": "orb",
			# 黑色小炮弹从炮口高度、炮身前方出现；这些仍是纯表现偏移。
			"projectile_visual_height": 28.0,
			"projectile_visual_forward_offset": 24.0,
			"projectile_colors": [Color(0.055, 0.055, 0.06), Color(0.055, 0.055, 0.06)],
			"color": Color(0.38, 0.40, 0.44),
		},
		# BEGIN EVENT AUDIO siege_minion
		"audio": {
			"team_overrides": [
				{
					"events": {"spawn:start": {"pool": ["res://assets/audio/units/minion_shared/spawn_r1.wav", "res://assets/audio/units/minion_shared/spawn_r2.wav", "res://assets/audio/units/minion_shared/spawn_r3.wav"], "volume_db": 0.0, "bus": "Combat"}},
					"attack_hit_by_segment": [
						[
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_onhit_r1.wav",
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_onhit_r2.wav",
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_onhit_r3.wav"
						],
						[
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_onhit_r1.wav",
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_onhit_r2.wav",
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_onhit_r3.wav"
						]
					],
					"attack_swing_volume_db": 0.0,
					"attack_hit_volume_db": 0.0,
					"attack_swing": [
						[
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_oncast_r1.wav",
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_oncast_r2.wav",
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_oncast_r3.wav"
						],
						[
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_oncast_r1.wav",
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_oncast_r2.wav",
							"res://assets/audio/units/siege_minion/order/play_sfx_sru_orderminionsiege_sru_orderminionsiegebasicattack_oncast_r3.wav"
						]
					]
				},
				{
					"attack_hit_by_segment": [
						[
							"res://assets/audio/units/siege_minion/chaos/play_sfx_sru_chaosminionsiege_sru_chaosminionsiegebasicattack_onhit_r1.wav",
							"res://assets/audio/units/siege_minion/chaos/play_sfx_sru_chaosminionsiege_sru_chaosminionsiegebasicattack_onhit_r2.wav",
							"res://assets/audio/units/siege_minion/chaos/play_sfx_sru_chaosminionsiege_sru_chaosminionsiegebasicattack_onhit_r3.wav"
						],
						[
							"res://assets/audio/units/siege_minion/chaos/play_sfx_sru_chaosminionsiege_sru_chaosminionsiegebasicattack_onhit_r1.wav",
							"res://assets/audio/units/siege_minion/chaos/play_sfx_sru_chaosminionsiege_sru_chaosminionsiegebasicattack_onhit_r2.wav",
							"res://assets/audio/units/siege_minion/chaos/play_sfx_sru_chaosminionsiege_sru_chaosminionsiegebasicattack_onhit_r3.wav"
						]
					],
					"attack_swing_volume_db": 0.0,
					"attack_hit_volume_db": 0.0,
					"events": {"spawn:start": {"pool": ["res://assets/audio/units/minion_shared/spawn_r1.wav", "res://assets/audio/units/minion_shared/spawn_r2.wav", "res://assets/audio/units/minion_shared/spawn_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
						"attack_missile_cast": {
							"pool": [
								"res://assets/audio/units/siege_minion/chaos/play_sfx_sru_chaosminionsiege_sru_chaosminionsiegebasicattack_onmissilecast_r1.wav",
								"res://assets/audio/units/siege_minion/chaos/play_sfx_sru_chaosminionsiege_sru_chaosminionsiegebasicattack_onmissilecast_r2.wav",
								"res://assets/audio/units/siege_minion/chaos/play_sfx_sru_chaosminionsiege_sru_chaosminionsiegebasicattack_onmissilecast_r3.wav"
							],
							"volume_db": 0.0,
							"bus": "Combat"
						}
					}
				}
			],
		},
		# END EVENT AUDIO siege_minion
		"card_art": {},
	}
