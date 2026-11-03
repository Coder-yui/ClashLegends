extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "荆棘喷射者", "cost": 4, "type": "building",
			"description": "发射尖刺攻击地面与空中敌人。",
			"hp": 800, "damage": 100, "range": 240.0,
			"speed": 0.0, "interval": 1.25, "first_hit": 0.08,
			"radius": 21.0, "size_tier": "slightly_large",
			"footprint_tiles": Vector2i(2, 2), "is_building": true,
			"lifespan": 25.0, "lifespan_hp_decay": true,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"projectile_speed": 520.0, "projectile_collision_radius": 3.0,
			"active_skills": [{"name": "致命棘刺", "kind": "buff", "cost": 2, "max_uses": 2, "cooldown": 14.0,
				"duration": 6.0, "health_bonus_ratio": 0.5, "body_scale_multiplier": 1.25,
				"damage_multiplier": 1.5,
				"cast_duration": 0.0, "impact_delay": 0.0, "cast_locks": [],
				"description": "持续6秒：最大生命值提高50%并获得新增生命，模型与碰撞增大25%，攻击造成150%伤害（单发150）。"}],
		},
		"visual": {
			"visual_active_buff_scene": "res://assets/effects/thorn_spitter/buff.tscn",
			"active_skills": [{"icon_path": "res://assets/skills/zyra_q.png", "resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/thorn_spitter/player.gd", "variant": "buff"}]}}],
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/thorn_spitter/player.gd", "variant": "missile"}]},
			"visual_scene_path": "res://assets/units/thorn_spitter/thorn_spitter_view.tscn",
			"visual_radius": 30.0, "visual_forward_yaw": 0.0,
			"color": Color(0.8, 0.2, 0.2), "show_team_ring": false,
			"projectile_visual": "thorn_spitter_bullet", "projectile_visual_height": 50.0,
			"visual_animations": {
				"deploy": "Up", "idle": "Idle1", "attack": "Attack1", "death": "Death", "death_duration": 0.8,
			},
		},
		# BEGIN IMPORTED AUDIO thorn_spitter
		"audio": {
			"events": {
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/thorn_spitter/play_sfx_zyra_zyraqplant_onbuffactivate_r1.wav",
						"res://assets/audio/units/thorn_spitter/play_sfx_zyra_zyraqplant_onbuffactivate_r2.wav",
						"res://assets/audio/units/thorn_spitter/play_sfx_zyra_zyraqplant_onbuffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/thorn_spitter/play_sfx_zyra_zyraqplant_onbuffdeactivate_d.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/thorn_spitter/play_sfx_zyrathornplant_zyraqplantmissile_oncast_r1_d.wav",
					"res://assets/audio/units/thorn_spitter/play_sfx_zyrathornplant_zyraqplantmissile_oncast_r2_d.wav",
					"res://assets/audio/units/thorn_spitter/play_sfx_zyrathornplant_zyraqplantmissile_oncast_r3_d.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit": [
				"res://assets/audio/units/thorn_spitter/play_sfx_zyrathornplant_zyraqplantmissile_onhit_r1_d.wav",
				"res://assets/audio/units/thorn_spitter/play_sfx_zyrathornplant_zyraqplantmissile_onhit_r2_d.wav",
				"res://assets/audio/units/thorn_spitter/play_sfx_zyrathornplant_zyraqplantmissile_onhit_r3_d.wav"
			],
			"attack_hit_volume_db": 0.0,
			"attack_launch_by_segment": [
				[
					"res://assets/audio/units/thorn_spitter/play_sfx_zyrathornplant_zyraqplantmissile_missilelaunch_r1.wav",
					"res://assets/audio/units/thorn_spitter/play_sfx_zyrathornplant_zyraqplantmissile_missilelaunch_r2.wav",
					"res://assets/audio/units/thorn_spitter/play_sfx_zyrathornplant_zyraqplantmissile_missilelaunch_r3.wav"
				]
			]
		},
		# END IMPORTED AUDIO thorn_spitter
		"card_art": {"path": "res://assets/cards/thorn_spitter_loading.png"},
	}
