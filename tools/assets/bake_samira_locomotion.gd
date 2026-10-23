extends SceneTree
## Bake skin0 upper-body masks and JointSnap events into independent presentation clips.
## Source GLB and gameplay are never changed. Re-run after changing the source model.
func _initialize() -> void: _bake.call_deferred()
func _pose(clip: Animation, time: float, skeleton: Skeleton3D) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone in skeleton.get_bone_count(): poses.append(skeleton.get_bone_rest(bone))
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone := skeleton.find_bone(path.get_subname(0))
		if bone < 0: continue
		match clip.track_get_type(track):
			Animation.TYPE_POSITION_3D: poses[bone].origin = clip.position_track_interpolate(track, time)
			Animation.TYPE_ROTATION_3D: poses[bone].basis = Basis(clip.rotation_track_interpolate(track, time)).scaled(poses[bone].basis.get_scale())
			Animation.TYPE_SCALE_3D: poses[bone].basis = Basis(poses[bone].basis.get_rotation_quaternion()).scaled(clip.scale_track_interpolate(track, time))
	return poses
func _bake() -> void:
	var model := load("res://assets/units/samira/source/samira.glb").instantiate() as Node3D
	root.add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.active = false
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: -- /absolute/locomotion_source.json /absolute/audit.json")
		model.free()
		quit(2)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var library := AnimationLibrary.new()
	var audit := {}
	for name in data.clips:
		var source := player.get_animation(name)
		assert(source != null, name)
		var record: Dictionary = data.clips[name]
		var result := source.duplicate(true) as Animation
		for track in result.get_track_count():
			while result.track_get_key_count(track) > 0: result.track_remove_key(track, 0)
		var max_snap := 0.0
		var count := ceili(source.length * 30.0)
		for frame in count + 1:
			var time := minf(float(frame) / 30.0, source.length)
			var poses := _pose(source, time, skeleton)
			if record.has("weights"):
				var base := player.get_animation(record.base)
				var lower := _pose(base, fmod(time, base.length), skeleton)
				for bone in poses.size():
					var weight: float = record.weights.get(skeleton.get_bone_name(bone), 0.0)
					poses[bone] = lower[bone].interpolate_with(poses[bone], weight)
			for bone in poses.size(): skeleton.set_bone_pose(bone, poses[bone])
			for event in record.events:
				if time + 0.00001 < float(event.start) or (float(event.end) >= 0.0 and time >= float(event.end)): continue
				var bone := skeleton.find_bone(event.bone)
				var target := skeleton.find_bone(event.target)
				assert(bone >= 0 and target >= 0)
				var global_pose := skeleton.get_bone_global_pose(target)
				max_snap = maxf(max_snap, skeleton.get_bone_global_pose(bone).origin.distance_to(global_pose.origin))
				var parent := skeleton.get_bone_parent(bone)
				poses[bone] = skeleton.get_bone_global_pose(parent).affine_inverse() * global_pose if parent >= 0 else global_pose
				skeleton.set_bone_pose(bone, poses[bone])
			for track in result.get_track_count():
				var path := result.track_get_path(track)
				if path.get_subname_count() == 0: continue
				var bone := skeleton.find_bone(path.get_subname(0))
				if bone < 0: continue
				match result.track_get_type(track):
					Animation.TYPE_POSITION_3D: result.position_track_insert_key(track, time, poses[bone].origin)
					Animation.TYPE_ROTATION_3D: result.rotation_track_insert_key(track, time, poses[bone].basis.get_rotation_quaternion())
					Animation.TYPE_SCALE_3D: result.scale_track_insert_key(track, time, poses[bone].basis.get_scale())
		library.add_animation(name, result)
		audit[name] = {"length": source.length, "maximum_unbaked_snap_distance": max_snap, "mask": record.has("weights")}
	assert(ResourceSaver.save(library, "res://assets/units/samira/locomotion.res", ResourceSaver.FLAG_COMPRESS) == OK)
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(audit, "\t") + "\n")
	print("BAKED ", audit)
	model.free()
	quit()
