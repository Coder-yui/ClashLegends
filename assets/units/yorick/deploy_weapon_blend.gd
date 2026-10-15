extends SkeletonModifier3D
## 牧魂人动作衔接：Weapon在模型空间沿最短旋转路径混合。
## 身体保留公共播放器混合；混合结束后恢复目标原片姿态。
var player: AnimationPlayer
var _weapon := -1
var _chain: Array[int] = []
var _tracks: Dictionary = {}
var _clip: StringName = &""
var _target_rotation := Quaternion.IDENTITY
var _from := Transform3D.IDENTITY
var _last_pose := Transform3D.IDENTITY
var _has_pose := false
var _blending := false
var _duration := 0.0
var _elapsed := 0.0
var _last_time := 0.0

func _initialize_bones() -> void:
	if _weapon >= 0: return
	var skeleton := get_skeleton()
	if skeleton == null: return
	_weapon = skeleton.find_bone("Weapon")
	var bone := _weapon
	while bone >= 0:
		_chain.push_front(bone)
		bone = skeleton.get_bone_parent(bone)

func begin_blend(clip: StringName, duration: float) -> void:
	_initialize_bones()
	_blending = _has_pose and is_instance_valid(player) and player.has_animation(clip) and duration > 0.0
	_clip = clip
	_from = _last_pose
	if _blending:
		_target_rotation = _sample_weapon(0.0).basis.get_rotation_quaternion()
		if _from.basis.get_rotation_quaternion().dot(_target_rotation) < 0.0:
			_target_rotation = -_target_rotation
	_duration = duration
	_elapsed = 0.0
	_last_time = 0.0

func _sample_weapon(time: float) -> Transform3D:
	var animation := player.get_animation(_clip)
	if not _tracks.has(_clip):
		_tracks[_clip] = {}
		for bone in _chain:
			var row := [-1, -1, -1]
			for track in animation.get_track_count():
				if String(animation.track_get_path(track).get_concatenated_subnames()) != get_skeleton().get_bone_name(bone): continue
				match animation.track_get_type(track):
					Animation.TYPE_POSITION_3D: row[0] = track
					Animation.TYPE_ROTATION_3D: row[1] = track
					Animation.TYPE_SCALE_3D: row[2] = track
			_tracks[_clip][bone] = row
	var pose := Transform3D.IDENTITY
	for bone in _chain:
		var rest := get_skeleton().get_bone_rest(bone)
		var row: Array = _tracks[_clip][bone]
		var position := animation.position_track_interpolate(row[0], time) if row[0] >= 0 else rest.origin
		var rotation := animation.rotation_track_interpolate(row[1], time) if row[1] >= 0 else rest.basis.get_rotation_quaternion()
		var scale := animation.scale_track_interpolate(row[2], time) if row[2] >= 0 else rest.basis.get_scale()
		pose *= Transform3D(Basis(rotation).scaled(scale), position)
	return pose

func _process_modification() -> void:
	_initialize_bones()
	if _weapon < 0 or not is_instance_valid(player): return
	var skeleton := get_skeleton()
	if _blending and player.assigned_animation == _clip:
		var time := player.current_animation_position
		var step := time - _last_time
		if step < 0.0 and player.get_animation(_clip).loop_mode != Animation.LOOP_NONE:
			step += player.get_animation(_clip).length
		_last_time = time
		var speed := absf(player.get_playing_speed())
		if speed > 0.0001: _elapsed += maxf(step, 0.0) / speed
		var target := _sample_weapon(time)
		var weight := clampf(_elapsed / _duration, 0.0, 1.0)
		_last_pose.origin = skeleton.get_bone_global_pose(_weapon).origin
		# 起始选择短弧，随后保持目标四元数同半球，避免目标经过180度时翻转插值方向。
		var rotation := target.basis.get_rotation_quaternion()
		if _target_rotation.dot(rotation) < 0.0: rotation = -rotation
		_target_rotation = rotation
		_last_pose.basis = Basis(_from.basis.get_rotation_quaternion().slerpni(_target_rotation, weight)).scaled(_from.basis.get_scale().lerp(target.basis.get_scale(), weight))
		skeleton.set_bone_global_pose(_weapon, _last_pose)
		if weight >= 1.0: _blending = false
	else:
		_blending = false
		_last_pose = skeleton.get_bone_global_pose(_weapon)
	_has_pose = true

func reset_pool_visual() -> void:
	_has_pose = false
	_blending = false
	_duration = 0.0
	_elapsed = 0.0
	_last_time = 0.0
