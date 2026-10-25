extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "火药桶", "cost": 4, "type": "building",
			"description": "无法攻击的防守建筑，20秒内自然衰减。死亡对半径140像素内地面敌人造成300伤害；本次爆炸击杀任意敌方目标时获得1金币。",
			"hp": 750, "damage": 0, "range": 0.0, "speed": 0.0, "interval": 1.0,
			"radius": 20.0, "footprint_tiles": Vector2i(2, 2), "can_attack": false,
			"is_air": false, "is_building": true, "building_only": false, "can_attack_air": false,
			"lifespan": 20.0, "lifespan_hp_decay": true,
			"death_burst_radius": 140.0, "death_burst_damage": 300.0, "death_burst_reward": 1.0,
			"active_skills": [{"name": "烈性火药", "kind": "detonate", "cost": 0, "max_uses": 1,
				"cooldown": 10.0, "cast_duration": 0.0, "cast_locks": [], "execute_health_ratio": 0.15,
				"description": "立即引爆。爆炸造成生命伤害后，生命低于15%的敌方单位被斩杀；不斩杀建筑，无法突破拒绝死亡。"}]
		},
		"visual": {
			"visual_radius": 34.5, "visual_scene_path": "res://assets/units/powder_keg/view.tscn",
			"visual_forward_yaw": 0.0, "color": Color(0.65, 0.36, 0.12),
			"visual_animations": {"deploy": "Spawn", "idle": "Idle1", "death": "Death", "death_duration": 0.8,
				"visual_actions": {"hit": {"animation": "Timer", "kind": "skill", "priority": 10, "blend_in": 0.0, "blend_out": 0.08}}},
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/powder_keg/player.gd", "variant": "explosion"}]},
			"active_skills": [{"icon_path": "res://assets/skills/gangplank_e.png"}]
		},
		"card_art": {"path": "res://assets/cards/powder_keg_loading.png"}, "audio": {"events": {"hit": {"pool": ["res://assets/audio/units/powder_keg/hit_1.wav", "res://assets/audio/units/powder_keg/hit_2.wav", "res://assets/audio/units/powder_keg/hit_3.wav"], "volume_db": 0.0, "bus": "Combat"}, "bounty:gain": {"pool": ["res://assets/audio/units/scuttle_crab/gold0.wav", "res://assets/audio/units/scuttle_crab/gold1.wav", "res://assets/audio/units/scuttle_crab/gold2.wav"], "volume_db": 0.0, "bus": "Combat"}, "deploy:start": {"pool": ["res://assets/audio/units/powder_keg/deploy_start_1.wav", "res://assets/audio/units/powder_keg/deploy_start_2.wav", "res://assets/audio/units/powder_keg/deploy_start_3.wav"], "volume_db": 0.0, "bus": "Combat"}, "death": {"pool": ["res://assets/audio/units/powder_keg/death_1.wav", "res://assets/audio/units/powder_keg/death_2.wav", "res://assets/audio/units/powder_keg/death_3.wav"], "volume_db": 0.0, "bus": "Combat"}}}
	}
