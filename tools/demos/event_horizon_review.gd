extends SceneTree
## 扭曲空间正式工作台与真实权威施法入口的可重复渲染。
var main: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("event_horizon")
	panel.show_workspace(1)
	main._clear_art_dev_units()
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	panel._set_battle_zoom(1.0)
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "event_horizon": print("[扭曲空间音频] tick=", main.get_authoritative_server_tick(), " ", cue))
	for team in [0, 1]:
		var center := Vector2(180 + 360*team, 820 if team == 0 else 480)
		for offset in [Vector2(120,0), Vector2.ZERO]:
			var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, "garen", center + offset, {"deploy_time_override":0.0}))
			unit.can_attack = false
			unit.root(10.0)
	for tick in 130:
		if tick == 5:
			for team in [0,1]: main.play_card(team, "event_horizon", Vector2(180 + 360*team, 820 if team == 0 else 480), {"immediate":true,"preview_active_spell":true})
		main._sim_step(0.05)
		main._spell_system.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if tick in [10,21,30,42,47,65,82,100]: await _capture("battle-%03d" % tick)
	panel.show_workspace(2)
	await create_timer(0.2).timeout
	await _capture("card-info")
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("event-horizon-runtime.wav"))
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("horizon-" + label + ".png")
	root.get_texture().get_image().save_png(path)
	print("[扭曲空间截图] ", path)
