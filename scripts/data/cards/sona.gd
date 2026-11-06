extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "琴瑟仙女", "cost": 4, "type": "unit",
			"description": "空中后排，可对地对空。部署完成2秒后首次奏响，之后每5秒奏响坚毅咏叹调，自身160范围内友军每0.5秒回复18生命，持续3秒。含自身，不含建筑。",
			"hp": 560, "damage": 52, "range": 190.0,
			"speed": SPEED_SLOW, "interval": 1.4, "first_hit": 0.52,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 4.0, "sight": 270.0,
			"projectile_speed": 420.0, "projectile_spawn_at_edge": true,
			"projectile_spawn_offset": 7.5, "projectile_collision_radius": 4.0,
			"is_air": true, "building_only": false, "can_attack_air": true,
			"heal_aura_initial_delay": 2.0, "heal_aura_trigger_interval": 5.0, "heal_aura_radius": 160.0, "heal_aura_duration": 3.0,
			"heal_aura_pulse_interval": 0.5, "heal_aura_amount": 18.0,
			"active_skills": [{
				"name": "狂舞终乐章", "kind": "frontal", "shape": "trapezoid",
				"cost": 2, "max_uses": 2, "cooldown": 12.0,
				"description": "向前发出长320、宽140的穿透音波，以640/秒飞行；敌方地面、空中单位及建筑受到140伤害和1秒眩晕，水晶免疫眩晕；同次施法只命中一次。",
				"length": 320.0, "near_width": 140.0, "far_width": 140.0,
				"projectile_count": 1, "projectile_piercing": true,
				"projectile_launch_delay": 0.3, "projectile_flight_duration": 0.5,
				"damage": 140, "stun_duration": 1.0,
				"impact_delay": 0.3, "cast_duration": 1.0,
				"cast_locks": ["movement", "attack", "facing"],
			}],
		},
		"visual": {
			"visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/sona/sona_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2", "Attack3"], "death": "Death", "death_duration": 0.8,
				"visual_actions": {"crescendo": {"animation": "Spell4", "durations": [1.0], "clip_ranges": [[0.0, 1.0]], "kind": "skill"}},
			},
			"visual_active_buff_scene": "res://assets/effects/sona/heal_aura.tscn",
			"projectile_visual": "sona_bolt", "projectile_visual_height": 70.0,
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/sona/player.gd", "variant": "basic"}, {"provider": "res://assets/effects/sona/player.gd", "variant": "heal_self"}]},
			"active_skills": [{"visual_action": "crescendo", "icon_path": "res://assets/skills/sona_0.png", "projectile_visual": "sona_wave", "projectile_model_launch": true, "projectile_visual_height": 70.0,
				"resource_dependencies": {"effects": [{"provider": "res://assets/effects/sona/player.gd", "variant": "wave"}, {"provider": "res://assets/effects/sona/player.gd", "variant": "cast"}]}}],
			"color": Color(0.2, 0.8, 0.65),
		},
		# BEGIN IMPORTED AUDIO sona
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/sona/deploy_voice.ogg"], "volume_db": 0.0, "clip_volume_db": {"res://assets/audio/units/sona/deploy_voice.ogg": -12.5}, "bus": "Voice"},
				"attack_launch": {
					"pool": [
						"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_onmissilelaunch_r1_d.wav",
						"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_onmissilelaunch_r2_d.wav",
						"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_onmissilelaunch_r3_d.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"heal_aura:start": {
					"pool": [
						"res://assets/audio/units/sona/play_sfx_sona_sonaw_oncast_r1.wav",
						"res://assets/audio/units/sona/play_sfx_sona_sonaw_oncast_r2.wav",
						"res://assets/audio/units/sona/play_sfx_sona_sonaw_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"heal_aura:sustain": {
					"pool": [
						"res://assets/audio/units/sona/play_sfx_sona_sonaambientwsound_onbuffactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"crescendo:sustain": {
					"pool": [
						"res://assets/audio/units/sona/play_sfx_sona_sonar_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"crescendo:release": {
					"pool": [
						"res://assets/audio/units/sona/play_sfx_sona_sonar_onmissilelaunch.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"crescendo:hit": {
					"pool": [
						"res://assets/audio/units/sona/play_sfx_sona_sonar_onhit_r1.wav",
						"res://assets/audio/units/sona/play_sfx_sona_sonar_onhit_r2.wav",
						"res://assets/audio/units/sona/play_sfx_sona_sonar_onhit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_oncast_r3_d.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit": [
				"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_onhit_r1_d.wav",
				"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_onhit_r2_d.wav",
				"res://assets/audio/units/sona/play_sfx_sona_sonabasicattack_onhit_r3_d.wav"
			],
			"attack_hit_volume_db": 0.0,
			"attack_swing_lead_time": 0.1
		},
		# END IMPORTED AUDIO sona
		"card_art": {"path": "res://assets/cards/sona_portrait.tres"},
	}
