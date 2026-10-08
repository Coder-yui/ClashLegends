extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "永恒梦魇", "cost": 3, "type": "unit",
			"description": "空中近战单位，可对地对空；可选暗影之刃强化下一击并吸血，或黑暗庇护抵挡敌方效果。",
			"hp": 560, "damage": 95, "range": MELEE_RANGE_MIN,
			"speed": SPEED_SLIGHTLY_SLOW, "interval": 1.4, "first_hit": 0.60,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 4.0, "sight": 210.0,
			"is_air": true, "building_only": false, "can_attack_air": true,
			"attack_pattern": [1.4, 1.4],
			"active_skills": [{"name": "黑暗庇护", "kind": "effect_shield", "cost": 2, "max_uses": 1, "cooldown": 10.0,
				"duration": 1.5, "block_haste_duration": 2.0, "block_attack_speed_multiplier": 1.3, "impact_delay": 0.0, "cast_duration": 0.0, "cast_locks": [],
				"description": "获得1.5秒护盾，抵挡一次敌方攻击、法术或技能及其全部附带效果；不影响已生效的流血、区域减速等效果，也不抵挡友方效果。成功抵挡后获得2秒30%攻速加成。"},
				{"name": "暗影之刃", "kind": "empowered_attack", "cost": 1, "max_uses": 2, "cooldown": 8.0,
				"empowered_damage_multiplier": 1.0, "cleave_damage": PRINCESS_TOWER_STATS.damage, "cleave_radius": 70.0, "heal_ratio": 0.3,
				"impact_delay": 0.0, "cast_duration": 0.0, "cast_locks": [],
				"description": "强化下一次普攻，对自身周围敌人追加55伤害；主目标承受普攻与追加伤害，回复本次实际扣除敌人生命总量的30%。刷新普攻前摇，不叠加储存。"}],
		},
		"visual": {
			"visual_active_buff_scene": "res://assets/effects/nocturne/nocturne_effects.tscn",
			"color": Color(0.25, 0.16, 0.4), "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/nocturne/nocturne_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"], "empowered_attack": "Attack3", "death": "Death", "death_clip_end": 1.5, "death_duration": 0.8,
				"clip_blends": {"Spell2>Run": 0.18, "Spell2>Attack1": 0.16, "Spell2>Attack2": 0.16, "Spell2>Attack3": 0.16},
				"visual_actions": {"effect_shield:start": {"animation": "Spell2", "kind": "skill", "priority": 10, "blend_in": 0.16, "blend_out": 0.18}}},
			"active_skills": [{"resource_dependencies": {
				"effects": [
					{
						"provider": "res://assets/effects/nocturne/nocturne_effects.gd",
						"variant": "shield"
					}
				],
				"fields": [
					"visual_active_buff_scene"
				]
			}, "icon_path": "res://assets/skills/nocturne_w.png"}, {"resource_dependencies": {
				"effects": [
					{
						"provider": "res://assets/effects/nocturne/nocturne_effects.gd",
						"variant": "cleave"
					}
				],
				"fields": [
					"visual_active_buff_scene"
				]
			}, "icon_path": "res://assets/skills/nocturne_p.png"}],
		},
		# BEGIN IMPORTED AUDIO nocturne
		"audio": {
			"events": {
				"deploy:voice": {
					"pool": [
						"res://assets/audio/units/nocturne/deploy.ogg"
					],
					"bus": "Voice",
					"clip_volume_db": {
						"res://assets/audio/units/nocturne/deploy.ogg": 0.0
					}
				},
				"effect_shield:start": {
					"pool": [
						"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturneshroudofdarkness_oncast_r1.wav",
						"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturneshroudofdarkness_oncast_r2.wav",
						"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturneshroudofdarkness_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/nocturne/play_sfx_nocturne_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"empowered_swing": {
					"pool": [
						"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturneumbrabladesattack_oncast_r1.wav",
						"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturneumbrabladesattack_oncast_r2.wav",
						"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturneumbrabladesattack_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack2_oncast_r1.wav",
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack2_oncast_r2.wav",
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit": [
				"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack_onhit_1559186049_1153642577_r2_d.wav",
				"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack_onhit_1559186049_1153642577_r3_d.wav"
			],
			"attack_hit_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack_onhit_1559186049_1153642577_r3_d.wav"
				],
				[
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturnebasicattack2_onhit_1559186049_1153642577_r3.wav"
				]
			],
			"empowered_hit": [
				"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturneumbrabladesattack_hit_r1_d.wav",
				"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturneumbrabladesattack_hit_r2_d.wav",
				"res://assets/audio/units/nocturne/play_sfx_nocturne_nocturneumbrabladesattack_hit_r3_d.wav"
			]
		},
		# END IMPORTED AUDIO nocturne
		"card_art": {"path": "res://assets/cards/nocturne_loading.png"},
	}
