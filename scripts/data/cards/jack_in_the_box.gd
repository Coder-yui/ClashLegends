extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "惊吓魔盒", "cost": 5, "type": "building",
			"description": "部署时隐身，部署完成后首次发现范围内敌人时破隐，使范围内敌方单位眩晕1秒。同时射击范围内全部敌人，单目标伤害翻倍；破隐后不再隐身。",
			"hp": 800, "damage": 50, "range": 160.0, "sight": 220.0,
			"speed": 0.0, "interval": 1.0, "first_hit": 0.33,
			"radius": RADIUS_SLIGHTLY_LARGE, "size_tier": SIZE_SLIGHTLY_LARGE,
			"footprint_tiles": Vector2i(2, 2), "is_building": true,
			"lifespan": 30.0, "lifespan_hp_decay": true,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"proximity_reveal_stun": 1.0, "attack_all_in_range": true, "isolated_attack_multiplier": 2.0,
			"projectile_speed": 520.0, "projectile_spawn_at_edge": false,
			"projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
			"active_skills": [{"name": "惊吓", "kind": "nova", "cost": 1, "max_uses": 2, "cooldown": 10.0,
				"radius": 181.0, "radius_from_attack_range": true, "damage": 0, "stun_duration": 1.0,
				"cast_duration": 0.0, "impact_delay": 0.0, "cast_locks": [],
				"description": "使攻击范围内敌方单位眩晕1秒。"}],
		},
		"visual": {
			"visual_scene_path": "res://assets/units/jack_in_the_box/box_view.tscn",
			"visual_radius": 30.0, "visual_forward_yaw": 0.0,
			"color": Color(0.63, 0.25, 0.78),
			"visual_animations": {"idle": "Idle1", "attack": "Attack1", "death": "Death", "death_duration": 0.8},
			"projectile_visual": "jack_in_the_box_bullet", "projectile_visual_height": 40.0,
			"projectile_colors": [Color(0.65, 0.25, 0.95), Color(0.85, 0.2, 0.7)],
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/jack_in_the_box/player.gd", "variant": "missile"}, {"provider": "res://assets/effects/jack_in_the_box/player.gd", "variant": "aoe"}]},
			"active_skills": [{"icon_path": "res://assets/skills/jack_in_the_box_0.png"}],
		},
		# BEGIN IMPORTED AUDIO jack_in_the_box
		"audio": {
			"events": {
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_oncast_r1.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_oncast_r2.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"stealth:exit": {
					"pool": [
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_buffactivate_r1.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_buffactivate_r2.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_buffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active:impact": {
					"pool": [
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_buffactivate_r1.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_buffactivate_r2.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_buffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_onbuffdeactivate_r1.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_onbuffdeactivate_r2.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shaco_jackinthebox_onbuffdeactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"attack_launch": {
					"pool": [
						"res://assets/audio/units/jack_in_the_box/play_sfx_shacobox_shacoboxspell_onmissilelaunch_r1.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shacobox_shacoboxspell_onmissilelaunch_r2.wav",
						"res://assets/audio/units/jack_in_the_box/play_sfx_shacobox_shacoboxspell_onmissilelaunch_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_hit": [
				"res://assets/audio/units/jack_in_the_box/play_sfx_shacobox_shacoboxspell_onhit_r1.wav",
				"res://assets/audio/units/jack_in_the_box/play_sfx_shacobox_shacoboxspell_onhit_r2.wav",
				"res://assets/audio/units/jack_in_the_box/play_sfx_shacobox_shacoboxspell_onhit_r3.wav"
			],
			"attack_hit_volume_db": 0.0
		},
		# END IMPORTED AUDIO jack_in_the_box
		"card_art": {"path": "res://assets/cards/jack_in_the_box_loading.png"},
	}
