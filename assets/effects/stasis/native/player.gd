extends Node3D
## 巴德基础R原始粒子采样重播，只读取表现年龄。
## The authority supplies age; this node never advances battle state.
const ROOT := "res://assets/effects/stasis/native/"
static var _datasets: Dictionary = {}
static var _meshes: Dictionary = {}
var _data: Dictionary
var _materials: Array = []
var _pools: Array = []
var _age := 0.0
var _frame := -1
var projection_basis := Basis.IDENTITY
var flight_position_at: Callable
var _source := ""
var _trails: Dictionary = {}

static func prewarm(source: String) -> Dictionary:
	if _datasets.has(source): return _datasets[source]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + source + "/sampled.json"))
	var materials: Array = []
	for e in data.emitters:
		var mesh_path: String = e.mesh_path
		if not _meshes.has(mesh_path): _meshes[mesh_path] = _mesh(mesh_path)
		materials.append(_material(e, source))
	_datasets[source] = {"data": data, "materials": materials}
	return _datasets[source]

func setup_native(source: String, unit_scale: float) -> void:
	_source = source
	var prepared := prewarm(source)
	_data = prepared.data
	_materials = prepared.materials
	scale = Vector3.ONE * unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func advance(delta: float) -> void:
	seek(_age + delta)

func seek(age: float) -> void:
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _data.frames.size() - 1)
	if frame == _frame: return
	_frame = frame
	var values: Array = _data.frames[frame]
	for emitter_index in values.size():
		var e: Dictionary = _data.emitters[emitter_index]
		var pool: Array = _pools[emitter_index]
		var particles: Array = values[emitter_index]
		if _source == "flight" and e.trail != null:
			_sync_trail(emitter_index, e, particles)
			continue
		while pool.size() < particles.size():
			var item := MeshInstance3D.new()
			item.mesh = _meshes[e.mesh_path]
			item.material_override = _materials[emitter_index].duplicate()
			item.material_override.set_shader_parameter("projection_basis", projection_basis)
			# Only footprint geometry deforms; symbols and free particle quads retain their native shape.
			var footprint_shape := _source == "warning" or (_source == "impact" and String(e.name) in ["light", "nova_ground", "Black_Ground", "distort", "up_glow"])
			item.material_override.set_shader_parameter("shape_basis", projection_basis if footprint_shape else Basis.IDENTITY)
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			item.custom_aabb = AABB(Vector3(-2500, -2500, -2500), Vector3(5000, 5000, 5000))
			add_child(item)
			pool.append(item)
		for j in pool.size():
			var item: MeshInstance3D = pool[j]
			item.visible = j < particles.size() and _age <= float(_data.duration)
			if item.visible:
				var sample := _sample(e, particles[j])
				item.material_override.set_shader_parameter("p", PackedFloat32Array(sample))
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = sample
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

static func _material(e: Dictionary, source: String) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	var shader_name := "warp" if e.distortion != null else ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix"))
	# 法术层保留原绘制顺序，并在单位与地表上保持可见。
	shader_name += "_no_depth"
	result.shader = load(ROOT + shader_name + ".gdshader")
	result.render_priority = clampi(100 + (int(e.rank) + 1000000 if int(e.rank) < 0 else int(e.rank)), -128, 127)
	# Original distortionMode=2 is the early, pre-particle phase.
	if e.distortion != null: result.render_priority = -110
	var params := {
		"is_mesh":e.meshDraw, "cull_mesh":e.backfaceCull, "billboard":e.billboard, "directed":e.directionOriented,
		"is_ray":e.ray, "reach":e.reach, "pivot":0.5 if e.pivotUp else 0.0,
		"ground_layer":e.groundLayer or (source == "impact" and String(e.name) in ["light", "nova_ground", "Black_Ground", "distort"]), "cell":_v2(e.cell), "cell_mult":_v2(e.cellMult),
		"uv_center":_v2(e.uv.center), "uv_flip":Vector2(float(e.uv.flipU),float(e.uv.flipV)),
		"address_mode":int(e.uv.addressMode), "alpha_ref":e.alphaRef,
		"has_mult":not e.mult_path.is_empty(), "has_ramp":not e.color_path.is_empty() and e.erosion == null,
		"has_erosion":e.erosion != null, "has_soft":false, "push_pull":e.depthPushPull,
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

## 原定义bindWeight=0的粒子锚定出生时的弹体位置，不能被当前弹体拖走。
func _sample(emitter: Dictionary, values: Array) -> Array:
	if _source != "flight" or not flight_position_at.is_valid(): return values
	var weight := float(emitter.bindWeight.constant[0])
	if weight >= 1.0: return values
	var birth := float(_data.birthTimes[str(int(emitter.index)) + ":" + str(int(values[0]))])
	var offset: Vector3 = (flight_position_at.call(birth) - global_position) / scale.x * (1.0 - weight)
	var result := values.duplicate()
	result[1] += offset.x
	result[2] += offset.y
	result[3] += offset.z
	return result

## 原版ArbitraryTrail两个发射器用存活粒子形成带状网格，保留原纹理/宽度/颜色/寿命。
func _sync_trail(index: int, emitter: Dictionary, particles: Array) -> void:
	if not _trails.has(index):
		var item := MeshInstance3D.new()
		item.mesh = ImmediateMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/effects/stasis/native/trail.gdshader")
		mat.set_shader_parameter("source_texture", load(emitter.texture_path))
		mat.render_priority = 100
		item.material_override = mat
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(item)
		_trails[index] = item
	var item: MeshInstance3D = _trails[index]
	var mesh: ImmediateMesh = item.mesh
	mesh.clear_surfaces()
	if particles.size() < 2 or not flight_position_at.is_valid(): return
	var ordered := particles.duplicate()
	ordered.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var points: Array[Vector3] = []
	var samples: Array = []
	for values in ordered:
		var sample := _sample(emitter, values)
		samples.append(sample)
		points.append(Vector3(sample[1], sample[2], sample[3]))
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for j in points.size():
		var tangent := points[mini(j + 1, points.size() - 1)] - points[maxi(j - 1, 0)]
		var facing := to_local(camera.global_position) - points[j]
		var side := tangent.cross(facing).normalized()
		if side.length_squared() < 0.001: side = Vector3.RIGHT
		var sample: Array = samples[j]
		var width := float(sample[4])
		mesh.surface_set_color(Color(sample[7], sample[8], sample[9], sample[10]))
		mesh.surface_set_uv(Vector2(float(j) / (points.size() - 1), 0))
		mesh.surface_add_vertex(points[j] - side * width)
		mesh.surface_set_uv(Vector2(float(j) / (points.size() - 1), 1))
		mesh.surface_add_vertex(points[j] + side * width)
	mesh.surface_end()
