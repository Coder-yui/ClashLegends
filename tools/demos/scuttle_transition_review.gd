extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("scuttle_crab")
	panel.show_workspace(1)
	panel._set_battle_zoom(1.3)
	main.set_physics_process(false)
	main.set_process(false)
	var units: Array[Unit] = []
	for row in 2:
		for team in 2:
			units.append(main._spawn_unit(UnitSpawnRequest.new(team, "scuttle_crab" if row == 0 else "void_scuttle_crab", Vector2(240 + team * 240, 710 + row * 180), {"deploy_time_override": 0.0})))
	await create_timer(1.8).timeout
	for unit in units: unit.take_damage(99999)
	var start := Time.get_ticks_msec()
	var previous := start
	var accumulator := 0.0
	var phase_age := 0.0
	var shots: Array = [0.5, 1.0, 1.5, 2.0, 2.5, 4.8, 8.5, 9.5, 10.75, 10.85, 11.0]
	var captures: Array = []
	var cleared := false
	var clear_test := "--clear-test" in OS.get_cmdline_user_args()
	while not shots.is_empty():
		await process_frame
		var now := Time.get_ticks_msec()
		var delta := root.get_process_delta_time()
		phase_age += delta
		previous = now
		accumulator += delta
		main._skill_presentation.tick_visuals(delta)
		while accumulator >= 0.05:
			main._active_skill_effect_system.tick_effects(0.05)
			accumulator -= 0.05
		var age := phase_age
		if clear_test and age >= 3.1 and not cleared:
			main.clear_preview_battle()
			cleared = true
		if age >= float(shots[0]):
			var label := str(shots.pop_front())
			RenderingServer.force_draw()
			var path := preload("res://tools/lib/development_paths.gd").output("crab-transition-" + label + ".png")
			captures.append({"path": path, "image": root.get_texture().get_image()})
			print("[Transition] ", age, " ", path)
	for capture in captures: capture.image.save_png(capture.path)
	recorder.set_recording_active(false)
	recorder.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("crab-phases-runtime.wav"))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	quit()
