extends Node3D
## Skin0 默认隐藏钓鱼道具；保持源骨骼、动画及其余网格。
var _prepared := false
func prepare_visual_animations() -> void:
	if _prepared: return
	_prepared = true
	for node in find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		instance.mesh = instance.mesh.duplicate() as ArrayMesh
		for index in range(instance.mesh.get_surface_count() - 1, -1, -1):
			var material := instance.mesh.surface_get_material(index)
			if material != null and material.resource_name in ["Bluefish", "Goldfish"]:
				(instance.mesh as ArrayMesh).surface_remove(index)
func _ready() -> void:
	prepare_visual_animations()
