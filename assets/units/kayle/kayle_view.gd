extends Node3D
## Skin0 初始隐藏列表 / Evolve3 / IdlePassive 的部件选择，仅负责表现。
@export var ranged := false
var _mesh: MeshInstance3D
var _full_mesh: ArrayMesh

func prepare_visual_animations() -> void:
	if _full_mesh != null: return
	_mesh = find_child("Meshes", true, false) as MeshInstance3D
	if _mesh == null: return
	_full_mesh = _mesh.mesh as ArrayMesh
	var hidden := ["level1", "sword_hilt_combined", "sword_blade_combined"] if ranged else ["level11", "wings_mid", "wings_bot", "sword_hilt", "sword_blade"]
	var filtered := ArrayMesh.new()
	for index in _full_mesh.get_surface_count():
		var material := _full_mesh.surface_get_material(index)
		if material != null and String(material.resource_name).to_lower() in hidden: continue
		filtered.add_surface_from_arrays(_full_mesh.surface_get_primitive_type(index), _full_mesh.surface_get_arrays(index))
		if ranged and material is BaseMaterial3D and String(material.resource_name) == "Kayle_Base_Body_Mat":
			material = material.duplicate()
			material.albedo_texture = preload("res://assets/units/kayle/source/exalted_body.png")
		if ranged and material is BaseMaterial3D and String(material.resource_name).begins_with("wings_"):
			var gold := ShaderMaterial.new()
			gold.shader = preload("res://assets/units/kayle/exalted_wings.gdshader")
			gold.set_shader_parameter("base_texture", material.albedo_texture)
			gold.set_shader_parameter("level16_gradient", preload("res://assets/units/kayle/source/wing_16_gradient.png"))
			material = gold
		filtered.surface_set_material(filtered.get_surface_count() - 1, material)
	_mesh.mesh = filtered

func _ready() -> void:
	prepare_visual_animations()

func reset_pool_visual() -> void:
	pass
