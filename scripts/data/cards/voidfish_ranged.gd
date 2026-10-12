extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	var data: Dictionary = preload("res://scripts/data/cards/voidfish.gd").definition().duplicate(true)
	data.gameplay.merge({"name": "远程虚空鱼", "cost": 3, "selectable": true,
		"description": "三角阵型部署3只远程空中虚空鱼，可攻击地面和空中目标。生命低于近战虚空鱼。",
		"hp": 80, "range": 140.0, "first_hit": 0.46,
		"projectile_speed": 420.0, "deploy_time": 1.0,
		"deployment_count": 3, "deployment_spacing": 36.0, "deployment_formation": "polygon",
		"active_skills": [{"name": "虚空再生", "kind": "death_spawn", "cost": 2, "max_uses": 1, "cooldown": 10.0,
			"duration": 3.0, "target_scope": "deployment_group", "spawn_id": "voidfish_ranged_single",
			"description": "本批仍存活的虚空鱼在3秒内被击杀时，各在死亡位置生成一只新的远程虚空鱼；新鱼不继承再生或主动资格。"}]}, true)
	data.visual.visual_scene_path = "res://assets/units/voidfish_ranged/voidfish_ranged_view.tscn"
	data.visual.visual_animations = {"deploy": "ranged_idle", "idle": "ranged_idle", "move": "ranged_run", "move_cycle": ["ranged_run"], "clip_blends": {"ranged_run>ranged_run": 0.12}, "attack": ["ranged_attack"], "death": "ranged_death", "death_duration": 0.6}
	data.visual.projectile_visual = "voidfish_missile"
	data.visual.resource_dependencies = {"effects": [{"provider": "res://assets/effects/voidfish_ranged/player.gd", "variant": "spawn"}, {"provider": "res://assets/effects/voidfish_ranged/player.gd", "variant": "missile"}]}
	data.visual.active_skills = [{"icon_path": "res://assets/skills/voidfish_ranged_0.png", "resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/voidfish_regeneration/player.gd", "variant": "regeneration"}]}}]
	data.visual.visual_active_buff_scene = "res://assets/effects/voidfish_regeneration/buff.tscn"
	data.card_art = {"path": "res://assets/cards/voidfish_ranged_loading.png"}
	data.audio.attack_swing = [["res://assets/audio/units/voidfish_ranged/swing_1.wav"]]
	data.audio.attack_hit = ["res://assets/audio/units/voidfish_ranged/hit_1.wav"]
	data.audio.attack_swing_lead_time = 0.10
	return data
