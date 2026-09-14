extends SceneTree
## 手动试听：Godot --path . --script tools/demos/missfortune_audio_demo.gd
## 录音输出到 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash_missfortune_audio.wav，覆盖普攻、W 和死亡。

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	main._audio_manager.cue_played.connect(func(id, cue, _pos): print("[missfortune audio] ", id, " ", cue))
	var record := AudioEffectRecord.new()
	var master := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master, record)
	record.set_recording_active(true)
	var missfortune: Unit = main._spawn_unit(0, "missfortune", Vector2(360, 900), 0.0)
	var target: Unit = main._spawn_unit(1, "garen", Vector2(360, 735), 0.0)
	target.move_speed = 0.0
	for tick in 150:
		if tick == 25:
			main.preview_active_skill(missfortune, CardDB.active_skills_for("missfortune")[0])
		if tick == 115:
			missfortune.take_damage(99999.0)
		main._sim_step(0.05)
		await create_timer(0.05).timeout
	record.set_recording_active(false)
	var recording := record.get_recording()
	if recording != null:
		recording.save_to_wav(preload("res://tools/lib/development_paths.gd").output("clash_missfortune_audio.wav"))
	AudioServer.remove_bus_effect(master, AudioServer.get_bus_effect_count(master) - 1)
	main.queue_free()
	await process_frame
	await process_frame
	quit()
