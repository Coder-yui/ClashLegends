extends Node3D
## 旧版 Jade_VoidSpawn 原版粒子采样，保留发射器与曲线。
## The authority supplies age; this node never advances battle state.
const ROOT := "res://assets/effects/void_spawn/"
static var _cache: Dictionary = {}
var opacity := 1.0
var emission_end := INF
var _particle_births := {}
var _kind := ""
var _birth_positions: Dictionary = {}
var _last_position := Vector3.INF
var _data: Dictionary = {}
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _age := 0.0
var _frame := -1
var _last_opacity := -1.0
var _last_basis := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
# Only the ordinary-death floor layers are projected onto terrain.
# Turret impact preserves its source planes in the channel-bone frame.
const GROUND_PLANES := ["FireRing", "CenterFlare"]
# Uniform project calibration; preserve authored layer proportions and curves.
const NATIVE_SCALES := {"burst": 0.012, "death": 0.012, "energy": 0.006, "glow": 0.006, "spawn": 0.015, "trail": 0.015}

static func native_scale(kind: String) -> float:
	return float(NATIVE_SCALES.get(kind, 0.006))

func shape_basis_for(_emitter_name: String) -> Basis:
	return projection_basis

static func layer_enabled(kind: String, emitter: String) -> bool:
	return true

func load_kind(kind: String) -> void:
	_kind = kind
	if not _cache.has(kind):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + kind + "/sampled.json"))
		var materials: Array[ShaderMaterial] = []
		for e in data.emitters:
			if not layer_enabled(kind, String(e.name)):
				materials.append(null)
				continue
			if not _meshes.has(e.mesh_path): _meshes[e.mesh_path] = _mesh(e.mesh_path)
			materials.append(_material(e))
		_cache[kind] = {"data": data, "materials": materials}
	_data = _cache[kind].data
	if kind == "trail":
		for frame_index in _data.frames.size():
			for emitter_index in _data.frames[frame_index].size():
				for particle in _data.frames[frame_index][emitter_index]:
					var key := Vector2i(emitter_index, int(particle[0]))
					if not _particle_births.has(key): _particle_births[key] = float(frame_index) / float(_data.fps)
	_materials.assign(_cache[kind].materials)

func setup_native(unit_scale: float) -> void:
	scale = Vector3.ONE * unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func advance(delta: float) -> void:
	seek(_age + delta)

func seek(age: float) -> void:
	if age < _age: _birth_positions.clear()
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _data.frames.size() - 1)
	if frame == _frame and opacity == _last_opacity and projection_basis == _last_basis and global_position == _last_position: return
	_frame = frame
	_last_position = global_position
	_last_opacity = opacity
	_last_basis = projection_basis
	var values: Array = _data.frames[frame]
	for emitter_index in values.size():
		var e: Dictionary = _data.emitters[emitter_index]
		var pool: Array = _pools[emitter_index]
		var particles: Array = values[emitter_index]
		if _kind == "trail" and is_finite(emission_end):
			particles = particles.filter(func(p): return float(_particle_births.get(Vector2i(emitter_index, int(p[0])), 0.0)) <= emission_end)
		while pool.size() < particles.size():
			var item := MeshInstance3D.new()
			item.mesh = _meshes[e.mesh_path]
			item.material_override = _materials[emitter_index].duplicate()
			item.material_override.set_shader_parameter("projection_basis", projection_basis)
			item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			item.custom_aabb = AABB(Vector3(-2500, -2500, -2500), Vector3(5000, 5000, 5000))
			# Body-centered flash; the authored floor splatter stays on terrain.
			item.position.y = 0.0
			add_child(item)
			pool.append(item)
		for j in pool.size():
			var item: MeshInstance3D = pool[j]
			item.visible = j < particles.size() and _age <= float(_data.duration)
			if item.visible:
				item.material_override.set_shader_parameter("projection_basis", projection_basis)
				item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
				item.material_override.set_shader_parameter("opacity", opacity)
				var sample: Array = particles[j]
				if String(e.name) in GROUND_PLANES:
					item.position.y = to_local(Vector3(global_position.x, 0.09, global_position.z)).y
				if _kind == "trail" or (_kind == "missile" and float(e.bindWeight.constant[0]) == 0.0):
					var serial := int(sample[0])
					if not _birth_positions.has(serial): _birth_positions[serial] = global_position
					var drift := to_local(_birth_positions[serial])
					if _kind == "trail":
						var birth := float(_particle_births.get(Vector2i(emitter_index, serial), _age))
						drift *= 1.0 - native_bind_weight(e, _age - birth)
					sample = sample.duplicate()
					sample[1] += drift.x
					sample[2] += drift.y
					sample[3] += drift.z
				item.material_override.set_shader_parameter("p", PackedFloat32Array(sample))
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = particles[j]
					var center := to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)

static func _mesh(path: String) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	if path.is_empty():
		for index in [0, 2, 1, 0, 3, 2]:
			var point: Vector2 = [Vector2(-0.5,-0.5), Vector2(0.5,-0.5), Vector2(0.5,0.5), Vector2(-0.5,0.5)][index]
			vertices.append(Vector3(point.x,point.y,0))
			uv.append(point)
			colors.append(Color.WHITE)
	else:
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		# Mirrored X with Godot's clockwise front faces; original SCB corner order.
		for i in raw.vertices.size() / 3:
			vertices.append(Vector3(-raw.vertices[i*3],raw.vertices[i*3+1],raw.vertices[i*3+2]))
			uv.append(Vector2(raw.uv[i*2],raw.uv[i*2+1]))
			colors.append(Color(raw.colors[i*4]/255.0,raw.colors[i*4+1]/255.0,raw.colors[i*4+2]/255.0,raw.colors[i*4+3]/255.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func _v2(a: Array) -> Vector2: return Vector2(a[0],a[1])
static func _v4(a: Array) -> Vector4: return Vector4(a[0],a[1],a[2],a[3])

static func _material(e: Dictionary) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load(resource_shader_path(e))
	result.render_priority = int(e.rank) + 999900 if int(e.rank) < 0 else int(e.rank)
	# Original distortionMode=2 is the early, pre-particle phase.
	if e.distortion != null: result.render_priority = -110
	var params := {
		"is_mesh":e.meshDraw, "cull_mesh":e.backfaceCull, "billboard":e.billboard, "directed":e.directionOriented,
		"is_ray":e.ray, "reach":e.reach, "pivot":0.5 if e.pivotUp else 0.0,
		"ground_layer":String(e.name) in GROUND_PLANES, "cell":_v2(e.cell), "cell_mult":_v2(e.cellMult),
		"uv_center":_v2(e.uv.center), "uv_flip":Vector2(float(e.uv.flipU),float(e.uv.flipV)),
		"address_mode":int(e.uv.addressMode), "alpha_ref":e.alphaRef,
		"has_mult":not e.mult_path.is_empty(), "has_ramp":not e.color_path.is_empty() and e.erosion == null,
		"has_erosion":e.erosion != null, "has_soft":e.soft != null, "push_pull":e.depthPushPull,
	}
	if e.multUv != null:
		params.merge({"mult_center":_v2(e.multUv.center),"mult_flip":Vector2(float(e.multUv.flipU),float(e.multUv.flipV)),"mult_address":int(e.multUv.addressMode)})
	if e.erosion != null:
		params.merge({"erosion_mix":_v4(e.erosion.mixer.constant),"erosion_band":Vector3(e.erosion.sliceWidth,1.0/maxf(e.erosion.featherIn,0.00000001),1.0/maxf(e.erosion.featherOut,0.00000001)),"erosion_address":int(e.erosion.addressMode)})
	if e.soft != null:
		var soft: Dictionary = e.soft
		params["soft_params"] = Vector4(soft.beginIn,soft.beginOut if soft.beginOut > 0 else 1e8,1.0/maxf(soft.deltaIn,0.00000001),1.0/maxf(soft.deltaOut,0.00000001))
	if e.distortion != null: params["warp_strength"] = e.distortion.strength
	for name in params: result.set_shader_parameter(name,params[name])
	for pair in [["source_texture","texture_path"],["mult_texture","mult_path"],["ramp_texture","color_path"],["erosion_texture","erosion_path"],["normal_texture","normal_path"]]:
		if not e[pair[1]].is_empty(): result.set_shader_parameter(pair[0],load(e[pair[1]]))
	return result

## 对外资源契约：定义读取不会创建粒子或加载纹理。
static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["burst", "death", "energy", "glow", "spawn", "trail"]: return {}
	return {"json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/void_spawn/player.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(e: Dictionary) -> String:
	return ROOT + ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix")) + ".gdshader"


static func native_bind_weight(emitter: Dictionary, particle_age: float) -> float:
	var weight: Dictionary = emitter.bindWeight
	var value := float(weight.constant[0])
	var keys: Array = weight.keys
	if keys.is_empty(): return value
	var t := particle_age / maxf(float(emitter.particleLifetime.constant[0]), 0.00001)
	var factor := float(keys[-1].values[0])
	if t <= float(keys[0].time): factor = float(keys[0].values[0])
	else:
		for index in range(1, keys.size()):
			if t <= float(keys[index].time):
				factor = lerpf(float(keys[index - 1].values[0]), float(keys[index].values[0]), inverse_lerp(float(keys[index - 1].time), float(keys[index].time), t))
				break
	return clampf(value * factor, 0.0, 1.0)
