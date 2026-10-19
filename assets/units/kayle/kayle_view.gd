extends "res://scripts/presentation/model_template_view.gd"
## Skin0 初始隐藏列表 / Evolve3 / IdlePassive 的部件选择，仅负责表现。
@export var ranged := false
var _mesh: MeshInstance3D
var _enrage_materials: Array[ShaderMaterial] = []
var _enrage_strength := 0.0
var _enrage_elapsed := 0.0

func _initialize_template_geometry() -> bool:
	_mesh = find_child("Meshes", true, false) as MeshInstance3D
	var selected: ArrayMesh = visual_template.meshes.get("ranged" if ranged else "normal")
	if _mesh == null or selected == null:
		preparation_errors.append("Kayle requires selected template mesh")
		return false
	_mesh.mesh = selected
	for index in selected.get_surface_count():
		var material := selected.surface_get_material(index)
		if ranged and material is BaseMaterial3D and String(material.resource_name).begins_with("wings_"):
			var gold := ShaderMaterial.new()
			gold.shader = preload("res://assets/units/kayle/exalted_wings.gdshader")
			gold.set_shader_parameter("base_texture", material.albedo_texture)
			gold.set_shader_parameter("level16_gradient", preload("res://assets/units/kayle/source/wing_16_gradient.png"))
			material = gold
		if material != null and String(selected.surface_get_material(index).resource_name).begins_with("wings_"):
			var original := selected.surface_get_material(index) as BaseMaterial3D
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
		if material != selected.surface_get_material(index): _mesh.set_surface_override_material(index, material)
	return true

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
