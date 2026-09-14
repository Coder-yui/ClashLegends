extends SceneTree
## 手动试听：Godot --path . --script tools/demos/garen_audio_demo.gd
## 顺序演示 Q、E（不是一场战斗携带两个技能），使用正式表现与技能入口。

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_local()
	main.set_process(false)
	main._audio_manager.cue_played.connect(func(_id, cue, _pos): print("[audio demo] ", cue))
	for choice in 2:
		main._clear_art_dev_units()
		await process_frame
		main._active_skill_choices["garen"] = choice
		var garen: Unit = main._spawn_unit(0, "garen", Vector2(220, 440), 0.0)
		if choice == 1:
			main._spawn_unit(1, "xin", Vector2(240, 460), 0.0)
			main._spawn_unit(1, "xin", Vector2(200, 460), 0.0)
		for tick in 120:
			if tick == 20:
				main.preview_active_skill(garen, CardDB.active_skills_for("garen")[choice])
			main._sim_step(0.05)
			await create_timer(0.05).timeout
			if tick == 35:
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("clash_garen_audio_%d.png") % choice)
		if is_instance_valid(garen):
			garen.notify_visual_death()
		await create_timer(1.5).timeout
	main.queue_free()
	await process_frame
	await process_frame
	quit()
