extends RefCounted
## 模型胸部优先；无合适骨骼时使用可见网格中心。仅供弹体表现。
static func create(model: Node3D) -> Node3D:
	var existing := model.find_child("ProjectileModelAnchor", true, false) as Node3D
	if existing != null: return existing
	if model.has_method("create_projectile_anchor"):
		var custom := model.call("create_projectile_anchor") as Node3D
		if custom != null: return custom
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

## 命中挂目标身体，不能复用自定义出弹口；优先原版胸部挂点，缺省用通用躯干骨。
static func body_position(body: Node2D) -> Variant:
	if not body.has_meta("projectile_model_anchor"): return null
	var reference = body.get_meta("projectile_model_anchor")
	if not reference is WeakRef: return null
	var anchor = reference.get_ref()
	if not is_instance_valid(anchor): return null
	if anchor is BoneAttachment3D:
		var skeleton := anchor.get_parent() as Skeleton3D
		if skeleton != null:
			for preferred in ["cbuffboneglbchestloc", "buffboneglbchestloc", "spine2", "chest", "spine1", "spine"]:
				for index in skeleton.get_bone_count():
					if String(skeleton.get_bone_name(index)).to_lower().replace("_", "") == preferred:
						return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
	return anchor.global_position
