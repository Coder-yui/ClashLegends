extends Node3D
## 原始BIN导出的落地粒子子集。只进行表现采样，不派发游戏事件。
const DATA_PATH := "res://assets/units/pantheon/r_original/systems.json"
const ADD := preload("res://assets/units/pantheon/r_original/particle_add.gdshader")
const MIX := preload("res://assets/units/pantheon/r_original/particle_mix.gdshader")
static var _data: Dictionary = {}
static var _mesh_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
var _emitters: Array = []
var _particles: Array = []
var _trails: Array = []
var _time := 0.0
var _factor := 0.0075
var _emitting := true
var _camera: Camera3D
var _rng := RandomNumberGenerator.new()
var _last_origin := Vector3.ZERO
var _motion_frame := false
var _system := ""
const MAX_PARTICLES := 220

static func systems() -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data

func setup(system: String, factor: float = 0.0075, motion_frame: bool = false) -> void:
	_system = system
	_motion_frame = motion_frame
	_factor = factor
	_rng.seed = 81271
	_camera = get_viewport().get_camera_3d()
	for c: Dictionary in systems()[system]:
		var material := _material(c)
		if bool(c.trail):
			var node := _node(material)
			_trails.append({"c": c, "node": node, "points": []})
		else:
			_emitters.append({"c": c, "next": float(c.delay), "count": 0, "material": material})
	_last_origin = global_position

func stop_emitting() -> void:
	_emitting = false

func advance(delta: float) -> void:
	_time += maxf(delta, 0.0)
	for e: Dictionary in _emitters:
		var c: Dictionary = e.c
		var end := minf(_time, float(c.duration))
		if not _emitting: continue
		var step := 1.0 / maxf(float(sample(c.rate, _time)), 0.1)
		while float(e.next) <= end and _particles.size() < MAX_PARTICLES:
			if bool(c.single) and int(e.count) > 0: break
			_spawn(c, float(e.next), e.material)
			e.next += step
			e.count += 1
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		var age := _time - float(p.birth)
		if age >= float(p.life):
			p.node.free()
			_particles.remove_at(i)
		else: _update(p, age)
	for trail: Dictionary in _trails: _update_trail(trail)
	_last_origin = global_position

func _node(material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = material
	node.add_to_group("presentation_fx")
	add_child(node)
	node.top_level = true
	return node

func _spawn(c: Dictionary, birth: float, material: ShaderMaterial) -> void:
	var life := maxf(float(_birth_sample(c.life, birth)), 0.02)
	if _time - birth >= life: return
	var node := _node(material.duplicate())
	if not String(c.mesh).is_empty(): node.mesh = _mesh(c.mesh)
	else:
		var quad := QuadMesh.new()
		quad.size = Vector2(2, 2)
		node.mesh = quad
	var color: Array = _birth_sample(c.birthColor, birth)
	var rotation: Vector3 = vec3(_birth_sample(c.birthRotation0, birth))
	_particles.append({"node": node, "c": c, "birth": birth, "life": life,
		"origin": global_position, "rotation": rotation, "color": Color(color[0], color[1], color[2], color[3]),
		"scale": vec3(_birth_sample(c.birthScale0, birth)), "velocity": vec3(_birth_sample(c.birthVelocity, birth)),
		"offset": vec3(_birth_sample(c.get("birthOffset", {"base": c.offset}), birth)),
		"frame": _rng.randi_range(0, maxi(int(c.frames) - 1, 0))})

func _update(p: Dictionary, age: float) -> void:
	var c: Dictionary = p.c
	var t := age / float(p.life)
	var node: MeshInstance3D = p.node
	var velocity: Vector3 = p.velocity
	var drag := vec3(sample(c.birthDrag, 0.0))
	var displacement := Vector3.ZERO
	for axis in 3:
		displacement[axis] = velocity[axis] * ((1.0 - exp(-drag[axis] * age)) / drag[axis] if drag[axis] > 0.001 else age)
	var offset: Vector3 = p.offset + vec3(sample(c.get("emitterPosition", {"base": [0,0,0]}), _time)) + displacement + vec3(sample(c.birthAcceleration, 0.0)) * age * age * 0.5
	var bind := clampf(float(sample(c.bind, t)), 0.0, 1.0)
	node.global_position = (p.origin as Vector3).lerp(global_position, bind) + (global_basis * offset + vec3(sample(c.worldAcceleration, t)) * age * age * 0.5) * _factor
	var angles: Vector3 = (p.rotation + vec3(sample(c.birthRotationalVelocity0, 0.0)) * age) * PI / 180.0
	if not String(c.mesh).is_empty() or String(c.get("primitive", "")) == "VfxPrimitiveArbitraryQuad":
		node.global_basis = global_basis * Basis.from_euler(angles)
	elif bool(c.ground):
		node.global_basis = global_basis * Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.BACK, angles.z)
		node.global_position.y = maxf(node.global_position.y, 0.045)
	elif is_instance_valid(_camera):
		node.global_basis = _camera.global_basis * Basis(Vector3.BACK, angles.x)
	# Static impact aftershock meshes are authored +X forward / +Y thickness.
	# Unlike missile meshes they must not inherit missile's (0,90,90) rotation.
	if _system in ["Spear_Impact", "Update_Impact"] and String(c.mesh).contains("aftershock_mesh"):
		var forward := global_basis.z.normalized()
		node.global_basis = Basis(forward, Vector3.UP, forward.cross(Vector3.UP))
	# Ground markers stay on the battlefield plane even when their source uses
	# ArbitraryQuad; ground was previously bypassed by the arbitrary-quad branch.
	if bool(c.ground) and String(c.mesh).is_empty():
		var across := node.global_basis.x
		across.y = 0.0
		if across.length_squared() < 0.0001: across = global_basis.x
		across.y = 0.0
		across = across.normalized()
		node.global_basis = Basis(across, Vector3.UP.cross(across), Vector3.UP)
		node.global_position.y = 0.045
	# 原始长矛网格以枪尖为原点、枪柄朝-Y；Godot落地代理将枪柄校正到上方。
	if String(c.mesh).contains("q_hold_spear"):
		node.global_basis = node.global_basis * Basis(Vector3.RIGHT, PI)
		node.global_position.y -= 2.0 * float(c.offset[1]) * _factor
	var size := (p.scale as Vector3) * vec3(sample(c.scale0, t)) * _factor
	for axis in 3: size[axis] = maxf(absf(size[axis]), 0.0001)
	node.scale = size
	# Original Air Streak pair was at lateral 0/+250; data now uses -125/+125.
	# Center its mesh cross-section too, without moving the authored forward tail.
	if String(c.mesh).contains("mis_air_streaks"):
		node.global_position -= node.global_basis.z * node.mesh.get_aabb().get_center().z
	var rgba: Array = sample(c.Color, t)
	var tint := Color(rgba[0], rgba[1], rgba[2], rgba[3]) * (p.color as Color)
	node.material_override.set_shader_parameter("tint", tint)
	node.material_override.set_shader_parameter("elapsed", age)
	node.material_override.set_shader_parameter("frame", float(p.frame))
	node.material_override.set_shader_parameter("uv_scale", vec2(sample(c.uvScale, t)))
	node.material_override.set_shader_parameter("erosion", float(sample(c.erosion_drive, t)))

func _update_trail(trail: Dictionary) -> void:
	var c: Dictionary = trail.c
	var points: Array = trail.points
	var life := maxf(float(sample(c.life, 0.0)), 0.1)
	var point := global_position + global_basis * vec3(sample(c.get("birthOffset", {"base": c.offset}), _time)) * _factor
	if _emitting and (points.is_empty() or point.distance_to(points.back().pos) > 0.05):
		points.append({"pos": point, "time": _time})
	while not points.is_empty() and _time - float(points[0].time) > life: points.pop_front()
	var node: MeshInstance3D = trail.node
	node.visible = points.size() >= 2
	if not node.visible: return
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var base_width := float(sample(c.birthScale0, 0.0)[0]) * _factor
	for i in points.size():
		var t := clampf((_time - float(points[i].time)) / life, 0, 1)
		var width := base_width * float(sample(c.scale0, t)[0])
		var tangent: Vector3 = points[mini(i+1, points.size()-1)].pos - points[maxi(i-1, 0)].pos
		var trail_normal := global_basis.z.normalized() if _motion_frame else Vector3.UP
		var side := tangent.cross(trail_normal).normalized() * width
		var rgba: Array = sample(c.Color, t)
		for sign in [-1.0, 1.0]:
			vertices.append(points[i].pos + side * sign + Vector3.UP * 0.05)
			uvs.append(Vector2(0 if sign < 0 else 1, float(i) / maxf(points.size()-1, 1)))
			colors.append(Color(rgba[0],rgba[1],rgba[2],rgba[3]))
		if i > 0: indices.append_array(PackedInt32Array([i*2-2,i*2-1,i*2,i*2-1,i*2+1,i*2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = mesh
	node.global_transform = Transform3D.IDENTITY
	node.material_override.set_shader_parameter("elapsed", _time)

func _birth_sample(c: Dictionary, t: float) -> Variant:
	var result = sample(c, t)
	var probabilities: Array = c.get("probabilities", [])
	if probabilities.is_empty(): return result
	if result is Array:
		result = result.duplicate()
		for axis in mini(result.size(), probabilities.size()): result[axis] *= float(sample(probabilities[axis], _rng.randf()))
	else: result *= float(sample(probabilities[0], _rng.randf()))
	return result

static func prepare_assets() -> void:
	for emitters: Array in systems().values():
		for c: Dictionary in emitters:
			for key in ["texture", "mult", "erosion"]:
				if not String(c.get(key, "")).is_empty(): _texture(c[key])
			if not String(c.mesh).is_empty(): _mesh(c.mesh)

static func sample(c: Dictionary, t: float) -> Variant:
	if not c.has("times"): return c.base
	var times: Array = c.times
	var values: Array = c.values
	if t <= float(times[0]): return values[0]
	for i in range(1, times.size()):
		if t <= float(times[i]):
			var f := inverse_lerp(float(times[i-1]), float(times[i]), t)
			if values[i] is Array:
				var result := []
				for j in values[i].size(): result.append(lerpf(float(values[i-1][j]), float(values[i][j]), f))
				return result
			return lerpf(float(values[i-1]), float(values[i]), f)
	return values.back()

static func vec3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
static func vec2(a: Array) -> Vector2:
	return Vector2(a[0], a[1])

static func _texture(path: String) -> Texture2D:
	if not _texture_cache.has(path): _texture_cache[path] = load(path)
	return _texture_cache[path]

static func _material(c: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ADD if int(c.blend) in [0, 4] else MIX
	material.render_priority = clampi(int(c.pass), -20, 40)
	material.set_shader_parameter("source_texture", _texture(c.texture))
	material.set_shader_parameter("uv_scale", vec2(sample(c.uvScale, 0.0)))
	material.set_shader_parameter("uv_offset", vec2(sample(c.birthUVOffset, 0.0)))
	material.set_shader_parameter("uv_scroll", vec2(sample(c.particleUVScrollRate, 0.0)) + vec2(sample(c.birthUvScrollRate, 0.0)))
	material.set_shader_parameter("tex_div", vec2(c.tex_div))
	if not String(c.mult).is_empty():
		material.set_shader_parameter("has_mult", true)
		material.set_shader_parameter("mult_texture", _texture(c.mult))
		material.set_shader_parameter("mult_scale", vec2(sample(c.mult_scale, 0.0)))
		material.set_shader_parameter("mult_scroll", vec2(sample(c.mult_scroll, 0.0)))
	if not String(c.erosion).is_empty():
		material.set_shader_parameter("has_erosion", true)
		material.set_shader_parameter("erosion_texture", _texture(c.erosion))
	return material

static func _mesh(path: String) -> ArrayMesh:
	if _mesh_cache.has(path): return _mesh_cache[path]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in range(0, data.vertices.size(), 3): vertices.append(Vector3(data.vertices[i],data.vertices[i+1],data.vertices[i+2]))
	for i in range(0, data.uv.size(), 2): uvs.append(Vector2(data.uv[i],data.uv[i+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[path] = mesh
	return mesh
