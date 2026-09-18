extends SceneTree
## 复用正式工作台、施法与固定 Tick，捕捉双方普通/满层星落的实际渲染。
var main: Node2D
var output := preload("res://tools/lib/development_paths.gd").output("aurelionsol-skill")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	main._art_dev_panel._select_item("aurelionsol")
	main._art_dev_panel.show_workspace(1)
	main._art_dev_panel.hide()
	main.set_process(false)
	for tower in main._towers: tower.can_attack = false
	for team in [0, 1]:
		for strong in [false, true]:
			main._clear_art_dev_units()
			main._art_dev_team = team
			main._place_art_dev_item(Vector2(360, 850 if team == 0 else 450))
			var source: Unit = main._art_dev_selected_unit()
			source._deploy_timer = 0
			source.move_speed = 0
			source.damage = 0
			source.skill_resource_value = 5 if strong else 0
			await create_timer(0.2).timeout
			main._use_art_dev_active_skill()
			for tick in 55:
				main._sim_step(0.05)
				main._active_skill_effect_system.tick_visuals(0.05)
				await create_timer(0.05).timeout
				if tick in [4, 14, 20, 23, 27, 32, 42]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output + "/team%d_%s_%02d.png" % [team, "sky" if strong else "star", tick])
	print("STARFALL_REVIEW ", output)
	quit()
