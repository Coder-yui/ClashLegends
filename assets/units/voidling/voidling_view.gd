extends Node3D
## W_VoidlingSpawn_Override/Avatar1：附着到真实骨骼网格，保留原2秒颜色与侵蚀曲线。
const SHADER = preload("res://assets/effects/malzahar/spawn_override/attached.gdshader")
const TRANSITION = preload("res://assets/effects/malzahar/spawn_override/malzahar_base_voidling_spawntransition.png")
const EROSION = preload("res://assets/effects/malzahar/spawn_override/dissolve_cloudy_03.png")
var _material: ShaderMaterial
var _age := 2.0
func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("source_texture", TRANSITION)
	_material.set_shader_parameter("erosion_texture", EROSION)
	for mesh in find_children("*", "MeshInstance3D", true, false): mesh.material_overlay = _material
	set_process(false)
func configure_unit_visual(unit: Unit) -> void:
	_age = 0.0 if unit.visual_spawn_transition == &"void_portal" else 2.0
	_material.set_shader_parameter("age", _age)
	set_process(_age < 2.0)
func _process(delta: float) -> void:
	_age = minf(_age + delta, 2.0)
	_material.set_shader_parameter("age", _age)
	if _age >= 2.0: set_process(false)
func reset_pool_visual() -> void:
	_age = 2.0
	if _material != null: _material.set_shader_parameter("age", _age)
	set_process(false)
