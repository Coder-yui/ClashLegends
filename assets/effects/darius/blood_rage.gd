extends ActiveBuffVisual3D
## 红色轮廓附着模型，环绕的上升火星始终随身体移动；只消费状态。
var _elapsed := 0.0
var _fade := 0.0
var _sparks: Array[MeshInstance3D] = []
var _radius := 0.5

func configure(visual_radius: float, _team: int = 0) -> void:
	_radius = visual_radius / 40.0
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = preload("res://assets/effects/darius/blood_rage.gdshader")
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.06, 0.025, 0.8)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.03, 0.01)
	for index in 14:
		var spark := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.025
		mesh.height = 0.16
		mesh.radial_segments = 6
		mesh.rings = 3
		spark.mesh = mesh
		spark.material_override = material
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		_sparks.append(spark)
	visible = false

func advance(enabled: bool, delta: float) -> void:
	active = enabled
	_elapsed += delta
	_fade = move_toward(_fade, 1.0 if active else 0.0, delta * 8.0)
	for material in overlay_instances:
		material.set_shader_parameter("strength", _fade)
		material.set_shader_parameter("elapsed", _elapsed)
	for index in _sparks.size():
		var phase := fposmod(_elapsed * 0.8 + index / 14.0, 1.0)
		var angle := index * 2.4 + _elapsed * 1.5
		_sparks[index].position = Vector3(cos(angle) * _radius, 0.1 + phase * 1.7, sin(angle) * _radius)
		_sparks[index].scale = Vector3.ONE * _fade * sin(phase * PI)
	visible = _fade > 0.0
