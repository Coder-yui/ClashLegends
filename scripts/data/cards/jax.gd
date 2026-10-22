extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "武器大师", "cost": 5, "type": "unit",
			"description": "近战范围攻击。无情连打：每次攻击有效命中叠加10%攻速，最多5层；再次命中刷新4秒持续时间。",
			"deploy_time": 2.0, "hp": 1100, "damage": 125, "range": MELEE_RANGE_MIN,
			"speed": SPEED_MEDIUM, "interval": 1.4, "first_hit": 0.23,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 7.0, "sight": 220.0, "splash_radius": 35.0,
			"hit_haste_name": "无情连打", "hit_haste_max_stacks": 5, "hit_haste_per_stack": 0.10, "hit_haste_duration": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{"name": "反击风暴", "kind": "counter_strike", "cost": 2, "max_uses": 2, "cooldown": 8.0,
				"duration": 2.0, "radius": 150, "damage": 150, "damage_per_dodge": 0.2, "max_dodges": 5,
				"stun_duration": 1.5, "ground_only": true,
				"description": "2秒内免疫普通攻击伤害，仍可移动攻击。结束对周围150范围地面敌人造成150伤害并眩晕1.5秒，每免疫一次普攻增伤20%，最高300伤害。死亡取消，凝滞中到期不补发。"}],
		},
		"visual": {
			"color": Color(0.58, 0.35, 0.67), "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/jax/jax_view.tscn", "visual_forward_yaw": 0.0,
			"attack_hit_visual": "splash_circle",
			"visual_animations": {"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run_Base",
				"attack": ["Attack_1_anm", "Attack_2_anm"], "active_buff_attack": ["Spell3_Attack1", "Spell3_Attack2", "Spell3_Attack3"], "active_buff_idle": "Spell3_Idle", "active_buff_move": "Spell3_Run",
				"transitions": {
					"Idle1_Base>move": "Run_In", "Idle_In>move": "Run_In",
					"Run_Base>idle": "Idle_In", "Run_In>idle": "Idle_In",
					"Attack_1_anm>idle": "Attack1_To_Idle", "Attack_2_anm>idle": "Attack2_To_Idle",
					"Attack_1_anm>move": "Attack1_To_Run", "Attack_2_anm>move": "Attack2_To_Run",
					"Attack1_To_Run>idle": "Idle_In", "Attack2_To_Run>idle": "Idle_In",
					"active_buff:start>idle": {"animation": "Spell3_Run_Intro_anm", "replace_attack": true, "blend_in": 0.0}, "active_buff:start>move": {"animation": "Spell3_Run_Intro_anm", "replace_attack": true, "blend_in": 0.0},
					"counter_strike:explode>idle": {"animation": "Spell3_B_Idle_anm", "replace_attack": true, "blend_in": 0.0}, "counter_strike:explode>move": {"animation": "Spell3b_run", "replace_attack": true, "blend_in": 0.0},
					"Spell3b_run>idle": "Idle_In",
				},
				"death": "Death", "death_duration": 0.8},
			"visual_active_buff_scene": "res://assets/effects/jax/buff.tscn",
			"active_skills": [{"icon_path": "res://assets/skills/jax_e.png", "resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/jax/player.gd", "variant": "buf"}, {"provider": "res://assets/effects/jax/player.gd", "variant": "cas"}, {"provider": "res://assets/effects/jax/player.gd", "variant": "tar"}]}}],
		},
		# BEGIN IMPORTED AUDIO jax
		"audio": {
			"events": {
				"deploy:voice": {
					"pool": [
						"res://assets/audio/units/jax/deploy.ogg"
					],
					"bus": "Voice",
					"clip_volume_db": {
						"res://assets/audio/units/jax/deploy.ogg": -8.0
					}
				},
				"active_buff:sustain": {
					"pool": [
						"res://assets/audio/units/jax/play_sfx_jax_jaxe_onbuffactivate_r1.wav",
						"res://assets/audio/units/jax/play_sfx_jax_jaxe_onbuffactivate_r2.wav",
						"res://assets/audio/units/jax/play_sfx_jax_jaxe_onbuffactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"counter_strike:explode": {
					"pool": [
						"res://assets/audio/units/jax/play_sfx_jax_jaxe_onbuffdeactivate_r1.wav",
						"res://assets/audio/units/jax/play_sfx_jax_jaxe_onbuffdeactivate_r2.wav",
						"res://assets/audio/units/jax/play_sfx_jax_jaxe_onbuffdeactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/jax/play_sfx_jax_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/jax/play_sfx_jax_respawn3d_buffactivate.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death:voice": {
					"pool": [
						"res://assets/audio/units/jax/play_vo_jax_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/jax/play_vo_jax_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/jax/play_vo_jax_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"counter_strike:hit": {
					"pool": [
						"res://assets/audio/units/jax/play_sfx_jax_jaxe_hit_r1.wav",
						"res://assets/audio/units/jax/play_sfx_jax_jaxe_hit_r2.wav",
						"res://assets/audio/units/jax/play_sfx_jax_jaxe_hit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/jax/play_sfx_jax_jaxbasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/jax/play_sfx_jax_jaxbasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/jax/play_sfx_jax_jaxbasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/jax/play_sfx_jax_jaxbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/jax/play_sfx_jax_jaxbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/jax/play_sfx_jax_jaxbasicattack2_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/jax/play_sfx_jax_jaxbasicattack_onhit_1559186049_1153642577_r_d.wav"
				],
				[
					"res://assets/audio/units/jax/play_sfx_jax_jaxbasicattack2_onhit_1559186049_1153642577_r.wav"
				]
			]
		},
		# END IMPORTED AUDIO jax
		"card_art": {"path": "res://assets/cards/jax_loading.png"},
	}
