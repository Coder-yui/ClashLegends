extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "翠神", "cost": 3, "type": "unit",
			"description": "射程稍长的远程后排，可攻击地面和空中目标。主动技能召唤前排护卫小菊。",
			"hp": 480, "damage": 65, "range": 240.0, "sight": 280.0,
			"speed": SPEED_SLIGHTLY_SLOW, "interval": 1.5, "first_hit": 0.11, "deploy_time": 1.0,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 3.0,
			"projectile_speed": 480.0, "projectile_collision_radius": 3.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{"name": "小菊！", "kind": "summon", "cost": 3, "max_uses": 1, "cooldown": 20.0,
				"spawn_id": "daisy", "spawn_count": 1, "spawn_forward_distance": 40.0, "spawn_deploy_time": 1.3,
				"cast_duration": 1.0, "impact_delay": 0.2,
				"description": "召唤护卫小菊。小菊每第三次攻击额外造成60伤害，并眩晕目标1秒。"}],
		},
		"visual": {
			"color": Color(0.36, 0.67, 0.31), "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/ivern/ivern_view.tscn", "visual_forward_yaw": 0.0,
			"projectile_visual_height": 80.0, "projectile_visual": "ivern_bolt",
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/ivern/player.gd", "variant": "basic"}]},
			"visual_animations": {"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run_Base",
				"attack": ["Ivern_ranged_attack01_anm", "Ivern_ranged_attack02_anm"], "death": "Death", "death_duration": 0.8,
				"visual_actions": {"active": {"animation": "Spell4", "kind": "skill"}}},
			"active_skills": [{"visual_action": "active", "icon_path": "res://assets/skills/ivern_r.png"}],
		},
		# BEGIN IMPORTED AUDIO ivern
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/ivern/deploy.ogg"], "bus": "Voice", "clip_volume_db": {"res://assets/audio/units/ivern/deploy.ogg": -8.0}},
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/ivern/play_sfx_ivern_respawn3d_buffactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/ivern/play_sfx_ivern_death3d_buffactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death:voice": {
					"pool": [
						"res://assets/audio/units/ivern/play_vo_ivern_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/ivern/play_vo_ivern_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/ivern/play_vo_ivern_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"active:cast": {
					"pool": [
						"res://assets/audio/units/ivern/play_sfx_ivern_ivernr_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/ivern/play_sfx_ivern_ivernbasicattackranged_cast_r1.wav",
					"res://assets/audio/units/ivern/play_sfx_ivern_ivernbasicattackranged_cast_r2.wav",
					"res://assets/audio/units/ivern/play_sfx_ivern_ivernbasicattackranged_cast_r3.wav"
				],
				[
					"res://assets/audio/units/ivern/play_sfx_ivern_ivernbasicattackranged_cast_r1.wav",
					"res://assets/audio/units/ivern/play_sfx_ivern_ivernbasicattackranged_cast_r2.wav",
					"res://assets/audio/units/ivern/play_sfx_ivern_ivernbasicattackranged_cast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit": [
				"res://assets/audio/units/ivern/play_sfx_ivern_ivernbasicattackranged_hit_1559186049_1153642577_r1.wav",
				"res://assets/audio/units/ivern/play_sfx_ivern_ivernbasicattackranged_hit_1559186049_1153642577_r2.wav",
				"res://assets/audio/units/ivern/play_sfx_ivern_ivernbasicattackranged_hit_1559186049_1153642577_r3.wav"
			],
			"attack_hit_volume_db": 0.0
		},
		# END IMPORTED AUDIO ivern
		"card_art": {"path": "res://assets/cards/ivern_portrait.tres"},
	}
