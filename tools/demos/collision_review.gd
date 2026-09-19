extends SceneTree
## 两类碰撞的实际渲染配方；输出截图供目视检查。
var output := preload("res://tools/lib/development_paths.gd").output("collision-review")
func _initialize() -> void: _run.call_deferred()
func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	var a: Unit = main._spawn_unit(0, "garen", Vector2(320, 880), 0)
	var b: Unit = main._spawn_unit(1, "garen", Vector2(320, 800), 0)
	var units: Array[Unit] = [a, b]
	for tick in 60:
		a._prev_pos = a.position
		b._prev_pos = b.position
		a._move_direction = Vector2.UP
		b._move_direction = Vector2.DOWN
		a._move_intent = Vector2.UP * a.move_speed
		b._move_intent = Vector2.DOWN * b.move_speed
		main._movement._apply_unit_movement(0.05, units)
		await create_timer(0.05).timeout
		if tick in [0, 15, 30, 59]: await _capture("opposing-%02d" % tick)
	a.free()
	b.free()
	var target: Unit = main._spawn_unit(1, "garen", Vector2(360, 850), 0)
	target.max_hp = 100000
	target.hp = target.max_hp
	target.freeze(100)
	var front: Unit = main._spawn_unit(0, "sett", Vector2(360, 925), 0)
	var rear: Unit = main._spawn_unit(0, "sett", Vector2(360, 981), 0)
	front._target = target
	rear._target = target
	for tick in 80:
		main._sim_step(0.05)
		await create_timer(0.05).timeout
		if tick in [0, 15, 30, 59, 79]: await _capture("follower-%02d" % tick)
	print("COLLISION_REVIEW rear_hits=", rear._attack_hit_index, " output=", output)
	front.free()
	rear.free()
	target.free()
	var tower: Tower = main._towers[2]
	var attacker: Unit = main._spawn_unit(0, "garen", tower.position + Vector2.DOWN * 180.0, 0)
	var defender: Unit = main._spawn_unit(1, "masteryi", attacker.position + Vector2.UP * 45.0, 0)
	attacker._target = tower
	defender._target = attacker
	for tick in 60:
		main._sim_step(0.05)
		await create_timer(0.05).timeout
		if tick in [0, 20, 59]: await _capture("defender-%02d" % tick)
	print("DEFENDER_REVIEW garen_turn=", attacker._avoidance_turn, " defender_hits=", defender._attack_hit_index)
	main.free()
	await create_timer(0.25).timeout
	quit()
