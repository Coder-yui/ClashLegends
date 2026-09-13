extends SceneTree
## 实际渲染 QA 工具，不是自动 mechanics 入口。截图输出 /tmp/clash-maintenance-render。
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/clash-maintenance-render")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	var left: Unit = main._spawn_unit(0, "garen", Vector2(260, 920), 0.0)
	var right: Unit = main._spawn_unit(1, "garen", Vector2(260, 790), 0.0)
	main._spawn_unit(0, "missfortune", Vector2(450, 1000), 0.0)
	main._spawn_unit(1, "garen", Vector2(450, 800), 0.0)
	var gnar: Unit = main._spawn_unit(0, "gnar", Vector2(550, 950), 0.0)
	main._spawn_unit(1, "aurelionsol", Vector2(480, 450), 0.0)
	await create_timer(1.2).timeout
	await _capture("01_attack")
	left.freeze(1.5)
	right.stun(1.5)
	gnar.transform_to_mega()
	await create_timer(0.5).timeout
	await _capture("02_control_transform")
	left.take_damage(99999.0)
	await create_timer(0.25).timeout
	await _capture("03_control_death")
	await create_timer(1.2).timeout
	await _capture("04_recovery")
	print("[渲染 QA] 四个实际渲染帧已保存")
	quit()

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/clash-maintenance-render/" + label + ".png")
