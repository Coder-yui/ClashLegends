extends SceneTree
var main
var panel
var record: AudioEffectRecord
func _initialize() -> void:
	_run.call_deferred()
func snap(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	var path := preload("res://tools/lib/development_paths.gd").output("corki/" + label + ".png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("corki")
	await create_timer(1.0).timeout
	await snap("model")
	panel.show_workspace(2)
	await snap("info")
	panel.show_workspace(1)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "corki": print("AUDIO ", cue))
	record = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		main._set_art_dev_team(team)
		panel._select_item("corki")
		main._run_workbench_scenario("spawn")
		await create_timer(1.2).timeout
		var unit: Unit = main._art_dev_selected_unit()
		main.play_card(team, "ashe", unit.position + Vector2(-100, 0), {"immediate": true, "validate_position": false})
		main.play_card(team, "anivia", unit.position + Vector2(100, 0), {"immediate": true, "validate_position": false})
		await create_timer(1.2).timeout
		await snap("comparison_" + str(team))
		main._run_workbench_scenario("target")
		main._workbench.target = weakref(unit)
		await create_timer(1.5).timeout
		for other in get_nodes_in_group("combatants"):
			if other is Unit and other.team != team: other.position = unit.position + unit.get_visual_facing_direction() * 250.0
		for use in 3:
			main._use_art_dev_active_skill()
			await create_timer(0.23).timeout
			await snap("missile_%d_%d" % [team, use])
			await create_timer(0.25).timeout
			await snap("impact_%d_%d" % [team, use])
			await create_timer(0.8).timeout
		unit.freeze(1.0)
		await create_timer(0.5).timeout
		await snap("freeze_" + str(team))
		await create_timer(1.0).timeout
		unit.take_damage(99999.0)
		await create_timer(0.3).timeout
		await snap("death_" + str(team))
		await create_timer(1.0).timeout
	record.set_recording_active(false)
	var path := preload("res://tools/lib/development_paths.gd").output("corki/battle.wav")
	record.get_recording().save_to_wav(path)
	print("RECORDING ", path)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	await process_frame
	quit()
