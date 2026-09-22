extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "恕瑞玛卫队", "cost": 7, "type": "unit",
			"description": "六名黄沙士兵横排部署，以长矛轮流刺击地面敌人。敌方两路防御塔均被摧毁后，才能在对方半场的合法区域部署。",
			"hp": 420, "damage": 60, "range": 72.0,
			"speed": SPEED_SLOW, "interval": 1.6, "first_hit": 0.4,
			"attack_pattern": [1.6, 1.6, 1.6],
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 4.0, "sight": 220.0,
			"deploy_pocket_requires_both_towers": true,
			"deployment_count": 6, "deployment_spacing": 100.0, "deployment_formation": "line",
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{"name": "黄沙庇护", "kind": "restoration_shield",
				"cost": 2, "max_uses": 1, "cooldown": 8.0, "target_scope": "deployment_group",
				"shield": 180, "shield_duration": 2.0,
				"description": "同次出牌的存活士兵各获得180点护盾，持续2秒；逐人判断，到期时护盾未破则回复至满血。"}],
		},
		"visual": {"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/shurima_guard/shurima_guard_view.tscn",
			"visual_forward_yaw": 0.0, "color": Color(0.88, 0.69, 0.28),
			"visual_animations": {"deploy": "AzirSoldier_Spawn_anm", "idle": "Idle1_Base", "move": "Run",
				"attack": ["Attack1_BASE", "Attack2_BASE", "AzirSoldier_Attack3_anm"],
				"death": "Death", "death_duration": 0.8}},
		"card_art": {},
		"audio": {"attack_swing": [["res://assets/audio/units/shurima_guard/play_sfx_azir_azirbasicattacksoldier_cast1_r1.wav", "res://assets/audio/units/shurima_guard/play_sfx_azir_azirbasicattacksoldier_cast1_r2.wav"], ["res://assets/audio/units/shurima_guard/play_sfx_azir_azirbasicattacksoldier_cast2_r1.wav", "res://assets/audio/units/shurima_guard/play_sfx_azir_azirbasicattacksoldier_cast2_r2.wav"], ["res://assets/audio/units/shurima_guard/play_sfx_azir_azirbasicattacksoldier_cast3_r1.wav", "res://assets/audio/units/shurima_guard/play_sfx_azir_azirbasicattacksoldier_cast3_r2.wav"]], "attack_hit": ["res://assets/audio/units/shurima_guard/play_sfx_azir_azirbasicattacksoldier_onhit_r1.wav", "res://assets/audio/units/shurima_guard/play_sfx_azir_azirbasicattacksoldier_onhit_r2.wav"], "attack_swing_volume_db": -5.0, "attack_hit_volume_db": -4.0, "events": {"deploy:start": {"pool": ["res://assets/audio/units/shurima_guard/play_sfx_azir_azirwspawnsound_onbuffcast_r1.wav", "res://assets/audio/units/shurima_guard/play_sfx_azir_azirwspawnsound_onbuffcast_r2.wav"], "volume_db": -5.0}, "death": {"pool": ["res://assets/audio/units/shurima_guard/play_sfx_azir_azirwspawnsound_onbuffdeactivate_r1.wav", "res://assets/audio/units/shurima_guard/play_sfx_azir_azirwspawnsound_onbuffdeactivate_r2.wav"], "volume_db": -5.0}, "active:cast": {"pool": ["res://assets/audio/units/shurima_guard/play_sfx_azir_azireshield_onbuffcast_r1.wav"], "volume_db": 0.0}}}
	}
