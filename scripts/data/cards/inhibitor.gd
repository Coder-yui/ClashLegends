extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "高地水晶", "cost": 7, "type": "building",
			"description": "持续召唤兵线：两波近战兵与远程兵后，第三波改为两个近战兵与一个炮车兵。被摧毁或自然死亡时召唤一个超级兵。",
			"hp": 1200, "damage": 0, "range": 0.0, "can_attack": false,
			"speed": 0.0, "interval": 1.0, "radius": 40.0,
			"footprint_tiles": Vector2i(3, 3),
			"is_air": false, "building_only": false, "can_attack_air": false, "is_building": true,
			"deploy_time": 1.0, "lifespan": 50.0, "lifespan_hp_decay": true,
			"spawn_side": "map_side", "spawn_sequence_interval": 0.5,
			"spawn_deploy_time": 0.0, "spawn_interval": 8.0,
			"spawn_waves": [
				[{"spawn_id": "melee_minion", "spawn_count": 1}, {"spawn_id": "ranged_minion", "spawn_count": 1}],
				[{"spawn_id": "melee_minion", "spawn_count": 1}, {"spawn_id": "ranged_minion", "spawn_count": 1}],
				[{"spawn_id": "melee_minion", "spawn_count": 2}, {"spawn_id": "siege_minion", "spawn_count": 1}],
			],
			"death_spawn_side": "map_side", "death_spawn_id": "super_minion", "death_spawn_count": 1, "death_spawn_deploy_time": 0.0,
			"active_skills": [{"name": "超级增援", "kind": "summon", "cost": 2, "max_uses": 2, "cooldown": 18.0,
				"spawn_side": "map_side", "spawn_id": "super_minion", "spawn_count": 1, "spawn_deploy_time": 0.0,
				"description": "立即召唤一个超级兵。"}],
		},
		"visual": {
			"visual_radius": 59.0,
			"active_skills": [{"icon_path": "res://assets/skills/inhibitor_0.png"}],
			"visual_scene_paths": ["res://assets/units/inhibitor/inhibitor_blue_view.tscn", "res://assets/units/inhibitor/inhibitor_red_view.tscn"],
			"visual_forward_yaw": PI,
			"visual_animations": {"deploy": "SRUAP_ChaosInhibitor_spawn_anm", "idle": "Idle_Normal1", "death": "Death_Base", "death_clip_end": 5.0, "death_duration": 1.0},
			"color": Color(0.25, 0.65, 0.95), "show_team_ring": false,
		},
		"card_art": {"path": "res://assets/cards/inhibitor_loading.png"},
		"audio": {"events": {
			"deploy:start": {"pool": ["res://assets/audio/units/inhibitor/spawn.wav"], "volume_db": 0.0, "bus": "Combat"},
			"idle:sustain": {"pool": ["res://assets/audio/units/inhibitor/idle.wav"], "volume_db": 0.0, "bus": "Combat"},
			"death": {"pool": ["res://assets/audio/units/inhibitor/death_r1.wav", "res://assets/audio/units/inhibitor/death_r2.wav", "res://assets/audio/units/inhibitor/death_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
		}},
	}
