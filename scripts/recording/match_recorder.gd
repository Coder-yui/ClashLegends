extends Node
## 本机录像生命周期；使用墙钟帧号，不修改模拟、动画或网络播放时钟。
signal completed(path: String, error: String)
const OPTIONS := preload("res://scripts/recording/recording_options.gd")
const ENCODER := preload("res://scripts/recording/recording_encoder.gd")
const CANVAS := preload("res://scripts/recording/recording_canvas.gd")
var options := OPTIONS.new()
var active := false
var finalizing := false
var last_result: Dictionary = {}
var _source: Node2D
var _source_viewport: Viewport
var _canvas: SubViewport
var _encoder: RefCounted
var _capture: AudioEffectCapture
var _spec: Dictionary
var _started_usec := 0
var _next_frame := 0
var _last_captured := -1
var _requested := false
var _stop_at_usec := 0
var _status_layer: CanvasLayer
var _status_button: Button
var _closing := false
var _old_auto_quit := true
var _lost_frames := 0
var _old_oversampling := 0.0

func setup(source: Node2D) -> void:
	_source = source
	_source_viewport = source.get_viewport()
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	_old_auto_quit = get_tree().auto_accept_quit
	set_process(false)

func density() -> float:
	return float(_spec.size.x) / 720.0 if active else 1.0

func begin() -> bool:
	if active or finalizing or not options.enabled: return false
	if DisplayServer.get_name() == "headless" or _source.runtime.mode == "server" or _source._workbench.enabled: return false
	var error: String = options.validate()
	_create_indicator()
	if not error.is_empty():
		_status_button.text = "录制未开始：" + error
		last_result = {"path": "", "error": error}
		return false
	_spec = options.session_spec()
	last_result = {}
	_encoder = ENCODER.new()
	if _encoder.start(_spec) != OK:
		_status_button.text = "录制未开始：无法启动编码线程"
		_encoder = null
		return false
	_canvas = CANVAS.new()
	add_child(_canvas)
	_canvas.setup(_source, _spec.size)
	_canvas.render_target_update_mode = SubViewport.UPDATE_DISABLED
	active = true
	_old_oversampling = _source_viewport.oversampling_override
	# 共享HUD的字形缓存按成片密度生成，避免缩小游戏窗口后录像文字变糊。
	_source_viewport.oversampling_override = maxf(float(_spec.size.x) / 720.0, _source_viewport.get_oversampling())
	finalizing = false
	_started_usec = 0
	_last_captured = -1
	_next_frame = 0
	_stop_at_usec = 0
	_lost_frames = 0
	get_tree().auto_accept_quit = false
	_source._refresh_display_layout()
	RenderingServer.frame_post_draw.connect(_on_frame)
	set_process(true)
	return true

func _create_indicator() -> void:
	if is_instance_valid(_status_layer): _status_layer.queue_free()
	_status_layer = CanvasLayer.new()
	_status_layer.layer = 120
	add_child(_status_layer)
	_status_button = Button.new()
	_status_button.position = Vector2(12, 8)
	_status_button.add_theme_font_override("font", CardArt.ui_font())
	_status_button.add_theme_font_size_override("font_size", 16)
	_status_button.add_theme_color_override("font_color", Color("ffb8aa"))
	_status_button.add_theme_stylebox_override("normal", UIMaterials.fine_panel(Color("889ba5"), 8))
	_status_button.add_theme_stylebox_override("hover", UIMaterials.fine_panel(Color(1.25, 1.16, 0.95), 8))
	_status_button.add_theme_stylebox_override("pressed", UIMaterials.fine_panel(Color(0.8, 0.85, 0.85), 8))
	_status_button.add_theme_stylebox_override("focus", UIPalette.panel(Color.TRANSPARENT, UIPalette.GOLD_LIGHT, 1, 0))
	_status_button.text = "● 正在准备录制…"
	_status_button.pressed.connect(func():
		if active: stop()
		elif not last_result.get("path", "").is_empty(): OS.shell_open(str(last_result.path).get_base_dir())
	)
	_status_layer.add_child(_status_button)

func _process(_delta: float) -> void:
	if _encoder == null: return
	var state: Dictionary = _encoder.snapshot()
	if state.done:
		_encoder.reap()
		_encoder = null
		if active: _release_capture()
		finalizing = false
		get_tree().auto_accept_quit = _old_auto_quit
		last_result = state
		last_result.duplicated_frames = _lost_frames
		_status_button.text = "录像已保存 · 打开文件夹" if state.error.is_empty() else str(state.error)
		_status_button.tooltip_text = str(state.path) if state.error.is_empty() else str(state.error)
		completed.emit(str(state.path), str(state.error))
		set_process(false)
		return
	if Time.get_ticks_usec() - int(state.heartbeat) > 10000000:
		_encoder.abort("录制编码超时，已停止录制；对局可继续。")
		if active: _release_capture()
		finalizing = true
		return
	if not active: return
	_drain_audio()
	if not active: return
	var now := Time.get_ticks_usec()
	if _stop_at_usec > 0 and now >= _stop_at_usec:
		stop()
		return
	var elapsed := 0.0 if _started_usec == 0 else float(now - _started_usec) / 1000000.0
	_status_button.text = "● %02d:%02d  停止录制" % [int(elapsed) / 60, int(elapsed) % 60]
	if _lost_frames > 0 or int(state.dropped) > 0:
		_status_button.text += " · 已补帧"
		_status_button.tooltip_text = "当前负载较高，录像已按真实时长补帧；下次可选择30帧档位。"
	if _started_usec == 0 or now + int(_delta * 500000.0) >= _next_frame:
		_canvas.refresh()
		_canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
		_requested = true


func _on_frame() -> void:
	if not active or not _requested: return
	_requested = false
	var now := Time.get_ticks_usec()
	if _started_usec == 0:
		_started_usec = now
		if _spec.sound:
			_capture = AudioEffectCapture.new()
			_capture.buffer_length = 2.0
			AudioServer.add_bus_effect(0, _capture)
	var index := floori(float(now - _started_usec) * float(_spec.fps) / 1000000.0)
	if index <= _last_captured: return
	if not _encoder.room_for_frame(): return
	var image := _canvas.get_texture().get_image()
	if image.is_empty():
		_encoder.abort("无法读取录制画面，已停止录制。")
		_release_capture()
		finalizing = true
		return
	image.convert(Image.FORMAT_RGB8)
	if _last_captured >= 0: _lost_frames += maxi(0, index - _last_captured - 1)
	_encoder.submit_frame(image.get_data(), index)
	_last_captured = index
	_next_frame = _started_usec + int(float(index + 1) * 1000000.0 / float(_spec.fps))

func _drain_audio() -> void:
	if _capture == null: return
	if _capture.get_discarded_frames() > 0:
		_encoder.abort("声音采集未能及时处理，已停止录制以避免音画错位。")
		_release_capture()
		finalizing = true
		return
	var available := _capture.get_frames_available()
	if available > 0 and not _encoder.submit_audio(_capture.get_buffer(available).to_byte_array()):
		_encoder.abort("录音写入拥堵，已停止录制；对局可继续。")
		_release_capture()
		finalizing = true

func finish_after_result() -> void:
	if active: _stop_at_usec = Time.get_ticks_usec() + 3000000

func stop() -> void:
	if not active: return
	_drain_audio()
	if not active: return
	var count := maxi(_last_captured + 1, ceili(float(Time.get_ticks_usec() - _started_usec) * float(_spec.fps) / 1000000.0)) if _started_usec > 0 else 0
	_encoder.finish(count)
	_release_capture()
	finalizing = true
	_status_button.text = "正在保存录像…"

func _release_capture(refresh_layout: bool = true) -> void:
	if active and is_instance_valid(_source_viewport):
		_source_viewport.oversampling_override = _old_oversampling
	active = false
	_requested = false
	if RenderingServer.frame_post_draw.is_connected(_on_frame): RenderingServer.frame_post_draw.disconnect(_on_frame)
	if _capture != null:
		for index in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
			if AudioServer.get_bus_effect(0, index) == _capture: AudioServer.remove_bus_effect(0, index)
		_capture = null
	if is_instance_valid(_canvas):
		_canvas.queue_free()
		_canvas = null
	if refresh_layout and is_instance_valid(_source) and _source.is_inside_tree(): _source._refresh_display_layout()

func finish_and_wait() -> void:
	stop()
	while finalizing: await get_tree().process_frame

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and (active or finalizing) and not _closing:
		_closing = true
		await finish_and_wait()
		get_tree().quit()

func _exit_tree() -> void:
	_release_capture(false)
	if _encoder != null:
		_encoder.abort("场景已退出，录制中止；临时文件保留。")
		_encoder.reap()
		_encoder = null
	get_tree().auto_accept_quit = _old_auto_quit
