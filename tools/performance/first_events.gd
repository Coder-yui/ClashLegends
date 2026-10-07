extends SceneTree
## 固定240帧/卡、1/60模拟步长；保留逐帧事件关联，截图不进入采样。
## 高生命、绕过经济、手动冲撞只用于可重复的首事件诊断。
var main: Node
var output := ""
var cues: Array = []
var results: Array = []
var current_card := ""
var current_frame := -1
var started := 0
var loading_frames: Array = []
var loading_last := 0

func loading_frame() -> void:
	var now := Time.get_ticks_usec()
	if loading_last > 0: loading_frames.append((now - loading_last) / 1000.0)
	loading_last = now

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty(): output = preload("res://tools/lib/development_paths.gd").output("first-events")
	DirAccess.make_dir_recursive_absolute(output)
	root.always_on_top = true
	Engine.max_fps = 60
	main = load("res://scenes/main.tscn").instantiate()
	main.set_script(preload("res://tools/performance/benchmark_main.gd"))
	main._deck = ["gnar", "anivia", "belveth", "rift_herald", "garen", "ashe", "freeze", "heal"]
	root.add_child(main)
	current_scene = main
	seed(12345)
	var setup_start := Time.get_ticks_usec()
	loading_last = setup_start
	process_frame.connect(loading_frame)
	await main._start_local_with_loading()
	process_frame.disconnect(loading_frame)
	var setup_ms := (Time.get_ticks_usec() - setup_start) / 1000.0
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	main._audio_manager.cue_played.connect(func(card, cue, _pos): cues.append({"case": current_card, "frame": current_frame, "tick": main._sim_tick_id, "card": card, "cue": cue}))
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var world_viewport: RID = main._battle_presentation._viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(world_viewport, true)
	for card in ["garen", "ashe", "gnar", "anivia", "belveth", "rift_herald"]:
		current_card = card
		main.clear_preview_battle()
		await process_frame
		var frames: Array = []
		var events: Array = []
		started = Time.get_ticks_usec()
		var last := started
		var source: Unit
		var target: Unit
		for frame in 240:
			await process_frame
			current_frame = frame
			var now := Time.get_ticks_usec()
			var row := {"frame": frame, "tick_before": main._sim_tick_id, "elapsed_ms": (now - started) / 1000.0,
				"interval_ms": (now - last) / 1000.0, "resources_before": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
				"previous_render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport),
				"previous_render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport),
				"previous_world_render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(world_viewport),
				"previous_world_render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(world_viewport),
				"previous_frame_setup_cpu_ms": RenderingServer.get_frame_setup_time_cpu(),
				"previous_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			last = now
			var before := Time.get_ticks_usec()
			if frame == 0:
				var ok: bool = main.play_card(0, card, Vector2(140, 720), {"immediate": true, "validate_position": false})
				ok = main.play_card(1, "garen", Vector2(140, 600), {"immediate": true, "validate_position": false}) and ok
				events.append({"frame": frame, "event": "deploy", "accepted": ok, "ms": (Time.get_ticks_usec() - before) / 1000.0})
				source = main._latest_unit_for_card(card, 0)
				target = main._latest_unit_for_card("garen", 1)
				if source == null or target == null:
					push_error("出牌未生成单位 " + card)
					quit(1)
					return
				source.hp = 100000
				source.max_hp = 100000
				target.hp = 100000
				target.max_hp = 100000
			if frame == 60:
				var skills := CardDB.active_skills_for(card)
				if not skills.is_empty() and is_instance_valid(source):
					source.configure_carried_active_skill(skills[0])
					source.skill_resource_value = source.skill_resource_max
					main._start_active_skill_cast(source, skills[0])
				events.append({"frame": frame, "event": "skill", "ms": (Time.get_ticks_usec() - before) / 1000.0})
				before = Time.get_ticks_usec()
				main.play_card(0, "freeze", Vector2(140, 600), {"immediate": true, "validate_position": false})
				events.append({"frame": frame, "event": "freeze", "ms": (Time.get_ticks_usec() - before) / 1000.0})
				before = Time.get_ticks_usec()
				main.play_card(0, "heal", Vector2(140, 720), {"immediate": true, "validate_position": false})
				events.append({"frame": frame, "event": "heal", "ms": (Time.get_ticks_usec() - before) / 1000.0})
			if frame == 140:
				if is_instance_valid(source):
					if card == "gnar": source.transform_to_mega()
					elif card in ["belveth", "anivia"]: source.take_damage(10000000)
					elif card == "rift_herald":
						source.structure_rush.target = main._towers[2]
						source.structure_rush.direction = Vector2.UP
						source.structure_rush._impact(source)
				events.append({"frame": frame, "event": "transform_death_summon", "ms": (Time.get_ticks_usec() - before) / 1000.0})
			row["event_and_setup_cpu_ms"] = (Time.get_ticks_usec() - now) / 1000.0
			before = Time.get_ticks_usec()
			main._process(1.0 / 60.0)
			row["main_cpu_ms"] = (Time.get_ticks_usec() - before) / 1000.0
			row["resources_after"] = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
			row["static_bytes"] = OS.get_static_memory_usage()
			row["form"] = source.form_index if is_instance_valid(source) else -1
			frames.append(row)
		results.append({"card": card, "events": events, "frames": frames})
		if "--capture" in OS.get_cmdline_user_args():
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(output.path_join(card + ".png"))
	var result := {"schema": 2, "fixed_sim_delta": 1.0 / 60.0, "frame_limit": 240, "setup_ms": setup_ms,
		"loading_frames_ms": loading_frames, "loading_stages": main.preparation_metrics,
		"pool_refill": main._battle_presentation.model_pool.refill_metrics if is_instance_valid(main._battle_presentation) else {},
		"pool_initial_capacity": main._battle_presentation.model_pool.initial_capacity if is_instance_valid(main._battle_presentation) else {},
		"pool_preparation": main._battle_presentation.model_pool.preparation_times,
		"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(),
		"gpu_timer_note": "Previous completed viewport timing; zero may mean unsupported, not zero GPU work.",
		"resource_note": "Godot resource count is a monitor snapshot, not a disk-load trace; frame interval includes prior frame work and OS/vsync waits.",
		"results": results, "cues": cues, "pool": main._battle_presentation.model_pool.metrics,
		"capacity": main._battle_presentation.model_pool.capacity, "resources": main._resources.resources.keys(),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	main.free()
	await process_frame
	result.memory_after_exit = OS.get_static_memory_usage()
	FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("[FIRST_EVENTS] completed ", results.size(), " cases, output=", output)
	quit()
