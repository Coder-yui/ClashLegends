extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "赛恩", "cost": 8, "type": "unit", "deploy_time": 2.0,
			"description": "高血量的大型推进单位，缓慢移动且仅攻击建筑。首次致死后对双方不可选取2秒，再满血进入狂暴：加速、加攻速、普攻吸血，改为攻击地面敌人，每秒流失最大生命的20%；复生与狂暴期间不能使用技能。",
			"hp": 2400, "damage": 180, "range": 40.0,
			"speed": SPEED_SLOW, "interval": 1.8, "first_hit": 1.8 * 11.0 / 55.0,
			"size_tier": SIZE_EXTREMELY_LARGE, "radius": RADIUS_EXTREMELY_LARGE,
			"mass": 12.0, "sight": 240.0,
			"is_air": false, "building_only": true, "can_attack_air": false,
			"death_form_delay": 2.0, "death_form_decay_duration": 5.0,
			"transformed_stats": {
				"name": "狂暴赛恩",
				"hp": 2400, "damage": 180, "range": 40.0,
				"speed": SPEED_FAST, "interval": 0.6, "first_hit": 0.12,
				"size_tier": SIZE_EXTREMELY_LARGE, "radius": RADIUS_EXTREMELY_LARGE,
				"mass": 12.0, "sight": 240.0,
				"is_air": false, "building_only": false, "can_attack_air": false,
				"attack_passive_multipliers": [0.0, 0.0], "attack_lifesteal_ratios": [0.5, 0.5],
			},
			"active_skills": [{
				"name": "灵魂熔炉", "kind": "explosive_shield",
				"description": "消耗1金币，获得400护盾。2秒后若本层护盾未破，则移除剩余护盾并对周围地面、空中单位及建筑造成240伤害。冷却8秒，最多2次。",
				"cost": 1, "max_uses": 2, "cooldown": 8.0,
				"shield": 400, "shield_duration": 2.0, "radius": 110.0, "damage": 240,
				"impact_delay": 0.0, "cast_duration": 0.0, "cast_locks": [], "ground_only": false,
			}],
		},
		"visual": {
			"visual_radius": RADIUS_EXTREMELY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/sion/sion_view.tscn", "visual_forward_yaw": 0.0,
			"color": Color(0.65, 0.22, 0.18),
			"visual_animations": {
				"deploy": "Idle_In", "idle": "Idle1_Base", "move": "Run",
				"attack": ["Attack_Tower2", "Attack_Tower"],
				"clip_blends": {"*>Attack_Tower2": 0.14, "*>Attack_Tower": 0.14},
				"death": "Death", "death_duration": 0.8, "death_clip_end": 2.5,
				"visual_actions": {"shield:explode": {"animation": "Spell2_B", "kind": "skill", "priority": 10, "blend_in": 0.06, "blend_out": 0.12}, "death_form": {"animation": "Passive_Death", "durations": [2.0], "clip_ranges": [[0.0, 2.0]], "kind": "transform"}},
			},
			"transformed_stats": {
				"visual_radius": RADIUS_EXTREMELY_LARGE + VISUAL_RADIUS_PADDING,
				"visual_scene_path": "res://assets/units/sion/sion_passive_view.tscn", "visual_forward_yaw": 0.0,
				"visual_animations": {"idle": "Passive_Idle1", "move": "Sion_Passive_Run_anm", "attack": ["Passive_Attack1", "Passive_Attack2"],
					"clip_blends": {"Passive_Death>Sion_Passive_Run_anm": 0.18, "Passive_Death>Passive_Attack1": 0.18, "Passive_Death>Passive_Attack2": 0.18, "Passive_Death>Passive_Idle1": 0.18},
					"death": "Death", "death_duration": 0.8, "death_clip_end": 2.5},
			},
			"active_skills": [{"icon_path": "res://assets/skills/sion_w.png"}],
		},
		"card_art": {"path": "res://assets/cards/sion_loading.png"},
		"audio": {
		"events": {
				"deploy:voice": {
						"pool": [
								"res://assets/audio/units/sion/deploy_battle.wav",
								"res://assets/audio/units/sion/deploy_crush.wav",
								"res://assets/audio/units/sion/deploy_dying.wav"
						],
						"volume_db": 0.0,
						"bus": "Voice"
				},
				"active:cast": {
						"pool": [
								"res://assets/audio/units/sion/play_sfx_sion_sionwshieldstacks_onbuffcast_r1.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionwshieldstacks_onbuffcast_r2.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionwshieldstacks_onbuffcast_r3.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
				},
				"shield:explode": {
						"pool": [
								"res://assets/audio/units/sion/play_sfx_sion_sionwsoundhit_onbuffcast_r1.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionwsoundhit_onbuffcast_r2.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionwsoundhit_onbuffcast_r3.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
				},
				"rebirth:voice": {"pool": ["res://assets/audio/units/sion/rebirth_voice.wav"], "bus": "Voice", "volume_db": 0.0},
				"rebirth:begin": {
						"pool": [
								"res://assets/audio/units/sion/play_sfx_sion_sionpassivedelay_onbuffcast_r1.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionpassivedelay_onbuffcast_r2.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionpassivedelay_onbuffcast_r3.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
				},
				"explosive_shield:sustain": {
						"pool": [
								"res://assets/audio/units/sion/play_sfx_sion_sionwshieldstacks_onbuffactivate.wav"
						],
						"volume_db": -8.0,
						"bus": "Combat"
				},
				"explosive_shield:break": {
						"pool": [
								"res://assets/audio/units/sion/play_sfx_sion_sionwshieldstacks_onbuffdeactivate_r1.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionwshieldstacks_onbuffdeactivate_r2.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionwshieldstacks_onbuffdeactivate_r3.wav"
						],
						"volume_db": 0.0,
						"bus": "Combat"
				}
		},
		"attack_swing": [
				[
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower2_oncast_r1.wav",
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower2_oncast_r2.wav",
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower2_oncast_r3.wav"
				],
				[
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower_oncast_r1.wav",
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower_oncast_r2.wav",
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower_oncast_r3.wav"
				]
		],
		"attack_swing_volume_db": -3.0,
		"attack_hit_by_segment": [
				[
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower2_onhit_r1.wav",
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower2_onhit_r2.wav",
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower2_onhit_r3.wav"
				],
				[
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower_onhit_r1.wav",
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower_onhit_r2.wav",
						"res://assets/audio/units/sion/play_sfx_sion_sionbasicattacktower_onhit_r3.wav"
				]
		],
		"attack_hit_volume_db": -5.0,
		"transformed_stats": {
				"events": {
						"rebirth:ready": {
								"pool": [
										"res://assets/audio/units/sion/play_sfx_sion_sionpassivezombie_onbuffcast_r1.wav",
										"res://assets/audio/units/sion/play_sfx_sion_sionpassivezombie_onbuffcast_r2.wav",
										"res://assets/audio/units/sion/play_sfx_sion_sionpassivezombie_onbuffcast_r3.wav"
								],
								"volume_db": 0.0,
								"bus": "Combat"
						},
						"death": {"pool": ["res://assets/audio/units/sion/death_sfx.wav"], "volume_db": 0.0, "bus": "Combat"},
						"death:voice": {
								"pool": [
										"res://assets/audio/units/sion/passive_death_0.wav",
										"res://assets/audio/units/sion/passive_death_1.wav",
										"res://assets/audio/units/sion/passive_death_2.wav"
								],
								"volume_db": 0.0,
								"bus": "Voice"
						},
						"berserk:sustain": {
						"fade_in": 0.25, "fade_out": 0.5,
								"pool": [
										"res://assets/audio/units/sion/play_sfx_sion_sionpassivezombie_onbuffactivate.wav"
								],
								"volume_db": -8.0,
								"bus": "Combat"
						}
				},
				"attack_swing": [
						[
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive_oncast_r1_d.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive_oncast_r2_d.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive_oncast_r3_d.wav"
						],
						[
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive2_oncast_r1.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive2_oncast_r2.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive2_oncast_r3.wav"
						]
				],
				"attack_swing_volume_db": -3.0,
				"attack_hit_by_segment": [
						[
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive_onhit_r1_d.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive_onhit_r2_d.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive_onhit_r3_d.wav"
						],
						[
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive2_onhit_r1.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive2_onhit_r2.wav",
								"res://assets/audio/units/sion/play_sfx_sion_sionbasicattackpassive2_onhit_r3.wav"
						]
				],
				"attack_hit_volume_db": -5.0
		}
},
	}
