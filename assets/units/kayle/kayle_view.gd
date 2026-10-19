extends Node3D
## Skin0 初始隐藏列表 / Evolve3 / IdlePassive 的部件选择，仅负责表现。
@export var ranged := false
var _mesh: MeshInstance3D
var _full_mesh: ArrayMesh
var _enrage_materials: Array[ShaderMaterial] = []
var _enrage_strength := 0.0
var _enrage_elapsed := 0.0

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
		if material != null and String(_full_mesh.surface_get_material(index).resource_name).begins_with("wings_"):
			var original := _full_mesh.surface_get_material(index) as BaseMaterial3D
			if original != null:
				var fire: ShaderMaterial
				if ranged:
					fire = material as ShaderMaterial
				else:
					material = material.duplicate()
					fire = ShaderMaterial.new()
					fire.shader = preload("res://assets/units/kayle/enrage_wings.gdshader")
					material.next_pass = fire
				fire.set_shader_parameter("base_texture", original.albedo_texture)
				fire.set_shader_parameter("rage_gradient", preload("res://assets/units/kayle/source/enrage_rage_gradient.png"))
				fire.set_shader_parameter("fire_tile", preload("res://assets/units/kayle/source/enrage_fire_tile.png"))
				_enrage_materials.append(fire)
		filtered.surface_set_material(filtered.get_surface_count() - 1, material)
	_mesh.mesh = filtered

func _ready() -> void:
	prepare_visual_animations()

## 模型代理仅传入已同步的满层状态；材质不读取或推进战斗状态。
func advance_hit_haste_visual(full: bool, delta: float) -> void:
	_enrage_elapsed += delta
	_enrage_strength = move_toward(_enrage_strength, 1.0 if full else 0.0, delta * 2.0)
	for material in _enrage_materials:
		material.set_shader_parameter("strength", _enrage_strength)
		material.set_shader_parameter("elapsed", _enrage_elapsed)

func reset_pool_visual() -> void:
	_enrage_strength = 0.0
	_enrage_elapsed = 0.0
	for material in _enrage_materials:
		material.set_shader_parameter("strength", 0.0)
		material.set_shader_parameter("elapsed", 0.0)
