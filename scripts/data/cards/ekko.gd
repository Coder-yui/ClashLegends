extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "时间刺客", "cost": 4, "type": "unit",
			"description": "Z型驱动共振：对每个目标的第三次有效普攻造成2倍普攻伤害，并获得3秒80%移动速度。不同目标独立计数，每个目标只触发一次。",
			"deploy_time": 1.0, "hp": 780, "damage": 110, "range": 48.0, "speed": SPEED_MEDIUM,
			"interval": 1.2, "first_hit": 0.2, "size_tier": SIZE_MEDIUM,
			"radius": RADIUS_MEDIUM, "mass": 4.0, "sight": 210.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"repeat_hit_count": 3, "repeat_hit_multiplier": 2.0,
			"repeat_hit_haste_duration": 3.0, "repeat_hit_speed_multiplier": 1.8,
			"position_history_duration": 4.0,
			"active_skills": [{"name": "时空断裂", "kind": "rewind_nova", "cost": 2,
				"max_uses": 1, "cooldown": 15.0, "rewind_seconds": 4.0,
				"radius": 140.0, "damage": 300, "ground_only": false,
				"impact_delay": 0.75, "cast_duration": 0.75,
				"cast_locks": ["movement", "attack", "facing"],
				"description": "开始回溯时回复满血，不可选中回溯0.75秒，回到施法时4秒前的位置并对半径140内敌人造成300伤害。历史不足时使用最早位置。"}],
		},
		"visual": {
			"visual_scene_path": "res://assets/units/ekko/ekko_view.tscn", "visual_forward_yaw": 0.0,
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING, "color": Color(0.2, 0.8, 0.8),
			"visual_animations": {"deploy": "Idle_In", "idle": "PunkGenius_Idle01_anm",
				"move": "Run_Base", "haste_move": "Run_Haste", "attack": ["Attack_P_1", "Attack_P_2", "Attack_P_3"],
				"attack_hit": ["Attack_P_1", "Attack_P_2", "Attack_P_3"],
				"attack_clip_ranges": [[0.0, 0.266667], [0.0, 0.266667], [0.0, 0.266667]],
				"attack_hit_clip_ranges": [[0.266667, 2.133333], [0.266667, 2.133333], [0.266667, 2.133333]],
				"attack_hit_duration": [1.4, 1.4, 1.4], "transition_blends": {"sequence": 0.0}, "transitions": {"Spell4>idle": "Spell4_End", "Spell4>move": "Spell4_End_To_Run", "Spell4_End>idle": "Spell4_End_To_Idle", "Spell4_End>move": "Spell4_End_To_Run"},
				"death": "Death", "death_clip_end": 1.5, "death_duration": 0.8,
				"visual_actions": {"rewind": {"animation": ["Spell4"], "durations": [0.75], "kind": "skill", "sequence_blend": 0.0}}},
			"active_skills": [{"visual_action": "rewind", "icon_path": "res://assets/skills/ekko_r.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/ekko/player.gd", "variant": "vanish"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "end"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-ChargeUp"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-RewindIndicator"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-TrailEnd"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-TrailEnd_Red"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-RewindIndicator_Red"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-TimeDevice_Active"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-Tar"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-Tar_Impact"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-RewindPose1"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-RewindPose2"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-RewindPose3"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-RewindPose4"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-RewindPose5"}, {"provider": "res://assets/effects/ekko/player.gd", "variant": "r-RewindPose6"}]}}],
		},
		# BEGIN IMPORTED AUDIO ekko
		"audio": {
			"events": {
				"rewind:voice": {"pool": ["res://assets/audio/units/ekko/play_vo_ekko_ekkor_cast3d_r1.wav", "res://assets/audio/units/ekko/play_vo_ekko_ekkor_cast3d_r2.wav", "res://assets/audio/units/ekko/play_vo_ekko_ekkor_cast3d_r3.wav"], "bus": "Voice", "volume_db": 0.0},
				"active:land": {"pool": ["res://assets/audio/units/ekko/play_sfx_ekko_ekkor_buffdeactivate_r1.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkor_buffdeactivate_r2.wav"], "bus": "Combat", "volume_db": 0.0},
				"deploy:voice": {"pool": ["res://assets/audio/units/ekko/play_vo_ekko_attack2dgeneral_r5.wav"], "bus": "Voice", "volume_db": 0.0},
				"active:cast": {
					"pool": [
						"res://assets/audio/units/ekko/play_sfx_ekko_ekkor_oncast_r1.wav",
						"res://assets/audio/units/ekko/play_sfx_ekko_ekkor_oncast_r2.wav",
						"res://assets/audio/units/ekko/play_sfx_ekko_ekkor_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"rewind:start": {
					"pool": [
						"res://assets/audio/units/ekko/play_sfx_ekko_ekkor_buffactivate_r1.wav",
						"res://assets/audio/units/ekko/play_sfx_ekko_ekkor_buffactivate_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"passive:proc": {
					"pool": [
						"res://assets/audio/units/ekko/play_sfx_ekko_ekkopassive_hit_r1.wav",
						"res://assets/audio/units/ekko/play_sfx_ekko_ekkopassive_hit_r2.wav",
						"res://assets/audio/units/ekko/play_sfx_ekko_ekkopassive_hit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/ekko/play_sfx_ekko_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [["res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_oncast_r1_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_oncast_r2_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_oncast_r3_d.wav"], ["res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_oncast_r1_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_oncast_r2_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_oncast_r3_d.wav"], ["res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_oncast_r1_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_oncast_r2_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_oncast_r3_d.wav"]],
			"attack_swing_volume_db": 0.0,
			"attack_hit_by_segment": [["res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_onhit_1559186049_1153642577_r1_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_onhit_1559186049_1153642577_r2_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_onhit_1559186049_1153642577_r3_d.wav"], ["res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_onhit_1559186049_1153642577_r1_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_onhit_1559186049_1153642577_r2_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_onhit_1559186049_1153642577_r3_d.wav"], ["res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_onhit_1559186049_1153642577_r1_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_onhit_1559186049_1153642577_r2_d.wav", "res://assets/audio/units/ekko/play_sfx_ekko_ekkobasicattackp1_onhit_1559186049_1153642577_r3_d.wav"]]
		},
		# END IMPORTED AUDIO ekko
		"card_art": {"path": "res://assets/cards/ekko_loading.png"},
	}
