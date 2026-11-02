extends Node3D
## 特效挂在真实模型骨架上，随临时体型增长一次。
func create_buff_anchor() -> Node3D:
	for skeleton in find_children("*", "Skeleton3D", true, false):
		var index: int = skeleton.find_bone("C_Buffbone_Glb_Center_Loc")
		if index >= 0:
			var anchor := BoneAttachment3D.new()
			anchor.name = "PlantBuffAnchor"
			anchor.bone_idx = index
			skeleton.add_child(anchor)
			return anchor
	return null
