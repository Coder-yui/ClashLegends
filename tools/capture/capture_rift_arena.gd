extends SceneTree
## Actual game renderer QA; run without --headless. Outputs live outside resources.
## Godot --path . --script tools/capture/capture_rift_arena.gd

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(720, 1400)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for _i in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	var out := ProjectSettings.globalize_path("res://builds/arena_preview")
	DirAccess.make_dir_recursive_absolute(out)
	main._battle_presentation._viewport.get_texture().get_image().save_png(out + "/rift_arena_clean.png")
	# Exercise the shared entry point, both teams and both lanes; no authority bypass.
	for spec in [[0, "garen", Vector2(140, 760)], [1, "garen", Vector2(140, 520)],
		[0, "ashe", Vector2(580, 840)], [1, "ashe", Vector2(580, 440)]]:
		main.play_card(spec[0], spec[1], spec[2], {"immediate": true})
	for _i in range(40):
		main._sim_step(0.05)
		await process_frame
	main._selected_card = "garen"
	main._deployment_preview_pos = Vector2(340, 820)
	main._deployment_preview_tile = Vector2i(8, 20)
	main._deployment_preview_valid = true
	main._deployment_preview_visible = true
	main.queue_redraw()
	for _i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/rift_arena_gameplay.png")
	# Load the retained candidate map only for the asset overview. The live Main
	# scene continues to use its original 2D background throughout this capture.
	# The overview camera is not a gameplay camera or an authority-coordinate change.
	var presentation: BattlePresentation3D = main._battle_presentation
	var candidate := (load("res://assets/arena/rift_arena/rift_arena.tscn") as PackedScene).instantiate()
	presentation._world_root.add_child(candidate)
	for child in presentation._world_root.get_children():
		if child is UnitModel3D or child is TowerModel3D:
			child.set_process(false)
	presentation._viewport.size = Vector2i(1100, 1000)
	presentation._viewport.transparent_bg = false
	presentation._camera.size = 50.0
	presentation._camera.position = Vector3(24.0, 34.0, 36.0)
	presentation._camera.look_at(Vector3(0.0, -0.5, 0.0), Vector3.UP)
	for _i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	presentation._viewport.get_texture().get_image().save_png(out + "/rift_arena_overview.png")
	print("[Arena render] draw calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("[Arena capture] ", out)
	quit()
