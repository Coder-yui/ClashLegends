extends SceneTree
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-nexus-audio")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var recorder := AudioEffectRecord.new()
	var index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	var start := Time.get_ticks_msec()
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if String(id).begins_with("world_nexus"): print("[水晶声音] ", (Time.get_ticks_msec()-start)/1000.0, " ", id, " ", cue))
	main._start_local()
	main._minion_waves_enabled = false
	if main._ai != null: main._ai.enabled = false
	await create_timer(1).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUTPUT + "/hold.png")
	await create_timer(3).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUTPUT + "/spawn.png")
	await create_timer(4).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUTPUT + "/idle.png")
	main._king_enemy.take_damage(main._king_enemy.hp + 1)
	await create_timer(0.3).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUTPUT + "/death.png")
	await create_timer(8).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUTPUT + "/ruin.png")
	recorder.set_recording_active(false)
	var wav := recorder.get_recording()
	if wav != null: wav.save_to_wav(OUTPUT + "/lifecycle.wav")
	AudioServer.remove_bus_effect(0, index)
	main.queue_free()
	await process_frame
	quit()
