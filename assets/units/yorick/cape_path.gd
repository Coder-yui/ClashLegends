extends SkeletonModifier3D
## Skin0：三条 CapeUpper_[MLR]2_Ground→5_Ground，最大转角120度。
## 自身路径拖曳、转向滞后与身体投影避让；不查询世界物理或其他单位。
## FullAnim CAPE 事件在非跑步片段出现；解释为混回作者姿态，事件方向为适配推断。
const MAX_ANGLE := deg_to_rad(120.0)
const EVENT_BLEND_IN := {&"Attack1": 0.5, &"Attack2": 0.5, &"Attack3": 0.75,
	&"IdleIn": 1.0, &"Spell1": 0.5, &"Death": 0.5, &"Idle1": 0.45}
var player: AnimationPlayer
var _bones: Array[int] = []
var _history: Array[Vector3] = []
var _bone_weights: Array[float] = []
var _weight := 0.0
var _target_weight := 0.0
var _blend_duration := 0.25
var _clip := &""
var _last_clip_time := 0.0
var _tail_direction := Vector3.BACK
var _last_frame := -1
var _initialized := false
var max_applied_angle := 0.0
var _headings: Array[float] = []
var _angles: Array[float] = []
var _last_origin := Vector3.ZERO
var _last_heading := 0.0
var _motion_weight := 0.0
var _idle_turn_weight := 0.0
var _pelvis := -1
var _chest := -1
var self_avoidance_count := 0
# 模型空间身体投影胶囊：躯干/髋部半径与披风厚度，不含武器、外部单位或地形。
const BODY_RADIUS := 0.38


func begin_blend(clip: StringName, duration: float) -> void:
	_clip = clip
	_last_clip_time = 0.0
	_target_weight = 1.0 if clip in [&"Run_Base", &"Spell2_Run", &"Spell1_Cast_Run"] else 0.0
	# 原动画进入作者姿态0.5/0.75/1秒；Attack1/2/3退出事件0.25秒。
	_blend_duration = maxf(float(EVENT_BLEND_IN.get(clip, 0.25)) if _target_weight == 0.0 else 0.25, duration)
	if not _initialized: _weight = _target_weight

func _initialize_bones() -> void:
	if not _bones.is_empty(): return
	var skeleton := get_skeleton()
	_pelvis = skeleton.find_bone("Pelvis")
	_chest = skeleton.find_bone("Spine3")
	# 源101项遮罩0x125c4354与原GLB skin joints次序核对；FullAnim为全零。
	for side in ["M", "L", "R"]:
		var names := ["CapeUpper_%s2_Ground", "CapeUpper_%sB_2_3_Ground", "CapeUpper_%s3_Ground",
			"CapeUpper_%sB_3_4_Ground", "CapeUpper_%s4_Ground", "CapeUpper_%s5_Ground"]
		var weights := [0.5, 0.6 if side == "R" else 0.7, 0.8, 0.9, 1.0, 1.0]
		for index in names.size():
			var bone := skeleton.find_bone(names[index] % side)
			if bone >= 0:
				_bones.append(bone)
				_bone_weights.append(weights[index])

func _seed_path(origin: Vector3, backward: Vector3, scale_factor: float) -> void:
	_history.clear()
	_tail_direction = backward
	# 缺失历史用初始朝向补齐，不从世界原点或上一实例拖出披风。
	for index in range(81): _history.append(origin + backward * float(index) * 0.05 * scale_factor)
	_headings.clear()
	_angles.clear()
	var heading := atan2(backward.x, backward.z)
	for bone in _bones:
		_headings.append(heading)
		_angles.append(0.0)
	_last_origin = origin
	_last_heading = heading
	_motion_weight = 0.0
	_idle_turn_weight = 0.0
	_initialized = true

func _sample_path(distance: float) -> Vector3:
	var remaining := maxf(distance, 0.0)
	for index in range(_history.size() - 1):
		var segment := _history[index].distance_to(_history[index + 1])
		if segment >= remaining and segment > 0.000001:
			return _history[index].lerp(_history[index + 1], remaining / segment)
		remaining -= segment
	return _history.back() + _tail_direction * remaining

func _process_modification() -> void:
	# stop() 保留 assigned_animation，预热回收还会移除动画库；pause() 则仍有有效姿态。
	if not is_instance_valid(player) or not player.is_animation_active() or not player.has_animation(player.assigned_animation): return
	_initialize_bones()
	var skeleton := get_skeleton()
	var transform := skeleton.global_transform
	var scale_factor := maxf(transform.basis.get_scale().x, 0.001)
	var backward := -transform.basis.z.normalized()
	backward.y = 0.0
	backward = backward.normalized()
	var origin := transform.origin
	origin.y = 0.0
	if not _initialized or origin.distance_to(_history[0]) > 4.0 * scale_factor:
		_seed_path(origin, backward, scale_factor)
	if player.assigned_animation != _clip: begin_blend(player.assigned_animation, 0.14)
	var delta := 0.0
	var heading := atan2(backward.x, backward.z)
	var frame := Engine.get_process_frames()
	if frame != _last_frame:
		_last_frame = frame
		var time := player.current_animation_position
		var elapsed := time - _last_clip_time
		if elapsed < 0.0 and player.get_animation(_clip).loop_mode != Animation.LOOP_NONE:
			elapsed += player.get_animation(_clip).length
		_last_clip_time = time
		var speed := absf(player.get_playing_speed())
		if speed > 0.0001: delta = minf(maxf(elapsed, 0.0) / speed, 0.05)
		if delta > 0.0:
			var moving := clampf(origin.distance_to(_last_origin) / (delta * scale_factor * 0.5), 0.0, 1.0)
			_motion_weight = lerpf(_motion_weight, moving, 1.0 - exp(-delta / 0.22))
			var turning := clampf(absf(angle_difference(_last_heading, heading)) / delta / 2.0, 0.0, 1.0)
			_idle_turn_weight = maxf(turning, _idle_turn_weight * exp(-delta / 0.3))
		_last_origin = origin
		_last_heading = heading
		# 动画停住时混合也停住，原片事件秒数随该片播放倍率映射。
		_weight = move_toward(_weight, _target_weight, maxf(elapsed, 0.0) / maxf(_blend_duration, 0.001))
		if origin.distance_to(_history[0]) >= 0.025 * scale_factor:
			_history.push_front(origin)
			if _history.size() > 192:
				_tail_direction = (_history[-1] - _history[-2]).normalized()
				_history.pop_back()
	# 临时放入本帧位置，让低速移动不以采样距离为步长跳动。
	_history.push_front(origin)
	var poses: Array[Transform3D] = []
	for bone in _bones: poses.append(skeleton.get_bone_global_pose(bone))
	max_applied_angle = 0.0
	self_avoidance_count = 0
	if _pelvis < 0 or _chest < 0:
		_history.pop_front()
		return
	var body_a := skeleton.get_bone_global_pose(_pelvis).origin
	var body_b := skeleton.get_bone_global_pose(_chest).origin
	for index in _bones.size():
		var bone := _bones[index]
		var authored := poses[index]
		var distance := maxf(-authored.origin.z, 0.0) * scale_factor
		var tangent := _sample_path(distance + 0.05 * scale_factor) - _sample_path(distance)
		if tangent.length_squared() < 0.00000001: continue
		var path_heading := atan2(tangent.x, tangent.z)
		var target_heading := heading + angle_difference(heading, path_heading) * _motion_weight
		# 世界朝向保留惯性：近身跟随快，尾端更迟；停步时目标回到角色背后。
		var response := lerpf(0.09, 0.28, _bone_weights[index])
		_headings[index] = lerp_angle(_headings[index], target_heading, 1.0 - exp(-delta / response))
		var influence := maxf(_weight, _idle_turn_weight if _clip == &"Idle1" else 0.0)
		var angle := clampf(angle_difference(heading, _headings[index]), -MAX_ANGLE, MAX_ANGLE) * influence * _bone_weights[index]
		# 限制程序偏转的变化速度，避免掉头跨过正负180度时翻边。
		_angles[index] = move_toward(_angles[index], angle, delta * 5.0)
		angle = _angles[index]
		# 位置继承父链修正；只替换全局朝向，避免每个关节重复累乘同一偏转。
		var pose := skeleton.get_bone_global_pose(bone)
		# 只约束路径修正，保留原片姿态。按下一段骨链的扫掠线段避让身体投影。
		var base_basis := authored.basis
		var local_axis := (transform.basis.inverse() * Vector3.UP).normalized()
		if index % 6 < 5:
			var next_authored := poses[index + 1]
			var offset := authored.basis.inverse() * (next_authored.origin - authored.origin)
			var safe_angle := 0.0
			# 从原姿态逐步扫向目标，阻止骨链一步跨到身体另一侧。
			for step in range(1, 17):
				var candidate := angle * float(step) / 16.0
				var endpoint := pose.origin + Basis(local_axis, candidate) * base_basis * offset
				if _body_intersects(pose.origin, endpoint, body_a, body_b):
					self_avoidance_count += 1
					var blocked_angle := candidate
					for refinement in 6:
						var middle := (safe_angle + blocked_angle) * 0.5
						var middle_end := pose.origin + Basis(local_axis, middle) * base_basis * offset
						if _body_intersects(pose.origin, middle_end, body_a, body_b): blocked_angle = middle
						else: safe_angle = middle
					break
				safe_angle = candidate
			angle = safe_angle
		_angles[index] = angle
		pose.basis = Basis(local_axis, angle) * base_basis
		max_applied_angle = maxf(max_applied_angle, absf(angle))
		skeleton.set_bone_global_pose(bone, pose)
	_history.pop_front()

func _body_intersects(start: Vector3, end: Vector3, body_a: Vector3, body_b: Vector3) -> bool:
	start.y = 0.0
	end.y = 0.0
	body_a.y = 0.0
	body_b.y = 0.0
	var closest := Geometry3D.get_closest_points_between_segments(start, end, body_a, body_b)
	return closest[0].distance_squared_to(closest[1]) < BODY_RADIUS * BODY_RADIUS

func reset_pool_visual() -> void:
	_history.clear()
	_headings.clear()
	_angles.clear()
	_motion_weight = 0.0
	_idle_turn_weight = 0.0
	self_avoidance_count = 0
	_initialized = false
	_weight = 0.0
	_target_weight = 0.0
	_clip = &""
	_last_clip_time = 0.0
	_last_frame = -1
	max_applied_angle = 0.0
