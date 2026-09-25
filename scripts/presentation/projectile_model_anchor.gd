extends RefCounted
## 模型胸部优先；无合适骨骼时使用可见网格中心。仅供弹体表现。
static func create(model: Node3D) -> Node3D:
	var existing := model.find_child("ProjectileModelAnchor", true, false) as Node3D
	if existing != null: return existing
	for skeleton in model.find_children("*", "Skeleton3D", true, false):
		for preferred in ["spine2", "chest", "spine1", "spine"]:
			for index in skeleton.get_bone_count():
				if String(skeleton.get_bone_name(index)).to_lower().replace("_", "") == preferred:
					var anchor := BoneAttachment3D.new()
					anchor.name = "ProjectileModelAnchor"
					anchor.bone_idx = index
					skeleton.add_child(anchor)
					return anchor
	var anchor := Marker3D.new()
	anchor.name = "ProjectileModelAnchor"
	var bounds := AABB()
	var found := false
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree(): continue
		var local_bounds: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if found else local_bounds
		found = true
	model.add_child(anchor)
	anchor.position = bounds.get_center()
	return anchor
