extends SceneTree
## 实际渲染与混音录音；工作台 Spell4 试听、范围护盾及基础单位攻击。
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-event-audio")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._select_item("twisted_fate")
	panel.show_workspace(2)
	for i in panel._audio_cue.item_count:
		if "R2·Gate 落点" in panel._audio_cue.get_item_text(i):
			panel._audio_cue.select(i)
			panel._filter_audio(i)
			break
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/spell4-workbench.png")
	panel._select_item("sun_disc")
	panel.show_workspace(1)
	main._run_workbench_scenario("spawn")
	main._audio_manager.cue_played.connect(func(id, cue, pos): print("[事件试听] ", id, " ", cue, " ", pos))
	var recording := AudioEffectRecord.new()
	var index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, recording)
	recording.set_recording_active(true)
	await create_timer(1.2).timeout
	main.play_card(0, "melee_minion", Vector2(350, 900), {"immediate": true, "validate_position": false})
	main._use_art_dev_active_skill(0)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/shield.png")
	main.play_card(0, "heal", Vector2(350, 900), {"immediate": true, "validate_position": false})
	main.play_card(0, "tombstone", Vector2(470, 940), {"immediate": true, "validate_position": false})
	for team in 2:
		main.play_card(team, "ranged_minion", Vector2(240 + team * 40, 800 - team * 80), {"immediate": true, "validate_position": false})
		main.play_card(team, "siege_minion", Vector2(440 - team * 40, 800 - team * 80), {"immediate": true, "validate_position": false})
	await create_timer(7).timeout
	recording.set_recording_active(false)
	var wav := recording.get_recording()
	if wav != null: wav.save_to_wav(OUTPUT + "/runtime.wav")
	AudioServer.remove_bus_effect(0, index)
	main._clear_art_dev_units()
	main.queue_free()
	await process_frame
	quit()
