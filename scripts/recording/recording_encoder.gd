extends RefCounted
## 有界生产者队列；阻塞管道写入、音频落盘与封装均在工作线程。
const MAX_VIDEO_QUEUE := 3
const MAX_AUDIO_BYTES := 4 * 1024 * 1024
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _thread := Thread.new()
var _video: Array[Dictionary] = []
var _audio := PackedByteArray()
var _ending := false
var _aborted := false
var _end_frame := 0
var _state := {"done": false, "error": "", "path": "", "pid": -1, "written": 0, "dropped": 0, "heartbeat": 0}
var _spec: Dictionary

func start(spec: Dictionary) -> Error:
	_spec = spec.duplicate()
	_state.heartbeat = Time.get_ticks_usec()
	return _thread.start(_encode)

func snapshot() -> Dictionary:
	_mutex.lock()
	var state := _state.duplicate()
	_mutex.unlock()
	return state

func room_for_frame() -> bool:
	_mutex.lock()
	var room: bool = _video.size() < MAX_VIDEO_QUEUE and not _ending and not _state.done
	if not room: _state.dropped += 1
	_mutex.unlock()
	return room

func submit_frame(frame: PackedByteArray, index: int) -> void:
	_mutex.lock()
	if _video.size() < MAX_VIDEO_QUEUE and not _ending:
		_video.append({"bytes": frame, "index": index})
	_mutex.unlock()
	_wake.post()

func submit_audio(bytes: PackedByteArray) -> bool:
	_mutex.lock()
	var accepted := _audio.size() + bytes.size() <= MAX_AUDIO_BYTES and not _ending
	if accepted: _audio.append_array(bytes)
	_mutex.unlock()
	_wake.post()
	return accepted

func finish(frame_count: int) -> void:
	_mutex.lock()
	_ending = true
	_end_frame = frame_count
	_mutex.unlock()
	_wake.post()

func abort(message: String) -> void:
	_mutex.lock()
	_aborted = true
	_ending = true
	_state.error = message
	var pid := int(_state.pid)
	# 与工作线程的进程查询互斥，避免kill后再次查询已被Godot移除的pid。
	if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
	_state.pid = -1
	_mutex.unlock()
	_wake.post()

func reap() -> void:
	if _thread.is_started(): _thread.wait_to_finish()

func _publish(key: String, value: Variant) -> void:
	_mutex.lock()
	_state[key] = value
	_mutex.unlock()

func _publish_process(pid: int) -> void:
	_mutex.lock()
	_state.pid = pid
	# 退出请求可能恰好发生在创建进程与登记pid之间。
	if _aborted:
		if OS.is_process_running(pid): OS.kill(pid)
		_state.pid = -1
	_mutex.unlock()

func _is_aborted() -> bool:
	_mutex.lock()
	var value := _aborted
	_mutex.unlock()
	return value

static func video_arguments(spec: Dictionary, path: String) -> PackedStringArray:
	var dimensions: Vector2i = spec.size
	var args := PackedStringArray(["-hide_banner", "-loglevel", "error", "-nostdin", "-n", "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", "%dx%d" % [dimensions.x, dimensions.y], "-framerate", str(spec.fps), "-i", "pipe:0", "-an"])
	if OS.get_name() == "macOS":
		args.append_array(["-c:v", "h264_videotoolbox", "-allow_sw", "1", "-realtime", "1"])
	else:
		args.append_array(["-c:v", "libx264", "-preset", "veryfast", "-threads", "2"])
	args.append_array(["-b:v", spec.bitrate, "-pix_fmt", "yuv420p", "-g", str(int(spec.fps) * 2), "-movflags", "+frag_keyframe+empty_moov", path])
	return args

func _wait_process(pid: int, timeout_ms: int) -> bool:
	var start := Time.get_ticks_msec()
	while true:
		_mutex.lock()
		if _aborted:
			_mutex.unlock()
			return false
		if not OS.is_process_running(pid):
			var success := OS.get_process_exit_code(pid) == 0
			_state.pid = -1
			_mutex.unlock()
			return success
		if Time.get_ticks_msec() - start > timeout_ms:
			OS.kill(pid)
			_state.pid = -1
			_mutex.unlock()
			return false
		_state.heartbeat = Time.get_ticks_usec()
		_mutex.unlock()
		OS.delay_msec(10)
	return false

func _write(pipe: FileAccess, bytes: PackedByteArray) -> bool:
	if _is_aborted(): return false
	if not pipe.store_buffer(bytes): return false
	_publish("heartbeat", Time.get_ticks_usec())
	return true

func _encode() -> void:
	var partial: String = _spec.path.trim_suffix(".mp4") + ".video.partial.mp4"
	var audio_path: String = _spec.path.trim_suffix(".mp4") + ".audio.partial.f32"
	var audio_file: FileAccess
	if _spec.sound:
		audio_file = FileAccess.open(audio_path, FileAccess.WRITE)
		if audio_file == null:
			_complete("无法写入录音文件，请检查保存位置和磁盘空间。")
			return
	var process := OS.execute_with_pipe(_spec.encoder, video_arguments(_spec, partial))
	if process.is_empty():
		_complete("视频编码器无法启动，请检查录制设置。")
		return
	var pid := int(process.pid)
	_publish_process(pid)
	var pipe: FileAccess = process.stdio
	var previous := PackedByteArray()
	var written := 0
	var failed := false
	var final_frames := 0
	while true:
		_wake.wait()
		_mutex.lock()
		var frames := _video
		_video = []
		var audio_bytes := _audio
		_audio = PackedByteArray()
		var ending := _ending
		final_frames = _end_frame
		_mutex.unlock()
		if _is_aborted():
			failed = true
			break
		if audio_file != null and not audio_bytes.is_empty():
			if not audio_file.store_buffer(audio_bytes):
				failed = true
				break
		for frame in frames:
			if previous.is_empty(): previous = frame.bytes
			while written < int(frame.index):
				if not _write(pipe, previous):
					failed = true
					break
				written += 1
			if failed or not _write(pipe, frame.bytes):
				failed = true
				break
			previous = frame.bytes
			written += 1
			_publish("written", written)
		if failed: break
		if ending:
			while written < final_frames and not previous.is_empty():
				if not _write(pipe, previous):
					failed = true
					break
				written += 1
			break
	pipe.close()
	if audio_file != null: audio_file.close()
	var video_ok := _wait_process(pid, 20000)
	_publish("pid", -1)
	if failed or not video_ok or written == 0:
		_complete("录制未完成，请检查编码器或磁盘空间；已写入的临时文件保留在保存目录。")
		return
	var args := PackedStringArray(["-hide_banner", "-loglevel", "error", "-nostdin", "-n", "-i", partial])
	if _spec.sound:
		args.append_array(["-f", "f32le", "-ar", str(_spec.sample_rate), "-ac", "2", "-i", audio_path, "-map", "0:v:0", "-map", "1:a:0", "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-af", "apad"])
	args.append_array(["-c:v", "copy", "-t", str(float(written) / float(_spec.fps)), "-movflags", "+faststart", _spec.path])
	var mux := OS.execute_with_pipe(_spec.encoder, args)
	if mux.is_empty():
		_complete("录像封装未启动；临时视频与声音已保留。")
		return
	_publish_process(int(mux.pid))
	(mux.stdio as FileAccess).close()
	if not _wait_process(int(mux.pid), 60000):
		_complete("录像封装失败；临时视频与声音已保留。")
		return
	DirAccess.remove_absolute(partial)
	if _spec.sound: DirAccess.remove_absolute(audio_path)
	_publish("written", written)
	_publish("path", _spec.path)
	_complete("")

func _complete(error: String) -> void:
	_mutex.lock()
	if _state.error.is_empty(): _state.error = error
	_state.pid = -1
	_state.done = true
	_mutex.unlock()
