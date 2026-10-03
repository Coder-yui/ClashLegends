extends ActiveBuffVisual3D
## 原版余震纹理的 Godot 随身表现；状态与时钟由模型代理提供。
var _age := 0.0
var _ring: MeshInstance3D

func configure(radius: float, _team: int = 0) -> void:
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = preload("res://assets/effects/aftershock/body.gdshader")
	overlay_material.set_shader_parameter("source_texture", preload("res://assets/effects/aftershock/avatar_mult.png"))
	_ring = MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * radius / 40.0 * 3.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = preload("res://assets/effects/aftershock/buff.png")
	mat.albedo_color = Color(0.8, 1.0, 0.6, 1.0)
	mesh.material = mat
	_ring.mesh = mesh
	_ring.position.y = 0.04
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	visible = false

func advance(enabled: bool, delta: float) -> void:
	active = enabled
	visible = enabled
	_age += delta
	for material in overlay_instances:
		material.set_shader_parameter("strength", 1.0 if enabled else 0.0)
		material.set_shader_parameter("elapsed", _age)
	if _ring != null:
		_ring.rotation.y = _age * 0.8
		_ring.scale = Vector3.ONE * (1.0 + 0.025 * sin(_age * 6.0))
