extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "盖伦", "cost": 5, "type": "unit",
			"description": "高生命值的近战战士，专注攻击建筑，适合在前线持续推进。",
			"hp": 1050, "damage": 88, "range": MELEE_RANGE_MIN,
			# 命中位于攻击周期约 35% 处，给挥剑留出短前摇，把较长时间留给收招。
			"speed": SPEED_SLOW, "interval": 1.1, "first_hit": 0.38,
			"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE,
			"mass": 8.0, "sight": 220.0,
			"is_air": false, "building_only": true, "can_attack_air": false,
			"active_skills": [{
					"name": "致命打击", "kind": "empowered_attack",
					"cost": 1, "max_uses": 2, "cooldown": 6.0,
					"description": "强化下一次普通攻击，使其造成双倍伤害；强化尚未打出时移动速度提高两档。技能不会重置或延后当前攻击节奏。",
					"empowered_damage_multiplier": 2.0,
					# 盖伦基础为“慢”，提高两档后达到“中等”。强化攻击出手后立即失去加速。
					"empowered_speed_multiplier": 1.3636,
				},{
					"name": "审判", "kind": "continuous_area",
					"cost": 2, "max_uses": 1, "cooldown": 10.0,
					"description": "旋转 3 秒，对当前身边的地面敌人每秒造成 60 点伤害；施放期间只锁定攻击，仍可移动和改变朝向。",
					"radius": 90.0, "damage": 60, "ground_only": true,
					"duration": 3.0, "tick_interval": 1.0,
					"impact_delay": 0.0, "cast_duration": 3.0,
					"cast_locks": ["attack"],
				}],
		},
		"visual": { "visual_radius": RADIUS_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/garen/garen_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn_Base", "idle": "Idle1_Base",
				"move": "Run_Base", "empowered_move": "Run_Spell1",
				"attack": ["Attack1", "Attack2"], "empowered_attack": "Spell1",
				# 原表明确的普攻/Q入口；审判退出到Q是0秒，不能套用其他来源的0.1秒。
				"clip_blends": {
					"Attack2>Attack1": 0.0,
					"Respawn_Base>Spell1": 0.1, "Idle1_Base>Spell1": 0.1,
					"Run_Base>Spell1": 0.1, "Run_Spell1>Spell1": 0.1,
					"Attack1>Spell1": 0.1, "Attack2>Spell1": 0.1,
					"Spell1>Spell1": 0.1, "Spell3_0>Spell1": 0.0,
				},
				"visual_actions": {
					"judgment": {"animation": "Spell3_0", "durations": [3.0], "kind": "skill", "blend_in": 0.0, "blend_out": 0.0},
				},
				"death": "Death", "death_duration": 0.8,
			},
			"color": Color(0.35, 0.55, 0.90),
			"active_skills": [{ "icon_path": "res://assets/skills/garen_0.png",
				},{ "icon_path": "res://assets/skills/garen_1.png", "visual_action": "judgment",
				}],
		},
		"card_art": {}, # 默认 assets/cards/<card_id>_loading.*
		"audio": {
			"attack_swing": [
				[
					"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_oncast_r1.wav",
					"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_oncast_r2.wav",
					"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_oncast_r3.wav",
					"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_oncast_r4.wav",
				],
				[
					"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack2_oncast_r3.wav",
					"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack2_oncast_r4.wav",
				],
			],
			"attack_hit": [
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_1153642577_r2_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_1153642577_r3_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_1153642577_r4_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_1216965916_r1_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_1216965916_r2_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_1216965916_r3_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_1216965916_r4_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_2058049674_r1_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_2058049674_r2_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_2058049674_r3_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_2058049674_r4_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_2473969246_r1_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_2473969246_r2_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_2473969246_r3_d.wav",
				"res://assets/audio/units/garen/play_sfx_garen_garenbasicattack_onhit_1559186049_2473969246_r4_d.wav",
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_volume_db": 0.0,
			"events": {
				# 用户指定的三段部署候选共用一个池，每次生成只播放其中一个。
				"deploy:voice": {"pool": [
					"res://assets/audio/units/garen/champion_choose_86_zh_cn.wav",
					"res://assets/audio/units/garen/play_vo_garen_move2dstandard_r16_zh_cn.wav",
					"res://assets/audio/units/garen/play_vo_garen_move2dstandard_r11_zh_cn.wav",
				], "volume_db": 0.0, "bus": "Voice"},
				"empowered_buff:start": {"pool": ["res://assets/audio/units/garen/play_sfx_garen_garenq_onbuffactivate_r1.wav", "res://assets/audio/units/garen/play_sfx_garen_garenq_onbuffactivate_r2.wav"], "volume_db": 0.0, "bus": "Combat"},
				"empowered_buff:end": {"pool": ["res://assets/audio/units/garen/play_sfx_garen_garenq_onbuffdeactivate.wav"], "volume_db": 0.0, "bus": "Combat"},

				"empowered_ready": {"pool": [
						"res://assets/audio/units/garen/play_sfx_garen_garenq_oncast_r1.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garenq_oncast_r2.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garenq_oncast_r3.wav",
					], "volume_db": 0.0},
				"empowered_swing": {"pool": [
						"res://assets/audio/units/garen/play_sfx_garen_garenqattack_oncast_r.wav",
					], "volume_db": 0.0},
				"judgment:start": {"pool": [
						"res://assets/audio/units/garen/play_sfx_garen_garene_oncast_r1.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garene_oncast_r2.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garene_oncast_r3.wav",
					], "volume_db": 0.0},
				"judgment:sustain": {"pool": [
						"res://assets/audio/units/garen/play_sfx_garen_garene_onbuffactivate_r1.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garene_onbuffactivate_r2.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garene_onbuffactivate_r3.wav",
					], "volume_db": 0.0},
				"judgment:end": {"pool": [
						"res://assets/audio/units/garen/play_sfx_garen_garene_onbuffdeactivate_r1.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garene_onbuffdeactivate_r2.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garene_onbuffdeactivate_r3.wav",
					], "volume_db": 0.0},
				"judgment:hit": {"pool": [
						"res://assets/audio/units/garen/play_sfx_garen_garene_hit_r1.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garene_hit_r2.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garene_hit_r3.wav",
						"res://assets/audio/units/garen/play_sfx_garen_garene_hit_r4.wav",
					], "volume_db": 0.0},
				"death": {"pool": [
						"res://assets/audio/units/garen/play_sfx_garen_death3d_cast.wav",
					], "volume_db": 0.0},
			},
		},
	}
