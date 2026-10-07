extends SceneTree
## Godot --path . --script tools/demos/ashe_audio_demo.gd
## 单机专项复现；联网统一使用 tools/dev.py verify --network-render。

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not preload("res://tools/lib/demo_options.gd").local_only(self): return
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._audio_manager.cue_played.connect(func(id, cue, _pos):
		if id == "ashe":
			print("[ashe audio] ", cue))
	main._start_local()
	main.set_process(false)
	main._clear_art_dev_units()
	await process_frame
	var ashe: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "ashe", Vector2(360, 930), {"deploy_time_override": 0.0}))
	for position in [Vector2(340, 810), Vector2(390, 810)]:
		var target: Unit = main._spawn_unit(UnitSpawnRequest.new(1, "garen", position, {"deploy_time_override": 0.0}))
		target.move_speed = 0.0 # 演示木桩，避免模型重叠遮住射箭动作。
	for tick in 160:
		if tick == 40:
			main.preview_active_skill(ashe, CardDB.active_skills_for("ashe")[0])
		main._sim_step(0.05)
		await create_timer(0.05).timeout
		if tick in [20, 54]:
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("clash_ashe_audio_%d.png") % tick)
	main.queue_free()
	await process_frame
	await process_frame
	quit()
