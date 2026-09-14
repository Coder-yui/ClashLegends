extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "近战兵", "cost": 1, "type": "unit", "selectable": true,
			"description": "基础近战单位，适合成群推进并为后排吸收伤害。",
			"hp": 210, "damage": 42, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.0, "first_hit": 0.32,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"mass": 2.0, "sight": 180.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{"name": "男爵之力", "kind": "buff", "cost": 0, "max_uses": 2, "cooldown": 5.0, "duration": 4.0, "speed_multiplier": 1.35, "damage_multiplier": 1.25,
				}],
		},
		"visual": {
			"visual_active_buff_scene": "res://assets/effects/baron_minion/melee_minion.tscn",
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_paths": [
				"res://assets/units/melee_minion/melee_minion_order_view.tscn",
				"res://assets/units/melee_minion/melee_minion_chaos_view.tscn",
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
			},
			"color": Color(0.58, 0.62, 0.70),
		},
		# BEGIN EVENT AUDIO melee_minion
		"audio": {
			"team_overrides": [
				{
					"events": {"spawn:start": {"pool": ["res://assets/audio/units/minion_shared/spawn_r1.wav", "res://assets/audio/units/minion_shared/spawn_r2.wav", "res://assets/audio/units/minion_shared/spawn_r3.wav"], "volume_db": 0.0, "bus": "Combat"}},
					"attack_hit_by_segment": [
						[
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack_onhit_r1.wav",
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack_onhit_r2.wav",
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack_onhit_r3.wav"
						],
						[
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack2_onhit_r1.wav",
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack2_onhit_r2.wav",
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack2_onhit_r3.wav"
						]
					],
					"attack_swing_volume_db": 0.0,
					"attack_hit_volume_db": 0.0,
					"attack_swing": [
						[
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack_oncast_r1.wav",
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack_oncast_r2.wav",
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack_oncast_r3.wav"
						],
						[
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack2_oncast_r1.wav",
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack2_oncast_r2.wav",
							"res://assets/audio/units/melee_minion/order/play_sfx_sru_orderminionmelee_sru_orderminionmeleebasicattack2_oncast_r3.wav"
						]
					]
				},
				{
					"events": {"spawn:start": {"pool": ["res://assets/audio/units/minion_shared/spawn_r1.wav", "res://assets/audio/units/minion_shared/spawn_r2.wav", "res://assets/audio/units/minion_shared/spawn_r3.wav"], "volume_db": 0.0, "bus": "Combat"}},
					"attack_hit_by_segment": [
						[
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack_onhit_r1.wav",
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack_onhit_r2.wav",
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack_onhit_r3.wav"
						],
						[
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack2_onhit_r1.wav",
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack2_onhit_r2.wav",
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack2_onhit_r3.wav"
						]
					],
					"attack_swing_volume_db": 0.0,
					"attack_hit_volume_db": 0.0,
					"attack_swing": [
						[
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack_oncast_r1.wav",
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack_oncast_r2.wav",
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack_oncast_r3.wav"
						],
						[
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack2_oncast_r1.wav",
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack2_oncast_r2.wav",
							"res://assets/audio/units/melee_minion/chaos/play_sfx_sru_chaosminionmelee_sru_chaosminionmeleebasicattack2_oncast_r3.wav"
						]
					]
				}
			],
		},
		# END EVENT AUDIO melee_minion
		"card_art": {},
	}
