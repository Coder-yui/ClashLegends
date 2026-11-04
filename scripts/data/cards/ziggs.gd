extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "爆破鬼才", "cost": 3, "type": "unit",
			"description": "对地范围投弹手，炸弹落点在出手时锁定，不追踪目标。爆破专家：攻击后摧毁生命低于15%的建筑，对防御塔和水晶为10%。",
			"hp": 360, "damage": 70, "range": 160.0, "speed": SPEED_MEDIUM,
			"interval": 1.5, "first_hit": 0.5, "empowered_first_hit": 0.38,
			"size_tier": SIZE_SLIGHTLY_SMALL, "radius": RADIUS_SLIGHTLY_SMALL,
			"mass": 2.5, "sight": 240.0, "is_air": false, "building_only": false, "can_attack_air": false,
			"projectile_speed": 360.0, "projectile_collision_radius": 4.0, "splash_radius": 30.0,
			"ballistic_attack": true, "structure_execute_ratio": 0.15, "tower_execute_ratio": 0.1,
			"active_skills": [{"name": "弹跳炸弹", "kind": "empowered_attack", "cost": 1, "max_uses": 2, "cooldown": 9.0,
				"description": "接下来3次攻击沿固定方向弹跳，每枚炸弹落地3次，每次造成70点、半径1格的范围伤害；后两跳各向前延伸1.5格。再次释放刷新为3次。",
				"empowered_damage_multiplier": 1.0, "attack_count": 3, "radius": 40.0, "bounce_count": 3, "bounce_distance": 60.0,
				"cast_duration": 0.0, "impact_delay": 0.0, "cast_locks": []}],
		},
		"visual": {
			"visual_active_buff_scene": "res://assets/effects/ziggs/empowered.tscn",
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/ziggs/player.gd", "variant": "basic"}, {"provider": "res://assets/effects/ziggs/player.gd", "variant": "hit"}, {"provider": "res://assets/effects/ziggs/player.gd", "variant": "missile"}, {"provider": "res://assets/effects/ziggs/player.gd", "variant": "missile2"}, {"provider": "res://assets/effects/ziggs/player.gd", "variant": "missile3"}, {"provider": "res://assets/effects/ziggs/player.gd", "variant": "passive"}]},
			"visual_radius": RADIUS_SLIGHTLY_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/ziggs/ziggs_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Ziggs_Idle1_anm", "idle": "Ziggs_Idle1_anm", "move": "Run", "attack": ["Attack1", "Attack2"], "empowered_attack": "Spell1", "death": "Death", "death_duration": 0.8},
			"projectile_visual": "ziggs_bomb", "projectile_visual_height": 28.0, "projectile_impact_visual": "ziggs_explosion",
			"color": Color(1.0, 0.55, 0.12), "active_skills": [{"icon_path": "res://assets/skills/ziggs_q.png"}],
		},
		# BEGIN IMPORTED AUDIO ziggs
		"audio": {
			"events": {
				"bomb:basic_impact": {"pool": [
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_onhit_r1_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_onhit_r2_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_onhit_r3_d.wav"
				], "volume_db": 0.0, "bus": "Combat"},
				"bomb:impact": {"pool": [
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsq_hit_r1.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsq_hit_r2.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsq_hit_r3.wav"
				], "volume_db": 0.0, "bus": "Combat"},
				"deploy:voice": {"pool": ["res://assets/audio/units/ziggs/deploy_choose_zh_cn.ogg"], "volume_db": 0.0, "bus": "Voice"},
				"empowered_swing": {
					"pool": [
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsq_oncast_r1.wav",
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsq_oncast_r2.wav",
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsq_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death:voice": {
					"pool": [
						"res://assets/audio/units/ziggs/play_vo_ziggs_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/ziggs/play_vo_ziggs_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/ziggs/play_vo_ziggs_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/ziggs/play_sfx_ziggs_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"empowered_launch": {
					"pool": [
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsqspell_onmissilelaunch_r1.wav",
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsqspell_onmissilelaunch_r2.wav",
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsqspell_onmissilelaunch_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"empowered_ready": {
					"pool": [
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsshortfuse_onbuffactivate_r1.wav",
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsshortfuse_onbuffactivate_r2.wav",
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsshortfuse_onbuffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"bomb:second_launch": {
					"pool": [
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsqspell2_onmissilelaunch_r.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"bomb:third_launch": {
					"pool": [
						"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsqspell3_onmissilelaunch_r_d.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_oncast_r3_d.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_launch_by_segment": [
				[
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_onmissilelaunch_r1_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_onmissilelaunch_r2_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_onmissilelaunch_r3_d.wav"
				],
				[
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_onmissilelaunch_r1_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_onmissilelaunch_r2_d.wav",
					"res://assets/audio/units/ziggs/play_sfx_ziggs_ziggsbasicattack_onmissilelaunch_r3_d.wav"
				]
			],
		},
		# END IMPORTED AUDIO ziggs
		"card_art": {"path": "res://assets/cards/ziggs_loading.png"},
	}
