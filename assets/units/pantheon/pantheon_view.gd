extends Node3D
## 按基础皮肤的初始隐藏列表过滤回城/表情部件；不改变权威身体。
var _prepared := false
func prepare_visual_animations() -> void:
	if _prepared: return
	var mesh := find_child("Meshes", true, false) as MeshInstance3D
	if mesh == null: return
	var original := mesh.mesh as ArrayMesh
	var filtered := ArrayMesh.new()
	for index in original.get_surface_count():
		var material := original.surface_get_material(index)
		if material != null and String(material.resource_name).to_lower() in ["head", "comet", "recall", "joke"]: continue
		filtered.add_surface_from_arrays(original.surface_get_primitive_type(index), original.surface_get_arrays(index))
		filtered.surface_set_material(filtered.get_surface_count() - 1, material)
	mesh.mesh = filtered
	_prepared = true
func _ready() -> void:
	prepare_visual_animations()
func reset_pool_visual() -> void:
	prepare_visual_animations()
