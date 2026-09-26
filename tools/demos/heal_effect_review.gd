extends SceneTree
## 实际工作台渲染与真实回血入口回归。
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	var panel = main._art_dev_panel
	panel._persist = false
	if "--control-review" in OS.get_cmdline_user_args():
		await _review_control(main, panel)
		return
	if "--status-review" in OS.get_cmdline_user_args():
		await _review_status(main, panel)
		return
	panel._select_item("xin")
	panel.show_workspace(1)
	main._run_workbench_scenario("spawn")
	await create_timer(1.0).timeout
	var unit: Unit = main._art_dev_selected_unit()
	assert(unit != null)
	unit.hp = unit.max_hp
	unit.heal(10)
	assert(unit.restoration_fx_timer == 0.0, "满血不播放")
	unit.hp -= 80
	unit.heal(10)
	assert(unit.restoration_fx_timer > 0.0, "普通治疗播放")
	unit.restoration_fx_timer = 0.4
	unit.heal(10)
	assert(unit.restoration_fx_timer == 0.4, "连续回血不重置")
	unit.restoration_fx_timer = 0.0
	unit.heal_every_hits = 1
	unit.heal_amount = 10
	unit._try_heal_on_hit(1)
	assert(unit.restoration_fx_timer > 0.0, "普攻回血播放")
	unit.restoration_fx_timer = 0.0
	unit._try_attack_lifesteal(10, 1.0)
	assert(unit.restoration_fx_timer > 0.0, "吸血播放")
	unit.restoration_fx_timer = 0.0
	unit._restore_shield_health()
	assert(unit.restoration_fx_timer > 0.0, "护盾回复播放")
	unit.restoration_fx_timer = 0.0
	unit.hp = 0
	unit.heal(10)
	assert(unit.restoration_fx_timer == 0.0, "死亡不播放")
	unit.hp = unit.max_hp - 40
	unit.heal(10)
	panel._set_battle_zoom(2.0)
	await create_timer(0.25).timeout
	unit.set_process(false)
	for index in 4:
		unit.restoration_fx_timer = 0.7 - (0.08 + float(index) * 0.16)
		unit.queue_redraw()
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var output := preload("res://tools/lib/development_paths.gd").output("clash-heal-stagger-" + str(index) + ".png")
		root.get_texture().get_image().save_png(output)
		print("[回血截图] ", output)
	print("[回血验证] 7 项通过")
	main.queue_free()
	await process_frame
	quit()

func _review_status(main: Node, panel: CanvasLayer) -> void:
	panel.show_workspace(1)
	panel._set_battle_zoom(2.0)
	for card in ["xin", "anivia"]:
		panel._select_item(card)
		main._run_workbench_scenario("spawn")
		await create_timer(1.5).timeout
		var unit: Unit = main._art_dev_selected_unit()
		unit.apply_slow(60.0, 0.6)
		unit.apply_attack_speed_slow(60.0, 0.6)
		unit.hp -= 60
		unit.heal(20)
		unit.set_process(false)
		unit.restoration_fx_timer = 0.35
		unit.queue_redraw()
		for frame in 5: await process_frame
		if unit.is_air:
			assert(unit._status_effect_offset.y < -10.0, "空军附着平面必须离地")
		await RenderingServer.frame_post_draw
		var output := preload("res://tools/lib/development_paths.gd").output("status-" + card + ".png")
		root.get_texture().get_image().save_png(output)
		print("[状态截图] ", output, " 附着偏移 ", unit._status_effect_offset)
	main.queue_free()
	await process_frame
	quit()

func _review_control(main: Node, panel: CanvasLayer) -> void:
	panel.show_workspace(1)
	panel._set_battle_zoom(2.0)
	for card in ["xin", "anivia"]:
		main._clear_art_dev_units()
		await process_frame
		panel._select_item(card)
		main._run_workbench_scenario("spawn")
		await create_timer(1.5).timeout
		var unit: Unit = main._art_dev_selected_unit()
		unit.apply_slow(20.0, 0.55)
		unit.apply_attack_speed_slow(20.0, 0.6)
		await create_timer(0.3).timeout
		print("[控制表现] ", card, " 移动拖痕=", unit.movement_slow_effect_visible())
		await _capture_control(card + "-moving")
		unit.stun(10.0)
		await create_timer(0.2).timeout
		assert(not unit.movement_slow_effect_visible(), "眩晕停步不显示减速")
		assert(unit.stun_visual() and unit.attack_speed_slow_visual(), "两类持续状态仍显示")
		await _capture_control(card + "-stun-a")
		await create_timer(0.45).timeout
		await _capture_control(card + "-stun-b")
	panel._set_battle_zoom(1.0)
	for tower in main._towers: tower.stun(10.0)
	await create_timer(0.3).timeout
	await _capture_control("towers")
	main.queue_free()
	await process_frame
	quit()

func _capture_control(label: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var output := preload("res://tools/lib/development_paths.gd").output("control-" + label + ".png")
	root.get_texture().get_image().save_png(output)
	print("[控制截图] ", output)
