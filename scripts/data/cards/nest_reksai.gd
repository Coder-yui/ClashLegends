extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/reksai.gd").definition().duplicate(true)
	for field in ["deploy_zone", "pre_deploy_time", "pre_deploy_burrow_speed", "deploy_sweep_name", "deploy_sweep_radius", "deploy_sweep_damage", "deploy_sweep_knockback", "deploy_sweep_duration", "deploy_sweep_mass_factor_max"]:
		data.gameplay.erase(field)
	data.gameplay.merge({"description": "巢穴被摧毁后出现，以复生动作部署，使用普通攻击。", "selectable": false, "deploy_time": 1.1, "active_skills": []}, true)
	data.visual.erase("visual_pre_deploy_scene")
	data.visual.erase("visual_active_buff_scene")
	data.visual.erase("resource_dependencies")
	data.visual.visual_scene_path = "res://assets/units/queen_nest/reksai_view.tscn"
	data.visual.visual_animations.deploy = "Respawn"
	data.visual.active_skills = []
	data.audio.events.erase("pre_deploy:sustain")
	data.audio.events.erase("deploy:hit")
	for event in ["empowered_buff:start", "empowered_buff:end", "active:cast"]:
		data.audio.events.erase(event)
	for field in ["empowered_swing_by_segment", "empowered_hit_by_segment"]:
		data.audio.erase(field)
	data.audio.events.erase("deploy:voice")
	return data
