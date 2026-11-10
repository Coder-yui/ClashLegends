extends RefCounted
## 用户偏好与固定视频档位，不参与对局配置或网络协议。
const CONFIG_PATH := "user://recording.cfg"
const PRESETS := [
	{"name": "省资源 · 720p / 30 帧", "size": Vector2i(720, 1280), "fps": 30, "bitrate": "5M"},
	{"name": "标准 · 1080p / 30 帧", "size": Vector2i(1080, 1920), "fps": 30, "bitrate": "10M"},
	{"name": "流畅 · 1080p / 60 帧", "size": Vector2i(1080, 1920), "fps": 60, "bitrate": "16M"},
]
var enabled := false
var preset := 2
var sound := true
var directory := ""
var encoder_path := ""

func _init() -> void:
	directory = OS.get_system_dir(OS.SYSTEM_DIR_MOVIES).path_join("ClashLegends")
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK: return
	enabled = bool(config.get_value("recording", "enabled", false))
	preset = clampi(int(config.get_value("recording", "preset", 2)), 0, PRESETS.size() - 1)
	sound = bool(config.get_value("recording", "sound", true))
	directory = str(config.get_value("recording", "directory", directory))
	encoder_path = str(config.get_value("recording", "encoder", ""))

func save() -> Error:
	var config := ConfigFile.new()
	for key in ["enabled", "preset", "sound", "directory"]:
		config.set_value("recording", key, get(key))
	config.set_value("recording", "encoder", encoder_path)
	return config.save(CONFIG_PATH)

func encoder() -> String:
	var filename := "ffmpeg.exe" if OS.get_name() == "Windows" else "ffmpeg"
	var candidates: Array[String] = [encoder_path, OS.get_executable_path().get_base_dir().path_join(filename), "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
	for folder in OS.get_environment("PATH").split(";" if OS.get_name() == "Windows" else ":"):
		candidates.append(folder.path_join(filename))
	for path in candidates:
		if not path.is_empty() and FileAccess.file_exists(path): return path
	return ""

func validate() -> String:
	if encoder().is_empty(): return "未找到视频编码器，请在录制设置中选择 FFmpeg。"
	if directory.is_empty() or not directory.is_absolute_path(): return "请选择有效的录像保存文件夹。"
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return "无法创建保存文件夹，请更换位置。"
	var probe := directory.path_join(".clash-recording-check-%d" % Time.get_ticks_usec())
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null: return "无法写入保存文件夹，请更换位置。"
	file.close()
	DirAccess.remove_absolute(probe)
	return ""

func session_spec() -> Dictionary:
	var spec: Dictionary = PRESETS[preset].duplicate()
	spec.encoder = encoder()
	spec.sound = sound
	spec.sample_rate = int(AudioServer.get_mix_rate())
	# 毫秒与进程号避免同秒多次录制覆盖；FFmpeg仍使用-n拒绝覆盖。
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("T", "_")
	spec.path = directory.path_join("ClashLegends_%s_%d_%d.mp4" % [stamp, OS.get_process_id(), Time.get_ticks_usec() % 1000000])
	return spec
