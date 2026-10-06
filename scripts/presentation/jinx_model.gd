extends Node3D
## 双形态步态混合、Respawn挂点及模型复用；只读表现，不改变权威动作。
const LOWER_BODY_MASK := ["Root", "Pelvis", "L_Hip", "L_KneeUpper", "L_KneeLower", "L_Foot", "L_Toe", "L_Buffbone_Glb_Foot_Loc", "R_Hip", "R_KneeUpper", "R_KneeLower", "R_Foot", "R_Toe", "R_Buffbone_Glb_Foot_Loc"]
var _form := -1
var _previous_form := -1
var _phase_owned := false
var _run_from: Animation
var _idle_from: Animation
var _source: Unit
var _swap_elapsed := 0.0
var _swap_serial := -1
var _swap_observed_left := -1.0
var _leg_phase := 0.0
var _leg_blend := 0.0
var _leg_tracks: Array[Vector2i] = []
var _run_clip: Animation
var _idle_clip: Animation
var _player: AnimationPlayer
var _skeleton: Skeleton3D

func configure_unit_visual(unit: Unit) -> void:
	_source = unit
	process_priority = 100 # 在基础播放器后同步步态。
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	_leg_tracks.clear()
	if _player == null or _skeleton == null: return
	_run_clip = _player.get_animation("Jinx_Rlauncher_run_anm" if _form == 0 else "Run_Base")
	_idle_clip = _player.get_animation("Jinx_Rlauncher_idle1_anm" if _form == 0 else "Idle1_Base")
	_run_from = _player.get_animation("Jinx_Rlauncher_run_anm" if _previous_form == 0 else "Run_Base")
	_idle_from = _player.get_animation("Jinx_Rlauncher_idle1_anm" if _previous_form == 0 else "Idle1_Base")
	for track in _run_clip.get_track_count():
		var path := _run_clip.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var index := _skeleton.find_bone(String(path.get_subname(0)))
		if index >= 0 and String(path.get_subname(0)) in LOWER_BODY_MASK:
			_leg_tracks.append(Vector2i(track, index))

func _process(delta: float) -> void:
	if not is_instance_valid(_source) or _source.hp <= 0.0 or _player == null: return
	# Respawn原图第25帧的JointSnap；位置仅限骨骼表现。
	if _player.current_animation == "Respawn" and _player.current_animation_position >= 25.0 / 30.0:
		var launcher := _skeleton.find_bone("Rocket_Launcher")
		var world := _skeleton.find_bone("Rocket_Launcher_World")
		if launcher >= 0 and world >= 0: _skeleton.set_bone_global_pose(launcher, _skeleton.get_bone_global_pose(world))
	var serial := _source.get_visual_action_serial()
	var left := _source.get_visual_action_time_left()
	var duration := _source.get_visual_action_duration()
	if _source.is_frozen() or CombatInteraction.in_stasis(_source): return
	var switching := _source.get_visual_action_name() == &"transform" and serial > _source.cancelled_visual_serial and left > 0.0
	if switching:
		if serial != _swap_serial or not is_equal_approx(left, _swap_observed_left):
			_swap_serial = serial
			_swap_observed_left = left
			_swap_elapsed = maxf(0.0, duration - left)
		else:
			_swap_elapsed = minf(_swap_elapsed + delta, minf(duration, duration - left + Unit.SIM_DT))
	var progress := clampf(_swap_elapsed / maxf(duration, 0.001), 0.0, 1.0) if switching else 1.0
	_update_lower_body(delta, switching, progress)

func set_visual_form(form: int) -> void:
	if form != _form:
		_previous_form = _form if _form >= 0 else form
	_form = form
	var anchor := find_child("ProjectileModelAnchor", true, false) as BoneAttachment3D
	if anchor != null: anchor.bone_name = "Rocket_Launcher_Front" if _form == 0 else "Minigun_Barrel1"
func can_reuse_visual(scene: String) -> bool:
	return scene == "res://assets/units/jinx/jinx_view.tscn"
func create_projectile_anchor() -> Node3D:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null: return null
	var bone := "Rocket_Launcher_Front" if _form == 0 else "Minigun_Barrel1"
	if skeleton.find_bone(bone) < 0: return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "ProjectileModelAnchor"
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment

## 两形态共用步态时钟；切枪渐变跑姿，持续移动结束切枪不重新起跑。
func _update_lower_body(delta: float, switching: bool, progress: float) -> void:
	if _run_clip == null: return
	var moving := _source.get_locomotion_visual_state_code() == 2 and (_source.get_action_permissions_visual() & ControlState.MOVE) != 0
	var current := String(_player.current_animation)
	var running := current in ["Run_Base", "Jinx_Rlauncher_run_anm"]
	if switching and moving: _phase_owned = true
	if not moving: _phase_owned = false
	if _phase_owned:
		_leg_phase = fposmod(_leg_phase + delta * _source.get_effective_movement_rate_visual() / _run_clip.length, 1.0)
		# 基础播放器回到Run时同步整个身体，不把腿交回第0帧。
		if running and not switching: _player.seek(_leg_phase * _run_clip.length, true)
	elif moving and running:
		_leg_phase = fposmod(_player.current_animation_position / _run_clip.length, 1.0)
	if not switching and not (_phase_owned and running):
		_leg_blend = 0.0
		return
	_leg_blend = smoothstep(0.0, 1.0, progress)
	var clip := _run_clip if moving else _idle_clip
	var old_clip := _run_from if moving else _idle_from
	var sample := _leg_phase * clip.length if moving else 0.0
	var old_sample := _leg_phase * old_clip.length if moving else 0.0
	for pair in _leg_tracks:
		var path := _run_clip.track_get_path(pair.x)
		var kind := _run_clip.track_get_type(pair.x)
		var track := clip.find_track(path, kind)
		var old_track := old_clip.find_track(path, kind)
		if track < 0 or old_track < 0: continue
		match kind:
			Animation.TYPE_POSITION_3D: _skeleton.set_bone_pose_position(pair.y, old_clip.position_track_interpolate(old_track, old_sample).lerp(clip.position_track_interpolate(track, sample), _leg_blend))
			Animation.TYPE_ROTATION_3D: _skeleton.set_bone_pose_rotation(pair.y, old_clip.rotation_track_interpolate(old_track, old_sample).slerp(clip.rotation_track_interpolate(track, sample), _leg_blend))
			Animation.TYPE_SCALE_3D: _skeleton.set_bone_pose_scale(pair.y, old_clip.scale_track_interpolate(old_track, old_sample).lerp(clip.scale_track_interpolate(track, sample), _leg_blend))
