extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "潘森", "cost": 4, "type": "unit",
			"description": "进攻核心，可在河道外的全图地面部署，落地伤害周围地面敌人。携带贯星长枪时普攻积累红怒，满4层强化下一次技能。",
			"hp": 640, "damage": 72, "range": 40.0,
			"speed": SPEED_SLIGHTLY_FAST, "interval": 0.9, "first_hit": 0.25,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 5.0, "sight": 220.0,
			"deploy_zone": "global", "pre_deploy_time": 0.6, "deploy_time": 0.7,
			"deploy_sweep_name": "大荒星陨（落地）", "deploy_sweep_radius": 90.0, "deploy_sweep_damage": 100,
			"deploy_sweep_knockback": 0.0, "deploy_sweep_duration": 0.25, "deploy_sweep_mass_factor_max": 1.0,
			"skill_resource_max": 4.0, "skill_resource_attack_gain": 1.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{
				"name": "贯星长枪", "kind": "frontal", "shape": "trapezoid",
				"cost": 1, "cooldown": 5.0, "max_uses": 2,
				"description": "快速向前刺击，造成120点地面伤害。普攻出手获得1层红怒，上限4层；未满层释放保留红怒并加1层，满层释放消耗全部红怒造成240点伤害。",
				"length": 135.0, "near_width": 42.0, "far_width": 42.0,
				"damage": 120, "ground_only": true, "impact_delay": 0.15, "cast_duration": 0.4,
				"cast_locks": ["movement", "attack", "facing"],
				"uses_skill_resource": true, "resource_consume_only_full": true, "resource_nonfull_cast_gain": 1.0,
				"resource_full_damage_multiplier": 2.0,
			}],
		},
		"visual": {
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/pantheon/pantheon_view.tscn", "visual_forward_yaw": 0.0,
			"color": Color(0.76, 0.55, 0.24), "skill_resource_full_color": Color(1.0, 0.15, 0.08, 1.0),
			"visual_animations": {
				"deploy": "Spell4_Hit", "idle": "Idle1", "move": "Run_Base",
				"attack": ["Attack1", "Attack2", "Attack3"],
				"death": "Death", "death_duration": 0.8,
				"transitions": {"Spell1_Hit>idle": "Spell1_Hit_Toidle", "Spell1_Hit>move": "Spell1_Hit_Torun", "Spell4_Hit>idle": "Spell4_Hit_ToIdle"},
				"visual_actions": {
					"spear_tap": {"animation": "Spell1_Hit", "kind": "skill", "blend_in": 0.0},
					"spear_tap_empowered": {"animation": "Spell1_Hit", "kind": "skill", "blend_in": 0.0},
				},
			},
			"active_skills": [{"icon_path": "res://assets/skills/pantheon_q.png", "visual_action": "spear_tap", "full_resource_visual_action": "spear_tap_empowered"}],
		},
		# BEGIN IMPORTED AUDIO pantheon
		"audio": {
			"events": {
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonr_land_vfx.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spear_tap:start": {
					"pool": [
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_cast_lua_r1.wav",
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_cast_lua_r2.wav",
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_cast_lua_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spear_tap:hit": {
					"pool": [
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_hit_vfx_r1.wav",
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_hit_vfx_r2.wav",
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_hit_vfx_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spear_tap_empowered:start": {
					"pool": [
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_cast_empowered_lua_r1.wav",
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_cast_empowered_lua_r2.wav",
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_cast_empowered_lua_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spear_tap_empowered:hit": {
					"pool": [
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_hit_empowered_vfx_r1.wav",
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_hit_empowered_vfx_r2.wav",
						"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonqtap_hit_empowered_vfx_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/pantheon/play_vo_pantheon_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/pantheon/play_vo_pantheon_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/pantheon/play_vo_pantheon_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack_oncast_r1.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack_oncast_r2.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack3_oncast_r1.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack3_oncast_r2.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack3_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack_onhit_1559186049_1153642577_r1.wav",
				"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack_onhit_1559186049_1153642577_r2.wav",
				"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack_onhit_1559186049_1153642577_r3.wav"
			],
			"attack_hit_volume_db": -5.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack_onhit_1559186049_1153642577_r3.wav"
				],
				[
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack2_onhit_1559186049_1153642577_r3.wav"
				],
				[
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack3_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack3_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/pantheon/play_sfx_pantheon_pantheonbasicattack3_onhit_1559186049_1153642577_r3.wav"
				]
			]
		},
		# END IMPORTED AUDIO pantheon
		"card_art": {"path": "res://assets/cards/pantheon_loading.png"},
	}
