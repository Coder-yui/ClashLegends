extends SkeletonModifier3D
## 原版低优先级Passive武器层：Hammer遮罩叠加，Blank权重退到零。
## 不写身体/腿部骨骼，不干预移动和战斗。形态时钟完全来自权威表现快照。
var model: Node3D
var hammer: Animation
var tracks: Array[Vector2i] = []
var weights: Dictionary = {}

func configure(owner_model: Node3D, player: AnimationPlayer) -> void:
	model = owner_model
	hammer = player.get_animation("Melee_Passive")
	weights = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/jayce/weapon_mask.json")).bones
	var skeleton := get_skeleton()
	for track in hammer.get_track_count():
		var path := hammer.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone_name := String(path.get_subname(0))
		if not weights.has(bone_name): continue
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0: tracks.append(Vector2i(track, bone))

func hammer_weight(unit: Unit) -> float:
	return 1.0 if unit.get_form_index() == 1 else 0.0

func _process_modification() -> void:
	if not is_instance_valid(model) or model._dead: return
	var unit = model._unit.get_ref() if model._unit != null else null
	if not is_instance_valid(unit) or unit.hp <= 0.0: return
	var skeleton := get_skeleton()
	var weight := hammer_weight(unit)
	if weight <= 0.0: return
	for pair in tracks:
		var blend := weight * float(weights[skeleton.get_bone_name(pair.y)])
		match hammer.track_get_type(pair.x):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(pair.y, skeleton.get_bone_pose_position(pair.y).lerp(hammer.position_track_interpolate(pair.x, hammer.length), blend))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(pair.y, skeleton.get_bone_pose_rotation(pair.y).slerp(hammer.rotation_track_interpolate(pair.x, hammer.length), blend))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(pair.y, skeleton.get_bone_pose_scale(pair.y).lerp(hammer.scale_track_interpolate(pair.x, hammer.length), blend))
