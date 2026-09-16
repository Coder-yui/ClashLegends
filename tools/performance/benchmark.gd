extends SceneTree
var frame_ms: Array[float] = []
var main_process_ms: Array[float] = []
var backlog_ms: Array[float] = []
var spawn_ms: Array[float] = []
var transform_ms: Array[float] = []
var memory_bytes: Array[float] = []
var main: Node2D
var events: Array = []
var slow_frames: Array = []
var objects: Array[float] = []

func option(key: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(key + "="): return argument.trim_prefix(key + "=")
	return fallback

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(12345)
	var case := option("--perf-case", "load")
	var count := int(option("--perf-count", "32"))
	var duration := float(option("--perf-seconds", "12"))
	var rendered := DisplayServer.get_name() != "headless"
	var audio_enabled := option("--perf-audio", "on") == "on"
	var output := option("--perf-output", preload("res://tools/lib/development_paths.gd").output("performance"))
	DirAccess.make_dir_recursive_absolute(output)
	if rendered: root.always_on_top = true
	Engine.max_fps = 60 if rendered else 0
	main = load("res://scenes/main.tscn").instantiate()
	main.set_script(preload("res://tools/performance/benchmark_main.gd"))
	var deck := ["garen", "ashe", "xin", "gnar", "teemo", "masteryi", "tombstone", "anivia"]
	if case == "herald": deck[2] = "rift_herald"
	main._deck = deck.duplicate()
	root.add_child(main)
	current_scene = main
	main.set_process(false)
	await process_frame
	var first_exit := {}
	if option("--perf-entry", "fresh") == "repeat":
		await main._start_local_with_loading()
		main.free()
		await create_timer(0.25).timeout
		first_exit = {"memory": OS.get_static_memory_usage(), "objects": Performance.get_monitor(Performance.OBJECT_COUNT)}
		main = load("res://scenes/main.tscn").instantiate()
		main.set_script(preload("res://tools/performance/benchmark_main.gd"))
		main._deck = deck.duplicate()
		root.add_child(main)
		current_scene = main
		main.set_process(false)
		await process_frame
	# Main._ready 会 randomize；在初始化完成后再固定本次实验的种子。
	seed(12345)
	var setup_start := Time.get_ticks_usec()
	main.silent = not audio_enabled
	print("[PERF_STAGE] start local")
	if option("--perf-prepare", "menu") == "menu":
		await main._start_local_with_loading()
	else:
		main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = case == "match"
	main.drive_match = case == "match"
	if not audio_enabled: main._audio_manager.end_battle()
	print("[PERF_STAGE] scene ready")
	var setup_ms := (Time.get_ticks_usec() - setup_start) / 1000.0
	var units: Array[Unit] = []
	if case in ["load", "effects"]: units = spawn_load(count, false)
	print("[PERF_STAGE] load ready")
	var started := Time.get_ticks_usec()
	var last_frame := started
	var frames := 0
	var spawned := false
	var transformed := false
	var record: AudioEffectRecord
	var record_index := AudioServer.get_bus_effect_count(0)
	if "--perf-record" in OS.get_cmdline_user_args():
		record = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, record)
		record.set_recording_active(true)
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := (now - started) / 1000000.0
		frame_ms.append((now - last_frame) / 1000.0)
		if frame_ms.back() > 16.67: slow_frames.append({"frame": frames, "tick": main._sim_tick_id, "ms": frame_ms.back()})
		var dt: float = (now - last_frame) / 1000000.0 if rendered else 0.05
		last_frame = now
		if case == "burst" and frames == 60:
			events.append({"frame": frames, "event": "spawn", "count": count})
			units = spawn_load(count, true)
			spawned = true
		if case == "burst" and frames == 180:
			events.append({"frame": frames, "event": "transform", "count": count})
			var before := Time.get_ticks_usec()
			for unit in units:
				if is_instance_valid(unit): unit.transform_to_mega()
			transform_ms.append((Time.get_ticks_usec() - before) / 1000.0)
			transformed = true
		if case == "herald" and frames % 180 == 60:
			events.append({"frame": frames, "event": "both_heralds_summon", "count": 12})
			for unit in get_nodes_in_group("combatants"):
				if unit is Unit: unit.take_damage(10000000)
			for team in [0, 1]:
				var source: Unit = main._spawn_unit(team, "rift_herald", Vector2(360, 850 if team == 0 else 430), 0.0)
				source.structure_rush.target = main._towers[2 if team == 0 else 0]
				source.structure_rush.direction = Vector2.UP if team == 0 else Vector2.DOWN
				source.structure_rush.target.hp = 10000000
				source.structure_rush._impact(source)
		if case == "effects" and frames % 120 == 0:
			for index in 8:
				main.play_card(index % 2, "freeze" if index % 2 == 0 else "heal", Vector2(130 + index % 4 * 150, 640), {"immediate": true, "validate_position": false})
		var before := Time.get_ticks_usec()
		main._process(dt)
		main_process_ms.append((Time.get_ticks_usec() - before) / 1000.0)
		backlog_ms.append(main._simulation_clock.remainder * 1000.0)
		objects.append(Performance.get_monitor(Performance.OBJECT_COUNT))
		memory_bytes.append(float(OS.get_static_memory_usage()))
		frames += 1
		if case == "match":
			if main.game_over: break
			if main._sim_tick_id > 6120 or elapsed > 420.0:
				push_error("完整对局未在规则上限内结束")
				break
		elif (rendered and elapsed >= duration) or (not rendered and frames >= int(duration * 20.0)):
			break
		if frames % (600 if rendered else 1000) == 0: print("[PERF_PROGRESS] case=%s frames=%d tick=%d" % [case, frames, main._sim_tick_id])
	if rendered:
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(output.path_join("final.png"))
	if record != null:
		record.set_recording_active(false)
		var wav := record.get_recording()
		if wav != null: wav.save_to_wav(output.path_join("master-mix.wav"))
		AudioServer.remove_bus_effect(0, record_index)
	var result := {"schema": 1, "capture_policy": "after_measurement", "case": case, "count": count, "seed": 12345, "rendered": rendered,
		"preparation": option("--perf-prepare", "menu"), "entry": option("--perf-entry", "fresh"), "first_exit": first_exit,
		"loading_stages": main.get("preparation_metrics"), "pool": main._battle_presentation.model_pool.get("metrics") if is_instance_valid(main._battle_presentation) else {},
		"pool_preparation": main._battle_presentation.model_pool.get("preparation_times") if is_instance_valid(main._battle_presentation) else {},
		"events": events, "slow_frames": slow_frames, "objects": distribution(objects),
		"visual": option("--perf-visual", "on"), "audio": audio_enabled,
		"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"recorded_audio": record != null, "backlog_final_ms": main._simulation_clock.remainder * 1000.0, "frames": frames, "ticks": main._sim_tick_id, "setup_ms": setup_ms,
		"frame_ms": distribution(frame_ms), "main_process_ms": distribution(main_process_ms),
		"tick_ms": distribution(main.tick_ms), "movement_ms": distribution(main.movement_ms),
		"collision_ms": distribution(main.collision_ms), "navigation_ms": distribution(main.navigation_ms),
		"path_ms": distribution(main.path_ms), "navigation_calls": distribution(main.navigation_calls), "snapshot_ms": distribution(main.snapshot_ms),
		"snapshot_bytes": distribution(main.snapshot_bytes), "particle_copy_ms": distribution(main.particle_copy_ms),
		"backlog_ms": distribution(backlog_ms), "spawn_ms": distribution(spawn_ms), "transform_ms": distribution(transform_ms),
		"memory_bytes": distribution(memory_bytes), "max_combatants": main.max_combatants,
		"audio_budget": main._audio_manager.budget_snapshot(), "commands": main.commands,
		"game_over": main.game_over, "terminal": main._terminal_result.get("reason", ""),
		"completed": main.game_over if case == "match" else (spawned and transformed if case == "burst" else true)}
	main.free()
	await create_timer(0.25).timeout
	result.memory_after_exit = OS.get_static_memory_usage()
	result.objects_after_exit = Performance.get_monitor(Performance.OBJECT_COUNT)
	FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("[PERF_RESULT] " + JSON.stringify(result))
	quit(0 if result.completed else 1)

func spawn_load(count: int, heavy: bool) -> Array[Unit]:
	var units: Array[Unit] = []
	var before := Time.get_ticks_usec()
	for index in count:
		var team := index % 2
		var row := index / 16
		var pos := Vector2(90 + (index % 8) * 76, (900 - row * 38) if team == 0 else (380 + row * 38))
		var card := "gnar" if heavy else ("ashe" if index % 4 == 0 else "melee_minion")
		var unit: Unit = main._spawn_unit(team, card, pos, 0.0)
		unit.max_hp = 10000000.0
		unit.hp = unit.max_hp
		unit.damage = 0.0
		units.append(unit)
	spawn_ms.append((Time.get_ticks_usec() - before) / 1000.0)
	return units

func distribution(values: Array) -> Dictionary:
	if values.is_empty(): return {"samples": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in sorted: sum += float(value)
	return {"samples": sorted.size(), "mean": sum / sorted.size(), "p95": sorted[mini(ceili(sorted.size() * 0.95) - 1, sorted.size() - 1)],
		"p99": sorted[mini(ceili(sorted.size() * 0.99) - 1, sorted.size() - 1)], "max": sorted.back()}
