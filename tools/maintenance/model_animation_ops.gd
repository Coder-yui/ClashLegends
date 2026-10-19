extends RefCounted
## 开发期纯动画/索引加工；活体状态不依赖此脚本。

static func compose_animation(scale_animation: Animation, base_animation: Animation, pose_animation: Animation, additive_scale_start_overrides: Dictionary = {}) -> Animation:
	var composed := Animation.new()
	composed.length = maxf(scale_animation.length, pose_animation.length)
	composed.loop_mode = Animation.LOOP_NONE
	for scale_track_index in scale_animation.get_track_count():
		var track_type := scale_animation.track_get_type(scale_track_index)
		if track_type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var track_path := scale_animation.track_get_path(scale_track_index)
		var base_track_index := _find_track(base_animation, track_type, track_path)
		var pose_track_index := _find_track(pose_animation, track_type, track_path)
		if base_track_index < 0 or pose_track_index < 0:
			continue
		var output_track_index := composed.add_track(track_type)
		composed.track_set_path(output_track_index, track_path)
		composed.track_set_interpolation_type(output_track_index, scale_animation.track_get_interpolation_type(scale_track_index))
		var key_times := PackedFloat32Array([0.0, composed.length])
		for key_index in scale_animation.track_get_key_count(scale_track_index):
			key_times.append(scale_animation.track_get_key_time(scale_track_index, key_index))
		for key_index in pose_animation.track_get_key_count(pose_track_index):
			key_times.append(pose_animation.track_get_key_time(pose_track_index, key_index))
		key_times.sort()
		var previous_key_time := -1.0
		for key_time in key_times:
			if is_equal_approx(key_time, previous_key_time):
				continue
			previous_key_time = key_time
			var scale_value = _interpolate_track(scale_animation, scale_track_index, minf(key_time, scale_animation.length))
			if track_type == Animation.TYPE_SCALE_3D and additive_scale_start_overrides.has(String(track_path)):
				scale_value = _remap_scale_start(
					scale_value,
					scale_animation.track_get_key_value(scale_track_index, 0),
					scale_animation.track_get_key_value(scale_track_index, scale_animation.track_get_key_count(scale_track_index) - 1),
					float(additive_scale_start_overrides[String(track_path)])
				)
			var base_value = base_animation.track_get_key_value(base_track_index, 0)
			var pose_value = _interpolate_track(pose_animation, pose_track_index, minf(key_time, pose_animation.length))
			var composed_value = _compose_additive_value(track_type, pose_value, base_value, scale_value)
			composed.track_insert_key(output_track_index, key_time, composed_value)
	return composed

static func _remap_scale_start(value: Vector3, original_start: Vector3, original_end: Vector3, desired_uniform_start: float) -> Vector3:
	var desired_start := Vector3.ONE * desired_uniform_start
	return Vector3(
		_remap_scale_component(value.x, original_start.x, original_end.x, desired_start.x),
		_remap_scale_component(value.y, original_start.y, original_end.y, desired_start.y),
		_remap_scale_component(value.z, original_start.z, original_end.z, desired_start.z)
	)

static func _remap_scale_component(value: float, original_start: float, original_end: float, desired_start: float) -> float:
	if is_equal_approx(original_start, original_end):
		return value
	var progress := (value - original_start) / (original_end - original_start)
	return lerpf(desired_start, original_end, progress)

static func _interpolate_track(animation: Animation, track_index: int, time: float) -> Variant:
	match animation.track_get_type(track_index):
		Animation.TYPE_POSITION_3D:
			return animation.position_track_interpolate(track_index, time)
		Animation.TYPE_ROTATION_3D:
			return animation.rotation_track_interpolate(track_index, time)
		Animation.TYPE_SCALE_3D:
			return animation.scale_track_interpolate(track_index, time)
	return animation.track_get_key_value(track_index, 0)

static func _find_track(animation: Animation, track_type: Animation.TrackType, track_path: NodePath) -> int:
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) == track_type and animation.track_get_path(track_index) == track_path:
			return track_index
	return -1

static func _compose_additive_value(track_type: Animation.TrackType, pose_value: Variant, base_value: Variant, scale_value: Variant) -> Variant:
	match track_type:
		Animation.TYPE_POSITION_3D:
			return pose_value + scale_value - base_value
		Animation.TYPE_ROTATION_3D:
			return (pose_value * base_value.inverse() * scale_value).normalized()
		Animation.TYPE_SCALE_3D:
			return pose_value * _safe_scale_ratio(scale_value, base_value)
	return scale_value

static func _safe_scale_ratio(value: Vector3, base: Vector3) -> Vector3:
	return Vector3(
		value.x / base.x if absf(base.x) > 0.0001 else 1.0,
		value.y / base.y if absf(base.y) > 0.0001 else 1.0,
		value.z / base.z if absf(base.z) > 0.0001 else 1.0
	)

static func absolute_delta(delta: Animation, idle: Animation, source: Animation) -> void:
	for track in delta.get_track_count():
		var base_track := idle.find_track(delta.track_get_path(track), delta.track_get_type(track))
		if base_track < 0: continue
		for key in delta.track_get_key_count(track):
			var t := delta.track_get_key_time(track, key)
			match delta.track_get_type(track):
				Animation.TYPE_POSITION_3D: delta.track_set_key_value(track, key, idle.position_track_interpolate(base_track, t) + source.position_track_interpolate(track, t))
				Animation.TYPE_ROTATION_3D: delta.track_set_key_value(track, key, idle.rotation_track_interpolate(base_track, t) * source.rotation_track_interpolate(track, t))
				Animation.TYPE_SCALE_3D: delta.track_set_key_value(track, key, idle.scale_track_interpolate(base_track, t) * source.scale_track_interpolate(track, t))

static func filter_bone_indices(indices: PackedInt32Array, bones: PackedInt32Array, weights: PackedFloat32Array, hidden_bind_index: int) -> PackedInt32Array:
	var kept_indices := PackedInt32Array()
	for triangle_start in range(0, indices.size(), 3):
		if triangle_start + 2 >= indices.size():
			break
		var hidden_vertices := 0
		for corner in 3:
			var vertex_index := indices[triangle_start + corner]
			var hidden_weight := 0.0
			for influence in 4:
				var influence_index := vertex_index * 4 + influence
				if influence_index < bones.size() and bones[influence_index] == hidden_bind_index:
					hidden_weight += weights[influence_index]
			if hidden_weight >= 0.5:
				hidden_vertices += 1
		if hidden_vertices < 3:
			kept_indices.append(indices[triangle_start])
			kept_indices.append(indices[triangle_start + 1])
			kept_indices.append(indices[triangle_start + 2])
	return kept_indices
