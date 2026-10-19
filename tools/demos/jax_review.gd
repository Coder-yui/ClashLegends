extends SceneTree
## 实际工作台、双方模型、命中圈、E动画和运行混音取证。
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
	panel._select_item("jax")
	panel.show_workspace(1)
	main.set_physics_process(false)
	main.set_process(false)
	panel._set_battle_zoom(1.3)
	if "--animations" in OS.get_cmdline_user_args():
		await _review_transitions()
		recorder.set_recording_active(false)
		AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
		main.queue_free()
		await process_frame
		quit()
		return
	var deployment: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "jax", Vector2(350,850)))
	for step in range(41):
		if step in [0,20,40]:
			await _capture("deploy-%02d" % step)
		main._sim_step(0.05)
		await create_timer(0.05).timeout
	deployment.free()
	var units: Array[Unit] = []
	for team in [0, 1]:
		var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team, "jax", Vector2(220+240*team,850), {"deploy_time_override":0.0}))
		units.append(unit)
	var reference: Unit = main._spawn_unit(UnitSpawnRequest.new(0,"darius",Vector2(350,850),{"deploy_time_override":0.0}))
	await create_timer(0.8).timeout
	await _capture("idle-size")
	for unit in units: main.preview_active_skill(unit, CardDB.active_skills_for("jax")[0])
	await create_timer(0.2).timeout
	await _capture("active-idle")
	for unit in units:
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-unit.team,"target_dummy",unit.position+Vector2(0,-65 if unit.team==0 else 65),{"deploy_time_override":0.0}))
		target.hp = 10000
		target.max_hp = 10000
		unit._target = target
		unit.hp = 1100
		main.preview_active_skill(unit,CardDB.active_skills_for("jax")[0])
	for frame in range(65):
		main._sim_step(0.05)
		main._projectile_system.tick_visuals(0.05)
		main._skill_presentation.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if frame in [1,5,9,20,35,39,40,42,44,46,48,50,60]:
			await _capture("combat-%02d" % frame)
			if frame == 40:
				for view in main._battle_presentation._aftershock_effect._views.values(): print("[Jax burst] ", view.position, " ", view.scale, " age ", view._age, " children ", view.get_child_count())
	for unit in units: unit.take_damage(99999)
	await create_timer(0.4).timeout
	await _capture("death")
	await create_timer(1.2).timeout
	main._projectile_system.tick_visuals(1.6)
	main._skill_presentation.tick_visuals(1.6)
	await _capture("cleared")
	panel.show_workspace(2)
	await create_timer(0.2).timeout
	await _capture("card-info")
	recorder.set_recording_active(false)
	recorder.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("jax-runtime.wav"))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("jax-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[Jax render] ",path)

func _review_transitions() -> void:
	var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "jax", Vector2(350,850), {"deploy_time_override":0.0}))
	await create_timer(0.3).timeout
	var view: UnitModel3D
	for child in main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit: view = child
	unit._move_intent = Vector2.UP * unit.move_speed
	await create_timer(0.12).timeout
	await _capture("anim-run-in")
	unit._move_intent = Vector2.ZERO
	await create_timer(0.12).timeout
	await _capture("anim-idle-in")
	unit.begin_counter_strike(CardDB.active_skills_for("jax")[0])
	await create_timer(0.12).timeout
	await _capture("anim-e-intro")
	await create_timer(0.8).timeout
	unit._tick_active_statuses(2.0)
	main._active_skill_effect_system.tick_effects(0.05)
	await create_timer(0.12).timeout
	print("[Jax animation] idle end: ", view._animation_player.current_animation)
	await _capture("anim-e-end-idle")
	unit._move_intent = Vector2.UP * unit.move_speed
	await create_timer(0.08).timeout
	print("[Jax animation] interrupted by move: ", view._animation_player.current_animation)
	await _capture("anim-e-end-interrupt-move")
	unit.presentation_cue.emit(&"counter_strike:explode")
	await create_timer(0.12).timeout
	print("[Jax animation] moving end: ", view._animation_player.current_animation)
	await _capture("anim-e-end-run")
	unit._attacking = true
	unit._attack_visual_serial += 1
	await create_timer(0.08).timeout
	print("[Jax animation] interrupted by attack: ", view._animation_player.current_animation)
	await _capture("anim-e-end-interrupt-attack")
	unit._attacking = false
	unit._move_intent = Vector2.ZERO
	await create_timer(0.12).timeout
	await _capture("anim-attack-to-idle")
