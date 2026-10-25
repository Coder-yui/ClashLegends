extends SceneTree
## 双方浪潮、卡面与真实音频入口的可重复渲染。
var main: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("tidal_wave")
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
		if id == "tidal_wave": print("[浪潮音频] tick=", main.get_authoritative_server_tick(), " ", cue))
	for team in [0, 1]:
		for spec in ([] if "--no-units" in OS.get_cmdline_user_args() else [["garen", 1-team, Vector2(0,-100 if team == 0 else 100)], ["garen",team,Vector2(30,-50 if team == 0 else 50)], ["anivia",1-team,Vector2(-50,-200 if team == 0 else 200)]]):
			var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(spec[1], spec[0], Vector2(180 + 360*team, 760 if team == 0 else 520) + spec[2], {"deploy_time_override":0.0}))
			unit.can_attack = false
			unit.root(10.0)
	for tick in 145:
		if tick == 5:
			for team in [0,1]: main.play_card(team, "tidal_wave", Vector2(180 + 360*team, 760 if team == 0 else 520), {"immediate":true,"preview_active_spell":true})
		main._sim_step(0.05)
		main._spell_system.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if tick in [6,10,15,20,28,35,50,65,85]: await _capture("wave-%03d" % tick)
	main._selected_card = "tidal_wave"
	main._deployment_preview_visible = true
	main._deployment_preview_valid = true
	main._deployment_preview_pos = Vector2(140,700)
	main._deployment_preview_tile = Vector2i(3,17)
	main.queue_redraw()
	await _capture("deployment-preview")
	panel._on_team_toggled(true)
	main._update_deployment_preview(Vector2(140,580))
	main.queue_redraw()
	await _capture("red-deployment-preview")
	main._selected_card = ""
	main._clear_deployment_preview()
	panel.show_workspace(2)
	await create_timer(0.2).timeout
	await _capture("card-info")
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("tidal-wave-runtime.wav"))
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("tidal-" + label + ".png")
	root.get_texture().get_image().save_png(path)
	print("[浪潮截图] ", path)
