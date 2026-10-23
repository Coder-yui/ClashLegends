extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "沙漠玫瑰", "cost": 4, "type": "unit",
			"description": "远程双枪射手；目标表面间距1.6格以内改用刀刃，伤害提高50%，攻击间隔由1.4秒变为1秒。被动悍勇本色：远程命中叠1层、近战叠2层，每层加5%移速，满5层改为加30%。命中刷新4秒持续时间；炼狱扳机消耗满层，期间不能叠层。",
			"hp": 620, "damage": 72, "range": 165.0,
			"speed": SPEED_MEDIUM, "interval": 1.4, "first_hit": 0.25,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 4.0, "sight": 230.0,
			"projectile_speed": 700.0, "projectile_spawn_at_edge": false,
			"projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
			"close_attack_range": 1.6 * ArenaRules.TILE_SIZE, "close_attack_damage_multiplier": 1.5,
			"close_attack_speed_multiplier": 1.4, "close_attack_hit_gain": 2.0,
			"skill_resource_passive": true, "skill_resource_duration": 4.0,
			"skill_resource_move_per_stack": 0.05, "skill_resource_full_move_bonus": 0.3,
			"skill_resource_max": 5.0, "skill_resource_hit_gain": 1.0,
			"skill_resource_block_during_cast": true,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "炼狱扳机", "kind": "continuous_area", "cost": 1,
				"max_uses": 1, "unlimited_uses": true, "cooldown": 5.0,
				"uses_skill_resource": true, "requires_full_resource": true,
				"radius": 180.0, "damage": 24, "duration": 2.0, "tick_interval": 0.2,
				"impact_delay": 0.0, "cast_duration": 2.0,
				"cast_locks": ["attack"], "ground_only": false,
				"description": "消耗悍勇本色全部5层，旋转射击2秒并向目标移动至技能范围内，每秒对半径180内的地面与空中敌军造成120伤害；期间不能普攻或叠加被动层数。每次1金币，冷却5秒，次数不限。",
			}],
		},
		"visual": {
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/samira/player.gd", "variant": "bullet"}, {"provider": "res://assets/effects/samira/player.gd", "variant": "ready"}]},
			"visual_active_buff_scene": "res://assets/effects/samira/buff.tscn",
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/samira/samira_view.tscn", "visual_forward_yaw": 0.0,
			"color": Color(0.8, 0.24, 0.2), "skill_resource_full_color": Color(1.0, 0.3, 0.12),
			"projectile_visual": "samira_bullet", "projectile_visual_height": 48.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle_anm", "move": "Run_OOC_anm",
				"attack": ["Attack1_Gun_Start_anm", "Attack2_Gun_Start_anm", "Attack1_Sword_anm", "Attack2_Sword_anm"],
				"attack_hit": ["Attack1_Gun_Hit_anm", "Attack2_Gun_Hit_anm", "Attack1_Sword_Hit_anm", "Attack2_Sword_Hit_anm"],
				"attack_reference_interval": 1.0 / 0.658,
				"attack_stance_duration": 4.0,
				"attack_idle": ["Idle_Gun_anm", "Idle_Gun_anm", "Idle_Sword_anm", "Idle_Sword_anm"],
				"attack_idle_enter": ["Idle_Gun_IN_anm", "Idle_Gun_IN_anm", "Idle_Sword_IN_anm", "Idle_Sword_IN_anm"],
				"attack_move": ["Run_Gun_anm", "Run_Gun_anm", "Run_Sword_anm", "Run_Sword_anm"],
				"attack_sheath_idle": ["Sheath_Gun_Idle_anm", "Sheath_Gun_Idle_anm", "Sheath_Sword_Idle_anm", "Sheath_Sword_Idle_anm"],
				"attack_sheath_move": ["Sheath_Gun_Run_anm", "Sheath_Gun_Run_anm", "Sheath_Sword_Run_anm", "Sheath_Sword_Run_anm"],
				"transition_blends": {"sequence": 0.0},
				"transitions": {
					"Spell4>move": {"animation": "Spell4_INTO_Run_anm", "attack_stance_index": 0, "blend_in": 0.0},
					"Spell4>idle": {"animation": "Idle_Gun_IN_anm", "attack_stance_index": 0, "blend_in": 0.08},
				},
				"attack_recover": ["Attack1_Gun_INTO_Idle_anm", "Attack2_Gun_INTO_Idle_anm", "Attack1_Sword_INTO_Idle_anm", "Attack2_Sword_INTO_Idle_anm"],
				"attack_to_move": ["Attack_Gun_INTO_Run_Front_anm", "Attack_Gun_INTO_Run_Front_anm", "Attack1_Sword_INTO_Run_anm", "Attack2_Sword_INTO_Run_anm"],
				"death": "Death", "death_duration": 0.8,
				"visual_actions": {"inferno": {"animation": ["Spell4_Start", "Spell4"], "durations": [0.5, 1.5], "kind": "skill", "blend_in": 0.0, "sequence_blend": 0.0}},
			},
			"active_skills": [{"visual_action": "inferno", "icon_path": "res://assets/skills/samira_r.png", "resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/samira/player.gd", "variant": "cas"}]}}],
		},
		# BEGIN IMPORTED AUDIO samira
		"audio": {
			"events": {
				"deploy:voice": {
					"pool": [
						"res://assets/audio/units/samira/deploy_voice_1.wav",
						"res://assets/audio/units/samira/deploy_voice_2.wav",
						"res://assets/audio/units/samira/deploy_voice_3.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"inferno:start": {
					"pool": [
						"res://assets/audio/units/samira/play_sfx_samira_samirar_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"inferno:sustain": {
					"pool": [
						"res://assets/audio/units/samira/play_sfx_samira_samirar_onbuffactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"resource_full": {
					"pool": [
						"res://assets/audio/units/samira/play_sfx_samira_samirarreadybuff_onbuffactivate_m.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/samira/play_sfx_samira_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_oncast_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_oncast_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_oncast_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_oncast_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_oncast_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_oncast_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_oncast_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_oncast_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onhit_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onhit_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onhit_r3.wav"
				],
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onhit_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onhit_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onhit_r3.wav"
				],
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_onhit_1559186049_1153642577_r3.wav"
				],
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattackmelee2_onhit_1559186049_1153642577_r3.wav"
				]
			],
			"attack_launch_by_segment": [
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onmissilelaunch_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onmissilelaunch_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onmissilelaunch_r3.wav"
				],
				[
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onmissilelaunch_r1.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onmissilelaunch_r2.wav",
					"res://assets/audio/units/samira/play_sfx_samira_samirabasicattack2_onmissilelaunch_r3.wav"
				],
				[],
				[]
			]
		},
		# END IMPORTED AUDIO samira
		"card_art": {"path": "res://assets/cards/samira_loading.png"},
	}
