extends SceneTree
## 实战声音与时间戳；可传 --mode=host / --mode=join 做同场联机复核。
const OUTPUT := "/tmp/clash-apex-audio"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var team := 0
	var network := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): network = true
		if arg == "--team=1": team = 1
	if not network: main._start_local()
	main._minion_waves_enabled = false
	if main._ai != null: main._ai.enabled = false
	var started := Time.get_ticks_msec()
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "apex_turret": print("[apex] ", main.mode, " t=", (Time.get_ticks_msec() - started) / 1000.0, " ", cue))
	var recorder := AudioEffectRecord.new()
	var bus_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	if main.mode != "client":
		for _attempt in range(100):
			if main._match_started: break
			await create_timer(0.1).timeout
		await create_timer(0.5).timeout
		for tower in main._towers: tower.can_attack = false
		main.play_card(1 - team, "garen", Vector2(360, 640), {"immediate": true, "validate_position": false})
		var target: Unit = main._latest_unit_for_card("garen", 1 - team)
		target.freeze(30.0)
		main.play_card(team, "apex_turret", Vector2(360, 960 if team == 0 else 320), {"immediate": true, "validate_position": false})
		await create_timer(2.0).timeout
		target.position = Vector2(360, 800 if team == 0 else 480)
		await create_timer(3.0).timeout
		var turret: Unit = main._latest_unit_for_card("apex_turret", team)
		main.play_card(1 - team, "garen", Vector2(360, 710 if team == 0 else 570), {"immediate": true, "validate_position": false})
		var far_target: Unit = main._latest_unit_for_card("garen", 1 - team)
		far_target.freeze(30.0)
		main.preview_active_skill(turret, CardDB.active_skills_for("apex_turret")[0])
		var observed := 0.0
		var captured := false
		while observed < 1.2:
			await process_frame
			observed += root.get_process_delta_time()
			if not network and not captured:
				for projectile in main._projectile_system.projectiles.values():
					if String(projectile.get("visual", "")) == "electromagnetic_wave":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(OUTPUT + "/beam_%s.png" % team)
						captured = true
						break
		turret.take_damage(10000.0)

		await create_timer(3.0).timeout
	else:
		await create_timer(12.0).timeout
	recorder.set_recording_active(false)
	var wav := recorder.get_recording()
	if wav != null: wav.save_to_wav(OUTPUT + "/" + String(main.mode) + ".wav")
	AudioServer.remove_bus_effect(0, bus_index)
	if not network:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + "/battle.png")
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
	quit()
