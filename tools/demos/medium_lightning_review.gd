extends SceneTree
## 正式工作台入口：双方强化落雷、塔失效与实际混音录制。
var main: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("medium_lightning")
	panel.show_workspace(1)
	main._clear_art_dev_units()
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	panel._set_battle_zoom(1.0)
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "medium_lightning": print("[落雷音频] ", cue))
	var points := []
	for tower in main.world.towers_snapshot():
		tower.can_attack = false
		if tower.is_king: continue
		if tower.global_position.x > 360: continue
		points.append({"pos": tower.global_position, "team": 1-tower.team})
		for team in [0,1]:
			var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team,"garen",tower.global_position+Vector2(80,45 if team == tower.team else -45),{"deploy_time_override":0.0}))
			unit.position = tower.global_position+Vector2(80,30 if team == tower.team else -30)
			unit.can_attack = false
			unit.root(20.0)
	await create_timer(0.2).timeout
	await capture("before")
	for tick in 125:
		if tick == 2:
			for point in points: main.play_card(point.team,"medium_lightning",point.pos,{"immediate":true,"preview_active_spell":true})
		main._sim_step(0.05)
		main._spell_system.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if tick in [2,12,22,32,41,42,44,60,80,82,88,105]: await capture("tick-%02d" % tick)
	panel.show_workspace(2)
	await create_timer(0.2).timeout
	await capture("card-info")
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("medium-lightning-runtime.wav"))
	main.queue_free()
	await process_frame
	quit()
func capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("medium-lightning-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[落雷截图] ",path)
