extends RefCounted
## 主线程进度心跳；不能从独立线程掩盖卡住的引擎/绘制。
var enabled := false
var _tree: SceneTree
var _path := ""
var _token := ""
var _sequence := 0
var _last_msec := -1000
var _ready := false
var _phase := "starting"

func _init(tree: SceneTree) -> void:
	_tree = tree
	_path = OS.get_environment("CLASH_SAFE_PROBE_HEARTBEAT")
	_token = OS.get_environment("CLASH_SAFE_PROBE_TOKEN")
	enabled = not _path.is_empty() and not _token.is_empty() and not OS.get_environment("CLASH_SAFE_PROBE_PARENT_PID").is_empty()
	if enabled:
		_write()
		_tree.process_frame.connect(_on_frame)

func set_phase(phase: String, ready: bool = false) -> void:
	_phase = phase
	_ready = _ready or ready
	if enabled: _write()

func _on_frame() -> void:
	if Time.get_ticks_msec() - _last_msec >= 250: _write()

func _write() -> void:
	_last_msec = Time.get_ticks_msec()
	_sequence += 1
	var temporary := _path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write watchdog heartbeat")
		_tree.quit(1)
		return
	file.store_string(JSON.stringify({"token": _token, "pid": OS.get_process_id(), "sequence": _sequence, "ready": _ready, "phase": _phase}))
	file.close()
	if DirAccess.rename_absolute(temporary, _path) != OK:
		push_error("Cannot publish watchdog heartbeat")
		_tree.quit(1)
