extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "兹若特传送门", "cost": 6, "type": "building",
			"description": "持续60秒的召唤建筑，部署完成生成1只虚空兽，之后每6秒生成1只。主动立即摧毁自身并生成2只虚空兽。",
			"hp": 900, "damage": 0, "range": 0.0, "can_attack": false,
			"speed": 0.0, "interval": 1.0, "radius": 30.0,
			"footprint_tiles": Vector2i(3, 3), "deploy_time": 1.7,
			"is_air": false, "building_only": false, "can_attack_air": false, "is_building": true,
			"lifespan": 60.0, "lifespan_hp_decay": true,
			"spawn_id": "void_spawn_single", "spawn_interval": 6.0, "spawn_count": 1,
			"spawn_side": "map_side", "spawn_defer_while_controlled": true,
			"active_skills": [{"name": "虚空迸发", "kind": "summon", "cost": 1, "max_uses": 1, "cooldown": 10.0,
				"spawn_id": "void_spawn_single", "spawn_count": 2, "sacrifice_source": true}],
		},
		"visual": {
			"visual_radius": 50.0, "color": Color(0.55, 0.2, 0.8),
			"visual_scene_path": "res://assets/units/void_gate/void_gate_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Spawn", "idle": "Idle1", "death": "Death", "death_duration": 2.2,
				"visual_actions": {"summon": {"animation": "Spit", "kind": "deploy", "durations": [0.9333333], "priority": 10}}},
			"active_skills": [{"icon_path": "res://assets/skills/void_gate_0.png"}],
			"resource_dependencies": {"effects": [
				{"provider": "res://assets/effects/void_gate/player.gd", "variant": "spawn"},
				{"provider": "res://assets/effects/void_gate/player.gd", "variant": "idle"},
				{"provider": "res://assets/effects/void_gate/player.gd", "variant": "spit"},
				{"provider": "res://assets/effects/void_gate/player.gd", "variant": "death"}]},
		},
		"card_art": {"path": "res://assets/cards/void_gate_loading.png"},
		"audio": {"events": {"deploy:start": {"pool": ["res://assets/audio/units/void_gate/deploy_start_1.wav", "res://assets/audio/units/void_gate/deploy_start_2.wav", "res://assets/audio/units/void_gate/deploy_start_3.wav"], "volume_db": 0.0, "bus": "Combat"}, "death": {"pool": ["res://assets/audio/units/void_gate/death_1.wav"], "volume_db": 0.0, "bus": "Combat"}}},
	}
