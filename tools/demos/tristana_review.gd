extends SceneTree
var main
var panel
var record: AudioEffectRecord
func _initialize() -> void:
	_run.call_deferred()
func snap(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	var path := preload("res://tools/lib/development_paths.gd").output("tristana/" + label + ".png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	if label in ["q_0", "q_1"]:
		await closeup(label)
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	panel = main._art_dev_panel
	panel._persist = false
	panel._select_item("tristana")
	await create_timer(0.6).timeout
	await snap("model")
	panel.show_workspace(2)
	await snap("info")
	panel.show_workspace(1)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "tristana": print("AUDIO ", cue))
	record = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	for team in [0, 1]:
		main._clear_art_dev_units()
		main._set_art_dev_team(team)
		panel._select_item("tristana")
		main._run_workbench_scenario("spawn")
		await create_timer(1.2).timeout
		var unit: Unit = main._art_dev_selected_unit()
		main.play_card(team, "teemo", unit.position + Vector2(-100, 0), {"immediate": true, "validate_position": false})
		main.play_card(team, "gnar", unit.position + Vector2(100, 0), {"immediate": true, "validate_position": false})
		await create_timer(1.2).timeout
		await snap("comparison_" + str(team))
		main._run_workbench_scenario("target")
		main._workbench.target = weakref(unit)
		await create_timer(1.5).timeout
		main.preview_active_skill(unit, CardDB.active_skills_for("tristana")[0])
		await create_timer(0.6).timeout
		await snap("q_" + str(team))
		var heat := main.find_child("RapidFireBarrelHeat", true, false) as MeshInstance3D
		assert(heat != null and heat.visible and heat.skin != null)
		assert(heat.get_node(heat.skeleton) is Skeleton3D)
		panel.show_workspace(2)
		var paused_tick: int = main._sim_tick_id
		await create_timer(0.5).timeout
		assert(main._sim_tick_id == paused_tick)
		panel.show_workspace(1)
		await create_timer(5.0).timeout
		await snap("q_end_" + str(team))
		assert(is_instance_valid(heat) and not heat.visible)
		unit.freeze(2.0)
		await create_timer(1.5).timeout
		await snap("freeze_" + str(team))
		await create_timer(2.0).timeout
		unit.take_damage(99999.0)
		await create_timer(1.0).timeout
		assert(not is_instance_valid(heat) or not heat.is_visible_in_tree())
		print("HEAT_LIFECYCLE_OK team=", team)
	record.set_recording_active(false)
	var path := preload("res://tools/lib/development_paths.gd").output("tristana/battle.wav")
	record.get_recording().save_to_wav(path)
	print("RECORDING ", path)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	main.queue_free()
	await process_frame
	await process_frame
	quit()

func closeup(label: String) -> void:
	var unit: Unit = main._art_dev_selected_unit()
	var model: Node3D
	for child in main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit: model = child
	if model == null: return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 720)
	viewport.world_3d = main._battle_presentation._viewport.find_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.cull_mask = 1 << 19
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.8
	viewport.add_child(camera)
	camera.current = true
	for mesh: GeometryInstance3D in model.find_children("*", "GeometryInstance3D", true, false): mesh.layers |= 1 << 19
	var focus := model.global_position + Vector3(0, 0.9, 0)
	camera.global_position = focus + Vector3(3, 2.0, 5.5)
	camera.look_at(focus)
	await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("tristana/" + label + "_close.png"))
	for mesh: GeometryInstance3D in model.find_children("*", "GeometryInstance3D", true, false): mesh.layers &= ~(1 << 19)
	viewport.queue_free()
