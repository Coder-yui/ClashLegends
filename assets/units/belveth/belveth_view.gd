extends Node3D
## 永久使用原生大招外观；网格与纹理只影响表现。
const ULTIMATE_TEXTURE = preload("res://assets/units/belveth/source/ultimate_body.png")
var prepared := false

func _ready() -> void:
	prepare_visual_animations()

func prepare_visual_animations() -> void:
	if prepared: return
	prepared = true
	_prepare_ultimate_mesh()

func _prepare_ultimate_mesh() -> void:
	# skin0 GearSkinUpgrade: 隐藏 HEAD，Body 替换为原生 ultimate 纹理。
	for instance in find_children("*", "MeshInstance3D", true, false):
		var original := instance.mesh as ArrayMesh
		if original == null: continue
		var filtered := ArrayMesh.new()
		for surface in original.get_surface_count():
			var material := original.surface_get_material(surface) as StandardMaterial3D
			if material != null and material.resource_name.to_lower() == "head": continue
			filtered.add_surface_from_arrays(original.surface_get_primitive_type(surface), original.surface_get_arrays(surface))
			if material != null:
				material = material.duplicate() as StandardMaterial3D
				if material.resource_name.to_lower() == "body": material.albedo_texture = ULTIMATE_TEXTURE
			filtered.surface_set_material(filtered.get_surface_count() - 1, material)
		instance.mesh = filtered
