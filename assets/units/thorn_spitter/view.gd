extends Node3D
## 原植物的Buffbones独立轨：仅恢复辅助挂点，不覆盖Vine/Bloom动作。
const SOURCE_SKIN_SCALE := 1.2
func _ready() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons := find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty(): skeleton = skeletons[0]
	var players := find_children("*", "AnimationPlayer", true, false)
	if skeleton == null or players.is_empty(): return
	var animation: Animation = players[0].get_animation("Buffbones")
	if animation == null: return
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone := String(path.get_subname(0))
		if not "buffbone" in bone.to_lower(): continue
		var index := skeleton.find_bone(bone)
		if index < 0 or animation.track_get_key_count(track) == 0: continue
		var value = animation.track_get_key_value(track, 0)
		match animation.track_get_type(track):
			Animation.TYPE_POSITION_3D: skeleton.set_bone_pose_position(index, value)
			Animation.TYPE_ROTATION_3D: skeleton.set_bone_pose_rotation(index, value)
			Animation.TYPE_SCALE_3D: skeleton.set_bone_pose_scale(index, value)

func make_anchor(bone: String, label: String) -> Node3D:
	for skeleton in find_children("*", "Skeleton3D", true, false):
		var index: int = skeleton.find_bone(bone)
		if index >= 0:
			var anchor := BoneAttachment3D.new()
			anchor.name = label
			anchor.bone_idx = index
			skeleton.add_child(anchor)
			return anchor
	return null

func create_projectile_anchor() -> Node3D:
	return make_anchor("Buffbone_Glb_Weapon_1", "ProjectileModelAnchor")

func create_buff_anchor() -> Node3D:
	return make_anchor("C_Buffbone_Glb_Center_Loc", "PlantBuffAnchor")

func native_effect_scale() -> float:
	# GLB包装为模型原坐标缩放；皮肤本身1.2不应重复乘给独立VFX。
	return $Model.global_basis.get_scale().abs().x / SOURCE_SKIN_SCALE
