extends RefCounted
## 迁移诊断：显式传入实施前的本地源码快照；不把旧加工代码留在运行资源中。
static func legacy(scene: String, baseline: String) -> Node3D:
	var result: Node3D = load(scene).instantiate()
	if result.get_script() == null:
		result.free(); return null
	var path: String = result.get_script().resource_path.trim_prefix("res://")
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(baseline.path_join(path))
	if script.reload() != OK:
		result.free()
		return null
	result.set_script(script)
	# 参数必须来自实施前场景，不能让新配方同时控制旧参照，掩盖迁移参数错误。
	var source := FileAccess.get_file_as_string(baseline.path_join(scene.trim_prefix("res://")))
	var lines := source.split("\n")
	var fields := ["ranged", "filtered_clips", "hidden_surface_indices", "hidden_bone_name", "additive_output_clip", "additive_scale_clip", "additive_base_clip", "additive_pose_clip", "additive_secondary_output_clip", "additive_secondary_pose_clip", "additive_scale_start_overrides"]
	var index := 0
	while index < lines.size():
		var line: String = lines[index]
		index += 1
		var split := line.find(" = ")
		if split < 0: continue
		var field := line.substr(0, split)
		if field not in fields: continue
		var expression := line.substr(split + 3)
		if expression == "{":
			while index < lines.size():
				expression += "\n" + lines[index]
				index += 1
				if lines[index - 1] == "}": break
		result.set(field, str_to_var(expression))
	return result

static func animation_data(animation: Animation) -> Array:
	var result := [animation.length, animation.loop_mode, animation.step, animation.resource_name]
	for track in animation.get_track_count():
		var values := [animation.track_get_type(track), animation.track_get_path(track), animation.track_get_interpolation_type(track), animation.track_get_interpolation_loop_wrap(track), animation.track_is_enabled(track), animation.track_is_imported(track)]
		for key in animation.track_get_key_count(track): values.append([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key), animation.track_get_key_transition(track, key)])
		result.append(values)
	return result

static func equal(a: Variant, b: Variant) -> bool:
	return var_to_bytes(a) == var_to_bytes(b)

static func material_data(material: Material) -> Dictionary:
	var result := {}
	if material == null: return result
	for property in material.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name in ["resource_path", "resource_scene_unique_id"]: continue
		var value: Variant = material.get(property.name)
		result[property.name] = value.resource_path if value is Resource else value
	return result

static func material_chain(material: Material) -> Dictionary:
	var result := material_data(material)
	if material != null: result["next_pass"] = material_chain(material.next_pass) if material.next_pass != null else {}
	return result
