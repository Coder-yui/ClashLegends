extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	print("[场景验收] 工作台已启动")
	var panel = main._art_dev_panel
	panel.show_workspace(1)
	for index in 4:
		print("[场景验收] 布置 ", index)
		panel._scenario_option.select(index)
		panel._scenario_option.item_selected.emit(index)
		panel.scenario_requested.emit("preset:" + String(panel.SCENARIOS.PRESETS[index].id))
		await create_timer(10.0 if index == 1 else 1.3).timeout
		print("[场景验收] 截图 ", index)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("workbench-scenario-%d.png") % index)
		_check_controls(panel)
	panel._on_team_toggled(true)
	panel._scenario_option.select(0)
	panel._scenario_option.item_selected.emit(0)
	await main._load_workbench_preset("surrounded")
	await create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("workbench-scenario-red.png"))
	print("[场景验收] 四种预设与红方镜像已实际渲染")
	quit()
func _check_controls(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Button or node is Label):
		var rect: Rect2 = node.get_global_rect()
		if rect.end.x > root.get_visible_rect().size.x + 1 or rect.end.y > root.get_visible_rect().size.y + 1:
			push_error("场景控件越界：" + str(node.name))
	for child in node.get_children():
		_check_controls(child)
