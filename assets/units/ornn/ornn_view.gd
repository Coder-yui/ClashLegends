extends Node3D
## Original skin0 initialSubmeshToHide: cosmetic props, absent during combat.
const HIDDEN_MATERIALS := ["Ornn_Base_Sword_Mat", "Ornn_Base_Bucket_Mat", "Ornn_Base_Poro_Mat"]
var prepared := false

func _ready() -> void:
	prepare_visual_animations()

func prepare_visual_animations() -> void:
	if prepared: return
	prepared = true
	for node in find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if not instance.mesh is ArrayMesh: continue
		var mesh := instance.mesh.duplicate() as ArrayMesh
		for index in range(mesh.get_surface_count() - 1, -1, -1):
			var material := mesh.surface_get_material(index)
			if material != null and material.resource_name in HIDDEN_MATERIALS:
				mesh.surface_remove(index)
		instance.mesh = mesh

# The imported mesh AABB includes hidden cosmetic vertices; focus on the body.
func get_preview_focus(_fallback: Vector3) -> Vector3:
	return global_transform * Vector3(0.0, 1.202, 0.156)
