extends SceneTree
## 空转审判 → 死亡中断审判 → 寒冰死亡；同时录制实际 Master 混音供试听。
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._audio_manager.cue_played.connect(func(id, cue, _pos): print("[sustain demo] ", id, " ", cue))
	var network := false
	for arg in OS.get_cmdline_user_args():
		network = network or arg in ["--mode=host", "--mode=join"]
	if network:
		await create_timer(5.0).timeout
		if main.mode == "host":
			for unit in get_nodes_in_group("combatants"):
				if unit is Unit and unit.card_id == "garen":
					main.preview_active_skill(unit, CardDB.active_skills_for("garen")[1])
				if unit is Unit and unit.card_id == "ashe":
					unit.take_damage(99999.0)
		await create_timer(5.0).timeout
		main.queue_free()
		await process_frame
		await process_frame
		await create_timer(0.25).timeout
		quit()
		return
	main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	var record := AudioEffectRecord.new()
	var master := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master, record)
	record.set_recording_active(true)
	var garen: Unit = main._spawn_unit(0, "garen", Vector2(360, 1000), 0.0)
	main.preview_active_skill(garen, CardDB.active_skills_for("garen")[1])
	for tick in 190:
		if tick == 85:
			main.preview_active_skill(garen, CardDB.active_skills_for("garen")[1])
		if tick == 105:
			garen.take_damage(99999.0)
		if tick == 135:
			var ashe: Unit = main._spawn_unit(0, "ashe", Vector2(360, 1000), 0.0)
			ashe.take_damage(99999.0)
		main._sim_step(0.05)
		await create_timer(0.05).timeout
		if tick == 40:
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/clash_sustained_audio.png")
	record.set_recording_active(false)
	var recording := record.get_recording()
	if recording != null:
		recording.save_to_wav("/tmp/clash_sustained_audio.wav")
	AudioServer.remove_bus_effect(master, AudioServer.get_bus_effect_count(master) - 1)
	main.queue_free()
	await process_frame
	await process_frame
	quit()
