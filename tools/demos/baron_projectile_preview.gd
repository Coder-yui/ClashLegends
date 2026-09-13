extends SceneTree
## 真实弹体系统的男爵炮弹逐帧渲染验收。
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	main.play_card(0, "siege_minion", Vector2(360, 850), {"immediate": true, "validate_position": false})
	main.play_card(1, "super_minion", Vector2(360, 480), {"immediate": true, "validate_position": false})
	await create_timer(1.1).timeout
	var source: Unit = main._latest_unit_for_card("siege_minion", 0)
	var target: Unit = main._latest_unit_for_card("super_minion", 1)
	source.move_speed = 0
	target.move_speed = 0
	main.preview_active_skill(source, CardDB.active_skills_for("siege_minion")[0])
	main._projectile_system.launch(source, target, 1.0, source.projectile_speed, 0.0, 0.0, source.color)
	DirAccess.make_dir_recursive_absolute("/tmp/clash-baron-cannon")
	for i in range(12):
		await create_timer(0.07).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/clash-baron-cannon/%02d.png" % i)
	main.free()
	await process_frame
	quit()
