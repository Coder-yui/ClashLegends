extends SceneTree
## 庇护清泉双方、地空、暂停与消散的真实工作台渲染。
var main: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("pool_of_reflection")
	panel.show_workspace(1)
	main._clear_art_dev_units()
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	main._audio_manager.set_process(false)
	panel._set_battle_zoom(1.0)
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "pool_of_reflection": print("[庇护清泉音频] tick=", main.get_authoritative_server_tick(), " ", cue))
	for team in [0, 1]:
		var center := Vector2(180 + 360*team, 820 if team == 0 else 480)
		for offset in [Vector2.ZERO, Vector2(60, 0)]:
			var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team, "garen" if offset == Vector2.ZERO else "anivia", center + offset, {"deploy_time_override":0.0}))
			unit.can_attack = false
			unit.root(10.0)
	for tick in 115:
		if tick == 5:
			for team in [0,1]: main.play_card(team, "pool_of_reflection", Vector2(180 + 360*team, 820 if team == 0 else 480), {"immediate":true,"preview_active_spell":true})
		main._sim_step(0.05)
		main._spell_system.tick_visuals(0.05)
		main._audio_manager._process(0.05)
		await create_timer(0.05).timeout
		if tick in [6,15,35,55,65,75,90,110]: await _capture("battle-%03d" % tick)
	panel.show_workspace(2)
	await create_timer(0.2).timeout
	await _capture("card-info")
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("pool-of-reflection-runtime.wav"))
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("pool-" + label + ".png")
	root.get_texture().get_image().save_png(path)
	print("[庇护清泉截图] ", path)
