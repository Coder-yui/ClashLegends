extends Node3D
## 自制R表现：只读取引导端点、固定范围与表现时钟。
const ROOT := "res://assets/effects/malzahar/nether_grasp/"
var _kind := ""
var _mesh: MeshInstance3D
var _material: ShaderMaterial

static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["beam", "zone"]: return {}
	return {"paths": [ROOT + variant + ".gdshader"], "sample": {"player": ROOT + "player.gd", "kind": variant, "setup": "native", "times": [0.025, 0.1, 0.5, 1.5]}}

func load_kind(kind: String) -> void:
	_kind = kind
	_material = ShaderMaterial.new()
	_material.shader = load(ROOT + kind + ".gdshader")
	_mesh = MeshInstance3D.new()
	if kind == "zone":
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0, 2.0)
		_mesh.mesh = plane
	else:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		_mesh.mesh = quad
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

func setup_native(unit_scale: float) -> void:
	scale = Vector3.ONE * unit_scale

func seek(age: float, remaining: float = 5.0) -> void:
	_material.set_shader_parameter("elapsed", age)
	_material.set_shader_parameter("strength", smoothstep(0.0, 0.1, age) * smoothstep(0.0, 0.2, remaining))

func set_endpoints(start: Vector3, end: Vector3, camera: Camera3D) -> void:
	position = (start + end) * 0.5
	var delta := end - start
	if delta.length_squared() < 0.000001:
		visible = false
		return
	visible = true
	var along := delta.normalized()
	var across := along.cross(camera.global_position - position).normalized()
	if across.length_squared() < 0.000001: across = Vector3.RIGHT
	basis = Basis(across * 0.5, along * delta.length(), across.cross(along))
