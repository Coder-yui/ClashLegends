extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "训练木桩", "cost": 3, "type": "building",
			"description": "无法攻击的防守建筑，用生命吸收敌人的火力。余震短暂减伤后向周围爆炸。",
			"hp": 750, "damage": 0, "range": 0.0, "speed": 0.0,
			"interval": 1.0, "radius": RADIUS_SLIGHTLY_LARGE, "footprint_tiles": Vector2i(2, 2),
			"can_attack": false, "is_air": false, "building_only": false, "can_attack_air": false, "is_building": true,
			"lifespan": 15.0, "lifespan_hp_decay": true,
			"active_skills": [{"name": "余震", "kind": "aftershock", "cost": 2, "max_uses": 1,
				"cooldown": 10.0, "duration": 2.5, "damage_reduction": 0.6, "radius": 90.0, "damage": 80,
				"ground_only": false,
				"description": "立即获得60%减伤，持续2.5秒；到期时对周围90像素内敌人造成80伤害。死亡取消爆炸，凝滞期间到期不爆炸。"}],
		},
		"visual": {
			"visual_radius": 34.5,
			"visual_active_buff_scene": "res://assets/effects/aftershock/buff.tscn",
			"active_skills": [{"icon_path": "res://assets/skills/target_dummy_0.png"}],
			"visual_scene_paths": ["res://assets/units/target_dummy/blue_view.tscn", "res://assets/units/target_dummy/red_view.tscn"],
			"visual_forward_yaw": 0.0, "show_team_ring": false,
			"color": Color(0.4, 0.6, 0.8),
			"visual_animations": {"deploy": "Spawn", "idle": "Idle1_Base", "death": "Death", "death_duration": 1.0,
				"visual_actions": {"hit": {"animation": "Hit", "kind": "skill", "priority": 10, "blend_in": 0.04, "blend_out": 0.08}}},
		},
		"card_art": {},
		"audio": {
			"events": {
				"active_buff:sustain": {"pool": [
					"res://assets/audio/units/target_dummy/play_sfx_perks_resolve_aftershock_onbuffactivate_r1.wav",
					"res://assets/audio/units/target_dummy/play_sfx_perks_resolve_aftershock_onbuffactivate_r2.wav",
					"res://assets/audio/units/target_dummy/play_sfx_perks_resolve_aftershock_onbuffactivate_r3.wav",
				], "volume_db": 0.0, "bus": "Combat"},
				"aftershock:explode": {"pool": [
					"res://assets/audio/units/target_dummy/play_sfx_perks_resolve_aftershock_onbuffdeactivate_r1.wav",
					"res://assets/audio/units/target_dummy/play_sfx_perks_resolve_aftershock_onbuffdeactivate_r2.wav",
					"res://assets/audio/units/target_dummy/play_sfx_perks_resolve_aftershock_onbuffdeactivate_r3.wav",
				], "volume_db": 0.0, "bus": "Combat"},
				"death": {"pool": [
					"res://assets/audio/units/target_dummy/play_sfx_practicedummy_death_r1.wav",
					"res://assets/audio/units/target_dummy/play_sfx_practicedummy_death_r2.wav",
					"res://assets/audio/units/target_dummy/play_sfx_practicedummy_death_r3.wav",
				], "volume_db": 0.0, "bus": "Combat"},
				"hit": {"pool": [
					"res://assets/audio/units/target_dummy/play_sfx_practicedummy_onhit_r1.wav",
					"res://assets/audio/units/target_dummy/play_sfx_practicedummy_onhit_r2.wav",
					"res://assets/audio/units/target_dummy/play_sfx_practicedummy_onhit_r3.wav",
					"res://assets/audio/units/target_dummy/play_sfx_practicedummy_onhit_r4.wav",
				], "volume_db": 0.0, "bus": "Combat"},
				"deploy:start": {"pool": [
					"res://assets/audio/units/target_dummy/play_sfx_practicedummy_spawn_r1.wav",
					"res://assets/audio/units/target_dummy/play_sfx_practicedummy_spawn_r2.wav",
				], "volume_db": 0.0, "bus": "Combat"},
			},
		},
	}
