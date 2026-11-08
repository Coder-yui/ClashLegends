extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var data := {
		"gameplay": {
			"name": "女王巢穴", "cost": 4, "type": "building",
			"description": "雷克塞沉睡的洞穴。持续25秒，被摧毁后雷克塞以复生动作出巢。",
			"hp": 600, "damage": 0, "range": 0.0, "speed": 0.0, "interval": 1.0,
			"radius": 25.0, "footprint_tiles": Vector2i(3, 3), "is_building": true,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"lifespan": 25.0, "lifespan_hp_decay": true,
			"transform_duration": 0.0,
			"death_spawn_id": "nest_reksai", "death_spawn_count": 1, "death_spawn_side": "center",
			"active_skills": [{"name": "女王之怒", "kind": "summon", "cost": 1, "max_uses": 1, "cooldown": 15.0,
				"description": "立即唤醒暴怒雷克塞，留下空巢，永久使用Q范围攻击。",
				"spawn_id": "enraged_reksai", "spawn_count": 1, "spawn_forward_distance": 50.0,
				"spawn_deploy_time": 0.0, "transform_source": true}],
		},
		"visual": {
			"visual_scene_path": "res://assets/units/queen_nest/nest_view.tscn", "visual_radius": 50.0,
			"visual_forward_yaw": PI, "color": Color(0.49, 0.22, 0.62),
			"visual_animations": {"deploy": "reksaitunnel_spawn", "idle": "reksaitunnel_idle1", "death": "reksaitunnel_death_open", "death_duration": 0.8},
			"active_skills": [{"icon_path": "res://assets/skills/queen_nest_e.png", "resource_dependencies": {"fields": ["transformed_stats"]}}],
		},
		"card_art": {"path": "res://assets/cards/queen_nest.png"}, "audio": {"events": {
			"deploy:start": {"pool": ["res://assets/audio/units/queen_nest/nest_deploy.wav"], "volume_db": 0.0, "bus": "Combat"},
			"death": {"pool": ["res://assets/audio/units/queen_nest/nest_death.wav"], "volume_db": 0.0, "bus": "Combat"},
			"active:cast": {"pool": ["res://assets/audio/units/queen_nest/w_burrow_voice.wav"], "volume_db": 0.0, "bus": "Voice"},
		}},
	}
	var empty: Dictionary = data.gameplay.duplicate(true)
	empty.erase("transformed_stats")
	empty.erase("death_spawn_side")
	empty.erase("death_spawn_id")
	empty.name = "空巢穴"
	empty.death_spawn_count = 0
	empty.active_skills = []
	data.gameplay.transformed_stats = empty
	data.visual.transformed_stats = {"visual_radius": 50.0}
	data.audio.transformed_stats = {"events": {"death": data.audio.events.death.duplicate(true)}}
	return data
