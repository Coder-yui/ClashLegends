extends Node3D
## 弩箭骨骼挂点，仅供弹体投影；不改变权威出生点。
func create_projectile_anchor() -> Node3D:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons := find_children("*", "Skeleton3D", true, false)
		if skeletons.is_empty(): return null
		skeleton = skeletons[0]
	var bone := skeleton.find_bone("Arrow")
	if bone < 0: return null
	var anchor := BoneAttachment3D.new()
	anchor.name = "ProjectileModelAnchor"
	skeleton.add_child(anchor)
	anchor.bone_name = "Arrow"
	anchor.bone_idx = bone
	return anchor
