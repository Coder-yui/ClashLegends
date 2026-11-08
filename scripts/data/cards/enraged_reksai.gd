extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/nest_reksai.gd").definition().duplicate(true)
	data.gameplay.merge({"name": "暴怒雷克塞", "summon_prefer_outward": true, "description": "提前出巢，持续使用女王之怒进行范围攻击。", "damage": 90, "first_hit": 0.18, "splash_radius": 60.0, "deploy_time": 0.0}, true)
	data.visual.visual_scene_path = "res://assets/units/queen_nest/enraged_view.tscn"
	data.visual.visual_animations.attack = ["Spell1", "Spell1B"]
	data.visual.resource_dependencies = {"effects": [{"provider": "res://assets/effects/reksai/player.gd", "variant": "swipe"}, {"provider": "res://assets/effects/reksai/player.gd", "variant": "swipe_second"}, {"provider": "res://assets/effects/reksai/player.gd", "variant": "buff"}]}
	var original: Dictionary = preload("res://scripts/data/cards/reksai.gd").definition()
	data.audio.attack_swing = [original.audio.empowered_swing_by_segment[0], original.audio.empowered_swing_by_segment[1]]
	data.audio.events.erase("deploy:start")
	data.audio.events.erase("deploy:voice")
	return data
