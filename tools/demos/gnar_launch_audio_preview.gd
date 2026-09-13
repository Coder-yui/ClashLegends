extends SceneTree
## 默认真实渲染/录音；也支持 -- --mode=host 或 --mode=join 核对可靠启停。
const OUTPUT := "/tmp/clash-gnar-launch"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var network := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			network = true
	if not network:
		main._start_local()
	main._minion_waves_enabled = false
	if main._ai != null:
		main._ai.enabled = false
	var record := AudioEffectRecord.new()
	var record_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	if main.mode != "client":
		for _attempt in 100:
			if main._match_started: break
			await create_timer(0.1).timeout
		for tower in main._towers:
			tower.can_attack = false
		main.play_card(0, "gnar", Vector2(360, 960), {"immediate": true, "validate_position": false})
		main.play_card(1, "garen", Vector2(360, 820), {"immediate": true, "validate_position": false})
		var target: Unit = main._latest_unit_for_card("garen", 1)
		target.freeze(30.0)
	var previous := []
	var elapsed := 0.0
	var transitions := 0
	while elapsed < 7.0:
		await process_frame
		elapsed += root.get_process_delta_time()
		var active: Array = main._audio_manager._projectile_launch_players.keys()
		if active != previous:
			print("[launch生命周期] ", main.mode, " t=", snappedf(elapsed, 0.01), " ids=", active)
			previous = active.duplicate()
			transitions += 1
	record.set_recording_active(false)
	var wav := record.get_recording()
	if wav != null:
		wav.save_to_wav(OUTPUT + "/" + String(main.mode) + "_mix.wav")
	AudioServer.remove_bus_effect(0, record_index)
	print("[launch验收] ", main.mode, " transitions=", transitions, " remaining=", main._audio_manager._projectile_launch_players.size())
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
	quit(0 if transitions >= 4 else 1)
