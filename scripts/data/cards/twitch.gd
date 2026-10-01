extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "图奇", "cost": 4, "type": "unit",
			"description": "隐身远程射手。攻击起手破隐，开启技能保持隐身，连续2秒没有攻击、施法或受伤后重新隐身；双方玩家都可见虚化模型，隐身不免疫范围伤害。",
			"hp": 420, "damage": 68, "range": 170.0,
			"speed": SPEED_MEDIUM, "interval": 1.0, "first_hit": 0.24,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 3.0, "sight": 300.0, "stealth_delay": 2.0,
			"projectile_speed": 520.0, "projectile_spawn_at_edge": true,
			"projectile_spawn_offset": 7.5, "projectile_collision_radius": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "火力全开", "kind": "buff", "cost": 2, "max_uses": 1, "cooldown": 0.0,
				"description": "持续5秒，攻速提高50%，弹速翻倍，攻击距离从170提升到200；普攻变为固定飞行300距离的直线穿透弩箭，不追踪移动目标，每支箭对沿途每个敌人造成一次完整普攻伤害。",
				"duration": 5.0, "attack_speed_multiplier": 1.5,
				"projectile_speed_multiplier": 2.0, "range_bonus": 30.0, "piercing_attacks": true, "piercing_distance": 300.0,
				"cast_duration": 0.25, "impact_delay": 0.0, "cast_locks": [],
			}],
		},
		"visual": {
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/twitch/twitch_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "deploy_clip_ratio": 1.0 / 3.2999982833862305, "idle": "Idle1_Base", "move": "Run",
				"stealth_idle": "Idle_Stealth", "stealth_move": "Run_Stealth",
				"clip_blends": {
					"Run>Run": 0.0,
					"Run>Death": 0.0,
					"Attack1>Death": 0.0,
					"Attack2>Death": 0.0,
					"Idle_Stealth>Idle_Stealth": 0.0,
					"Idle_Stealth>Death": 0.0,
					"Idle1_Base>Idle1_Base": 0.0,
					"Idle1_Base>Death": 0.0,
					"Respawn>Respawn": 0.0,
					"Respawn>Death": 0.0,
					"Spell4>Death": 0.0,
					"Death>Death": 0.0,
					"Run_Stealth>Death": 0.0,
					"Run_Stealth>Run_Stealth": 0.0,
				},
				"active_buff_attack": "Spell4", "attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.8,
			},
			"active_buff_projectile_visual": "venom_bolt",
			"projectile_visual": "crossbow_bolt", "projectile_visual_height": 30.0 * CHARACTER_SCALE_MULTIPLIER,
			"color": Color(0.45, 0.80, 0.16),
			"active_skills": [{"icon_path": "res://assets/skills/twitch_0.png"}],
		},
		# BEGIN IMPORTED AUDIO twitch
		"audio": {
			"events": {
				"active_buff:attack_launch": {"pool": ["res://assets/audio/units/twitch/spray_and_pray_onmissilelaunch_1.wav", "res://assets/audio/units/twitch/spray_and_pray_onmissilelaunch_2.wav", "res://assets/audio/units/twitch/spray_and_pray_onmissilelaunch_3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_buff:attack_hit": {"pool": ["res://assets/audio/units/twitch/spray_and_pray_onhit_1.wav", "res://assets/audio/units/twitch/spray_and_pray_onhit_2.wav", "res://assets/audio/units/twitch/spray_and_pray_onhit_3.wav"], "volume_db": -5.0, "bus": "Combat"},

				"deploy:voice": {"pool": ["res://assets/audio/units/twitch/deploy_q_end_r4_zh_cn.wav", "res://assets/audio/units/twitch/deploy_q_end_r1_zh_cn.wav", "res://assets/audio/units/twitch/deploy_q_end_r3_zh_cn.wav"], "volume_db": 0.0, "bus": "Voice"},
				"stealth:enter": {"pool": ["res://assets/audio/units/twitch/twitch_q_enter.wav"], "volume_db": -3.0, "bus": "Combat"},
				"stealth:exit": {"pool": ["res://assets/audio/units/twitch/twitch_q_exit.wav"], "volume_db": -3.0, "bus": "Combat"},

				"attack_launch": {
					"pool": [
						"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_onmissilelaunch_r1.wav",
						"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_onmissilelaunch_r2.wav",
						"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_onmissilelaunch_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_buff:start": {
					"pool": [
						"res://assets/audio/units/twitch/play_sfx_twitch_twitchfullautomatic_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_buff:end": {
					"pool": [
						"res://assets/audio/units/twitch/play_sfx_twitch_twitchfullautomatic_onbuffdeactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/twitch/play_vo_twitch_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/twitch/play_vo_twitch_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/twitch/play_vo_twitch_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_oncast_r1.wav",
					"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_oncast_r2.wav",
					"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_oncast_r1.wav",
					"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_oncast_r2.wav",
					"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_onhit_1559186049_1153642577_r1.wav",
				"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_onhit_1559186049_1153642577_r2.wav",
				"res://assets/audio/units/twitch/play_sfx_twitch_twitchbasicattack_onhit_1559186049_1153642577_r3.wav"
			],
			"attack_hit_volume_db": -5.0
		},
		# END IMPORTED AUDIO twitch
		"card_art": {},
	}
