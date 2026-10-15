extends SceneTree
## 实际工作台、双方模型、命中圈、Q动画和运行混音取证。
var main: Node2D
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("yorick")
	panel.show_workspace(1)
	main.set_physics_process(false)
	main.set_process(false)
	panel._set_battle_zoom(1.3)
	var units: Array[Unit] = []
	for team in [0, 1]:
		var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team, "yorick", Vector2(220+240*team,850), {"deploy_time_override":0.0}))
		units.append(unit)
	var reference: Unit = main._spawn_unit(UnitSpawnRequest.new(0,"darius",Vector2(350,850),{"deploy_time_override":0.0}))
	await create_timer(0.8).timeout
	await _capture("idle-size")
	for unit in units:
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-unit.team,"target_dummy",unit.position+Vector2(0,-65 if unit.team==0 else 65),{"deploy_time_override":0.0}))
		target.hp = 10000
		target.max_hp = 10000
		unit._target = target
		unit.hp = 400
		main._active_skill_effect_system.apply(unit,CardDB.active_skills_for("yorick")[0])
	for frame in range(55):
		main._sim_step(0.05)
		main._projectile_system.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if frame in [1,5,6,9,20,35,50]: await _capture("combat-%02d" % frame)
	for unit in units: unit.take_damage(99999)
	await create_timer(0.4).timeout
	await _capture("death")
	await create_timer(1.2).timeout
	main._projectile_system.tick_visuals(1.6)
	await _capture("cleared")
	panel.show_workspace(2)
	await create_timer(0.2).timeout
	await _capture("card-info")
	recorder.set_recording_active(false)
	recorder.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("yorick-runtime.wav"))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("yorick-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[Yorick render] ",path)
