extends SceneTree
## 检查被动推挤与围塔能力，不改变正式参数或选择攻击空位。
var output := preload("res://tools/lib/development_paths.gd").output("crowd-contact-review")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for t in main._towers: t.can_attack = false
	var tower: Tower = main._towers[2]
	tower.max_hp = 1000000
	tower.hp = tower.max_hp
	var units: Array[Unit] = []
	var count := 24
	var card_id := "imp"
	var columns := 3
	var ticks := 400
	var range_override := -1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticks="): ticks = int(arg.get_slice("=", 1))
		if arg.begins_with("--card="): card_id = arg.get_slice("=", 1)
		if arg.begins_with("--columns="): columns = int(arg.get_slice("=", 1))
		if arg.begins_with("--crowd-count="): count = int(arg.get_slice("=", 1))
		if arg.begins_with("--contact-range="): range_override = float(arg.get_slice("=", 1))
	var spacing := float(CardDB.get_unit_stats(card_id).radius) * 2.0 + 4.0
	for index in count:
		var pos := tower.position + Vector2((index % columns - (columns - 1) * 0.5) * spacing, 100 + (index / columns) * spacing)
		var unit: Unit = main._spawn_unit(0, card_id, pos, 0)
		unit._target = tower
		units.append(unit)
		if range_override >= 0.0: unit.attack_range = range_override
	print("CONFIG card=", card_id, " count=", count, " mass=", units[0].mass, " radius=", units[0].body_radius, " range=", units[0].attack_range, " tower_radius=", tower.body_radius)
	_measure_mass(main)
	var stopped_push_ticks := 0
	var max_stopped_step := 0.0
	for tick in ticks:
		var before: Array[Vector2] = []
		for unit in units: before.append(unit.position)
		main._sim_step(0.05)
		for index in units.size():
			var unit := units[index]
			if unit._attacking and unit._move_intent == Vector2.ZERO:
				var step := unit.position.distance_to(before[index])
				if step > 0.01: stopped_push_ticks += 1
				max_stopped_step = maxf(max_stopped_step, step)
		if tick in [39, 99, 199, 399] or tick == ticks - 1:
			var in_range := 0
			var ever_hit := 0
			var rear_half := 0
			var angles: Array[float] = []
			for unit in units:
				if unit._target_gap(tower) <= unit.attack_range + 0.01: in_range += 1
				if unit._attack_hit_index > 0: ever_hit += 1
				if unit.position.y < tower.position.y: rear_half += 1
				angles.append(rad_to_deg((unit.position - tower.position).angle()))
			print("CROWD tick=", tick + 1, " in_range=", in_range, " ever_hit=", ever_hit, " far_side=", rear_half, " angles=", angles)
			if not DisplayServer.get_name() == "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("crowd-%03d.png" % tick))
		if not DisplayServer.get_name() == "headless": await create_timer(0.01).timeout
	print("PASSIVE_PUSH ticks=", stopped_push_ticks, " max_step=", max_stopped_step, " output=", output)
	main.free()
	await create_timer(0.25).timeout
	quit()

func _measure_mass(main: Node) -> void:
	# 同样重叠2px、无自主移动、开阔地，隔离质量对被动接触位移的影响。
	for ids in [["garen", "imp"], ["garen", "garen"], ["imp", "garen"]]:
		var front: Unit = main._spawn_unit(0, ids[0], Vector2(340, 850), 0)
		var rear: Unit = main._spawn_unit(0, ids[1], Vector2(340, 950), 0)
		rear.position = front.position + Vector2.DOWN * (front.body_radius + rear.body_radius - 2.0)
		var start_front := front.position
		var start_rear := rear.position
		var pair: Array[Unit] = [front, rear]
		main._movement._resolve_unit_collisions(0.05, pair)
		print("MASS front=", ids[0], " mass=", front.mass, " rear=", ids[1], " mass=", rear.mass,
			" front_step=", front.position.distance_to(start_front), " rear_step=", rear.position.distance_to(start_rear))
		front.free()
		rear.free()
