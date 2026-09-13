extends SceneTree
## 非 headless 运行；生成 /tmp/clash-workbench-*.png，并核对工作区暂停边界。
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	await create_timer(1).timeout
	await _capture("model")
	panel.show_workspace(1)
	main._run_workbench_scenario("spawn")
	await create_timer(1.5).timeout
	main._run_workbench_scenario("target")
	await create_timer(0.5).timeout
	await _capture("battle")
	panel.show_workspace(2)
	var paused_tick: int = main._sim_tick_id
	await create_timer(0.3).timeout
	if main._sim_tick_id != paused_tick:
		push_error("素材观察期间实战仍在推进")
		quit(1)
		return
	print("[工作台验证] 切离实战暂停权威 Tick")
	await _capture("audio")
	panel.show_workspace(3)
	await create_timer(0.3).timeout
	await _capture("review")
	panel._select_item("freeze")
	panel.show_workspace(0)
	await create_timer(0.3).timeout
	await _capture("spell")
	panel.show_workspace(1)
	panel._spell_active.button_pressed = true
	await _capture("spell_battle")
	panel.show_workspace(0)
	panel._select_item("gnar")
	panel._form = 1
	panel._refresh_assets()
	await create_timer(0.3).timeout
	await _capture("form")
	panel.show_workspace(1)
	await create_timer(0.2).timeout
	if main._sim_tick_id <= paused_tick:
		push_error("返回实战没有恢复权威 Tick")
		quit(1)
		return
	main._clear_art_dev_units()
	await process_frame
	print("[工作台验证] 返回实战继续推进，清空结束当前实验")
	quit()
func _capture(id: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check_controls(current_scene._art_dev_panel)
	root.get_texture().get_image().save_png("/tmp/clash-workbench-" + id + ".png")
	print("[工作台截图] ", id)

func _check_controls(node: Node) -> void:
	if node is Button and node.is_visible_in_tree():
		if node.get_global_rect().end.x > root.get_visible_rect().size.x + 1.0:
			push_error("工作台控件超出窗口：" + node.text)
	for child in node.get_children():
		_check_controls(child)
