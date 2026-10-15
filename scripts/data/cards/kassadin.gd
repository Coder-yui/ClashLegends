extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "虚空行者", "cost": 3, "type": "unit",
			"description": "浮空地面战士，可直接过河。虚空之石：永久穿过普通单位，仍受建筑、塔和水晶阻挡。",
			"hp": 620, "damage": 90, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.2, "first_hit": 0.21,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 4.0, "sight": 210.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"river_traversal": true, "permanent_unit_phasing": true,
			"active_skills": [{"name": "虚空行走", "kind": "blink_nova", "cost": 0, "cost_by_use": [0, 1, 2],
				"max_uses": 3, "unlimited_uses": true, "cooldown": 2.0,
				"damage": 80, "damage_by_use": [80, 120, 160], "length": 160.0, "landing_extension": 60.0, "radius": 70.0, "ground_only": false,
				"impact_delay": 0.25, "cast_duration": 0.35, "cast_locks": ["movement", "attack", "facing"],
				"description": "向当前朝向传送160像素；落点被结构阻挡时优先前延，最多额外60+自身半径+2，超限则回退；着陆对周围70像素敌人造成80/120/160伤害。费用0/1/2金币，第三次起费用与伤害封顶，次数不限，每次冷却2秒。"}],
		},
		"visual": {
			"visual_scene_path": "res://assets/units/kassadin/kassadin_view.tscn", "visual_forward_yaw": 0.0,
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/kassadin/player.gd", "variant": "idle_blade"}]},
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING, "color": Color(0.48, 0.20, 0.72),
			"visual_animations": {"deploy": "Respawn", "idle": "Idle1", "move": "Run_Base", "attack": ["Attack1", "Attack2"],
				"death": "Death", "death_duration": 0.8,
				"transitions": {"Spell4>move": "Spell4_To_Run"},
				"transition_blends": {"locomotion": 0.16, "action_out": 0.16},
				"clip_blends": {"Respawn>Run_Base": 0.18, "Respawn>Idle1": 0.18,
					"Respawn>Attack1": 0.14, "Respawn>Attack2": 0.14},
				"visual_actions": {"active": {"animation": "Spell4", "kind": "skill"}}},
			"active_skills": [{"visual_action": "active", "icon_path": "res://assets/skills/kassadin_r.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/kassadin/player.gd", "variant": "appear"}, {"provider": "res://assets/effects/kassadin/player.gd", "variant": "vanish"}]}}],
		},
		# BEGIN IMPORTED AUDIO kassadin
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/kassadin/deploy.ogg"], "bus": "Voice", "volume_db": 0.0, "clip_volume_db": {"res://assets/audio/units/kassadin/deploy.ogg": -13.5}},
				"active:cast": {
					"pool": [
						"res://assets/audio/units/kassadin/play_sfx_kassadin_riftwalk_oncast_r1.wav",
						"res://assets/audio/units/kassadin/play_sfx_kassadin_riftwalk_oncast_r2.wav",
						"res://assets/audio/units/kassadin/play_sfx_kassadin_riftwalk_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active:land": {
					"pool": [
						"res://assets/audio/units/kassadin/play_sfx_kassadin_riftwalk_buffactivate_r1.wav",
						"res://assets/audio/units/kassadin/play_sfx_kassadin_riftwalk_buffactivate_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/kassadin/play_vo_kassadin_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/kassadin/play_vo_kassadin_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/kassadin/play_vo_kassadin_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack_onhit_r1_d.wav",
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack_onhit_r2_d.wav",
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack_onhit_r3_d.wav"
				],
				[
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack2_onhit_r1.wav",
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack2_onhit_r2.wav",
					"res://assets/audio/units/kassadin/play_sfx_kassadin_kassadinbasicattack2_onhit_r3.wav"
				]
			]
		},
		# END IMPORTED AUDIO kassadin
		"card_art": {"path": "res://assets/cards/kassadin_loading.png"},
	}
