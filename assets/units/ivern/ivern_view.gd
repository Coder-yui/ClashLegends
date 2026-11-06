extends Node3D
## 原版默认隐藏草墙、松鼠和苹果；只保留基础身体材质。
func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var original: Mesh = node.mesh
		if original == null: continue
		var mesh := ArrayMesh.new()
		for surface in original.get_surface_count():
			var material := original.surface_get_material(surface)
			if material == null or material.resource_name != "Ivern_Base_Mat": continue
			mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface), original.surface_get_arrays(surface))
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		node.mesh = mesh

func create_projectile_anchor() -> Node3D:
	for skeleton in find_children("*", "Skeleton3D", true, false):
		var index: int = skeleton.find_bone("C_Buffbone_Glb_Head_Loc")
		if index < 0: continue
		var anchor := BoneAttachment3D.new()
		anchor.bone_idx = index
		skeleton.add_child(anchor)
		return anchor
	return null
