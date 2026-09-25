extends SceneTree
## 真实弹体逐帧渲染验收，默认男爵炮弹；--card=<id>可检查其他正式弹体。
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var card := "siege_minion"
	var target_distance := 370.0
	var target_step := 0.0
	var target_angle := 0.0
	var target_card := "super_minion"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--angle="): target_angle = deg_to_rad(float(argument.trim_prefix("--angle=")))
		if argument.begins_with("--card="): card = argument.trim_prefix("--card=")
		if argument.begins_with("--distance="): target_distance = float(argument.trim_prefix("--distance="))
		if argument.begins_with("--target-step="): target_step = float(argument.trim_prefix("--target-step="))
		if argument.begins_with("--target-card="): target_card = argument.trim_prefix("--target-card=")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	main.play_card(0, card, Vector2(360, 850), {"immediate": true, "validate_position": false})
	main.play_card(1, target_card, Vector2(360, 850) + Vector2.UP.rotated(target_angle) * target_distance, {"immediate": true, "validate_position": false})
	await create_timer(1.1).timeout
	var source: Unit = main._latest_unit_for_card(card, 0)
	var target: Unit = main._latest_unit_for_card(target_card, 1)
	main.set_process(false)
	source.position = Vector2(360, 850)
	target.position = Vector2(360, 850) + Vector2.UP.rotated(target_angle) * target_distance
	source._prev_pos = source.position
	target._prev_pos = target.position
	main._projectile_system.clear_all()
	source.move_speed = 0
	target.move_speed = 0
	if card == "siege_minion": main.preview_active_skill(source, CardDB.active_skills_for(card)[0])
	main._projectile_system.launch(source, target, 1.0, source.projectile_speed, 0.0, 0.0, source.color)
	DirAccess.make_dir_recursive_absolute(preload("res://tools/lib/development_paths.gd").output("clash-projectile-" + card))
	for i in range(24):
		if i == 4:
			target.position.x += target_step
			target._prev_pos = target.position
		main._tick_projectiles(0.05)
		main._projectile_system.tick_visuals(0.05)
		await create_timer(0.05).timeout
		# 模拟20Hz权威Tick间的额外渲染帧。
		main._projectile_system.tick_visuals(1.0 / 120.0)
		await RenderingServer.frame_post_draw
		if i == 2 and "--closeup" in OS.get_cmdline_user_args():
			await _capture_closeup(main._projectile_system, card)
		root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("clash-projectile-" + card + "/%02d.png") % i)
	print("[弹体验收] ", preload("res://tools/lib/development_paths.gd").output("clash-projectile-" + card))
	main.free()
	await process_frame
	quit()

func _capture_closeup(system: ProjectileSystem, card: String) -> void:
	for view in system._native_visuals._views.values():
		if bool(view.wave): continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(720, 360)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.size = Vector2(720, 360)
		background.color = Color(0.025, 0.035, 0.06)
		viewport.add_child(background)
		var closeup: Node2D = view.node.duplicate()
		viewport.add_child(closeup)
		closeup.position = Vector2(400, 180)
		closeup.rotation = PI * 0.5
		closeup.scale = Vector2.ONE * 4.0
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("clash-projectile-" + card + "/projectile-closeup.png"))
		viewport.queue_free()
		return
