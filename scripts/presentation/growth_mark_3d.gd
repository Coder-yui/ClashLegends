class_name GrowthMark3D
extends MeshInstance3D
## 水平花叶纹样与人物共享3D深度；只读成长状态，不能覆盖人物身体。
static var _shared_mesh: ArrayMesh

func _init() -> void:
	if _shared_mesh == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 5:
			var angle := TAU * float(i) / 5.0
			_add_petal(surface, angle, 0.51, 0.45, 0.23, Color(0.83, 0.65, 1.0, 0.44))
			_add_petal(surface, angle + 0.5, 0.86, 0.18, 0.085, Color(0.71, 0.92, 0.51, 0.48))
		_add_petal(surface, 0.0, 0.0, 0.13, 0.13, Color(0.94, 0.86, 0.65, 0.38))
		_shared_mesh = surface.commit()
	mesh = _shared_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material.render_priority = -10
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _add_petal(surface: SurfaceTool, angle: float, offset: float, length: float, width: float, color: Color) -> void:
	var center := Vector2(offset, 0.0).rotated(angle)
	for i in 32:
		var a := TAU * float(i) / 32.0
		var b := TAU * float(i + 1) / 32.0
		var left := Vector2(offset + cos(a) * length, sin(a) * width).rotated(angle)
		var right := Vector2(offset + cos(b) * length, sin(b) * width).rotated(angle)
		for point in [center, left, right]:
			surface.set_color(color)
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(point.x, 0.0, point.y))
