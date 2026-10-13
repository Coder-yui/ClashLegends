extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "虚空先知", "cost": 5, "type": "unit",
			"description": "空中后排召唤法师。部署完成2秒后开始召唤，此后每8秒从脚下同一个固定裂隙依次召唤3只虚灵，间隔0.5秒。",
			"hp": 620, "damage": 60, "range": 190.0, "speed": SPEED_MEDIUM,
			"interval": 1.2, "first_hit": 0.35, "size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 2.0, "sight": 250.0, "is_air": true, "building_only": false, "can_attack_air": true,
			"projectile_speed": 380.0,
			"spawn_id": "voidling", "spawn_interval": 8.0, "spawn_initial_delay": 2.0,
			"spawn_count": 3, "spawn_sequence_interval": 0.5, "spawn_side": "below", "spawn_deploy_time": 0.0,
			"active_skills": [{"name": "冥府之握", "kind": "channeled_attack", "cost": 3, "max_uses": 1, "cooldown": 10.0,
				"duration": 2.5, "radius": 90.0, "zone_duration": 5.0, "zone_damage": 30, "zone_tick_interval": 0.5,
				"description": "下一次攻击不受致盲影响，命中后引导眩晕2.5秒，自身不能移动或攻击。眩晕、冰冻、凝滞、击退、强制位移、沉默、嘲讽打断引导。命中位置生成半径90的区域，每0.5秒造成30伤害，独立持续5秒。"}, {"name": "虚空虫群", "kind": "summon", "cost": 1, "max_uses": 3, "cooldown": 6.0,
				"spawn_id": "voidling", "spawn_count": 3, "spawn_side": "below", "spawn_sequence_interval": 0.5,
				"cast_duration": 1.0, "impact_delay": 0.25,
				"description": "施放W，动作0.25秒时开启裂隙，以0.5秒间隔召唤3只虚灵。施法期间不能攻击。"}],
		},
		"visual": {
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/malzahar/player.gd", "variant": "portal_start"}, {"provider": "res://assets/effects/malzahar/player.gd", "variant": "portal_end"}, {"provider": "res://assets/effects/malzahar/player.gd", "variant": "cast"}]},
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/malzahar/malzahar_view.tscn", "visual_forward_yaw": 0.0,
			"visual_animations": {"deploy": "Idle1", "idle": "Idle1", "move": "Run", "attack": ["Attack1", "Attack2"], "death": "Death", "death_duration": 1.0, "visual_actions": {"channel": "Spell4", "void_swarm": {"animation": "Spell2", "kind": "skill"}}},
			"projectile_visual": "malzahar_missile", "projectile_visual_height": 50.0,
			"projectile_colors": [Color(0.65, 0.15, 0.9), Color(0.65, 0.15, 0.9)], "color": Color(0.65, 0.15, 0.9),
			"active_skills": [{"icon_path": "res://assets/skills/malzahar_0.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/malzahar/player.gd", "variant": "zone"}, {"provider": "res://assets/effects/malzahar/player.gd", "variant": "beam"}]}}, {"icon_path": "res://assets/skills/malzahar_w.png", "visual_action": "void_swarm"}],
		},
		"audio": {"events": {"summon:start": {"pool": ["res://assets/audio/units/malzahar/spawn_1_1.wav", "res://assets/audio/units/malzahar/spawn_1_2.wav", "res://assets/audio/units/malzahar/spawn_1_3.wav", "res://assets/audio/units/malzahar/spawn_2_1.wav", "res://assets/audio/units/malzahar/spawn_2_2.wav", "res://assets/audio/units/malzahar/spawn_2_3.wav", "res://assets/audio/units/malzahar/spawn_3_1.wav", "res://assets/audio/units/malzahar/spawn_3_2.wav", "res://assets/audio/units/malzahar/spawn_3_3.wav"], "bus": "Combat", "volume_db": 0.0}, "attack_launch": {"pool": ["res://assets/audio/units/malzahar/attack_launch_1.wav", "res://assets/audio/units/malzahar/attack_launch_2.wav", "res://assets/audio/units/malzahar/attack_launch_3.wav"], "volume_db": 0.0, "bus": "Combat"}, "death": {"pool": ["res://assets/audio/units/malzahar/death_1.wav", "res://assets/audio/units/malzahar/death_2.wav", "res://assets/audio/units/malzahar/death_3.wav"], "volume_db": 0.0, "bus": "Combat"}, "channel:sustain": {"pool": ["res://assets/audio/units/malzahar/channel_start_1.wav"], "volume_db": 0.0, "bus": "Combat"}, "channel:zone_sustain": {"pool": ["res://assets/audio/units/malzahar/channel_zone_1.wav", "res://assets/audio/units/malzahar/channel_zone_2.wav"], "volume_db": 0.0, "bus": "Combat"}, "deploy:voice": {"pool": ["res://assets/audio/units/malzahar/deploy_voice.ogg"], "bus": "Voice", "volume_db": 0.0, "clip_volume_db": {"res://assets/audio/units/malzahar/deploy_voice.ogg": -12.5}}}, "attack_hit": ["res://assets/audio/units/malzahar/attack_hit_1.wav", "res://assets/audio/units/malzahar/attack_hit_2.wav", "res://assets/audio/units/malzahar/attack_hit_3.wav"], "attack_hit_volume_db": 0.0},
		"card_art": {"path": "res://assets/cards/malzahar_loading.png"},
	}
