extends SceneTree
## 真实对局、固定录像画布与实时编码验收；仅本工具加入音画同步闪块/短音。
var output := ""
var dimensions := Vector2i(720, 1280)
var quality := 0
var seconds := 6.0
var with_sound := true
var resize_during := false
var finish_mode := "result"
var clean := false
var settings_only := false
var red := false
var main: Node2D

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--seconds="): seconds = float(argument.trim_prefix("--seconds="))
		if argument == "--silent": with_sound = false
		if argument == "--resize": resize_during = true
		if argument == "--clean": clean = true
		if argument == "--settings-only": settings_only = true
		if argument == "--red": red = true
		if argument.begins_with("--finish="): finish_mode = argument.trim_prefix("--finish=")
		if argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			dimensions = Vector2i(int(parts[0]), int(parts[1]))
	assert(not output.is_empty() and DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("display_window_initialized", true)
	root.gui_embed_subwindows = true
	root.size = dimensions
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.runtime._deck = ["garen", "ashe", "heal", "freeze", "final_spark", "mirror", "medium_lightning", "kayle"]
	if settings_only:
		main._pick_deck_ui(func(): pass)
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("deck.png"))
		var controls: Node = main._deck_builder.find_child("RecordingControls", true, false)
		controls._show_settings()
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("settings.png"))
		main.free()
		quit()
		return
	main._resources.prepare(["garen", "ashe"])
	main._battle_loading = true
	main._start_local()
	main._battle_loading = false
	if red:
		main.runtime.local_team = 1
		main._refresh_display_layout()
	main._ai.enabled = false
	main.runtime._minion_waves_enabled = false
	for entry in [[0, "garen", Vector2(260, 760)], [1, "garen", Vector2(260, 520)], [0, "ashe", Vector2(460, 840)]]:
		main.runtime.account(entry[0]).elixir = 10
		assert(main.play_card(entry[0], entry[1], entry[2], {"immediate": true}))
	var recorder: Node = main._recorder
	recorder.options.enabled = true
	recorder.options.directory = output
	recorder.options.preset = quality
	recorder.options.sound = with_sound
	if finish_mode == "failure": recorder.options.encoder_path = "/usr/bin/false"
	# 测试不保存用户偏好。
	var flash := ColorRect.new()
	flash.color = Color.BLACK
	flash.visible = not clean
	flash.size = Vector2(120, 100)
	flash.position = Vector2(main.get_viewport_rect().size.x * 0.5 - 60, 100)
	main._timer_label.get_parent().add_child(flash)
	var tone := AudioStreamPlayer.new()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 48000
	var data := PackedByteArray()
	data.resize(4800 * 2)
	for sample in 4800: data.encode_s16(sample * 2, int(sin(TAU * 880.0 * sample / 48000.0) * 10000))
	stream.data = data
	tone.stream = stream
	main.add_child(tone)
	for i in 10: await process_frame
	assert(recorder.begin())
	while recorder.active and recorder._started_usec == 0: await process_frame
	var started := Time.get_ticks_usec()
	var flashed := false
	var resized := false
	var flash_time := 0.0
	var peak_memory := 0
	var frame_times: Array[float] = []
	var previous := started
	while recorder.active and float(Time.get_ticks_usec() - started) / 1000000.0 < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
		peak_memory = maxi(peak_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		var elapsed := float(now - started) / 1000000.0
		if elapsed >= 2 and not flashed:
			flashed = true
			flash_time = float(now - recorder._started_usec) / 1000000.0
			flash.color = Color.WHITE
			if not clean: tone.play()
		if elapsed >= 2.2: flash.color = Color.BLACK
		if elapsed >= 3 and resize_during and not resized:
			resized = true
			root.size = Vector2i(1280, 720)
			for i in 3: await process_frame
			flash.position.x = main.get_viewport_rect().size.x * 0.5 - 60
		if elapsed >= 1 and not FileAccess.file_exists(output.path_join("recording.png")):
			await RenderingServer.frame_post_draw
			recorder._canvas.get_texture().get_image().save_png(output.path_join("recording.png"))
	var saved_results: Array[Dictionary] = []
	if finish_mode == "close":
		recorder.completed.connect(func(_path: String, _error: String):
			FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(recorder.last_result, "\t"))
			print("[RECORDING_CLOSE] ", JSON.stringify(recorder.last_result))
		)
		recorder.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		await create_timer(15).timeout
		push_error("窗口关闭录制收尾未按时退出")
		quit(1)
		return
	if finish_mode == "abort":
		var worker: RefCounted = recorder._encoder
		main.free()
		var result: Dictionary = worker.snapshot()
		FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
		print("[RECORDING_ABORT] ", JSON.stringify(result))
		quit(0 if result.done and not result.error.is_empty() else 1)
		return
	if finish_mode == "return":
		recorder.completed.connect(func(_path: String, _error: String): saved_results.append(recorder.last_result.duplicate()))
		main.return_to_main_menu()
		while saved_results.is_empty(): await process_frame
		while is_instance_valid(main): await process_frame
		main = current_scene
	else:
		if finish_mode == "early": recorder.stop()
		else: main._end_game(0, "time")
		while recorder.active or recorder.finalizing: await process_frame
		saved_results.append(recorder.last_result.duplicate())
	frame_times.sort()
	var report: Dictionary = saved_results[0]
	report.finish_mode = finish_mode
	report.flash_time = flash_time
	report.peak_static_bytes = peak_memory
	report.frame_p50_ms = frame_times[int(frame_times.size() * 0.5)] if not frame_times.is_empty() else 0.0
	report.frame_p95_ms = frame_times[int(frame_times.size() * 0.95)] if not frame_times.is_empty() else 0.0
	report.window = str(dimensions)
	report.preset = quality
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("[RECORDING_SMOKE] ", JSON.stringify(report))
	var passed: bool = report.error.is_empty() and FileAccess.file_exists(report.path)
	if finish_mode == "failure": passed = not report.error.is_empty()
	main.free()
	await process_frame
	quit(0 if passed else 1)
