extends SceneTree
## 非 headless 运行；生成 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-workbench-*.png，并核对工作区暂停边界。
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if "--deployment-review" in OS.get_cmdline_user_args():
		await _review_deployment()
		return
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var old_content_size := root.content_scale_size
	var old_canvas := root.canvas_transform
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	panel.set_quick_cards(["garen", "ashe", "gwen", "freeze", "sett", "gnar", "kayn", "mirror"])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--card="):
			panel._select_item(argument.trim_prefix("--card="))
	await create_timer(1).timeout
	await _capture("model")
	panel._show_library(true)
	await _capture("library")
	panel._show_library(false)
	panel.show_workspace(1)
	main._run_workbench_scenario("spawn")
	await create_timer(1.5).timeout
	main._run_workbench_scenario("target")
	await create_timer(0.5).timeout
	await _capture("battle")
	panel._set_battle_zoom(1.0)
	await _capture("battle_overview")
	panel._show_library(true)
	await _capture("multi_picker")
	panel._show_library(false)
	panel.set_select_mode(true)
	var inspected: Unit = main._latest_unit_for_card("garen", 0)
	if inspected != null: main._workbench_map_click(inspected.position)
	await _capture("multi_select")
	var controls_scroll: ScrollContainer = panel._inspection_controls.get_parent().get_parent().get_parent().get_parent()
	controls_scroll.scroll_vertical = 10000
	await _capture("battle_controls")
	controls_scroll.scroll_vertical = 0
	panel._set_battle_zoom(1.0)
	panel.show_workspace(2)
	var paused_tick: int = main._sim_tick_id
	await create_timer(0.3).timeout
	if main._sim_tick_id != paused_tick:
		push_error("素材观察期间实战仍在推进")
		quit(1)
		return
	print("[工作台验证] 切离实战暂停权威 Tick")
	await _capture("audio")
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
	main.free()
	await process_frame
	if root.content_scale_size != old_content_size or root.canvas_transform != old_canvas:
		push_error("退出工作台没有恢复原有窗口布局")
		quit(1)
		return
	print("[工作台验证] 退出恢复窗口与战场变换")
	quit()
func _capture(id: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check_controls(current_scene._art_dev_panel)
	root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("clash-workbench-") + id + ".png")
	print("[工作台截图] ", id)

func _check_controls(node: Node) -> void:
	if node is Button and node.is_visible_in_tree():
		if not _inside_scroll(node) and (node.get_global_rect().end.x > root.get_visible_rect().size.x + 1.0 or node.get_global_rect().end.y > root.get_visible_rect().size.y + 1.0):
			push_error("工作台控件超出窗口：" + node.text)
	for child in node.get_children():
		_check_controls(child)

func _inside_scroll(node: Node) -> bool:
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: return true
		ancestor = ancestor.get_parent()
	return false

## 复用正式下牌入口检查横排、后场寻路与恢复表现，避免另建卡牌展台。
func _review_deployment() -> void:
	var card := "shurima_guard"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--card="): card = arg.trim_prefix("--card=")
	for x in [260, 300, 340, 380, 420, 460]:
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		main._deck = [card, "garen", "ashe", "teemo", "freeze", "masteryi", "tombstone", "aurelionsol"]
		main._start_local()
		main._ai.enabled = false
		main.set_process(false)
		main.set_physics_process(false)
		main._elixir.elixir = 10
		if not main.play_card(0, card, Vector2(x, 1260)):
			push_error("正式下牌失败")
			quit(1)
			return
		for tick in 32: main._sim_step(0.05)
		var soldiers: Array[Unit] = []
		for node in get_nodes_in_group("combatants"):
			if node is Unit and node.card_id == card: soldiers.append(node)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("deployment-") + str(x) + ".png")
		for tick in 220: main._sim_step(0.05)
		var left := 0
		for unit in soldiers:
			if unit.position.x < 360: left += 1
		print("[实际寻路] x=", x, " left=", left, " right=", soldiers.size() - left)
		if left != {260: 4, 300: 4, 340: 3, 380: 3, 420: 2, 460: 2}[x]:
			push_error("实际后场分兵不符")
			quit(1)
			return
		if x == 340:
			for unit in soldiers:
				unit.hp = 100
				unit.add_restoration_shield(180, 0.05)
				unit._tick_active_statuses(0.05)
			await create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("restoration-") + "heal.png")
		main.free()
		await process_frame
	quit()
