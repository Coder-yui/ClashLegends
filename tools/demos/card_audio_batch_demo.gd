extends SceneTree
## 正式工作台出牌/技能事件的可复现录音；输出到 /tmp/clash-card-audio。
const CARDS := ["aurelionsol", "sett", "gwen", "teemo", "twisted_fate", "xin", "gnar", "anivia", "apex_turret", "pix", "imp"]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._audio_manager.cue_played.connect(func(id, cue, _pos): print("[batch audio] ", id, " ", cue))
	if "--network" in OS.get_cmdline_user_args():
		await create_timer(6.0).timeout
		if main.mode == "host":
			main.play_card(1, "garen", Vector2(360, 680), {"immediate": true, "validate_position": false})
			main.play_card(0, "teemo", Vector2(360, 790), {"immediate": true, "validate_position": false})
			main.play_card(0, "aurelionsol", Vector2(300, 790), {"immediate": true, "validate_position": false})
			await create_timer(1.2).timeout
			var teemo: Unit = main._latest_unit_for_card("teemo", 0)
			if teemo != null: main.preview_active_skill(teemo, CardDB.active_skills_for("teemo")[0])
		await create_timer(8.0).timeout
		main.multiplayer.multiplayer_peer.close()
		main.multiplayer.multiplayer_peer = null
		main.queue_free()
		await process_frame
		await process_frame
		await create_timer(0.25).timeout
		quit()
		return
	DirAccess.make_dir_recursive_absolute("/tmp/clash-card-audio")
	main._start_art_dev()
	main._art_dev_panel.show_workspace(1)
	var master := AudioServer.get_bus_index("Master")
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(master, record)
	var selected_cards: Array = CARDS.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cards="): selected_cards.assign(arg.trim_prefix("--cards=").split(","))
	for index in selected_cards.size():
		var id: String = selected_cards[index]
		main._clear_art_dev_units()
		await process_frame
		main._art_dev_panel._select_item(id)
		main._set_art_dev_team(index % 2)
		record.set_recording_active(true)
		main._run_workbench_scenario("spawn")
		main._run_workbench_scenario("target")
		await create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/clash-card-audio/"+id+".png")
		main._set_art_dev_skill_resource(0.0)
		main._use_art_dev_active_skill()
		await create_timer(2.0).timeout
		main._set_art_dev_skill_resource(999.0)
		main._use_art_dev_active_skill()
		await create_timer(0.25).timeout
		main._run_workbench_scenario("freeze")
		await create_timer(3.8).timeout
		main._run_workbench_scenario("death")
		await create_timer(1.5).timeout
		record.set_recording_active(false)
		var recording := record.get_recording()
		if recording != null: recording.save_to_wav("/tmp/clash-card-audio/"+id+".wav")
		print("[batch recording] ", id)
	AudioServer.remove_bus_effect(master, AudioServer.get_bus_effect_count(master)-1)
	main.queue_free()
	await process_frame
	await process_frame
	quit()
