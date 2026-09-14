extends SceneTree
## 实际渲染非穿透 W：前排挡后排、侧箭继续。固定模拟，输出 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-ashe-volley-collision。
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-ashe-volley-collision")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	main._art_dev_panel.show_workspace(1)
	main.set_process(false)
	for team in [0, 1]:
		main._clear_art_dev_units()
		var forward := Vector2.UP if team == 0 else Vector2.DOWN
		var origin := Vector2(360, 860 if team == 0 else 420)
		main.play_card(team, "ashe", origin, {"immediate": true, "validate_position": false})
		var ashe: Unit = main._latest_unit_for_card("ashe", team)
		ashe._deploy_timer = 0.0
		ashe.move_speed = 0.0
		var targets: Array[Unit] = []
		for offset in [forward * 80.0, forward * 150.0, forward.rotated(deg_to_rad(23.65)) * 150.0]:
			var dummy := Unit.new()
			dummy.card_id = "training_dummy"
			dummy.setup(1 - team, CardDB.training_dummy_stats(), "W 木桩")
			dummy.position = origin + offset
			main.add_child(dummy)
			targets.append(dummy)
		ashe.active_skill_cast_facing = forward
		var skill: Dictionary = CardDB.active_skills_for("ashe")[0].duplicate(true)
		skill["cast_forward"] = forward
		main.preview_active_skill(ashe, skill)
		for frame in 22:
			if frame % 3 == 0:
				main._sim_step(0.05)
			main._active_skill_effect_system.tick_visuals(1.0 / 60.0)
			await process_frame
			await RenderingServer.frame_post_draw
			if frame in [5, 11, 14, 17, 21]:
				root.get_texture().get_image().save_png(OUTPUT + "/team%d_frame%02d.png" % [team, frame])
		print("[W 实测] team=", team, " hp=", targets.map(func(u): return u.hp), " arrows=", main._projectile_system.projectiles.size())
	main.queue_free()
	await process_frame
	quit()
