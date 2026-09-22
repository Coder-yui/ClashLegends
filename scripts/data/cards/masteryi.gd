extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "剑圣", "cost": 3, "type": "unit",
			"description": "高速近战刺客，攻击频率高，适合快速处理脆弱目标。",
			# 近战高攻速刺客：血薄但攻速极快
			"hp": 480, "damage": 52, "range": MELEE_RANGE_MIN,
			"speed": SPEED_EXTREMELY_FAST, "interval": 0.7, "first_hit": 0.2,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 4.0, "sight": 200.0,
			# 双重打击：第三段被动动作在首刀后追加一次 50% 伤害的普通攻击判定。
			"attack_extra_hit_damage_multipliers": [[], [], [0.5]],
			"attack_extra_hit_delays": [[], [], [0.12]],
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{
					"name": "高原血统", "kind": "buff", "cost": 1, "max_uses": 2, "cooldown": 6.0,
					"duration": 5.0, "speed_multiplier": 1.5, "damage_multiplier": 1.0, "attack_speed_multiplier": 1.4,
					"ignore_movement_slow": true, "ignore_attack_speed_slow": true,
				}],
		},
		"visual": {
			"active_skills": [{"icon_path": "res://assets/skills/masteryi_0.png"}],
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/masteryi/masteryi_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "masteryi_2013_idle1_anm",
				"move": "Run", "haste_move": "2013_Run_Haste",
				"attack": ["masteryi_2013_attack1_anm", "masteryi_2013_attack2_anm", "masteryi_2013_passive_anm"],
				# 原表仅明确这些普攻之间的0.1秒混合；其余边继续使用通用策略。
				"clip_blends": {
					"masteryi_2013_attack2_anm>masteryi_2013_passive_anm": 0.1,
					"masteryi_2013_attack2_anm>masteryi_2013_attack1_anm": 0.1,
					"masteryi_2013_attack1_anm>masteryi_2013_passive_anm": 0.1,
				},
				"death": "Death", "death_duration": 0.8,
			},
			"color": Color(0.20, 0.80, 0.50),
		},
		"card_art": {}, # 默认 assets/cards/<card_id>_loading.*
		"audio": {
			"attack_hit_once_by_segment": [false, false, true],
			"attack_hit_by_segment": [["res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r1_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r2_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r3_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r4_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r1_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r2_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r3_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r4_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r1_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r2_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r3_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r4_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r1_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r2_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r3_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r4_d.wav"], ["res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r1_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r2_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r3_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r4_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r1_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r2_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r3_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r4_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r1_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r2_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r3_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r4_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r1_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r2_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r3_d.wav", "res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r4_d.wav"], ["res://assets/audio/units/masteryi/play_sfx_masteryi_masteryidoublestrike_onhit_1559186049_1153642577_r.wav"]],
			"attack_swing": [
				[
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_oncast_r1.wav",
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_oncast_r2.wav",
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_oncast_r3.wav",
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_oncast_r4.wav",
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_oncast_r5.wav",
				],
				[
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack2_oncast_r1.wav",
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack2_oncast_r2.wav",
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack2_oncast_r3.wav",
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack2_oncast_r4.wav",
				],
				[
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryidoublestrike_oncast_r1.wav",
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryidoublestrike_oncast_r2.wav",
					"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryidoublestrike_oncast_r3.wav",
				],
			],
			"attack_hit": [
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r2_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r3_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1153642577_r4_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r1_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r2_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r3_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_1216965916_r4_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r1_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r2_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r3_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2058049674_r4_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r1_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r2_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r3_d.wav",
				"res://assets/audio/units/masteryi/play_sfx_masteryi_masteryibasicattack_onhit_1559186049_2473969246_r4_d.wav",
			],
			"attack_swing_volume_db": 0.0, "attack_hit_volume_db": 0.0,
			"events": {
				# 原始部署对应事件 Play_vo_MasterYi_Attack2DGeneral；项目保留其一段渲染，不压缩。
				"deploy:voice": {"pool": ["res://assets/audio/units/masteryi/play_vo_masteryi_attack2dgeneral_r2_en_us.wav"], "volume_db": 0.0, "bus": "Voice"},
				"active_buff:start": {"pool": ["res://assets/audio/units/masteryi/play_sfx_masteryi_highlander_onbuffactivate.wav"]},
				"active_buff:sustain": {"pool": ["res://assets/audio/units/masteryi/play_sfx_masteryi_highlander_trail.wav"]},
				"active_buff:end": {"pool": ["res://assets/audio/units/masteryi/play_sfx_masteryi_highlander_onbuffdeactivate.wav"]},
				"death": {"pool": ["res://assets/audio/units/masteryi/play_sfx_masteryi_death3d_cast.wav"]},
			},
		},
	}
