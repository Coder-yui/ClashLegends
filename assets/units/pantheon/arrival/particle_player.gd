@static_unload
extends Node3D
signal particle_died(emitter: String, pose: Transform3D, death_age: float)
## 原始BIN导出的落地粒子子集。只进行表现采样，不派发游戏事件。
const PROFILE := preload("res://assets/units/pantheon/arrival/profile.gd")
const DATA_PATH := "res://assets/units/pantheon/r_original/systems.json"
const ADD := "res://assets/units/pantheon/arrival/particle_add.gdshader"
const MIX := "res://assets/units/pantheon/arrival/particle_mix.gdshader"
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
var _motion_frame := false
var _system := ""
const MAX_PARTICLES := 220

static func systems() -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data

func setup(system: String, factor: float = 0.0075, motion_frame: bool = false, emitter_filter: String = "", include_disabled: bool = false, bound_single_only: bool = false, source_definitions: Array = []) -> void:
	_system = system
	_motion_frame = motion_frame
	_factor = factor
	_rng.seed = 81271
	_camera = get_viewport().get_camera_3d()
	var definitions: Array = systems()[system] if source_definitions.is_empty() else source_definitions
	for source: Dictionary in definitions:
		if not emitter_filter.is_empty() and source.name != emitter_filter: continue
		if bound_single_only and (not source.single or float(sample(source.bind, 0.0)) < 1.0): continue
		var c := source.duplicate(true)
		c["adaptation"] = PROFILE.layer(system, c.name) if source_definitions.is_empty() else {}
		if not include_disabled and not c.adaptation.get("enabled", true): continue
		if c.adaptation.has("offset_override"):
			c.birthOffset = {"base": c.adaptation.offset_override}
		var material := _material(c)
		if bool(c.trail):
			var node := _node(material)
			_trails.append({"c": c, "node": node, "points": []})
		else:
			_emitters.append({"c": c, "next": float(c.delay), "count": 0, "material": material})

func stop_emitting() -> void:
	_emitting = false

func advance(delta: float) -> void:
	_time += maxf(delta, 0.0)
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		if _time - float(p.birth) >= float(p.life):
			_update(p, float(p.life))
			particle_died.emit(p.c.name, Transform3D(p.node.global_basis.orthonormalized(), p.node.global_position), float(p.birth) + float(p.life))
			p.node.free()
			_particles.remove_at(i)
	for e: Dictionary in _emitters:
		var c: Dictionary = e.c
		var end := minf(_time, float(c.duration))
		if not _emitting: continue
		while float(e.next) <= end + 0.000001:
			if bool(c.single) and int(e.count) > 0: break
			# Budget pressure drops this birth, never postpones it into a later burst.
			if _particles.size() < MAX_PARTICLES: _spawn(c, float(e.next), e.material)
			e.next += 1.0 / maxf(float(sample(c.rate, float(e.next))), 0.1)
			e.count += 1
	present(_time)
	for trail: Dictionary in _trails: _update_trail(trail)

func present(age: float) -> void:
	for p: Dictionary in _particles:
		var elapsed := maxf(age - float(p.birth), 0.0)
		p.node.visible = elapsed < float(p.life)
		_update(p, elapsed)

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
	var spawn_offset := Vector3.ZERO
	if float(c.get("spawn_radius", 0.0)) > 0.0:
		var angle := _rng.randf() * TAU
		var radius := sqrt(_rng.randf()) * float(c.spawn_radius)
		spawn_offset = Vector3(cos(angle) * radius, _rng.randf() * float(c.get("spawn_height", 0.0)), sin(angle) * radius)
	_particles.append({"node": node, "c": c, "birth": birth, "life": life,
		"origin": global_position, "basis": global_basis, "rotation": rotation, "color": Color(color[0], color[1], color[2], color[3]),
		"scale": vec3(_birth_sample(c.birthScale0, birth)), "orbital": vec3(_birth_sample(c.get("birthOrbitalVelocity", {"base": [0,0,0]}), birth)), "velocity": vec3(_birth_sample(c.birthVelocity, birth)),
		"offset": vec3(_birth_sample(c.get("birthOffset", {"base": c.offset}), birth)) + spawn_offset,
		"mult_offset": vec2(_birth_sample(c.mult_birth_offset, birth)),
		"mult_rate": vec2(_birth_sample(c.mult_birth_scroll, birth)),
		"frame_rate": float(_birth_sample(c.get("birthFrameRate", {"base": 0.0}), birth)),
		"frame": _rng.randi_range(0, maxi(int(c.frames) - 1, 0)) if bool(c.get("random_start_frame", true)) else 0})

func _update(p: Dictionary, age: float) -> void:
	var c: Dictionary = p.c
	var t := age / float(p.life)
	var node: MeshInstance3D = p.node
	var velocity: Vector3 = p.velocity
	var drag := vec3(sample(c.birthDrag, 0.0))
	var displacement := Vector3.ZERO
	for axis in 3:
		displacement[axis] = velocity[axis] * ((1.0 - exp(-drag[axis] * age)) / drag[axis] if drag[axis] > 0.001 else age)
	var offset: Vector3 = p.offset + vec3(sample(c.get("emitterPosition", {"base": [0,0,0]}), float(p.birth) + age)) + displacement + vec3(sample(c.birthAcceleration, 0.0)) * age * age * 0.5
	var orbital: Vector3 = p.get("orbital", Vector3.ZERO)
	if orbital.length_squared() > 0.0: offset = Basis.from_euler(orbital * age) * offset
	var bind := clampf(float(sample(c.bind, t)), 0.0, 1.0)
	var particle_basis: Basis = (p.basis as Basis).orthonormalized().slerp(global_basis.orthonormalized(), bind)
	node.global_position = (p.origin as Vector3).lerp(global_position, bind) + (particle_basis * offset + (vec3(sample(c.worldAcceleration, t)) + vec3(sample(c.get("fieldAcceleration", {"base": [0,0,0]}), t))) * age * age * 0.5) * _factor
	var orientation_basis: Basis = Basis.IDENTITY if bool(c.get("apply_local_orientation", false)) and not bool(c.get("local_orientation", true)) else particle_basis
	var angles: Vector3 = (p.rotation + vec3(sample(c.birthRotationalVelocity0, 0.0)) * age) * PI / 180.0
	if not String(c.mesh).is_empty() or String(c.get("primitive", "")) == "VfxPrimitiveArbitraryQuad":
		node.global_basis = orientation_basis * Basis.from_euler(angles)
	elif bool(c.ground):
		node.global_basis = global_basis * Basis(Vector3.RIGHT, -PI / 2.0) * Basis(Vector3.BACK, angles.z)
		node.global_position.y = maxf(node.global_position.y, 0.045)
	elif is_instance_valid(_camera):
		node.global_basis = _camera.global_basis * Basis(Vector3.BACK, angles.x)
	var adaptation: Dictionary = c.get("adaptation", {})
	if adaptation.get("orientation", "authored") == "impact_front":
		var forward := global_basis.z.normalized()
		node.global_basis = Basis(forward, Vector3.UP, forward.cross(Vector3.UP))
	if adaptation.get("orientation", "authored") == "ground":
		var across := node.global_basis.x
		across.y = 0.0
		if across.length_squared() < 0.0001: across = global_basis.x
		across.y = 0.0
		across = across.normalized()
		node.global_basis = Basis(across, Vector3.UP.cross(across), Vector3.UP)
		node.global_position.y = 0.045
	if adaptation.get("orientation", "authored") in ["ground_front", "ground_exit"]:
		var forward := PROFILE.path_forward(PROFILE.data().systems[_system].frame, global_basis)
		if adaptation.orientation == "ground_exit": forward = -forward
		node.global_basis = Basis(forward.cross(Vector3.UP), forward, Vector3.UP)
		node.global_position.y = 0.045
	var size := (p.scale as Vector3) * vec3(sample(c.scale0, t)) * _factor
	if bool(c.get("uniform_scale", false)): size = Vector3.ONE * size.x
	for axis in 3:
		var sign_value := -1.0 if bool(c.get("preserve_signed_scale", false)) and size[axis] < 0.0 else 1.0
		size[axis] = maxf(absf(size[axis]), 0.0001) * sign_value
	node.scale = size
	# The original two streak layers share the central opening in this adaptation.
	# Center its mesh cross-section too, without moving the authored forward tail.
	if bool(adaptation.get("center_mesh_z", false)):
		node.global_position -= node.global_basis.z * node.mesh.get_aabb().get_center().z
	var rgba: Array = sample(c.Color, t)
	var tint := Color(rgba[0], rgba[1], rgba[2], rgba[3]) * (p.color as Color)
	node.material_override.set_shader_parameter("tint", tint)
	node.material_override.set_shader_parameter("elapsed", age)
	node.material_override.set_shader_parameter("frame", fmod(float(p.frame) + floor(age * float(p.get("frame_rate", 0.0))), maxf(1.0, float(c.frames))))
	node.material_override.set_shader_parameter("uv_scale", vec2(sample(c.uvScale, t)))
	node.material_override.set_shader_parameter("erosion", float(sample(c.erosion_drive, t)))
	_update_flow(node.material_override, c, age, float(p.life), false)
	node.material_override.set_shader_parameter("mult_phase", integrated_flow(c.mult_scroll, age, float(p.life)) + (p.mult_rate as Vector2) * age + (p.mult_offset as Vector2))

func _update_trail(trail: Dictionary) -> void:
	var c: Dictionary = trail.c
	var points: Array = trail.points
	var life := maxf(float(sample(c.life, 0.0)), 0.1)
	var point := global_position + global_basis * (vec3(sample(c.get("birthOffset", {"base": c.offset}), _time)) + vec3(sample(c.emitterPosition, _time))) * _factor
	if _emitting and _time >= float(c.delay) and _time <= float(c.duration) + 0.000001 and (points.is_empty() or point.distance_to(points.back().pos) > 0.05):
		var distance := float(points.back().distance) + point.distance_to(points.back().pos) if not points.is_empty() else 0.0
		points.append({"pos": point, "time": _time, "distance": distance,
			"width": float(sample(c.birthScale0, _time)[0]) * _factor,
			"color": _birth_sample(c.birthColor, _time)})
	while not points.is_empty() and _time - float(points[0].time) > life: points.pop_front()
	var node: MeshInstance3D = trail.node
	node.visible = points.size() >= 2
	if not node.visible: return
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var tiling := maxf(float(sample(c.trail_tiling, 0.0)[0]) * _factor, 0.001)
	for i in points.size():
		var t := clampf((_time - float(points[i].time)) / life, 0, 1)
		var width := float(points[i].width) * float(sample(c.scale0, t)[0])
		var tangent: Vector3 = points[mini(i+1, points.size()-1)].pos - points[maxi(i-1, 0)].pos
		var trail_normal := global_basis.z.normalized() if _motion_frame else Vector3.UP
		if bool(c.get("camera_trail", false)) and is_instance_valid(_camera): trail_normal = _camera.global_basis.z
		var side := tangent.cross(trail_normal).normalized() * width
		var rgba: Array = sample(c.Color, t)
		for sign in [-1.0, 1.0]:
			vertices.append(points[i].pos + side * sign + Vector3.UP * 0.05)
			uvs.append(Vector2(float(points[i].distance) / tiling, 0 if sign < 0 else 1))
			var birth: Array = points[i].color
			colors.append(Color(rgba[0]*birth[0],rgba[1]*birth[1],rgba[2]*birth[2],rgba[3]*birth[3]))
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
	_update_flow(node.material_override, c, _time, life, true)

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
	for c in resource_emitters():
		for key in ["texture", "mult", "erosion", "distortion_texture", "palette_texture"]:
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
	material.shader = load(resource_shader_path(c))
	if not String(c.get("distortion_texture", "")).is_empty():
		material.set_shader_parameter("normal_map", _texture(c.distortion_texture))
		material.set_shader_parameter("distortion_strength", float(c.distortion_strength))
	if not String(c.get("palette_texture", "")).is_empty():
		material.set_shader_parameter("palette_texture", _texture(c.palette_texture))
		material.set_shader_parameter("has_palette", true)
		material.set_shader_parameter("palette_row", float(c.palette_row))
		material.set_shader_parameter("palette_count", float(c.palette_count))
	material.render_priority = clampi(int(c.pass), -128, 127)
	material.set_shader_parameter("source_texture", _texture(c.texture))
	material.set_shader_parameter("uv_clamp", bool(c.get("uv_clamp", false)))
	material.set_shader_parameter("uv_scale", vec2(sample(c.uvScale, 0.0)))
	material.set_shader_parameter("uv_offset", vec2(sample(c.birthUVOffset, 0.0)))
	material.set_shader_parameter("uv_phase", Vector2.ZERO)
	material.set_shader_parameter("tex_div", vec2(c.tex_div))
	if not String(c.mult).is_empty():
		material.set_shader_parameter("has_mult", true)
		material.set_shader_parameter("mult_texture", _texture(c.mult))
		material.set_shader_parameter("mult_scale", vec2(sample(c.mult_scale, 0.0)))
		material.set_shader_parameter("mult_phase", Vector2.ZERO)
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

## Integrate authored rates, not age * current rate (which jumps/reverses when
## the rate drops). Curves use normalized particle life, offsets use UV units.
static func integrated_flow(curve: Dictionary, age: float, life: float) -> Vector2:
	var end := maxf(age, 0.0) / maxf(life, 0.001)
	var times: Array = curve.get("times", [])
	var at := 0.0
	var phase := Vector2.ZERO
	for knot in times:
		var next := minf(float(knot), end)
		if next > at:
			phase += (vec2(sample(curve, at)) + vec2(sample(curve, next))) * (next - at) * 0.5
			at = next
		if at >= end: break
	if end > at: phase += (vec2(sample(curve, at)) + vec2(sample(curve, end))) * (end - at) * 0.5
	return phase * life

static func _update_flow(material: ShaderMaterial, c: Dictionary, age: float, life: float, trail: bool) -> void:
	var phase := integrated_flow(c.particleUVScrollRate, age, life) + vec2(sample(c.birthUvScrollRate, 0.0)) * age
	if trail:
		# U follows oldest -> newest centerline points, V spans the width.
		# Increasing sampled U moves the visible pattern toward the older wake.
		phase = Vector2(absf(phase.x), 0.0)
	material.set_shader_parameter("uv_phase", phase)
	material.set_shader_parameter("mult_phase", integrated_flow(c.mult_scroll, age, life) + vec2(sample(c.mult_birth_scroll, 0.0)) * age + vec2(sample(c.mult_birth_offset, 0.0)))

## Offline review teardown only; matches intentionally retain their warm cache.
static func release_prepared_assets() -> void:
	_mesh_cache.clear()
	_texture_cache.clear()

static func resource_shader_matches(value: Dictionary) -> bool:
	return value.has("blend") and value.has("duration") and value.has("texture")

static func resource_shader_path(value: Dictionary) -> String:
	if not String(value.get("distortion_texture", "")).is_empty(): return "res://scripts/presentation/native_particle_distortion.gdshader"
	return ADD if int(value.blend) in [0, 4] else MIX

## 与运行时系统/层开关相同的潘森依赖集合。
static func resource_emitters() -> Array:
	var result: Array = []
	for system in PROFILE.data().systems:
		if not PROFILE.data().systems[system].get("enabled", true): continue
		for emitter in systems()[system]:
			if PROFILE.layer(system, emitter.name).get("enabled", true): result.append(emitter)
	return result
