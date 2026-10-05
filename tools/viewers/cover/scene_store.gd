extends RefCounted
## 摄影台的本机布景；只保存值，不序列化 Node / Resource。
const PATH := "user://cover_studio_scene.cfg"

static func snapshot(studio: SceneTree) -> Dictionary:
	var frames: Dictionary = studio.get("_camera_frames").duplicate(true)
	var camera: Camera3D = studio.get("_camera")
	frames[studio.get("_ratio")] = {"transform": camera.transform, "fov": camera.fov}
	var members: Array = []
	for member in studio.get("_members"):
		var player: AnimationPlayer = member.player
		members.append({"card_id": member.card_id, "team": member.team, "form": member.form,
			"transform": member.model.transform, "clip": member.clip,
			"time": player.current_animation_position if player != null and player.is_playing() else member.time,
			"default_position": member.default_position, "default_yaw": member.default_yaw})
	var effects: Array = []
	for effect in studio.get("_effects"):
		var entry: Dictionary = effect.duplicate()
		entry.erase("node")
		entry.erase("playing")
		effects.append(entry)
	var external: Camera3D = studio.get("_external_camera")
	return {"version": 1, "ratio": studio.get("_ratio"), "frames": frames,
		"external_transform": external.transform, "external_fov": external.fov,
		"external_view": studio.get("_external_view"), "members": members, "effects": effects,
		"selected_member": studio.get("_selected_member"), "selected_effect": studio.get("_selected_effect"),
		"capture_name": studio.get("_capture_name").text,
		"drag_place": studio.get("_drag_place"), "placing_effect": studio.get("_placing_effect")}

static func write(path: String, state: Dictionary) -> Error:
	var config := ConfigFile.new()
	config.set_value("studio", "scene", state)
	var error := config.save(path + ".tmp")
	if error != OK: return error
	# 完整写完临时文件再替换；始终保留上一次可读取的方案。
	if FileAccess.file_exists(path):
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK: return error
	return DirAccess.rename_absolute(path + ".tmp", path)

static func read(path: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK: return {}
	var state: Variant = config.get_value("studio", "scene", null)
	return state if valid(state) else {}

static func valid(state: Variant) -> bool:
	if not state is Dictionary or state.get("version") != 1: return false
	if state.get("ratio") not in ["9x16", "16x9"]: return false
	if not state.get("frames") is Dictionary or not state.frames.has(state.ratio): return false
	for ratio in state.frames:
		var frame: Variant = state.frames[ratio]
		if ratio not in ["9x16", "16x9"] or not frame is Dictionary: return false
		if not _transform_ok(frame.get("transform")) or not _lens_ok(frame.get("fov")): return false
	if not _transform_ok(state.get("external_transform")) or not _lens_ok(state.get("external_fov")): return false
	if not state.get("members") is Array or not state.get("effects") is Array: return false
	for member in state.members:
		if not member is Dictionary: return false
		if not member.get("card_id") is String or not member.get("clip") is String: return false
		if member.get("team") not in [0, 1] or member.get("form") not in [0, 1]: return false
		if not _transform_ok(member.get("transform")) or not _number_ok(member.get("time")): return false
		if not member.get("default_position") is Vector3 or not member.default_position.is_finite(): return false
		if not _number_ok(member.get("default_yaw")): return false
	for effect in state.effects:
		if not effect is Dictionary: return false
		if effect.get("team") not in [0, 1]: return false
		if effect.get("kind") not in ["pantheon_arrival", "Spear_Impact", "update_missile", "Sliding_Comet", "Damage_Mis", "Update_Impact", "Ending_Shockwave", "Spear_Landing"]: return false
		if not effect.get("position") is Vector3 or not effect.position.is_finite(): return false
		if not _number_ok(effect.get("yaw")) or not _number_ok(effect.get("time")): return false
		if not _number_ok(effect.get("duration")) or effect.duration <= 0 or effect.duration > 5: return false
		if effect.time < 0 or effect.time > effect.duration: return false
	for key in ["external_view", "drag_place", "placing_effect"]:
		if not state.get(key) is bool: return false
	for key in ["selected_member", "selected_effect"]:
		if not state.get(key) is int: return false
	return state.get("capture_name") is String

static func _number_ok(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _lens_ok(value: Variant) -> bool:
	return _number_ok(value) and value >= 1 and value < 179

static func _transform_ok(value: Variant) -> bool:
	return value is Transform3D and value.is_finite() and not is_zero_approx(value.basis.determinant())
