extends Node3D
## 龙王基础皮肤星落与天瀑的原版采样；只消费表现时间。
## The authority supplies age; this node never advances battle state.
const ROOT := "res://assets/effects/aurelionsol_r/"
static var _cache: Dictionary = {}
var opacity := 1.0
var _kind := ""
var _trails: Dictionary = {}
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
# Semantic footprint geometry, including unflagged near-ground quads and the central dome.
const GROUND_PLANES := ["Darkness", "Darkness2", "Darkness_Expand", "IndicatorBG", "IndicatorMULT", "IndicatorFLASH", "IndicatorExpand"]

func shape_basis_for(_emitter_name: String) -> Basis:
	return projection_basis

static func layer_enabled(_kind: String, _emitter: String) -> bool:
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
		if e.trail != null:
			_sync_trail(emitter_index, e, particles)
			continue
		while pool.size() < particles.size():
			var item := MeshInstance3D.new()
			item.mesh = _meshes[e.mesh_path]
			item.material_override = _materials[emitter_index].duplicate()
			item.material_override.set_shader_parameter("projection_basis", projection_basis)
			item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			item.custom_aabb = AABB(Vector3(-2500, -2500, -2500), Vector3(5000, 5000, 5000))
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
				if _kind.ends_with("missile") and float(e.bindWeight.constant[0]) == 0.0:
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
	if variant not in ["tell", "missile", "impact", "strong_tell", "strong_missile", "strong_impact", "wave"]: return {}
	return {"paths": [ROOT + "trail.gdshader"], "json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/aurelionsol_r/player.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(e: Dictionary) -> String:
	var shader_name := "warp" if e.distortion != null else ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix"))
	return ROOT + shader_name + ".gdshader"

func _sync_trail(index: int, emitter: Dictionary, particles: Array) -> void:
	if not _trails.has(index):
		var item := MeshInstance3D.new()
		item.mesh = ImmediateMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/effects/aurelionsol_r/trail.gdshader")
		mat.set_shader_parameter("source_texture", load(emitter.texture_path))
		mat.render_priority = int(emitter.rank) + 999900 if int(emitter.rank) < 0 else int(emitter.rank)
		item.material_override = mat
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(item)
		_trails[index] = item
		_pools[index].append(item)
	var item: MeshInstance3D = _trails[index]
	var mesh: ImmediateMesh = item.mesh
	mesh.clear_surfaces()
	if particles.size() < 2: return
	var ordered := particles.duplicate()
	ordered.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var points: Array[Vector3] = []
	var samples: Array = []
	for values in ordered:
		var sample: Array = values.duplicate()
		var serial := int(sample[0])
		if not _birth_positions.has(serial): _birth_positions[serial] = global_position
		var drift := to_local(_birth_positions[serial])
		sample[1] += drift.x
		sample[2] += drift.y
		sample[3] += drift.z
		samples.append(sample)
		points.append(Vector3(sample[1], sample[2], sample[3]))
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var distance := 0.0
	for j in points.size():
		if j > 0: distance += points[j].distance_to(points[j-1])
		var tangent := points[mini(j + 1, points.size() - 1)] - points[maxi(j - 1, 0)]
		var facing := to_local(camera.global_position) - points[j]
		var side := tangent.cross(facing).normalized()
		if side.length_squared() < 0.001: side = Vector3.RIGHT
		var sample: Array = samples[j]
		var width := float(sample[4])
		mesh.surface_set_color(Color(sample[7], sample[8], sample[9], sample[10]))
		mesh.surface_set_uv(Vector2(0, distance / maxf(float(emitter.trail.tiling.constant[0]), 1.0)))
		mesh.surface_add_vertex(points[j] - side * width)
		mesh.surface_set_uv(Vector2(1, distance / maxf(float(emitter.trail.tiling.constant[0]), 1.0)))
		mesh.surface_add_vertex(points[j] + side * width)
	mesh.surface_end()
