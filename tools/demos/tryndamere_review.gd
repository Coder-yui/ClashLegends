extends SceneTree
var main
var panel
var record: AudioEffectRecord
func _initialize() -> void:
	_run.call_deferred()
func snap(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	var path := preload("res://tools/lib/development_paths.gd").output("tryndamere/" + label + ".png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("tryndamere")
	await create_timer(0.8).timeout
	await snap("model")
	panel.show_workspace(2)
	await snap("info")
	panel.show_workspace(1)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "tryndamere": print("AUDIO ", cue))
	record = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		main._set_art_dev_team(team)
		panel._select_item("tryndamere")
		main._run_workbench_scenario("spawn")
		await create_timer(1.2).timeout
		var unit: Unit = main._art_dev_selected_unit()
		main.play_card(team, "darius", unit.position + Vector2(-100, 0), {"immediate": true, "validate_position": false})
		main.play_card(team, "sett", unit.position + Vector2(100, 0), {"immediate": true, "validate_position": false})
		await create_timer(1.2).timeout
		await snap("comparison_" + str(team))
		for other in get_nodes_in_group("combatants"):
			if other is Unit and other != unit: other.queue_free()
		await process_frame
		main._workbench.target = weakref(unit)
		unit.position = Vector2(300, 900 if team == 0 else 380)
		main._run_workbench_scenario("target")
		main._workbench.target = weakref(unit)
		for i in 6:
			await create_timer(1.0).timeout
			print("ATTACK_SERIAL ", unit.get_attack_visual_serial(), " RAGE ", unit.skill_resource_value)
			if i in [1, 3, 5]: await snap("attack_" + str(team) + "_" + str(i))
		main.preview_active_skill(unit, CardDB.active_skills_for("tryndamere")[0])
		await create_timer(0.6).timeout
		await snap("rage_" + str(team))
		panel.show_workspace(2)
		var paused_tick: int = main._sim_tick_id
		await create_timer(0.5).timeout
		assert(main._sim_tick_id == paused_tick)
		panel.show_workspace(1)
		await create_timer(4.0).timeout
		await snap("rage_end_" + str(team))
		unit.freeze(2.0)
		await create_timer(0.5).timeout
		await snap("freeze_" + str(team))
		await create_timer(2.0).timeout
		unit.take_damage(99999.0)
		await create_timer(1.1).timeout
	record.set_recording_active(false)
	var path := preload("res://tools/lib/development_paths.gd").output("tryndamere/battle.wav")
	record.get_recording().save_to_wav(path)
	print("RECORDING ", path)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	await process_frame
	quit()
