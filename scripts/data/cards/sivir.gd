extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "战争女神", "cost": 5, "type": "unit",
			"description": "范围伤害后排。回旋镖固定方向穿透，去程、回程各造成一次伤害，接住后才能再次攻击。",
			"hp": 560, "damage": 70, "range": 160.0,
			"speed": SPEED_MEDIUM, "interval": 1.0, "first_hit": 0.25,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 3.0, "sight": 240.0,
			"projectile_speed": 400.0, "projectile_collision_radius": 12.0,
			"returning_attack_distance": 200.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{"name": "法术护盾", "kind": "effect_shield", "cost": 1, "max_uses": 2, "cooldown": 8.0,
				"duration": 1.5, "block_heal": 120.0, "impact_delay": 0.0, "cast_duration": 0.0, "cast_locks": [],
				"description": "获得1.5秒护盾，抵挡一次敌方攻击、法术或技能及其附带效果，成功抵挡后回复120生命。已有持续效果不消耗护盾。"}],
		},
		"visual": {
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/sivir/shield.gd", "variant": "blade"}]},
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/sivir/sivir_view.tscn", "visual_forward_yaw": 0.0,
			"projectile_visual": "sivir_blade", "projectile_visual_height": 35.0,
			"color": Color(0.95, 0.77, 0.3),
			"visual_animations": {"deploy": "Sivir_Base_Respawn_anm", "idle": "Idle1_Base", "move": "Run",
				"attack": ["Spell1"], "death": "Death", "death_duration": 0.8,
				"visual_actions": {"attack:return": {"animation": "Spell1_Catch", "kind": "skill", "priority": 10, "durations": [0.2], "blend_in": 0.03, "blend_out": 0.08}}},
			"visual_active_buff_scene": "res://assets/effects/sivir/shield.tscn",
			"active_skills": [{"icon_path": "res://assets/skills/sivir_e.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/sivir/shield.gd", "variant": "shield"}], "fields": ["visual_active_buff_scene"]}}],
		},
		# BEGIN IMPORTED AUDIO sivir
		"audio": {
			"events": {
				"attack_return:launch": {"pool": ["res://assets/audio/units/sivir/return_1.wav", "res://assets/audio/units/sivir/return_2.wav", "res://assets/audio/units/sivir/return_3.wav"], "bus": "Combat"},
				"deploy:voice": {"pool": ["res://assets/audio/units/sivir/deploy.ogg"], "bus": "Voice"},
				"attack_launch": {
					"pool": [
						"res://assets/audio/units/sivir/play_sfx_sivir_sivirqmissile_onmissilelaunch_r1.wav",
						"res://assets/audio/units/sivir/play_sfx_sivir_sivirqmissile_onmissilelaunch_r2.wav",
						"res://assets/audio/units/sivir/play_sfx_sivir_sivirqmissile_onmissilelaunch_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"effect_shield:start": {
					"pool": [
						"res://assets/audio/units/sivir/play_sfx_sivir_sivire_onbuffactivate_r1.wav",
						"res://assets/audio/units/sivir/play_sfx_sivir_sivire_onbuffactivate_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"effect_shield:end": {
					"pool": [
						"res://assets/audio/units/sivir/play_sfx_sivir_sivire_onbuffdeactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"effect_shield:block": {
					"pool": [
						"res://assets/audio/units/sivir/play_sfx_sivir_sivire_onbuffdeactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/sivir/play_sfx_sivir_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/sivir/play_sfx_sivir_sivirq_oncast_r1.wav",
					"res://assets/audio/units/sivir/play_sfx_sivir_sivirq_oncast_r2.wav",
					"res://assets/audio/units/sivir/play_sfx_sivir_sivirq_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit": [
				"res://assets/audio/units/sivir/play_sfx_sivir_sivirq_hit_r1.wav",
				"res://assets/audio/units/sivir/play_sfx_sivir_sivirq_hit_r2.wav",
				"res://assets/audio/units/sivir/play_sfx_sivir_sivirq_hit_r3.wav"
			],
			"attack_hit_volume_db": 0.0
		},
		# END IMPORTED AUDIO sivir
		"card_art": {"path": "res://assets/cards/sivir_loading.png"},
	}
