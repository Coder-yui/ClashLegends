extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "麦林炮手", "cost": 4, "type": "unit",
			"description": "射程较长、对地对空的远程炮手，开启急速射击后短时间大幅提高攻速。",
			"hp": 440, "damage": 76, "range": 220.0,
			"speed": SPEED_MEDIUM, "interval": 1.0, "first_hit": 0.12,
			"size_tier": SIZE_SLIGHTLY_SMALL, "radius": RADIUS_SLIGHTLY_SMALL,
			"mass": 2.5, "sight": 260.0,
			"projectile_speed": 580.0, "projectile_spawn_at_edge": true,
			"projectile_spawn_offset": 7.5, "projectile_collision_radius": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "急速射击", "kind": "buff", "cost": 2, "max_uses": 2, "cooldown": 12.0,
				"description": "持续5秒，攻击速度提高60%，攻击间隔缩短至0.625秒。",
				"duration": 5.0, "attack_speed_multiplier": 1.6,
				"cast_duration": 0.25, "impact_delay": 0.0, "cast_locks": [],
			}],
		},
		"visual": {
			"resource_dependencies": {
				"effects": [
					{
						"provider": "res://assets/effects/gwen_tristana/player.gd",
						"variant": "missile"
					}
				]
			},
			"visual_radius": RADIUS_SLIGHTLY_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/tristana/tristana_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run",
				"attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 0.8,
			},
			"visual_active_buff_scene": "res://assets/effects/tristana/rapid_fire.tscn",
			"projectile_visual": "tristana_bullet", "projectile_visual_height": 30.0,
			"color": Color(1.0, 0.60, 0.15),
			"active_skills": [{"resource_dependencies": {
				"effects": [
					{
						"provider": "res://assets/effects/gwen_tristana/player.gd",
						"variant": "rapid"
					}
				],
				"fields": [
					"visual_active_buff_scene"
				]
			}, "icon_path": "res://assets/skills/tristana_0.png"}],
		},
		# BEGIN IMPORTED AUDIO tristana
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/tristana/deploy_crossfire_zh_cn.wav", "res://assets/audio/units/tristana/deploy_ready_aim_fire_zh_cn.wav", "res://assets/audio/units/tristana/deploy_cannot_touch_me_zh_cn.wav"], "volume_db": 0.0, "bus": "Voice"},
				"attack_launch": {
					"pool": [
						"res://assets/audio/units/tristana/play_sfx_tristana_tristanabasicattack_onmissilelaunch_r1_d.wav",
						"res://assets/audio/units/tristana/play_sfx_tristana_tristanabasicattack_onmissilelaunch_r2_d.wav",
						"res://assets/audio/units/tristana/play_sfx_tristana_tristanabasicattack_onmissilelaunch_r3_d.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_buff:start": {
					"pool": [
						"res://assets/audio/units/tristana/play_sfx_tristana_tristanaq_oncast_r1.wav",
						"res://assets/audio/units/tristana/play_sfx_tristana_tristanaq_oncast_r2.wav",
						"res://assets/audio/units/tristana/play_sfx_tristana_tristanaq_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_buff:end": {
					"pool": [
						"res://assets/audio/units/tristana/play_sfx_tristana_tristanaq_onbuffdeactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/tristana/play_vo_tristana_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/tristana/play_vo_tristana_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/tristana/play_vo_tristana_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_hit": [
				"res://assets/audio/units/tristana/play_sfx_tristana_tristanabasicattack_onhit_1559186049_1153642577_r_d.wav"
			],
			"attack_hit_volume_db": 0.0
		},
		# END IMPORTED AUDIO tristana
		"card_art": {},
	}
