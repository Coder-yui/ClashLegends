extends SceneTree
## 实际工作台、双方模型、命中圈、E动画和运行混音取证。
var main: Node2D
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if "--movie" in OS.get_cmdline_user_args():
		await _run_movie()
		return
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

	unit._attacking = true
	unit._attack_visual_serial = 4
	unit.attack_timeline.visual_elapsed = 0.12
	await create_timer(0.08).timeout
	unit.begin_counter_strike(CardDB.active_skills_for("jax")[0])
	await create_timer(0.08).timeout
	print("[Jax animation] mid attack E: ", view._animation_player.current_animation, " position ", view._animation_player.current_animation_position)
	await _capture("anim-mid-attack-e")
	for serial in [5, 6, 7]:
		unit._attack_visual_serial = serial
		await create_timer(0.15).timeout
		print("[Jax animation] E cycle: ", view._animation_player.current_animation)
		await _capture("anim-e-cycle-%d" % serial)

	unit._tick_active_statuses(2.0)
	main._active_skill_effect_system.tick_effects(0.05)
	await create_timer(0.1).timeout
	print("[Jax pose] end over attack: ", view._animation_player.current_animation)
	await _capture("pose-end-over-attack")
	unit._attack_visual_serial += 1
	await create_timer(0.1).timeout
	print("[Jax pose] next attack: ", view._animation_player.current_animation)
	await _capture("pose-next-attack")
	unit.presentation_cue.emit(&"counter_strike:explode")
	await create_timer(0.12).timeout
	unit.freeze(0.3)
	await create_timer(0.1).timeout
	await _capture("pose-frozen-end")
	unit.control.tick_hard_controls(0.4)
	await create_timer(0.1).timeout
	print("[Jax pose] thaw: ", view._animation_player.current_animation)
	await _capture("pose-thaw-no-replay")

## Fixed-frame, real 20 Hz simulation; warmup frames are trimmed using the trace.
func _run_movie() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	if output.is_empty():
		quit(2)
		return
	var trace := FileAccess.open(output.path_join("trace.jsonl"), FileAccess.WRITE)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	main._art_dev_panel._persist = false
	main._art_dev_panel.show_workspace(1)
	main._art_dev_panel.hide()
	root.content_scale_size = Vector2i(720,1280)
	root.canvas_transform = Transform2D.IDENTITY
	for tower in main.world.towers_snapshot() + [main.world.king(0),main.world.king(1)]: tower.can_attack = false
	main.set_process(false)
	main.set_physics_process(false)
	for child in main.get_children():
		if child is CanvasLayer: child.hide()
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var background := ColorRect.new()
	background.size = Vector2(720,1280)
	background.color = Color("101a24")
	layer.add_child(background)
	var container := SubViewportContainer.new()
	container.position = Vector2(0,180)
	container.size = Vector2(720,800)
	container.stretch = true
	layer.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720,800)
	viewport.world_3d = main._battle_presentation._viewport.find_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	viewport.add_child(camera)
	camera.current = true
	var center: Vector3 = preload("res://scripts/presentation/spell_effect_projection.gd").ground(main._battle_presentation._camera, Vector2(360,800))
	camera.position = center + Vector3(0,16,12)
	camera.look_at(center)
	var title := Label.new()
	title.position = Vector2(28,70)
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_shadow_color",Color.BLACK)
	title.add_theme_constant_override("shadow_outline_size",8)
	layer.add_child(title)
	var status := Label.new()
	status.position = Vector2(28,1050)
	status.add_theme_font_size_override("font_size",20)
	status.add_theme_color_override("font_shadow_color",Color.BLACK)
	status.add_theme_constant_override("shadow_outline_size",6)
	layer.add_child(status)
	var warmup := preload("res://scripts/presentation/spell_effect_warmup.gd").new()
	title.text = "E 特效预热"
	await warmup.prepare({"jax":true},main._battle_presentation._world_root,camera)
	trace.store_line(JSON.stringify({"warmup_draws":warmup.draws,"errors":warmup.errors,"recipes":warmup.timings.keys()}))
	var names := ["预热完整 E 周期", "01  攻击前摇开 E → 持续攻击 → E 结束", "02  移动中开 E → 移动结束动作", "03  E 中眩晕 → 普通 Idle → 恢复", "04  E 中击退 → 普通 Idle → 恢复"]
	for scene in range(5):
		main.clear_preview_battle()
		await process_frame
		var unit: Unit = main._spawn_unit(UnitSpawnRequest.new(0,"jax",Vector2(360,850),{"deploy_time_override":0.0}))
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1,"target_dummy",Vector2(360,460 if scene == 2 else 785),{"deploy_time_override":0.0}))
		target.hp = 10000
		target.max_hp = 10000
		target.lifespan = 0.0
		await process_frame
		var view: UnitModel3D
		for child in main._battle_presentation._world_root.get_children():
			if child is UnitModel3D and child._source == unit: view = child
		title.text = names[scene]
		trace.store_line(JSON.stringify({"scene":scene,"start_frame":Engine.get_frames_drawn()}))
		var activated := false
		var previous_clip := ""
		for frame in range(330):
			if not activated and ((scene == 1 and unit._attacking) or (scene != 1 and frame == 30)):
				main.preview_active_skill(unit,CardDB.active_skills_for("jax")[0])
				activated = true
				trace.store_line(JSON.stringify({"scene":scene,"frame":frame,"event":"E start","attack_elapsed":unit.attack_timeline.visual_elapsed}))
			if frame == 66:
				if scene == 3: unit.stun(0.85)
				if scene == 4: unit.apply_knockback(unit.position + Vector2(0,-80),100.0,0.75)
			if frame % 3 == 0: main._sim_step(0.05)
			main._projectile_system.tick_visuals(1.0/60.0)
			main._skill_presentation.tick_visuals(1.0/60.0)
			await process_frame
			var focus: Vector3 = preload("res://scripts/presentation/spell_effect_projection.gd").ground(main._battle_presentation._camera,unit.position + Vector2(0,-40))
			camera.position = focus + Vector3(0,16,12)
			camera.look_at(focus)
			var clip := String(view._animation_player.current_animation)
			status.text = "当前动画：%s\n目标生命：%d    E 剩余：%.2f s    （60 fps · 原速）" % [clip,target.hp,unit.buffs.remaining(&"counter_strike")]
			if clip != previous_clip:
				trace.store_line(JSON.stringify({"scene":scene,"frame":frame,"clip":clip,"hp":target.hp}))
				previous_clip = clip
			RenderingServer.force_draw(false)
	trace.store_line(JSON.stringify({"end_frame":Engine.get_frames_drawn()}))
	trace.close()
	main.queue_free()
	await process_frame
	quit()
