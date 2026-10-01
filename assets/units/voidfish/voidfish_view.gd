extends Node3D
## 原生近战形态隐藏 Ranged 表面；不修改共享模型资源。
var prepared := false
func _ready() -> void:
	prepare_visual_animations()

func prepare_visual_animations() -> void:
	if prepared: return
	prepared = true
	for instance in find_children("*", "MeshInstance3D", true, false):
		var original: ArrayMesh = instance.mesh
		var filtered := ArrayMesh.new()
		for surface in original.get_surface_count():
			var material := original.surface_get_material(surface)
			if material != null and material.resource_name == "Ranged": continue
			filtered.add_surface_from_arrays(original.surface_get_primitive_type(surface), original.surface_get_arrays(surface))
			filtered.surface_set_material(filtered.get_surface_count() - 1, material)
		instance.mesh = filtered
