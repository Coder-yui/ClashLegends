extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "影流之镰·凯隐", "cost": 4, "type": "unit",
			"description": "可穿越河流和建筑，进入地形回复70生命，完整离开后可再次触发；地形内不能普攻，攻击前挤到最近合法地面。本阵营普通凯隐普攻命中非建筑敌军累计：远程4次解锁蓝凯、近战6次解锁红凯，率先完成永久锁定，仅影响后续部署。",
			"hp": 650, "damage": 80, "range": MELEE_RANGE_MIN,
			"speed": SPEED_SLIGHTLY_FAST, "interval": 1.1, "first_hit": 0.16,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 4.0, "sight": 240.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"terrain_traversal": true, "terrain_entry_heal": 70,
			"growth_ranged_id": "kayn_assassin", "growth_melee_id": "kayn_slayer", "growth_ranged_hits": 4, "growth_melee_hits": 6,
			"active_skills": [{"name": "巨镰横扫", "kind": "dash_strike", "cost": 2, "max_uses": 2, "cooldown": 6.0,
				"damage": 90, "length": 120.0, "width": 40.0, "radius": 65.0, "dash_duration": 0.3, "spin_delay": 0.5,
				"cast_duration": 0.7, "impact_delay": 0.0, "cast_locks": ["movement", "attack", "facing"],
				"description": "向前突进120像素，穿过的地面敌人受90伤害；随后旋转造成90伤害。突进期间可受伤，结束避开单位重叠。"}],
		},
		"visual": {"visual_scene_path": "res://assets/units/kayn/kayn_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Deploy_Base", "idle": "Idle1_Base", "move": "Run", "terrain_move": "Spell3_Run", "attack": ["Attack1", "Attack2", "Attack3"], "death": "Death", "death_duration": 1.0,
				"visual_actions": {"active": {"animation": ["Spell1_Dash", "Spell1_Stop", "Spell1_Circle"], "durations": [0.3, 0.1, 0.3], "sequence_blend": 0.0, "kind": "skill"}},
				"transitions": {"Spell1_Circle>terrain_move": "Spell1_Exit_To_Run", "Spell1_Circle>move": "Spell1_Exit_To_Run"}},
			"active_skills": [{"visual_action": "active", "icon_path": "res://assets/skills/kayn_q_primary.png"}], "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING, "color": Color(0.45, 0.3, 0.65)},
		"card_art": {"path": "res://assets/cards/kayn_loading.png"}, "audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/kayn/kayn_deploy_voice_1.wav", "res://assets/audio/units/kayn/kayn_deploy_voice_2.wav", "res://assets/audio/units/kayn/kayn_deploy_voice_3.wav"], "volume_db": 3.0, "bus": "Voice"},
				"active:cast": {
					"pool": [
						"res://assets/audio/units/kayn/kayn_q_cast_1.wav"
					],
					"volume_db": 2.0,
					"bus": "Combat"
				},
				"active:spin": {
					"pool": [
						"res://assets/audio/units/kayn/kayn_q_spin_1.wav"
					],
					"volume_db": 2.0,
					"bus": "Combat"
				},
				"active:hit": {
					"pool": [
						"res://assets/audio/units/kayn/kayn_q_hit_1.wav"
					],
					"volume_db": 2.0,
					"bus": "Combat"
				},
				"terrain:sustain": {"pool": ["res://assets/audio/units/kayn/kayn_terrain_sustain.wav"], "volume_db": 2.0, "bus": "Combat"},
				"terrain:exit": {"pool": ["res://assets/audio/units/kayn/kayn_terrain_exit.wav"], "volume_db": 2.0, "bus": "Combat"},
				"terrain:enter": {
					"pool": [
						"res://assets/audio/units/kayn/kayn_terrain_1.wav"
					],
					"volume_db": 2.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/kayn/kayn_death_1.wav"
					],
					"volume_db": 2.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/kayn/kayn_attack1_1.wav",
					"res://assets/audio/units/kayn/kayn_attack1_2.wav"
				],
				[
					"res://assets/audio/units/kayn/kayn_attack2_1.wav",
					"res://assets/audio/units/kayn/kayn_attack2_2.wav"
				],
				[
					"res://assets/audio/units/kayn/kayn_attack3_1.wav",
					"res://assets/audio/units/kayn/kayn_attack3_2.wav"
				]
			],
			"attack_swing_volume_db": 1.0,
			"attack_hit_volume_db": 1.0,
			"attack_hit": [
				"res://assets/audio/units/kayn/kayn_attack_hit_1.wav",
				"res://assets/audio/units/kayn/kayn_attack_hit_2.wav"
			]
		},
	}
