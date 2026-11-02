extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "H-28G进化炮台", "cost": 4, "type": "building",
			"description": "对地对空的远程炮台。射程内没有可攻击敌人时收缩待机，敌方不可选取；敌人进入射程后立即恢复攻击。",
			"hp": 720, "damage": 70, "range": 220.0,
			"speed": 0.0, "interval": 0.8, "first_hit": 0.21,
			"radius": 21.0, "size_tier": "slightly_large",
			"footprint_tiles": Vector2i(2, 2), "is_building": true,
			"lifespan": 24.0, "lifespan_hp_decay": true,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"projectile_speed": 500.0, "projectile_collision_radius": 3.0,
			"dormant_without_targets": true,
			"active_skills": [{"name": "海克斯修复", "kind": "buff", "cost": 1, "max_uses": 2, "cooldown": 8.0,
				"heal_amount": 240.0, "duration": 0.0, "cast_duration": 0.0, "impact_delay": 0.0, "cast_locks": [],
				"description": "修复炮台，回复240生命，自然衰血速度不变。"}],
		},
		"visual": {
			"visual_scene_path": "res://assets/units/evolution_turret/evolution_turret_view.tscn",
			"visual_radius": 30.0, "visual_forward_yaw": 0.0,
			"color": Color(0.75, 0.62, 0.2), "show_team_ring": false,
			"projectile_visual": "evolution_turret_bullet", "projectile_visual_height": 24.0,
			"visual_animations": {
				"visual_actions": {"activate": {"animation": "Activate", "durations": [0.2], "kind": "skill"}},
				"deploy": "Spawn", "idle": "Idle1", "dormant_idle": "Deactivate_Idle",
				"attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.8,
				"transitions": {"dormant>idle": "Deactivate"},
			},
			"active_skills": [{"icon_path": "res://assets/skills/heimerdinger_passive.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/evolution_turret/player.gd", "variant": "spawn"}]}}],
		},
		# BEGIN IMPORTED AUDIO evolution_turret
		"audio": {
			"events": {"dormant:enter": {"pool": ["res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerturretshutdown_onbuffactivate_r1.wav", "res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerturretshutdown_onbuffactivate_r2.wav", "res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerturretshutdown_onbuffactivate_r3.wav"], "volume_db": 0.0, "bus": "Combat"},"dormant:exit": {"pool": ["res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r1_d.wav", "res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r2_d.wav", "res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r3_d.wav"], "volume_db": -6.0, "bus": "Combat"},
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r1_d.wav",
						"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r2_d.wav",
						"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r3_d.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffdeactivate_r1.wav",
						"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffdeactivate_r2.wav",
						"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffdeactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active:cast": {
					"pool": [
						"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r1_d.wav",
						"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r2_d.wav",
						"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r3_d.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_launch_by_segment": [
				[
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onmissilelaunch_r1.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onmissilelaunch_r2.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onmissilelaunch_r3.wav"
				],
				[
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onmissilelaunch_r1.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onmissilelaunch_r2.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onmissilelaunch_r3.wav"
				]
			],
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onhit_r1.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onhit_r2.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onhit_r3.wav"
				],
				[
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onhit_r1.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onhit_r2.wav",
					"res://assets/audio/units/evolution_turret/play_sfx_heimertyellow_heimertyellowbasicattack2_onhit_r3.wav"
				]
			]
		},
		# END IMPORTED AUDIO evolution_turret
		"card_art": {"path": "res://assets/cards/evolution_turret_loading.png"},
	}
