extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "金币守卫", "cost": 6, "type": "building",
			"description": "部署完成后每5秒产出1金币，死亡产出2金币。眩晕、冰冻、凝滞期间到期收益延后，解除后发放一次并重新计时。",
			"hp": 640, "damage": 0, "range": 0.0, "speed": 0.0, "interval": 1.0,
			"radius": RADIUS_SLIGHTLY_LARGE, "size_tier": SIZE_SLIGHTLY_LARGE,
			"footprint_tiles": Vector2i(2, 2), "can_attack": false,
			"is_air": false, "is_building": true, "building_only": false, "can_attack_air": false,
			"lifespan": 32.0, "lifespan_hp_decay": true,
			"elixir_interval": 5.0, "elixir_amount": 1.0, "death_owner_elixir": 2.0,
			"active_skills": [{"name": "完美时机", "kind": "self_stasis", "cost": 0,
				"max_uses": 1, "cooldown": 20.0, "duration": 2.5,
				"description": "进入凝滞2.5秒，无法被选取或受伤，产出延后；暂停自然衰血。"}],
		},
		"visual": {
			"visual_scene_path": "res://assets/units/gold_ward/ward_view.tscn",
			"visual_radius": 30.0, "visual_forward_yaw": 0.0,
			"color": Color(0.95, 0.72, 0.20),
			"visual_animations": {"deploy": "sightward_base_idlein", "idle": "sightward_base_idle",
				"death": "sightward_base_idle_death", "death_duration": 0.8},
			"active_skills": [{"icon_path": "res://assets/skills/gold_ward_0.png", "resource_dependencies": {"effects": [{
				"provider": "res://scripts/presentation/self_stasis_resources.gd", "variant": "default"}]}}],
		},
		"card_art": {"path": "res://assets/cards/gold_ward_loading.png"},
		"audio": {"events": {
			"bounty:gain": {"pool": ["res://assets/audio/units/scuttle_crab/gold0.wav", "res://assets/audio/units/scuttle_crab/gold1.wav", "res://assets/audio/units/scuttle_crab/gold2.wav"], "volume_db": 0.0, "bus": "Combat"},
			"deploy:start": {"pool": ["res://assets/audio/units/gold_ward/deploy.wav", "res://assets/audio/units/gold_ward/deploy_2.wav", "res://assets/audio/units/gold_ward/deploy_3.wav"], "volume_db": 0.0, "bus": "Combat"},
			"death": {"pool": ["res://assets/audio/units/gold_ward/death.wav"], "volume_db": 0.0, "bus": "Combat"},
			"stasis_target:sustain": {"pool": ["res://assets/audio/units/gold_ward/stasis.wav"], "volume_db": 0.0, "bus": "Combat"}
		}},
	}
