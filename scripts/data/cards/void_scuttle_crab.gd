extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var result: Dictionary = preload("res://scripts/data/cards/scuttle_crab.gd").definition().duplicate(true)
	var gameplay: Dictionary = result.gameplay
	gameplay.merge({"name": "虚空迅捷蟹", "cost": 3, "hp": 1260,
		"description": "高生命坦克，只追逐建筑，在建筑前跳舞，每秒回复45生命。死亡留下半径150、持续6秒、每秒回复25生命的友军治疗区；被击杀给对方2金币。主动自尽仍留下治疗区，免除对方收益。",
		"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE, "mass": 7.0,
		"structure_mend_per_second": 45.0, "death_heal_radius": 150.0, "death_enemy_elixir": 2.0,
		"active_skills": [{"name": "归于虚空", "kind": "self_sacrifice", "cost": 1, "max_uses": 1, "cooldown": 10.0,
			"cast_duration": 0.0, "cast_locks": [], "description": "立即死亡并留下治疗区，不给对方金币。"}]}, true)
	result.visual.merge({"visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
		"visual_scene_path": "res://assets/units/void_scuttle_crab/void_scuttle_crab_view.tscn",
		"color": Color(0.6, 0.3, 0.8), "active_skills": [{"icon_path": "res://assets/skills/void_scuttle_crab_0.png"}]}, true)
	result.visual.resource_dependencies.effects = [{"provider": "res://assets/effects/scuttle_crab/void_ward_antenna_wake/player.gd", "variant": "default"}, {"provider": "res://assets/effects/scuttle_crab/void_z_visionring_green/player.gd", "variant": "default"}, {"provider": "res://assets/effects/scuttle_crab/void_z_visionring_red/player.gd", "variant": "default"}]
	result.visual.visual_animations.death_followup_scene_path = "res://assets/units/void_scuttle_crab/burrow_view.tscn"
	result.audio.events.erase("active:cast")
	result.audio.events["bounty:gain"] = {"pool": ["res://assets/audio/units/scuttle_crab/gold0.wav", "res://assets/audio/units/scuttle_crab/gold1.wav", "res://assets/audio/units/scuttle_crab/gold2.wav"], "volume_db": 0.0, "bus": "Combat"}
	result.audio.events["shrine:start"] = {"pool": ["res://assets/audio/units/scuttle_crab/voidward0.wav"], "volume_db": 0.0, "bus": "Combat"}
	result.audio.events["shrine:leap"] = {"pool": ["res://assets/audio/units/void_scuttle_crab/death_leap_1.wav"], "volume_db": 0.0, "bus": "Combat"}
	result.audio.events["death"] = {"pool": ["res://assets/audio/units/void_scuttle_crab/death_cast_1.wav"], "volume_db": 0.0, "bus": "Combat"}
	result.audio.events["deploy:start"] = {"pool": ["res://assets/audio/units/void_scuttle_crab/spawn_cast_1.wav"], "volume_db": 0.0, "bus": "Combat"}
	result.audio.events["mend:sustain"] = {"pool": ["res://assets/audio/units/void_scuttle_crab/sru_dance_1.wav", "res://assets/audio/units/void_scuttle_crab/sru_dance_2.wav", "res://assets/audio/units/void_scuttle_crab/sru_dance_3.wav"], "volume_db": 0.0, "bus": "Combat"}
	return result
