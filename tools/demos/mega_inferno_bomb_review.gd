extends SceneTree
## 终极爆弹正式工作台与真实权威施法入口的可重复渲染。
var main: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("mega_inferno_bomb")
	panel.show_workspace(1)
	main._clear_art_dev_units()
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	panel._set_battle_zoom(1.0)
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "mega_inferno_bomb": print("[终极爆弹音频] tick=", main.get_authoritative_server_tick(), " ", cue))
	var centers := [Vector2(180,820), Vector2(540,480)]
	if OS.get_environment("CLASH_BOMB_LONG_FLIGHT") == "1": centers = [Vector2(210,300), Vector2(510,1000)]
	for team in [0, 1]:
		var center: Vector2 = centers[team]
		for offset in [Vector2.ZERO, Vector2(130, 0)]:
			var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(1-team, "garen" if offset == Vector2.ZERO else "anivia", center + offset, {"deploy_time_override":0.0}))
			unit.max_hp = 3000
			unit.hp = 3000
			unit.add_shield(500, 15)
			unit.can_attack = false
			unit.root(10.0)
	for tick in 165:
		if tick == 5:
			for team in [0,1]: main.play_card(team, "mega_inferno_bomb", centers[team], {"immediate":true,"preview_active_spell":true})
		if tick == 80: panel._on_team_toggled(true)
		if tick == 50:
			for unit in main.get_tree().get_nodes_in_group("combatants"):
				if unit is Unit:
					unit.add_shield(4000, 10)
					unit.hp = unit.max_hp * 1.3
		main._sim_step(0.05)
		main._spell_system.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if tick in [6,12,20,24,28,32,38,42,52,65,82,100,155]: await _capture("battle-%03d" % tick)
	panel.show_workspace(2)
	await create_timer(0.2).timeout
	await _capture("card-info")
	record.set_recording_active(false)
	record.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("mega-inferno-bomb-runtime.wav"))
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("bomb-" + label + ".png")
	root.get_texture().get_image().save_png(path)
	print("[终极爆弹截图] ", path)
