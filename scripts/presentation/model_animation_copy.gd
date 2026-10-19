extends RefCounted
## 数值骨骼轨道直接由引擎复制，避免 duplicate 的逐属性序列化往返。
## 仍是实例独立 Animation；含资源/事件、压缩轨道或扩展数据时保留完整深复制。
static func copy_animation(source: Animation) -> Animation:
	if source.get_script() != null or not source.get_meta_list().is_empty():
		return source.duplicate(true) as Animation
	for track in source.get_track_count():
		if source.track_is_compressed(track) or source.track_get_type(track) not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D, Animation.TYPE_BLEND_SHAPE]:
			return source.duplicate(true) as Animation
	var result := Animation.new()
	result.resource_name = source.resource_name
	result.resource_local_to_scene = source.resource_local_to_scene
	result.length = source.length
	result.step = source.step
	result.loop_mode = source.loop_mode
	for marker in source.get_marker_names():
		result.add_marker(marker, source.get_marker_time(marker))
		result.set_marker_color(marker, source.get_marker_color(marker))
	for track in source.get_track_count(): source.copy_track(track, result)
	return result

static func copy_library(source: AnimationLibrary) -> AnimationLibrary:
	if source.get_script() != null or not source.get_meta_list().is_empty():
		return source.duplicate(true) as AnimationLibrary
	var result := source.duplicate(false) as AnimationLibrary
	var copies := {}
	for clip in source.get_animation_list():
		result.remove_animation(clip)
		var animation := source.get_animation(clip)
		if not copies.has(animation): copies[animation] = copy_animation(animation)
		result.add_animation(clip, copies[animation])
	return result
