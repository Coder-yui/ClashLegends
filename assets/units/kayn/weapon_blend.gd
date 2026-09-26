extends SkeletonModifier3D
## 镰刀在模型空间混合；默认最短路径，红凯进出地形沿固定的身体外侧路径。
## 只读动画采样，不改骨架、源片段、战斗位置或技能时钟。
var player: AnimationPlayer
var _weapon := -1
var _chain: Array[int] = []
var _tracks: Dictionary = {}
var _from := Transform3D.IDENTITY
var _last_pose := Transform3D.IDENTITY
var _has_pose := false
var _initial_clip := false
var _duration := 0.0
var _elapsed := 0.0
var _last_time := 0.0
var _clip := &""
var _outside_turn := false
var _outside_reverse := false
var _outside_axis := Vector3.ZERO

func begin_blend(clip: StringName, duration: float) -> void:
	_initialize_bones()
	if _weapon < 0: return
	# 首次部署和池复用没有上一帧动作，不得从 Rest/旧实例姿势生成过渡。
	# 此动作对固定从身体外侧抬起镰刀，不能仅靠最短路径选方向。
	_outside_reverse = player.assigned_animation == &"Spell3_Run" and clip == &"Run_Slayer"
	_outside_turn = _outside_reverse or (player.assigned_animation == &"Run_Slayer" and clip == &"Spell3_Run")
	if _outside_turn and _outside_axis == Vector3.ZERO:
		# 锁定已验证的外侧旋转轴；接近180度时不能按每帧长/短弧重新选边。
		var reference_from := sample_weapon(&"Run_Slayer", 0.22).basis.get_rotation_quaternion()
		var reference_to := sample_weapon(&"Spell3_Run", 0.0).basis.get_rotation_quaternion()
		if reference_from.dot(reference_to) > 0.0: reference_to = -reference_to
		var delta := reference_from.inverse() * reference_to
		_outside_axis = Vector3(delta.x, delta.y, delta.z).normalized()
	_initial_clip = not _has_pose
	_from = _last_pose
	_duration = maxf(duration, 0.0)
	_elapsed = 0.0
	_last_time = 0.0
	_clip = clip

func _initialize_bones() -> void:
	if _weapon >= 0: return
	var skeleton := get_skeleton()
	if skeleton == null: return
	_weapon = skeleton.find_bone("C_Weapon")
	var bone := _weapon
	while bone >= 0:
		_chain.push_front(bone)
		bone = skeleton.get_bone_parent(bone)

func sample_weapon(clip: StringName, time: float) -> Transform3D:
	_initialize_bones()
	var animation := player.get_animation(clip)
	if not _tracks.has(clip):
		var rows: Array = []
		for bone in _chain:
			var row := [-1, -1, -1]
			for track in animation.get_track_count():
				if String(animation.track_get_path(track).get_concatenated_subnames()) != get_skeleton().get_bone_name(bone): continue
				match animation.track_get_type(track):
					Animation.TYPE_POSITION_3D: row[0] = track
					Animation.TYPE_ROTATION_3D: row[1] = track
					Animation.TYPE_SCALE_3D: row[2] = track
			rows.append(row)
		_tracks[clip] = rows
	var result := Transform3D.IDENTITY
	for index in _chain.size():
		var rest := get_skeleton().get_bone_rest(_chain[index])
		var row: Array = _tracks[clip][index]
		var position := animation.position_track_interpolate(row[0], time) if row[0] >= 0 else rest.origin
		var rotation := animation.rotation_track_interpolate(row[1], time) if row[1] >= 0 else rest.basis.get_rotation_quaternion()
		var scale := animation.scale_track_interpolate(row[2], time) if row[2] >= 0 else rest.basis.get_scale()
		result *= Transform3D(Basis(rotation).scaled(scale), position)
	return result

func _process_modification() -> void:
	_initialize_bones()
	if _weapon < 0 or player == null or player.assigned_animation.is_empty(): return
	var skeleton := get_skeleton()
	if _duration > 0.0 and player.assigned_animation == _clip:
		var time := player.current_animation_position
		var step := time - _last_time
		if step < 0.0 and player.get_animation(_clip).loop_mode != Animation.LOOP_NONE:
			step += player.get_animation(_clip).length
		_last_time = time
		var speed := absf(player.get_playing_speed())
		if speed > 0.0001: _elapsed += maxf(step, 0.0) / speed
		var target := sample_weapon(_clip, time)
		_last_pose = target if _initial_clip else _from.interpolate_with(target, clampf(_elapsed / _duration, 0.0, 1.0))
		if _outside_turn and not _initial_clip:
			var from_rotation := _from.basis.get_rotation_quaternion()
			var target_rotation := target.basis.get_rotation_quaternion()
			var delta := from_rotation.inverse() * target_rotation
			# 出地形沿入地形参考弧反向返回，不能沿同一方向继续绕过躯干。
			var axis := -_outside_axis if _outside_reverse else _outside_axis
			if Vector3(delta.x, delta.y, delta.z).dot(axis) < 0.0: target_rotation = -target_rotation
			var weight := clampf(_elapsed / _duration, 0.0, 1.0)
			var rotation := from_rotation.slerpni(target_rotation, weight)
			_last_pose.basis = Basis(rotation).scaled(_from.basis.get_scale().lerp(target.basis.get_scale(), weight))
		skeleton.set_bone_global_pose(_weapon, _last_pose)
		if _elapsed >= _duration: _duration = 0.0
	else:
		_last_pose = skeleton.get_bone_global_pose(_weapon)
	_has_pose = true

func reset_pool_visual() -> void:
	_has_pose = false
	_initial_clip = false
	_duration = 0.0
	_elapsed = 0.0
	_clip = &""
	_outside_turn = false
	_outside_reverse = false
