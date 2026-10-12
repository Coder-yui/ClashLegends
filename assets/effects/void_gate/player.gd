extends Node3D
## 旧版 Jade_VoidGate 原版粒子采样，保留发射器与曲线。
## The authority supplies age; this node never advances battle state.
const ROOT := "res://assets/effects/void_gate/"
static var _cache: Dictionary = {}
static var _draw_keys: Array = []
const SPIT_OVERLAY_PRIORITY_OFFSET := 32
const BLEND_RANK := [1, 2, 1, 0, 2, 2, 2, 2, 3]
var opacity := 1.0
var _kind := ""
var _birth_positions: Dictionary = {}
var _last_position := Vector3.INF
var _data: Dictionary = {}
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _stopped := false
var _survivors: Array = []
var _age := 0.0
var _frame := -1
var _last_opacity := -1.0
var _last_basis := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
# Only the ordinary-death floor layers are projected onto terrain.
# Turret impact preserves its source planes in the channel-bone frame.
const GROUND_PLANES := []
# Uniform project calibration; preserve authored layer proportions and curves.
const NATIVE_SCALES := {"spawn": 0.0240833333333333, "death": 0.0240833333333333, "idle": 0.0240833333333333, "spit": 0.0240833333333333}

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
			var material := _material(e)
			# Project presentation policy: draw both BirthSpit layers after every
			# idle layer, including its additive glow. Preserve source alpha/scale.
			if kind == "spit": material.render_priority += SPIT_OVERLAY_PRIORITY_OFFSET
			materials.append(material)
		_cache[kind] = {"data": data, "materials": materials}
	_data = _cache[kind].data
	_materials.assign(_cache[kind].materials)

func setup_native(unit_scale: float) -> void:
	scale = Vector3.ONE * unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

# The native event stops emission, then applies each emitter's type-0
# maximum lifetime FROM BIRTH. It is not an extra lifetime after the stop.
func stop_emission(age: float) -> void:
	seek(age)
	_stopped = true
	_survivors.clear()
	var fps: float = _data.fps
	for i in _data.emitters.size():
		var e: Dictionary = _data.emitters[i]
		assert(int(e.lingerType) == 0 and float(e.emitterLinger) == 0.0)
		var survivors := {}
		for sample in _data.frames[_frame][i]:
			var serial := int(sample[0])
			var born := _frame
			# Samples preserve the original particle serials. Walk back only the
			# particles alive on exit; never admit a particle emitted after exit.
			while born > 0:
				var found := false
				for previous in _data.frames[born - 1][i]:
					if int(previous[0]) == serial:
						found = true
						break
				if not found: break
				born -= 1
			var lifetime: float = e.particleLifetime.constant[0]
			if not e.particleLifetime.tables.is_empty():
				# Randomized birth lifetime is already baked into this serial's samples.
				var end := _frame
				while end + 1 < _data.frames.size():
					var found := false
					for following in _data.frames[end + 1][i]:
						if int(following[0]) == serial:
							found = true
							break
					if not found: break
					end += 1
				lifetime = float(end - born + 1) / fps
			var capped := minf(lifetime, float(e.particleLinger))
			survivors[serial] = {"born": float(born) / fps, "life": lifetime, "cap": capped}
		_survivors.append(survivors)
	_frame = -1
	seek(age)

func has_live_particles() -> bool:
	for pool in _pools:
		for item in pool:
			if item.visible: return true
	return false

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
		if _stopped:
			particles = particles.filter(func(sample):
				return _survivors[emitter_index].has(int(sample[0])) and _age < float(_survivors[emitter_index][int(sample[0])].born) + float(_survivors[emitter_index][int(sample[0])].cap))
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
				if _stopped:
					var life: Dictionary = _survivors[emitter_index][int(sample[0])]
					if float(life.cap) < float(life.life):
						sample = sample.duplicate()
						var particle_age := maxf(_age - float(life.born), 0.0)
						# Reevaluate source over-life curves using the shortened lifetime.
						# Motion/UV clocks still use physical age, not the age fraction.
						for property in [["scale0", 4, 3], ["color", 7, 4]]:
							var curve: Dictionary = e[property[0]]
							assert(curve.tables.is_empty() and e.linger == null)
							for channel in int(property[2]):
								var before := _curve_channel(curve, particle_age / float(life.life), channel)
								var after := _curve_channel(curve, particle_age / float(life.cap), channel)
								if not is_zero_approx(before): sample[int(property[1]) + channel] *= after / before
				if String(e.name) in GROUND_PLANES:
					item.position.y = to_local(Vector3(global_position.x, 0.09, global_position.z)).y
				if _kind == "missile" and float(e.bindWeight.constant[0]) == 0.0:
					var serial := int(sample[0])
					if not _birth_positions.has(serial): _birth_positions[serial] = global_position
					var drift := to_local(_birth_positions[serial])
					sample = sample.duplicate()
					sample[1] += drift.x
					sample[2] += drift.y
					sample[3] += drift.z
				item.material_override.set_shader_parameter("p", PackedFloat32Array(sample))
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = particles[j]
					var center := to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
					# Godot's positive sorting_offset moves a transparent draw toward the eye.
					# Shader-displaced geometry has no usable CPU AABB; use its real center.
					var toward_eye := camera.global_basis.z.normalized()
					item.sorting_offset = (center - global_position).dot(toward_eye)
					if e.meshDraw and int(e.blendMode) == 1:
						# Concentric source spheres must sort by their front surfaces, not equal
						# centers. This is a Godot adaptation, not an extra native pass priority.
						var extent: Vector3 = item.mesh.get_aabb().size * 0.5
						var axes := Basis(Vector3(sample[12], sample[15], sample[18]), Vector3(sample[13], sample[16], sample[19]), Vector3(sample[14], sample[17], sample[20]))
						var geometry := global_basis * shape_basis_for(e.name) * axes * Basis.from_scale(Vector3(sample[4], sample[5], sample[6]))
						item.sorting_offset += Vector3(geometry.x.dot(toward_eye) * extent.x, geometry.y.dot(toward_eye) * extent.y, geometry.z.dot(toward_eye) * extent.z).length()


static func _curve_channel(curve: Dictionary, age: float, channel: int) -> float:
	var keys: Array = curve.keys
	if keys.is_empty(): return float(curve.constant[channel])
	if age <= float(keys[0].time): return float(keys[0].values[channel])
	for i in range(1, keys.size()):
		if age <= float(keys[i].time):
			var weight := (age - float(keys[i-1].time)) / (float(keys[i].time) - float(keys[i-1].time))
			return lerpf(float(keys[i-1].values[channel]), float(keys[i].values[channel]), weight)
	return float(keys[-1].values[channel])

static func _mesh(path: String) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
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
			if raw.has("normals"):
				normals.append(Vector3(-raw.normals[i*3], raw.normals[i*3+1], raw.normals[i*3+2]))
			colors.append(Color(raw.colors[i*4]/255.0,raw.colors[i*4+1]/255.0,raw.colors[i*4+2]/255.0,raw.colors[i*4+3]/255.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	if not normals.is_empty(): arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func _v2(a: Array) -> Vector2: return Vector2(a[0],a[1])
static func _v4(a: Array) -> Vector4: return Vector4(a[0],a[1],a[2],a[3])

static func _material(e: Dictionary) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load(resource_shader_path(e))
	result.render_priority = native_render_priority(e)
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
	if e.meshDraw and e.reflection != null:
		var r: Dictionary = e.reflection
		params["has_fresnel"] = true
		# mesh_vs uses RGB + exponent; fresnelColor alpha is not a multiplier.
		params["fresnel"] = Vector4(r.fresnelColor[0], r.fresnelColor[1], r.fresnelColor[2], r.fresnel)
	for name in params: result.set_shader_parameter(name,params[name])
	for pair in [["source_texture","texture_path"],["mult_texture","mult_path"],["ramp_texture","color_path"],["erosion_texture","erosion_path"],["normal_texture","normal_path"]]:
		if not e[pair[1]].is_empty(): result.set_shader_parameter(pair[0],load(e[pair[1]]))
	return result

## 对外资源契约：定义读取不会创建粒子或加载纹理。
static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["spawn", "death", "idle", "spit"]: return {}
	return {"raw": [ROOT + "render_order.json"], "json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/void_gate/player.gd", "kind": variant, "setup": "native"}}

## Share authored pass/simple/blend/flags priorities across all four systems.
## Local emitter indices are not cross-system draw keys. Equal keys remain tied
## so the renderer can sort instances; Idle must not be forced over Spit.
static func native_render_priority(e: Dictionary) -> int:
	if _draw_keys.is_empty():
		_draw_keys = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "render_order.json"))["keys"]
	var phase := 0 if int(e.pass) < 0 else 2
	if e.distortion != null:
		phase = 1 if int(e.distortion.mode) == 1 else -1
	var key := [phase, int(e.pass), int(e.simple), BLEND_RANK[int(e.blendMode)], int(e.miscRenderFlags)]
	var rank := -1
	for i in _draw_keys.size():
		var matches := true
		for j in key.size():
			if int(_draw_keys[i][j]) != int(key[j]): matches = false
		if matches:
			rank = i
			break
	assert(rank >= 0, "Unregistered native void gate draw key")
	return rank - 64

static func resource_shader_path(e: Dictionary) -> String:
	if e.distortion != null: return ROOT + "warp.gdshader"
	return ROOT + ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix")) + ".gdshader"
