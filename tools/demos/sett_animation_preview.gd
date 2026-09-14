extends SceneTree
## 实际工作台模拟 + 同一 3D 世界的近景相机。用 --fixed-fps 30 生成可复查的连续帧。
## Godot --path . --fixed-fps 30 --script tools/demos/sett_animation_preview.gd
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-sett-animation")
var main: Node2D
var focus_camera: Camera3D
var label: Label
var unit: Unit
var phase := "deploy / base 1x"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT + "/frames")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	main._art_dev_panel._select_item("sett")
	main._art_dev_panel.show_workspace(1)
	_setup_closeup()
	main.set_process(false) # 截图等待期间不让模拟额外推进，逐帧调用相同正式入口。
	_spawn_pair(0)
	var trace := FileAccess.open(OUTPUT + "/trace.jsonl", FileAccess.WRITE)
	var lifecycle_only := "--lifecycle-only" in OS.get_cmdline_user_args()
	for frame in (180 if lifecycle_only else 1290):
		if lifecycle_only:
			if frame in [60, 150]:
				phase = "death / source 0-1.7s in 0.8s"
				unit.take_damage(999999.0)
			if frame == 90:
				main._clear_art_dev_units()
				_spawn_pair(1)
				phase = "red deploy / Respawn first 1s"
		match frame:
			210:
				phase = "attack speed 2x (expires in 3s)"
				unit.apply_active_buff(3.0, 1.0, 1.0, 2.0)
			330:
				phase = "attack speed 0.5x (expires in 3s)"
				unit.apply_attack_speed_slow(3.0, 0.5)
			435:
				phase = "freeze 1s / resume"
				unit.freeze(1.0)
			480:
				phase = "normal W / target removed / ToRun"
				main._set_art_dev_skill_resource(0.0)
				main._use_art_dev_active_skill()
			500:
				var dummy: Unit = main._latest_unit_for_card("training_dummy", 1)
				if is_instance_valid(dummy): dummy.take_damage(999999.0)
			570:
				main._run_workbench_scenario("target")
			600:
				phase = "strong W / resume attack"
				main._set_art_dev_skill_resource(999.0)
				main._use_art_dev_active_skill()
			690:
				phase = "death while frozen / 1.7s source in 0.8s"
				unit.freeze(1.0)
				unit.take_damage(999999.0)
			795:
				main._clear_art_dev_units()
				_spawn_pair(1)
				phase = "red team / deploy / attack"
			960:
				phase = "red strong W / ToRun"
				main._set_art_dev_skill_resource(999.0)
				main._use_art_dev_active_skill()
			980:
				var dummy: Unit = main._latest_unit_for_card("training_dummy", 0)
				if is_instance_valid(dummy): dummy.take_damage(999999.0)
			1050:
				phase = "normal W / stationary recovery (preview movement disabled)"
				unit.move_speed = 0.0 # 仅此验收实例制造静止出口，不修改 CardDB
				main._set_art_dev_skill_resource(0.0)
				main._use_art_dev_active_skill()
			1170:
				phase = "strong W / stationary recovery"
				main._set_art_dev_skill_resource(999.0)
				main._use_art_dev_active_skill()
		main._process(1.0 / 30.0)
		await process_frame
		var view := _view()
		if is_instance_valid(view):
			view._process(1.0 / 30.0)
			view._animation_player.advance(1.0 / 30.0)
			for mesh in view.find_children("*", "VisualInstance3D", true, false):
				mesh.set_layer_mask_value(20, true)
			var target := view.global_position + Vector3.UP * 1.1
			focus_camera.global_position = target + Vector3(3, 2.6, 5.5)
			focus_camera.look_at(target)
			var player := view._animation_player
			label.text = "SETT | %s\n%s | clip %.2f | speed %.2fx" % [phase, player.current_animation, player.current_animation_position, player.get_playing_speed()]
			trace.store_line(JSON.stringify({"frame": frame, "phase": phase, "clip": player.current_animation, "position": player.current_animation_position, "playback_speed": player.get_playing_speed(), "serial": unit.get_attack_visual_serial() if is_instance_valid(unit) else -1}))
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			root.get_texture().get_image().save_png(OUTPUT + "/frames/%04d.png" % (frame / 2))
	trace.close()
	print("[腕豪渲染] 连续帧与动作日志：", OUTPUT)
	quit()

func _spawn_pair(team: int) -> void:
	main._set_art_dev_team(team)
	main._art_dev_panel._select_item("sett")
	main._place_art_dev_item(Vector2(360, 850 if team == 0 else 730))
	unit = main._art_dev_selected_unit()
	main._run_workbench_scenario("target")
	var view := _view()
	if view != null:
		view.set_process(false)
		view._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func _view() -> UnitModel3D:
	for child in main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			return child
	return null

func _setup_closeup() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 50
	main.add_child(overlay)
	var panel := SubViewportContainer.new()
	panel.size = Vector2(720, 520)
	panel.stretch = true
	overlay.add_child(panel)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 520)
	viewport.world_3d = main._battle_presentation._viewport.find_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	panel.add_child(viewport)
	focus_camera = Camera3D.new()
	focus_camera.cull_mask = 1 << 19 # 近景仅展示选中模型，避免同世界防御塔遮挡。
	focus_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	focus_camera.size = 5.5
	viewport.add_child(focus_camera)
	focus_camera.current = true
	label = Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 16)
	overlay.add_child(label)
