extends SceneTree
## 双阵营真实预部署/落地录音截图；可传 --mode=host / --mode=join。
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-event-network")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var network := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): network = true
	if not network: main._start_local()
	main._minion_waves_enabled = false
	if main._ai != null: main._ai.enabled = false
	var start := Time.get_ticks_msec()
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "sun_disc": print("[Event] ", main.mode, " t=", (Time.get_ticks_msec()-start)/1000.0, " ", cue, " waves=", main._active_skill_effect_system.shield_effects.size()))
	var recorder := AudioEffectRecord.new()
	var bus_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	if main.mode != "client":
		for _i in range(100):
			if main._match_started: break
			await create_timer(0.1).timeout
		await create_timer(0.5).timeout
		for tower in main._towers: tower.can_attack = false
		main.play_card(0, "sun_disc", Vector2(280, 840), {"immediate": true, "validate_position": false})
		main.play_card(1, "sun_disc", Vector2(420, 820), {"immediate": true, "validate_position": false})
		if not network:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT + "/pre_deploy.png")
	var seen := {}
	var elapsed := 0.0
	while elapsed < 5.0:
		await process_frame
		elapsed += root.get_process_delta_time()
		for unit in get_nodes_in_group("combatants"):
			if unit is Unit and unit.card_id == "sun_disc" and not seen.has(unit.team):
				seen[unit.team] = true
				if main.mode != "client":
					main._active_skill_effect_system.apply_area_shield(unit, CardDB.get_card("sun_disc").active_skills[0])
				print("[Event appeared] ", main.mode, " team=", unit.team, " deploy=", unit._deploy_timer, " ready=", unit.is_deployed())
				if not network:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OUTPUT + "/appeared_%s.png" % unit.team)
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	if recording != null: recording.save_to_wav(OUTPUT + "/" + String(main.mode) + ".wav")
	AudioServer.remove_bus_effect(0, bus_index)
	main.set_process(false)
	if network and main.multiplayer.multiplayer_peer != null:
		main.multiplayer.multiplayer_peer.close()
		main.multiplayer.multiplayer_peer = null
	main.mode = "local"
	main._clear_art_dev_units()
	await process_frame
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if seen.size() == 2 else 1)
