extends ActiveBuffVisual3D
## 自制黄色后向流线，只消费高原血统的表现状态。
const FLOW_SHADER := preload("res://assets/effects/masteryi/highlander.gdshader")
const STRANDS := 5
const SEGMENTS := 20
var _lines: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _phase := 0.0

func configure(_visual_radius: float, _team: int = 0) -> void:
	_material = ShaderMaterial.new()
	_material.shader = FLOW_SHADER
	for index in STRANDS:
		var line := MeshInstance3D.new()
		line.name = "HighlanderFlow" + str(index)
		line.material_override = _material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		_lines.append(line)
	visible = false

func advance(enabled: bool, delta: float) -> void:
	if enabled and not active: _phase = 0.0
	active = enabled
	visible = enabled
	if not enabled: return
	_phase += delta
	_material.set_shader_parameter("phase", _phase)
	var camera := get_viewport().get_camera_3d()
	var across_direction := Vector3.RIGHT
	if camera != null:
		var view_direction := global_basis.inverse() * camera.global_basis.z
		across_direction = Vector3.FORWARD.cross(view_direction).normalized()
	for index in _lines.size():
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		var side := float(index - 2)
		var length := 2.0 + float(index % 3) * 0.24
		for step in SEGMENTS + 1:
			var t := float(step) / SEGMENTS
			# +Z 为模型前方；各条固定横向位置与高度，平行沿 -Z 笔直延伸。
			var center := Vector3(side * 0.16, 1.15 + float(index % 2) * 0.32, -0.18 - t * length)
			var width := (0.085 + float(index % 2) * 0.015) * (1.0 - t * 0.8)
			# 光带横截面朝向当前镜头，避免正反方视角下退化成点。
			var across := across_direction * width
			vertices.append(center - across)
			vertices.append(center + across)
			uvs.append(Vector2(t, 0.0))
			uvs.append(Vector2(t, 1.0))
			if step > 0:
				var at := step * 2
				indices.append_array(PackedInt32Array([at-2, at-1, at, at-1, at+1, at]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_lines[index].mesh = mesh
