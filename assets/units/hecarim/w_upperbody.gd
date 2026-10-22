extends SkeletonModifier3D
## 原版 Spell2_Upperbody 骨骼遮罩。仅采样表现时钟，不驱动战斗。
const RELEASE_TIME := 0.44
var model: Node3D
var clip: Animation
var tracks: Array[Vector2i] = []
var _last_age := INF
var _interrupted := false

func reset_visual() -> void:
	_last_age = INF
	_interrupted = false

func configure(owner_model: Node3D, player: AnimationPlayer) -> void:
	model = owner_model
	clip = player.get_animation("Hecarim_Spell2_anm")
	var mask: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/hecarim/w_upperbody_mask.json")).bones
	var skeleton := get_skeleton()
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone_name := String(path.get_subname(0))
		if bone_name not in mask: continue
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0: tracks.append(Vector2i(track, bone))

func _process_modification() -> void:
	if not is_instance_valid(model) or model._dead: return
	var unit = model._unit.get_ref() if model._unit != null else null
	if not is_instance_valid(unit) or unit.hp <= 0.0: return
	var clock: Vector2 = unit.active_buff_clock_visual()
	var windup: bool = unit.get_visual_action_name() == &"active:cast" and unit.get_visual_action_time_left() > 0.0
	if windup:
		clock = Vector2(maxf(unit.get_visual_action_duration() - unit.get_visual_action_time_left(), 0.0), RELEASE_TIME)
	else:
		clock.x += RELEASE_TIME
	if clock.x < _last_age: _interrupted = false
	_last_age = clock.x
	if (not windup and not unit.get_active_buff_active_visual()) or clock.y <= 0.0 or clock.x >= clip.length: return
	if not windup and (unit.get_visual_state_code() == 3 or (unit.get_visual_action_name() in [&"charge_strike", &"charge_followthrough"] and unit.get_visual_action_time_left() > 0.0)):
		_interrupted = true
	if _interrupted or unit.is_frozen(): return
	var skeleton := get_skeleton()
	var weight := minf(clampf(clock.x / 0.08, 0.0, 1.0), clampf((clip.length - clock.x) / 0.12, 0.0, 1.0))
	for pair in tracks:
		match clip.track_get_type(pair.x):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(pair.y, skeleton.get_bone_pose_position(pair.y).lerp(clip.position_track_interpolate(pair.x, clock.x), weight))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(pair.y, skeleton.get_bone_pose_rotation(pair.y).slerp(clip.rotation_track_interpolate(pair.x, clock.x), weight))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(pair.y, skeleton.get_bone_pose_scale(pair.y).lerp(clip.scale_track_interpolate(pair.x, clock.x), weight))
