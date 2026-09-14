extends SceneTree
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-match-audio")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var network := OS.get_cmdline_user_args().has("--mode=host") or OS.get_cmdline_user_args().has("--mode=join")
	if not network: main._start_local()
	if main._ai != null: main._ai.enabled = false
	var seen: Array[String] = []
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "match":
			seen.append(String(cue))
			print("[match audio] ",main.mode," ",cue," battle=",main._battle_elapsed))
	for _i in range(100):
		if main._match_started: break
		await create_timer(0.1).timeout
	var recorder := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,recorder)
	recorder.set_recording_active(true)
	if main.mode != "client":
		for tower in main._towers: tower.can_attack=false
		# Deploy through the same card entry used by the workbench.
		main.play_card(0,"ranged_minion",Vector2(320,920),{"immediate":true,"validate_position":false})
	await create_timer(5.4).timeout
	if not network:
		root.get_texture().get_image().save_png(OUTPUT+"/first_wave.png")
	await create_timer(1.2).timeout
	if main.mode != "client": main._king_enemy.take_damage(10000)
	await create_timer(4).timeout
	if not network:
		root.get_texture().get_image().save_png(OUTPUT+"/victory.png")
	recorder.set_recording_active(false)
	var wav := recorder.get_recording()
	if wav != null: wav.save_to_wav(OUTPUT+"/"+main.mode+".wav")
	AudioServer.remove_bus_effect(0,slot)
	var expected := "defeat" if main.mode=="client" else "victory"
	var ok := seen.count("minions_spawn")==1 and seen.count(expected)==1
	print("[match audio result] ",main.mode," ",ok," ",seen)
	main.queue_free()
	await process_frame
	quit(0 if ok else 1)
