extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "小鬼", "cost": 0, "type": "unit", "selectable": false,
			"description": "墓碑及召唤技能生成的系统近战单位。",
			# 生命/攻击锚定公主塔单次伤害（当前55），落地后恰好被一击击杀。
			"hp": PRINCESS_TOWER_STATS.damage, "damage": PRINCESS_TOWER_STATS.damage, "range": MELEE_RANGE_MIN,
			"speed": SPEED_SLIGHTLY_FAST, "interval": 0.7, "first_hit": 0.25,
			"deploy_time": 0.0,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"mass": 1.0, "sight": 180.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
		},
		"visual": {
			"visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/imp/imp_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 当前实际片段对的原表 TimeBlendData；缺失边仍用项目通用混合。
				"clip_blends": {
					"Attack1>Attack3": 0.1,
					"Attack1>Attack2": 0.1,
					"Attack1>Idle1": 0.1,
					"Attack1>Death": 0.0,
					"Attack3>Attack1": 0.1,
					"Attack3>Attack2": 0.1,
					"Attack3>Idle1": 0.1,
					"Attack3>Death": 0.0,
					"Attack2>Attack1": 0.1,
					"Attack2>Attack3": 0.1,
					"Attack2>Idle1": 0.1,
					"Attack2>Death": 0.0,
					"Run1>Death": 0.0,
					"Idle1>Attack1": 0.1,
					"Idle1>Attack3": 0.1,
					"Idle1>Attack2": 0.1,
					"Idle1>Death": 0.0,
				},
				"deploy": "Spawn1", "idle": "Idle1", "move": "Run1",
				"attack": ["Attack1", "Attack2", "Attack3"],
				"death": "Death", "death_duration": 0.5,
			},
			"color": Color(0.55, 0.45, 0.80),
		},
		# BEGIN IMPORTED AUDIO imp
		"audio": {
			"events": {
				"spawn:start": {"pool": ["res://assets/audio/units/imp/play_sfx_yorick_yorickq_summon_r1.wav", "res://assets/audio/units/imp/play_sfx_yorick_yorickq_summon_r2.wav", "res://assets/audio/units/imp/play_sfx_yorick_yorickq_summon_r3.wav", "res://assets/audio/units/imp/play_sfx_yorick_yorickq_summon_r4.wav", "res://assets/audio/units/imp/play_sfx_yorick_yorickq_summon_r5.wav"], "volume_db": 0.0, "bus": "Combat"},
				"death": {
					"pool": [
						"res://assets/audio/units/imp/play_sfx_yorick_yorickq_ghoul_death_r1.wav",
						"res://assets/audio/units/imp/play_sfx_yorick_yorickq_ghoul_death_r2.wav",
						"res://assets/audio/units/imp/play_sfx_yorick_yorickq_ghoul_death_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				["res://assets/audio/units/imp/play_sfx_yorick_yorickq_ghoulattack_cast_r1.wav"],
				["res://assets/audio/units/imp/play_sfx_yorick_yorickq_ghoulattack_cast_r1.wav"],
				["res://assets/audio/units/imp/play_sfx_yorick_yorickq_ghoulattack_cast_r1.wav"],
			],
			"attack_swing_volume_db": -3.0,
		},
		# END IMPORTED AUDIO imp
		"card_art": {},
	}
