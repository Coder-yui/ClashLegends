extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("scuttle_crab")
	panel.show_workspace(1)
	main.set_physics_process(false)
	main.set_process(false)
	var units: Array[Unit] = []
	for team in [0,1]:
		var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team,"scuttle_crab",Vector2(230+260*team,800),{"deploy_time_override":0.0}))
		units.append(unit)
	var reference: Unit = main._spawn_unit(UnitSpawnRequest.new(0,"ashe",Vector2(360,800),{"deploy_time_override":0.0}))
	panel._set_battle_zoom(1.5)
	await create_timer(0.8).timeout
	await _capture("idle")
	for unit in units: unit.structure_mending = true
	await create_timer(1.0).timeout
	await _capture("dance")
	for unit in units:
		var skill: Dictionary = CardDB.active_skills_for("scuttle_crab")[0].duplicate(true)
		main.runtime._start_active_skill_cast(unit,skill)
		main._active_skill_effect_system.apply(unit,skill)
	for age in [0.1,0.3,0.6,1.2,2.5]:
		for effect in main._skill_presentation.frontal_effects: effect.timer = float(effect.duration)-age
		await _capture("randuin-"+str(age))
	main._skill_presentation.clear()
	for unit in units: unit.take_damage(99999)
	await create_timer(0.15).timeout
	await _capture("sinking-0.15")
	await create_timer(0.35).timeout
	await _capture("sinking-0.5")
	await create_timer(0.6).timeout
	for i in 22: main._active_skill_effect_system.tick_effects(0.05)
	for age in [0.1,0.8,2.5,5.8]:
		for effect in main._skill_presentation.frontal_effects: effect.timer = float(effect.duration)-age
		await _capture("shrine-"+str(age))
	main._skill_presentation.clear()
	await create_timer(1.5).timeout
	await _capture("cleared")
	await create_timer(4.5).timeout
	recorder.set_recording_active(false)
	recorder.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("scuttle-runtime.wav"))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	current_scene._art_dev_panel.show_workspace(1)
	for i in 5: await process_frame
	RenderingServer.force_draw()
	var path := preload("res://tools/lib/development_paths.gd").output("scuttle-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[Scuttle render] ",path)
