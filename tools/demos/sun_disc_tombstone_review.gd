extends SceneTree
const OUTPUT := "/tmp/clash-sun-disc-tombstone"
func _initialize() -> void:
	_run.call_deferred()
func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._minion_waves_enabled = false
	if main._ai != null: main._ai.enabled = false
	await create_timer(0.5).timeout
	for tower in main._towers:
		tower.can_attack = false
		main._audio_manager.stop_building_audio(tower.get_instance_id())
	var start := Time.get_ticks_msec()
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id in ["sun_disc", "tombstone"]: print("[building] ", (Time.get_ticks_msec()-start)/1000.0, " ", id, " ", cue))
	var recorder := AudioEffectRecord.new()
	var effect := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	var discs: Array = []
	for team in range(2):
		var position := Vector2(230, 880) if team == 0 else Vector2(490, 400)
		main.play_card(team,"sun_disc",position,{"immediate":true,"validate_position":false})
		discs.append(main._latest_unit_for_card("sun_disc",team))
		main.play_card(1-team,"garen",position+Vector2(0,-160 if team==0 else 160),{"immediate":true,"validate_position":false})
		main._latest_unit_for_card("garen",1-team).freeze(20.0)
	main.play_card(0,"tombstone",Vector2(480,1060),{"immediate":true,"validate_position":false})
	await create_timer(0.35).timeout
	await _capture("spawn")
	await create_timer(2.2).timeout
	await _capture("attack")
	for disc in discs:
		main.preview_active_skill(disc, CardDB.active_skills_for("sun_disc")[0])
	await create_timer(0.16).timeout
	await _capture("shield_wave")
	await create_timer(0.16).timeout
	await _capture("shield_edge")
	await create_timer(1.5).timeout
	for disc in discs: disc.take_damage(10000)
	await create_timer(0.4).timeout
	await _capture("death")
	await create_timer(5.0).timeout
	await _capture("finished")
	recorder.set_recording_active(false)
	var wav := recorder.get_recording()
	if wav != null: wav.save_to_wav(OUTPUT + "/lifecycle.wav")
	AudioServer.remove_bus_effect(0,effect)
	main.queue_free()
	await process_frame
	quit()
