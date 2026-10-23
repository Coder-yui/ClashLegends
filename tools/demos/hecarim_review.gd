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
	panel._select_item("hecarim")
	panel.show_workspace(1)
	main.set_physics_process(false)
	main.set_process(false)
	panel._set_battle_zoom(1.3)
	if "--deployment" in OS.get_cmdline_user_args():
		await _review_deployment()
		recorder.set_recording_active(false)
		recorder.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("hecarim-deployment.wav"))
		main.queue_free()
		await process_frame
		quit()
		return
	var deployment: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "hecarim", Vector2(350,850)))
	for step in range(41):
		if step in [0,20,40]:
			await _capture("deploy-%02d" % step)
		main._sim_step(0.05)
		await create_timer(0.05).timeout
	deployment.free()
	var units: Array[Unit] = []
	for team in [0, 1]:
		var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(team, "hecarim", Vector2(220+240*team,850), {"deploy_time_override":0.0}))
		units.append(unit)
	var reference: Unit = main._spawn_unit(UnitSpawnRequest.new(0,"darius",Vector2(350,1080),{"deploy_time_override":0.0}))
	await create_timer(0.8).timeout
	await _capture("idle-size")
	for unit in units: main.preview_active_skill(unit, CardDB.active_skills_for("hecarim")[0])
	await create_timer(0.2).timeout
	await _capture("active-idle")
	for unit in units:
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1-unit.team,"target_dummy",unit.position+Vector2(0,-65 if unit.team==0 else 65),{"deploy_time_override":0.0}))
		target.hp = 10000
		target.max_hp = 10000
		unit._target = target
		unit.hp = 400
		main.preview_active_skill(unit,CardDB.active_skills_for("hecarim")[0])
	for frame in range(105):
		main._sim_step(0.05)
		main._projectile_system.tick_visuals(0.05)
		main._skill_presentation.tick_visuals(0.05)
		await create_timer(0.05).timeout
		if frame in [1,9,20,40,60,79,90,100]:
			await _capture("combat-%02d" % frame)
			for unit in units:
				if is_instance_valid(unit):
					for view in main._battle_presentation._world_root.get_children():
						if view is UnitModel3D and view._source == unit:
							print("[Hecarim native] ", view._active_buff_visual, " clock=",unit.active_buff_clock_visual(), " visible=",view._active_buff_visual.visible if view._active_buff_visual != null else false)
	for unit in units:
		if is_instance_valid(unit): unit.take_damage(99999)
	await create_timer(0.4).timeout
	await _capture("death")
	await create_timer(1.2).timeout
	main._projectile_system.tick_visuals(1.6)
	main._skill_presentation.tick_visuals(1.6)
	await _capture("cleared")
	main.clear_preview_battle()
	var charger: Unit = main._spawn_unit(UnitSpawnRequest.new(0,"hecarim",Vector2(120,1100),{"deploy_time_override":0.0}))
	var charge_target: Unit = main._spawn_unit(UnitSpawnRequest.new(1,"target_dummy",Vector2(120,740),{"deploy_time_override":0.0}))
	charge_target.hp = 10000
	charge_target.max_hp = 10000
	for frame in range(80):
		main._sim_step(0.05)
		await create_timer(0.05).timeout
		if frame in [20,30,34,38,42,48,55,65]:
			await _capture("charge-%02d" % frame)
			for view in main._battle_presentation._world_root.get_children():
				if view is UnitModel3D and view._source == charger:
					print("[Hecarim move] frame=",frame," charged=",charger.is_charged_visual()," clip=",view._animation_player.current_animation)
	panel.show_workspace(2)
	await create_timer(0.2).timeout
	await _capture("card-info")
	recorder.set_recording_active(false)
	recorder.get_recording().save_to_wav(preload("res://tools/lib/development_paths.gd").output("hecarim-runtime.wav"))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := preload("res://tools/lib/development_paths.gd").output("hecarim-"+label+".png")
	root.get_texture().get_image().save_png(path)
	print("[Hecarim render] ",path)

func _review_deployment() -> void:
	for route in ["idle", "move", "attack"]:
		main.clear_preview_battle()
		var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "hecarim", Vector2(350, 850)))
		if route == "idle":
			unit.move_speed = 0.0
			unit.sight_range = 0.0
			unit.can_attack = false
		elif route == "attack":
			main._spawn_unit(UnitSpawnRequest.new(1, "target_dummy", Vector2(350, 790), {"deploy_time_override": 0.0}))
		for step in 70:
			if step in [0, 10, 19, 20, 21, 23, 26]:
				await _capture("deployment-" + route + "-%02d" % step)
				for view in main._battle_presentation._world_root.get_children():
					if view is UnitModel3D and view._source == unit:
						print("HECARIM_DEPLOY route=", route, " tick=", step, " clip=", view._animation_player.current_animation, " speed=", view._current_clip_speed, " blend=", view._last_clip_blend_time)
			main._sim_step(0.05)
			await create_timer(0.05).timeout
