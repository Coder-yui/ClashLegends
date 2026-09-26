extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "超级兵", "cost": 4, "type": "unit", "selectable": true,
			"description": "强化型近战单位，生命和伤害更高，适合在一路形成突破。",
			"hp": 720, "damage": 72, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.15, "first_hit": 0.38,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 6.0, "sight": 200.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{"name": "男爵之力", "kind": "buff", "cost": 2, "max_uses": 1, "cooldown": 7.0, "duration": 5.0, "speed_multiplier": 1.35, "damage_multiplier": 1.35, "shield": 140, "shield_duration": 5.0,
				}],
		},
		"visual": {
			"visual_active_buff_scene": "res://assets/effects/baron_minion/super_minion.tscn",
			"visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_paths": [
				"res://assets/units/super_minion/super_minion_order_view.tscn",
				"res://assets/units/super_minion/super_minion_chaos_view.tscn",
			],
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 当前实际片段对的原表 TimeBlendData；缺失边仍用项目通用混合。
				"clip_blends": {
					"Run>Death_Base": 0.0,
					"Attack1>Death_Base": 0.0,
					"Attack2>Death_Base": 0.0,
					"Idle1>Death_Base": 0.0,
				},
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"], "death": "Death_Base", "death_duration": 0.5,
			},
			"color": Color(0.52, 0.55, 0.62),
		},
		# BEGIN EVENT AUDIO super_minion
		"audio": {
			"team_overrides": [
				{
					"events": {"spawn:start": {"pool": ["res://assets/audio/units/minion_shared/spawn_r1.wav", "res://assets/audio/units/minion_shared/spawn_r2.wav", "res://assets/audio/units/minion_shared/spawn_r3.wav"], "volume_db": 0.0, "bus": "Combat"}},
					"attack_hit_by_segment": [
						[
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack_onhit_r1.wav",
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack_onhit_r2.wav",
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack_onhit_r3.wav"
						],
						[
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack2_onhit_r1.wav",
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack2_onhit_r2.wav",
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack2_onhit_r3.wav"
						]
					],
					"attack_swing_volume_db": 0.0,
					"attack_hit_volume_db": 0.0,
					"attack_swing": [
						[
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack_oncast_r1.wav",
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack_oncast_r2.wav",
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack_oncast_r3.wav"
						],
						[
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack2_oncast_r1.wav",
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack2_oncast_r2.wav",
							"res://assets/audio/units/super_minion/order/play_sfx_sru_orderminionsuper_sru_orderminionsuperbasicattack2_oncast_r3.wav"
						]
					]
				},
				{
					"events": {"spawn:start": {"pool": ["res://assets/audio/units/minion_shared/spawn_r1.wav", "res://assets/audio/units/minion_shared/spawn_r2.wav", "res://assets/audio/units/minion_shared/spawn_r3.wav"], "volume_db": 0.0, "bus": "Combat"}},
					"attack_hit_by_segment": [
						[
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack_onhit_r1.wav",
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack_onhit_r2.wav",
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack_onhit_r3.wav"
						],
						[
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack2_onhit_r1.wav",
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack2_onhit_r2.wav",
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack2_onhit_r3.wav"
						]
					],
					"attack_swing_volume_db": 0.0,
					"attack_hit_volume_db": 0.0,
					"attack_swing": [
						[
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack_oncast_r1.wav",
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack_oncast_r2.wav",
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack_oncast_r3.wav"
						],
						[
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack2_oncast_r1.wav",
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack2_oncast_r2.wav",
							"res://assets/audio/units/super_minion/chaos/play_sfx_sru_chaosminionsuper_sru_chaosminionsuperbasicattack2_oncast_r3.wav"
						]
					]
				}
			],
		},
		# END EVENT AUDIO super_minion
		"card_art": {},
	}
