extends SceneTree
## 实际工作台双阵营部署/主动横扫截图；输出 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-xin-sweep-review。
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	main._art_dev_panel.show_workspace(1)
	DirAccess.make_dir_recursive_absolute(preload("res://tools/lib/development_paths.gd").output("clash-xin-sweep-review"))
	for team in [0, 1]:
		main._clear_art_dev_units()
		await process_frame
		main._art_dev_panel._select_item("xin")
		main._set_art_dev_team(team)
		main._run_workbench_scenario("spawn")
		await _capture("%s_deploy" % team)
		await create_timer(1.1).timeout
		main._use_art_dev_active_skill()
		await _capture("%s_active" % team)
		await create_timer(0.6).timeout
	main.queue_free()
	await process_frame
	quit()

func _capture(label: String) -> void:
	for index in range(3):
		await create_timer(0.10).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("clash-xin-sweep-review/%s_%d.png") % [label, index])
